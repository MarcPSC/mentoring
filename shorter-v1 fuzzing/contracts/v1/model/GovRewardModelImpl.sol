// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "../../libraries/AllyLibrary.sol";
import "../../interfaces/IShorterBone.sol";
import "../../interfaces/governance/ICommittee.sol";
import "../../interfaces/v1/model/IGovRewardModel.sol";
import "../../criteria/ChainSchema.sol";
import "../../storage/model/GovRewardModelStorage.sol";
import "../../util/BoringMath.sol";

contract GovRewardModelImpl is ChainSchema, GovRewardModelStorage, IGovRewardModel {
    using BoringMath for uint256;
    using AllyLibrary for IShorterBone;

    modifier onlyCommittee() {
        shorterBone.assertCaller(msg.sender, AllyLibrary.COMMITTEE);
        _;
    }

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    /// #if_succeeds {:msg "Caller is either Farming or Committee"} msg.sender == farming || msg.sender == committee;
    /// #if_succeeds {:msg "User last reward block updated"} userLastRewardBlock[user] == block.number;
    function harvest(address user) external override returns (uint256 rewards) {
            require(msg.sender == farming || msg.sender == committee, "GovReward: Caller is neither Farming nor Committee");

        rewards = pendingReward(user);
        if (msg.sender == committee && rewards > 0) {
            shorterBone.mintByAlly(AllyLibrary.GOV_REWARD, user, rewards);
        }

        userLastRewardBlock[user] = block.number;
    }

    function pendingReward(address user) public view override returns (uint256 rewards) {
        uint256 _stakedAmount = getUserStakedAmount(user);
        if (_stakedAmount == 0 || userLastRewardBlock[user] == 0) {
            return uint256(0);
        }
        uint256 blockSpan = block.number.sub(userLastRewardBlock[user]);
        rewards = _stakedAmount.mul(blockSpan).mul(ApyPoint).div(getBlockePerYear()).div(100);
    }

    function getUserStakedAmount(address user) public view returns (uint256 _stakedAmount) {
        (_stakedAmount, ) = ICommittee(committee).getUserShares(user);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Farming address setted"} farming == newFarming;
    /// #if_succeeds {:msg "newFarming is not zero address"} farming == address(0);
    function setFarming(address newFarming) external isSavior {
        require(newFarming != address(0), "PoolReward: newFarming is zero address");
        farming = newFarming;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Apy point setted"} ApyPoint == 4;
    /// #if_succeeds {:msg "comitee address setted"} committee == _committee;
    /// #if_succeeds {:msg "Farming address setted"} farming == _farming;
    /// #if_succeeds {:msg "ipistrToken address setted"} ipistrToken == _ipistrToken;
    /// #if_succeeds {:msg "Initialized"} _initialized;
    /// #if_succeeds {:msg "Not previously initialized"} !old(_initialized);
    function initialize(address _shorterBone, address _ipistrToken, address _farming, address _committee) external isSavior {
        require(!_initialized, "GovReward: Already initialized");
        shorterBone = IShorterBone(_shorterBone);
        ipistrToken = _ipistrToken;
        farming = _farming;
        committee = _committee;
        ApyPoint = 4;
        _initialized = true;
    }

    /// #if_succeeds {:msg "The caller is committee"} shorterBone.getModule(AllyLibrary.COMMITTEE) == msg.sender;
    /// #if_succeeds {:msg "Apy point updated"} ApyPoint == newApyPoint;
    function setApyPoint(uint256 newApyPoint) external onlyCommittee {
        ApyPoint = newApyPoint;
    }

    function getBlockePerYear() internal view chainReady returns (uint256 _blockSpan) {
        _blockSpan = uint256(31536000).div(secondsPerBlock());
    }
}
