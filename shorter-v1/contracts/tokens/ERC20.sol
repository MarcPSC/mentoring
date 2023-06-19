// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "../interfaces/ISRC20.sol";
import "../util/BoringMath.sol";

// Data part taken out for building of contracts that receive delegate calls
contract ERC20Data {
    /// @notice owner > balance mapping.
    mapping(address => uint256) public balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;
}

/// @notice Enhanced ERC20 implementation
///#invariant unchecked_sum(balanceOf) == _totalSupply;
///#if_succeeds {:msg "The sum of balances doesn't change over time"} unchecked_sum(balanceOf) == old(unchecked_sum(balanceOf)) || msg.sig == bytes4(0x00000000);
contract ERC20 is ISRC20 {
    using BoringMath for uint256;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;

    /// @notice owner > balance mapping.
    mapping(address => uint256) public override balanceOf;
    /// @notice owner > spender > allowance mapping.
    mapping(address => mapping(address => uint256)) public override allowance;
    /// @notice owner > nonce mapping. Used in `permit`.
    mapping(address => uint256) public nonces;

    event Transfer(address indexed _from, address indexed _to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 value);

    /**
     * @dev Returns the name of the token.
     */
    function name() external view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /// #if_succeeds {:msg "Balance added to to address"} balanceOf[to] == old(balanceOf[to]) + value;
    /// #if_succeeds {:msg "Balance substracted from from address"} balanceOf[from] == old(balanceOf[from]) - value;
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /// #if_succeeds {:msg "Balance added to to address"} balanceOf[to] == old(balanceOf[to]) + value;
    /// #if_succeeds {:msg "Balance substracted from from address"} balanceOf[msg.sender] == old(balanceOf[msg.sender]) - value;
    /// #if_succeeds {:msg "Transaction marked as done"} $result == true;
    function transfer(address to, uint256 value) external virtual override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// #if_succeeds {:msg "Balance added to to address"} balanceOf[to] == old(balanceOf[to]) + value;
    /// #if_succeeds {:msg "Balance substracted from from address"} balanceOf[from] == old(balanceOf[from]) - value;
    /// #if_succeeds {:msg "Allowance modified if existed"} allowance[from][msg.sender] != uint256(-1) ==> allowance[from][msg.sender] == allowance[from][msg.sender].sub(value);
    /// #if_succeeds {:msg "Transaction marked as done"} $result == true;
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external virtual override returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice Approves `amount` from sender to be spend by `spender`.
    /// @param spender Address of the party that can draw from msg.sender's account.
    /// @param amount The maximum collective amount that `spender` can draw.
    /// @return (bool) Returns True if approved.
    /// #if_succeeds {:msg "Allowance modified"} allowance[msg.sender][spender] == amount;
    /// #if_succeeds {:msg "Updated allowance"} $result == true;
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /// #if_succeeds {:msg "Supply modified"} old(_totalSupply) + amount == _totalSupply;
    /// #if_succeeds {:msg "Mint amount not too large"} _totalSupply+ (amount) >= _totalSupply;
    /// #if_succeeds {:msg "Amount added to user balance"} old(balanceOf[user]) == balanceOf[user] - amount;
    function _mint(address user, uint256 amount) internal {
        uint256 newTotalSupply = _totalSupply.add(amount);
        require(newTotalSupply >= _totalSupply, "Mint amount too large");
        _totalSupply = newTotalSupply;
        balanceOf[user] = balanceOf[user].add(amount);
        emit Transfer(address(0), user, amount);
    }

    /// #if_succeeds {:msg "Supply modified"}  old(_totalSupply) - amount == _totalSupply;
    /// #if_succeeds {:msg "Burnt amount not too large"} old(balanceOf[user]) >= amount;
    /// #if_succeeds {:msg "Amount substracted from user balance"} old(balanceOf[user]) == balanceOf[user] + amount;
    function _burn(address user, uint256 amount) internal {
        require(balanceOf[user] >= amount, "Burn amount too large");
        _totalSupply = _totalSupply.sub(amount);
        balanceOf[user] = balanceOf[user].sub(amount);
        emit Transfer(user, address(0), amount);
    }
}
