// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/governance/IIpistrToken.sol";
import "../criteria/ChainSchema.sol";
import "../criteria/Affinity.sol";
import "../storage/PrometheusStorage.sol";
import "../tokens/ERC20.sol";

/// @notice Governance token of Shorter
contract IpistrTokenImpl is ChainSchema, ERC20, PrometheusStorage, IIpistrToken {
    using BoringMath for uint256;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    function spendableBalanceOf(address account) external view override returns (uint256 _balanceOf) {
        _balanceOf = _spendableBalanceOf(account);
    }

    function lockedBalanceOf(address account) external view override returns (uint256) {
        return _lockedBalances[account];
    }

    /// #if_succeeds {:msg "sufficient spendable amount"} _spendableBalanceOf(_msgSender()) >= value;
    function transfer(address to, uint256 value) external override returns (bool) {
        require(_spendableBalanceOf(_msgSender()) >= value, "IPISTR: Insufficient spendable amount");
        _transfer(_msgSender(), to, value);
        return true;
    }

    /// #if_succeeds {:msg "sufficient spendable amount"} _spendableBalanceOf(from) >= value;
    /// #if_succeeds {:msg "allowance updated"} allowance[from][_msgSender()] != uint256(-1) ==> allowance[from][_msgSender()] == old(allowance[from][_msgSender()]) - (value);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        require(_spendableBalanceOf(from) >= value, "IPISTR: Insufficient spendable amount");

        if (allowance[from][_msgSender()] != uint256(-1)) {
            allowance[from][_msgSender()] = allowance[from][_msgSender()].sub(value);
        }

        _transfer(from, to, value);
        return true;
    }

        function mint(address to, uint256 amount) external override isManager {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /// #if_succeeds {:msg "Locked ammount of user updated"} _lockedBalances[user] == (_lockedBalances[user]) + (amount);
        function setLocked(address user, uint256 amount) external override isManager {
        _lockedBalances[user] = _lockedBalances[user].add(amount);
        emit SetLocked(user, amount);
    }

    /// #if_succeeds {:msg "Suficient locked ammount"} _lockedBalances[account] >= amount;
    /// #if_succeeds {:msg "Ammount unlocked from account"} _lockedBalances[account] == (_lockedBalances[account]) - (amount);
        function unlockBalance(address account, uint256 amount) external override isManager {
        require(_lockedBalances[account] >= amount, "IPISTR: Insufficient lockedBalances");
        _lockedBalances[account] = _lockedBalances[account].sub(amount);
        emit Unlock(account, amount);
    }

        function burn(address account, uint256 amount) external isManager {
        _burn(account, amount);
        emit Burn(account, amount);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Decimals setted"} _decimals == 18;
    function initialize() external isSavior {
        _name = "IPI Shorter";
        _symbol = "IPISTR";
        _decimals = 18;
    }

    /// #if_succeeds {:msg "Account balance minus locked returned"} $result == balanceOf[account] - (_lockedBalances[account]);
    function _spendableBalanceOf(address account) internal view returns (uint256) {
        return balanceOf[account].sub(_lockedBalances[account]);
    }
}
