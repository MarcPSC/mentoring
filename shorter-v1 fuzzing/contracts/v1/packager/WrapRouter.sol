// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/v1/IPoolGuardian.sol";
import "../../util/BoringMath.sol";
import "../../util/Ownable.sol";
import "../../util/Pausable.sol";

contract WrapRouter is Ownable, Pausable {
    using BoringMath for uint256;

    address public immutable poolGuardian;
    address public immutable wrappedEtherAddr;
    mapping(address => uint256) public controvertibleAmounts;
    mapping(address => mapping(address => uint256)) private transferableAmounts;
    mapping(address => address[]) private grandeties;
    mapping(address => address) public inherits;
    mapping(address => uint256) private insideLobes;
    mapping(address => uint256) private outsideLobes;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    modifier onlyStrPool(uint256 _poolId) {
        (, address strPool, IPoolGuardian.PoolStatus stateFlag) = IPoolGuardian(poolGuardian).getPoolInfo(_poolId);
        require(stateFlag != IPoolGuardian.PoolStatus.GENESIS, "WrapRouter: Invalid status");
        require(strPool == msg.sender, "WrapRouter: Caller is not strPool");
        _;
    }

    constructor(address _poolGuardian, address _wrappedEtherAddr) public {
        poolGuardian = _poolGuardian;
        wrappedEtherAddr = _wrappedEtherAddr;
    }

    /// #if_succeeds {:msg "inherited token returned"} msg.sender != account ==> transferableAmounts[account][msg.sender] == old(transferableAmounts[account][msg.sender]) + (amount);
    /// #if_succeeds {:msg "Convertible ammount of user updated"} controvertibleAmounts[msg.sender] == old(controvertibleAmounts[msg.sender]) + (amount);
    function wrap(
        uint256 poolId,
        address token,
        address account,
        uint256 amount,
        address _stakedToken
    ) external whenNotPaused onlyStrPool(poolId) {
        if (token != address(_stakedToken)) return;
        if (msg.sender != account) {
            transferableAmounts[account][msg.sender] = transferableAmounts[account][msg.sender].add(amount);
        }
        controvertibleAmounts[msg.sender] = controvertibleAmounts[msg.sender].add(amount);
        _deposit(token, msg.sender, amount);
        IWrappedToken(inherits[token]).mint(msg.sender, amount);
    }

    /// #if_succeeds {:msg "inherited token returned"} msg.sender != account && old(transferableAmounts[account][msg.sender]) < burnAmount ==> $result == inherits[token];
    /// #if_succeeds {:msg "Transfereable ammount updated"} msg.sender != account && old(transferableAmounts[account][msg.sender]) >= burnAmount ==> transferableAmounts[account][msg.sender] == old(transferableAmounts[account][msg.sender])-(burnAmount);
    /// #if_succeeds {:msg "Sufficient liquidity"} msg.sender == account ==> amount <= controvertibleAmounts[msg.sender];
    /// #if_succeeds {:msg "Wrapped tokens removed from ballance"} controvertibleAmounts[msg.sender] == old(controvertibleAmounts[msg.sender]) + (amount);
    function unwrap(
        uint256 poolId,
        address token,
        address account,
        uint256 amount,
        uint256 burnAmount
    ) external whenNotPaused onlyStrPool(poolId) returns (address stakedToken) {
        if (msg.sender == account) {
            require(amount <= controvertibleAmounts[msg.sender], "WrapRouter unwrap: Insufficient liquidity");
        } else {
            uint256 stakedBal = transferableAmounts[account][msg.sender];
            if (stakedBal < burnAmount) {
                return inherits[token];
            }
            transferableAmounts[account][msg.sender] = stakedBal.sub(burnAmount);
        }

        controvertibleAmounts[msg.sender] = controvertibleAmounts[msg.sender].sub(amount);
        IWrappedToken(inherits[token]).burn(msg.sender, amount);
        _withdraw(token, msg.sender, amount);
        stakedToken = token;
    }

    /// #if_succeeds {:msg "sufficient balance"} old(transferableAmounts[from][msg.sender]) >= amount;
    /// #if_succeeds {:msg "Amount substracte from from address"} transferableAmounts[from][msg.sender] == old(transferableAmounts[from][msg.sender]) - (amount);
    /// #if_succeeds {:msg "Amount added to to address"} transferableAmounts[to][msg.sender] == old(transferableAmounts[to][msg.sender]) + (amount);
    function transferTokenShare(
        uint256 poolId,
        address from,
        address to,
        uint256 amount
    ) external onlyStrPool(poolId) {
        require(transferableAmounts[from][msg.sender] >= amount, "WrapRouter transferTokenShare: Insufficient balance");
        transferableAmounts[from][msg.sender] = transferableAmounts[from][msg.sender].sub(amount);
        transferableAmounts[to][msg.sender] = transferableAmounts[to][msg.sender].add(amount);
    }

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    /// #if_succeeds {:msg "All grandeties added"} forall(uint i in 1..._grandeties.length-1) grandeties[_token][grandeties[_token].length-1] == _grandeties[i];
    function setGrandeties(address _token, address[] calldata _grandeties) external onlyOwner {
        uint256 grandetiesSize = _grandeties.length;
        for (uint256 i = 0; i < grandetiesSize; i++) {
            grandeties[_token].push(_grandeties[i]);
        }
    }

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    /// #if_succeeds {:msg "All wraped tokens linked"} forall(uint i in 1..._tokens.length-1) inherits[_tokens[i]] == _wrappedTokens[i];
    /// #if_succeeds {:msg "Valid params"} _tokens.length == _wrappedTokens.length;
    function setWrappedTokens(address[] calldata _tokens, address[] calldata _wrappedTokens) external onlyOwner {
        require(_tokens.length == _wrappedTokens.length, "WrapRouter: Invaild params");

        for (uint256 i = 0; i < _tokens.length; i++) {
            inherits[_tokens[i]] = _wrappedTokens[i];
        }
    }

    function getTransferableAmount(address account, address strPool) external view returns (uint256 amount) {
        return transferableAmounts[account][strPool];
    }

    /// #if_succeeds {:msg "Returned staked Wrapped ether"} token == wrappedEtherAddr && inherits[token] != address(0) ==> stakedToken == _wrappableWithETH(strPool, account, value);
    /// #if_succeeds {:msg "Returned staked Wrapped token"} token != wrappedEtherAddr && inherits[token] != address(0) ==> stakedToken == _wrappableWithToken(token, strPool, account, amount);
    function wrappable(
        address token,
        address strPool,
        address account,
        uint256 amount,
        uint256 value
    ) public view returns (address stakedToken) {
        if (token == wrappedEtherAddr && inherits[token] != address(0)) {
            stakedToken = _wrappableWithETH(strPool, account, value);
        }
        if (token != wrappedEtherAddr && inherits[token] != address(0)) {
            stakedToken = _wrappableWithToken(token, strPool, account, amount);
        }
    }

    /// #if_succeeds {:msg "Returns linked wraped token"} transferableAmounts[account][msg.sender] < amount ==> $result == inherits[token];
    /// #if_succeeds {:msg "Returns null address"} transferableAmounts[account][msg.sender] >= amount &&  controvertibleAmounts[msg.sender] < amount ==> $result == address(0);
    /// #if_succeeds {:msg "Returns token address"} transferableAmounts[account][msg.sender] >= amount &&  controvertibleAmounts[msg.sender] >= amount ==> $result == token;
    function getUnwrappableAmount(
        address account,
        address token,
        uint256 amount
    ) external view returns (address) {
        uint256 transferableAmount = transferableAmounts[account][msg.sender];
        uint256 controvertibleAmount = controvertibleAmounts[msg.sender];
        if (transferableAmount < amount) {
            return inherits[token];
        }
        return controvertibleAmount < amount ? address(0) : token;
    }

    function getUnwrappableAmountByPercent(
        uint256 percent,
        address account,
        address token,
        uint256 amount,
        uint256 totalBorrowAmount
    )
        external
        view
        returns (
            address stakedToken,
            uint256 withdrawAmount,
            uint256 burnAmount,
            uint256 userShare
        )
    {
        uint256 transferableAmount = transferableAmounts[account][msg.sender];
        uint256 controvertibleAmount = controvertibleAmounts[msg.sender];
        uint256 _totalStakedTokenAmount = controvertibleAmount.add(totalBorrowAmount);

        userShare = _totalStakedTokenAmount > 0 ? transferableAmount.mul(1e18).div(_totalStakedTokenAmount) : 0;

        if (transferableAmount > 0) {
            stakedToken = token;
            withdrawAmount = controvertibleAmount.mul(userShare).mul(percent).div(1e20);
            burnAmount = transferableAmount.mul(percent).div(100);
        } else {
            stakedToken = inherits[token];
            withdrawAmount = amount.mul(percent).div(100);
            burnAmount = withdrawAmount;
        }
    }

    /// #if_succeeds {:msg "Grandetie is not zero address"} grandeties[token][old(insideLobes[token])] != address(0);
    /// #if_succeeds {:msg "Token inside lobes updated"} insideLobes[token] == old(insideLobes[token]) + 1 % grandeties[token].length;
    function _deposit(
        address token,
        address from,
        uint256 amount
    ) internal {
        address grandetie = grandeties[token][insideLobes[token]];
        require(grandetie != address(0), "WrapRouter: Grandetie is zero address");
        _safeTransferFrom(token, from, grandetie, amount);
        insideLobes[token] = insideLobes[token].add(1) % grandeties[token].length;
    }


    function _withdraw(
        address token,
        address to,
        uint256 amount
    ) internal {
        uint256 lobe = outsideLobes[token];
        uint256 grandetieSize = grandeties[token].length;

        for (uint256 i = 0; i < grandetieSize; i++) {
            uint256 slot = lobe.add(i) % grandetieSize;
            address grandetie = grandeties[token][slot];
            uint256 grandetieBal = IERC20(token).balanceOf(grandetie);

            if (grandetieBal >= amount) {
                _safeTransferFrom(token, grandetie, to, amount);
                outsideLobes[token] = slot.add(1) % grandetieSize;
                return;
            }
            if (grandetieBal != 0) {
                _safeTransferFrom(token, grandetie, to, grandetieBal);
                amount = amount.sub(grandetieBal);
            }
        }
    }

    /// #if_succeeds {:msg "Amount of token substracted from from address"} IERC20(token).balanceOf(from) == old(IERC20(token).balanceOf(from)) - amount;
    /// #if_succeeds {:msg "Amount of token added to to address"} IERC20(token).balanceOf(to) == old(IERC20(token).balanceOf(to)) + amount;
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 token0Bal = IERC20(token).balanceOf(from);
        uint256 token1Bal = IERC20(token).balanceOf(to);
        (bool success, ) = token.call(abi.encodeWithSelector(SELECTOR, from, to, amount));
        require(success, "WrapRouter: Transfer failed");
        /// #assert success;
        uint256 token0Aft = IERC20(token).balanceOf(from);
        uint256 token1Aft = IERC20(token).balanceOf(to);
        if (token0Aft.add(amount) != token0Bal || token1Bal.add(amount) != token1Aft) {
            revert("WrapRouter: Balances check failed");
        }
    }

    /// #if_succeeds {:msg "Token returned"} IERC20(token).balanceOf(account) >= amount ==> $result == token;
    /// #if_succeeds {:msg "Wrappable token linked to passed token returned"} IERC20(inherits[token]).balanceOf(account) >= amount && strPool != account ==> $result == inherits[token];
    function _wrappableWithToken(
        address token,
        address strPool,
        address account,
        uint256 amount
    ) internal view returns (address) {
        uint256 balance0 = IERC20(token).balanceOf(account);
        if (balance0 >= amount) {
            return token;
        }
        uint256 balance1 = IERC20(inherits[token]).balanceOf(account);
        if (balance1 >= amount && strPool != account) {
            return inherits[token];
        }
    }

    /// #if_succeeds {:msg "Wrapped Ether address returned"} value > 0 ==> $result == wrappedEtherAddr;
    /// #if_succeeds {:msg "Wrappable token linked to Wrapped Ether address returned"} IERC20(inherits[wrappedEtherAddr]).balanceOf(account) >= value && strPool != account ==> $result == inherits[wrappedEtherAddr];
    function _wrappableWithETH(
        address strPool,
        address account,
        uint256 value
    ) internal view returns (address) {
        if (value > 0) {
            return wrappedEtherAddr;
        }
        uint256 balance1 = IERC20(inherits[wrappedEtherAddr]).balanceOf(account);
        if (balance1 >= value && strPool != account) {
            return inherits[wrappedEtherAddr];
        }
    }
}

interface IWrappedToken {
    function mint(address to, uint256 amount) external;

    function burn(address user, uint256 amount) external;
}
