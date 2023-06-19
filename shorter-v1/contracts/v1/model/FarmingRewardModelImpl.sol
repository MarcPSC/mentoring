// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeERC20 as SafeToken} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../libraries/AllyLibrary.sol";
import "../../interfaces/v1/model/IFarmingRewardModel.sol";
import "../../interfaces/IShorterBone.sol";
import "../../criteria/ChainSchema.sol";
import "../../storage/model/FarmingRewardModelStorage.sol";
import "../../util/BoringMath.sol";

contract FarmingRewardModelImpl is ChainSchema, FarmingRewardModelStorage, IFarmingRewardModel {
    using BoringMath for uint256;
    using SafeToken for ISRC20;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    /// #if_succeeds {:msg "Caller is a Farming"} msg.sender == address(farming);
    function harvestByPool(address user) external override returns (uint256 rewards) {
            require(msg.sender == address(farming), "FarmingReward: Caller is not Farming");
        rewards = _harvest(user);
    }

    /// #if_succeeds {:msg "Caller is either Farming or User"} msg.sender == address(farming) || msg.sender == user;
    function harvest(address user) external override returns (uint256 rewards) {
        require(msg.sender == address(farming) || msg.sender == user, "FarmingReward: Caller is neither Farming nor User");
        rewards = _harvest(user);
        farming.harvest(farming.getTokenId(), user);
    }

    /// #if_succeeds {:msg "1.Result correct"} _getUserStakedAmount(_user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0 ==> unLockRewards_ == 0 && rewards_ == 0;
    /// #if_succeeds {:msg "2.Result correct"} !(_getUserStakedAmount(_user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(_user) > 0 && (_getLockedBalanceOf(_user).div(_getUnlockSpeed(_getUserStakedAmount(_user)))).add(userLastRewardBlock[_user]) > block.number ==> (block.number.sub(userLastRewardBlock[_user])).mul(_getUnlockSpeed(_getUserStakedAmount(_user))) == unLockRewards_ && rewards_ == 0;
    /// #if_succeeds {:msg "3.Result correct"} !(_getUserStakedAmount(_user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(_user) > 0 && (_getLockedBalanceOf(_user).div(_getUnlockSpeed(_getUserStakedAmount(_user)))).add(userLastRewardBlock[_user]) <= block.number ==> _getLockedBalanceOf(_user) == unLockRewards_ && rewards_ == (block.number.sub((_getLockedBalanceOf(_user).div(_getUnlockSpeed(_getUserStakedAmount(_user)))).add(userLastRewardBlock[_user]))).mul(_getBaseSpeed(_getUserStakedAmount(_user)));
    /// #if_succeeds {:msg "4.Result correct"} !(_getUserStakedAmount(_user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(_user) <= 0 ==> 0 == unLockRewards_ && rewards_ == (block.number.sub(userLastRewardBlock[_user])).mul(_getBaseSpeed(_getUserStakedAmount(_user)));
    function pendingReward(address _user) public view override returns (uint256 unLockRewards_, uint256 rewards_) {
        uint256 userStakedAmount = _getUserStakedAmount(_user);

        if (userStakedAmount == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) {
            return (0, 0);
        }

        uint256 userLockedAmount = _getLockedBalanceOf(_user);

        if (userLockedAmount > 0) {
            uint256 unlockedSpeed = _getUnlockSpeed(userStakedAmount);
            uint256 estimateEndBlock = (userLockedAmount.div(unlockedSpeed)).add(userLastRewardBlock[_user]);
            if (estimateEndBlock > block.number) {
                unLockRewards_ = (block.number.sub(userLastRewardBlock[_user])).mul(unlockedSpeed);
                return (unLockRewards_, 0);
            } else {
                unLockRewards_ = userLockedAmount;
                uint256 baseSpeed = _getBaseSpeed(userStakedAmount);
                rewards_ = (block.number.sub(estimateEndBlock)).mul(baseSpeed);
                return (unLockRewards_, rewards_);
            }
        }

        uint256 baseSpeed = _getBaseSpeed(userStakedAmount);
        rewards_ = (block.number.sub(userLastRewardBlock[_user])).mul(baseSpeed);
    }

    /// #if_succeeds {:msg "1.Result correct"} _getUserStakedAmount(user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0 ==> speed == 0;
    /// #if_succeeds {:msg "2.Result correct"} !(_getUserStakedAmount(user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(user) <= 0 ==> speed == _getBaseSpeed(_getUserStakedAmount(user));
    /// #if_succeeds {:msg "3.Result correct"} !(_getUserStakedAmount(user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(user) > 0 && (_getLockedBalanceOf(user).div(speed)).add(userLastRewardBlock[user]) <= block.number ==> speed == _getBaseSpeed(_getUserStakedAmount(user));
    /// #if_succeeds {:msg "4.Result correct"} !(_getUserStakedAmount(user) == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) && _getLockedBalanceOf(user) > 0 && (_getLockedBalanceOf(user).div(speed)).add(userLastRewardBlock[user]) > block.number ==> speed == _getUnlockSpeed(_getUserStakedAmount(user));
    function getSpeed(address user) external view returns (uint256 speed) {
        uint256 userLockedAmount = _getLockedBalanceOf(user);
        uint256 userStakedAmount = _getUserStakedAmount(user);

        if (userStakedAmount == 0 || maxLpSupply == 0 || maxUnlockSpeed == 0) {
            return 0;
        }

        if (userLockedAmount > 0) {
            speed = _getUnlockSpeed(userStakedAmount);
            uint256 estimateEndBlock = (userLockedAmount.div(speed)).add(userLastRewardBlock[user]);

            if (estimateEndBlock > block.number) {
                return speed;
            }
        }

        speed = _getBaseSpeed(userStakedAmount);
    }

    /// #if_succeeds {:msg "Max unlock speed updated"} maxUnlockSpeed == _maxUnlockSpeed;
        function setMaxUnlockSpeed(uint256 _maxUnlockSpeed) external isManager {
        maxUnlockSpeed = _maxUnlockSpeed;
    }

    /// #if_succeeds {:msg "Max lp supply updated"} maxLpSupply == _maxLpSupply;
        function setMaxLpSupply(uint256 _maxLpSupply) external isManager {
        maxLpSupply = _maxLpSupply;
    }

    function _getBaseSpeed(uint256 userStakedAmount) internal view returns (uint256 speed) {
        if (userStakedAmount >= maxLpSupply) {
            return maxUnlockSpeed;
        }

        return maxUnlockSpeed.mul(userStakedAmount).div(maxLpSupply);
    }

    /// #if_succeeds {:msg "1.Result correct"} userStakedAmount.mul(2 ** 10) < maxLpSupply ==> $result == userStakedAmount.mul(2 ** 10).mul(maxUnlockSpeed).div(maxLpSupply).div(10);
    /// #if_succeeds {:msg "2.Result correct"} userStakedAmount.mul(2 ** 10) >= maxLpSupply && userStakedAmount >= maxLpSupply ==> $result == maxUnlockSpeed;
    function _getUnlockSpeed(uint256 userStakedAmount) internal view returns (uint256 speed) {
        if (userStakedAmount.mul(2 ** 10) < maxLpSupply) {
            return userStakedAmount.mul(2 ** 10).mul(maxUnlockSpeed).div(maxLpSupply).div(10);
        }

        if (userStakedAmount >= maxLpSupply) {
            return maxUnlockSpeed;
        }

        for (uint256 i = 0; i < 10; i++) {
            if (userStakedAmount.mul(2 ** (9 - i)) < maxLpSupply) {
                uint256 _speed = (userStakedAmount.mul(2 ** (10 - i)).sub(maxLpSupply)).mul(maxUnlockSpeed).div(maxLpSupply).div(10);
                speed = speed.add(_speed);
                break;
            }

            speed = speed.add(maxUnlockSpeed.div(10));
        }
    }

    function _getUserStakedAmount(address _user) internal view returns (uint256 userStakedAmount_) {
        userStakedAmount_ = farming.getUserStakedAmount(_user);
    }

    function _getLockedBalanceOf(address account) internal view returns (uint256) {
        return ipistrToken.lockedBalanceOf(account);
    }

    /// #if_succeeds {:msg "User last reward block updated"} userLastRewardBlock[user] == block.number;
    /// #if_succeeds {:msg "Result correct"} let _unLockRewards, _rewards := pendingReward(user) in $result == _unLockRewards + _rewards;
    /// #if_succeeds {:msg "User balance unlocked"} let _unLockRewards, _ := pendingReward(user) in _unLockRewards > 0 && old(ipistrToken.lockedBalanceOf(user)) == ipistrToken.lockedBalanceOf(user) + _unLockRewards;
    function _harvest(address user) internal returns (uint256 rewards) {
        (uint256 _unLockRewards, uint256 _rewards) = pendingReward(user);
        if (_unLockRewards > 0) {
            ipistrToken.unlockBalance(user, _unLockRewards);
        }

        if (_rewards > 0) {
            shorterBone.mintByAlly(AllyLibrary.FARMING_REWARD, user, _rewards);
        }

        rewards = _unLockRewards.add(_rewards);
        userLastRewardBlock[user] = block.number;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "newFarming is not zero address"} newFarming != address(0);
    function setFarming(address newFarming) external isSavior {
        require(newFarming != address(0), "PoolReward: newFarming is zero address");
        farming = IFarming(newFarming);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Max lp supply setted"} maxLpSupply == 1e24;
    /// #if_succeeds {:msg "Max unlock speed setted"} maxUnlockSpeed == 1e17;
    /// #if_succeeds {:msg "Initialized"} _initialized;
    /// #if_succeeds {:msg "Not already initialized"} !old(_initialized);
    function initialize(address _shorterBone, address _farming, address _ipistrToken) external isSavior {
        require(!_initialized, "FarmingReward: Already initialized");
        maxLpSupply = 1e24;
        maxUnlockSpeed = 1e17;
        shorterBone = IShorterBone(_shorterBone);
        farming = IFarming(_farming);
        ipistrToken = IIpistrToken(_ipistrToken);

        _initialized = true;
    }
}
