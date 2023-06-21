// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import {SafeERC20 as SafeToken} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../interfaces/ISRC20.sol";
import "../../util/BoringMath.sol";
import "../../util/Ownable.sol";
import "../../util/Pausable.sol";
import "../../util/Whitelistable.sol";
import "../../storage/WrappedTokenStorage.sol";

contract WrappedTokenImpl is Ownable, Pausable, Whitelistable, WrappedTokenStorage {
    using BoringMath for uint256;
    using SafeToken for ISRC20;

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// #if_succeeds {:msg "Value substracted from from"} balanceOf[from] == old(balanceOf[from]) - (value);
    /// #if_succeeds {:msg "Value added to to"} balanceOf[to] == old(balanceOf[to]) + (value);
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /// #if_succeeds {:msg "Value substracted from sender"} balanceOf[msg.sender] == old(balanceOf[msg.sender]) - (value);
    /// #if_succeeds {:msg "Value added to to"} balanceOf[to] == old(balanceOf[to]) + (value);
    /// #if_succeeds {:msg "Sender is in whitelist"} whitelisted[msg.sender]; 
    /// #if_succeeds {:msg "to is in whitelist"} whitelisted[to]; 
    function transfer(address to, uint256 value) external whenNotPaused inWhitelist(msg.sender) inWhitelist(to) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// #if_succeeds {:msg "to is in whitelist"} whitelisted[to]; 
    /// #if_succeeds {:msg "from is in whitelist"} whitelisted[from]; 
    /// #if_succeeds {:msg "Allowance updated"} allowance[from][msg.sender] != uint256(-1) ==> allowance[from][msg.sender] == old(allowance[from][msg.sender]) - (value); 
    /// #if_succeeds {:msg "Value substracted from from"} balanceOf[from] == old(balanceOf[from]) - (value);
    /// #if_succeeds {:msg "Value added to to"} balanceOf[to] == old(balanceOf[to]) + (value);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external whenNotPaused inWhitelist(from) inWhitelist(to) returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }

        _transfer(from, to, value);
        return true;
    }

    /// #if_succeeds {:msg "Allowance updated"} amount == old(allowance[msg.sender][spender]); 
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// #if_succeeds {:msg "Caller is a minter"} minter[msg.sender];
    /// #if_succeeds {:msg "Token added to user balance"} balanceOf[to] == old(balanceOf[to]) + (amount);
    function mint(address to, uint256 amount) external {
        require(minter[msg.sender], "WrappedToken: Caller is not Minter");
        _mint(to, amount);
    }

    /// #if_succeeds {:msg "Caller is a minter"} minter[msg.sender]; 
    /// #if_succeeds {:msg "Token substracted from user balance"} balanceOf[user] == old(balanceOf[user]) - (amount);
    function burn(address user, uint256 amount) external {
        require(minter[msg.sender], "WrappedToken: Caller is not Minter");
        _burn(user, amount);
    }

    /// #if_succeeds {:msg "Token added to user balance"} balanceOf[user] == old(balanceOf[user]) + (amount);
    function _mint(address user, uint256 amount) internal {
        balanceOf[user] = balanceOf[user].add(amount);
        emit Transfer(address(0), user, amount);
    }

    /// #if_succeeds {:msg "Amount not too large"} balanceOf[user] >= amount; 
    /// #if_succeeds {:msg "Token substracted from user balance"} balanceOf[user] == old(balanceOf[user]) - (amount);
    function _burn(address user, uint256 amount) internal {
        require(balanceOf[user] >= amount, "WrappedToken: Amount too large");
        balanceOf[user] = balanceOf[user].sub(amount);
        emit Transfer(user, address(0), amount);
    }

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    /// #if_succeeds {:msg "Minter added"} minter[newMinter] == flag;
    function setMinter(address newMinter, bool flag) external onlyOwner {
        minter[newMinter] = flag;
    }

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    /// #if_succeeds {:msg "Decimals setted"} _decimals == uint8(decimals_);
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) external onlyOwner {
        _name = name_;
        _symbol = symbol_;
        _decimals = uint8(decimals_);
    }
}
