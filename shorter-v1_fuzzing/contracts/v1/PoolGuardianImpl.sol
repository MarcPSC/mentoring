// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/AllyLibrary.sol";
import "../interfaces/IPool.sol";
import "../interfaces/v1/IPoolGuardian.sol";
import "../interfaces/IShorterFactory.sol";
import "../interfaces/v1/IWrapRouter.sol";
import "../criteria/ChainSchema.sol";
import "../storage/TheiaStorage.sol";
import "../util/BoringMath.sol";

contract PoolGuardianImpl is ChainSchema, TheiaStorage, IPoolGuardian {
    using BoringMath for uint256;
    using AllyLibrary for IShorterBone;

    address public override WrappedEtherAddr;

    modifier onlyCommittee() {
        shorterBone.assertCaller(msg.sender, AllyLibrary.COMMITTEE);
        _;
    }

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    /// #if_succeeds {:msg "Initialized flag setted"} _initialized && !old(_initialized);
    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function initialize(address _shorterBone, address _WrappedEtherAddr, uint256[] memory _levelScoresDef, uint256[] memory _leverageThresholds) external isSavior {
        require(!_initialized, "PoolGuardian: Already initialized");
        require(_levelScoresDef.length == _leverageThresholds.length, "PoolGuardian: Invalid leverage params");
        shorterBone = IShorterBone(_shorterBone);
        levelScoresDef = _levelScoresDef;
        leverageThresholds = _leverageThresholds;
        WrappedEtherAddr = _WrappedEtherAddr;
        _initialized = true;
        emit PoolGuardianInitiated();
    }

     /// @notice Add a new pool. DO NOT add the pool with identical meters
    /// #if_succeeds {:msg "The caller is committee"} shorterBone.getModule(AllyLibrary.COMMITTEE) == msg.sender;
    /// #if_succeeds {:msg "Pool staked token added"} poolInfoMap[createPoolParams.poolId].stakedToken == createPoolParams.stakedToken;
    /// #if_succeeds {:msg "Pool stable token added"} poolInfoMap[createPoolParams.poolId].stableToken == createPoolParams.stableToken;
    /// #if_succeeds {:msg "Pool state flag setted to genesis"} poolInfoMap[createPoolParams.poolId].stateFlag == PoolStatus.GENESIS;
    /// #if_succeeds {:msg "Pool id added to the list"} poolIds[poolIds.length-1] == createPoolParams.poolId;
    function addPool(IPool.CreatePoolParams calldata createPoolParams) external override chainReady onlyCommittee { 
        require(_checkLeverageValid(createPoolParams.stakedToken, createPoolParams.leverage), "PoolGuardian: Invalid leverage");
        address strToken = IShorterFactory(shorterBone.getShorterFactory()).createStrPool(createPoolParams.poolId);
        address poolRewardModel = shorterBone.getModule(AllyLibrary.POOL_REWARD);
        
        IPool(strToken).initialize(wrapRouter, shorterBone.getTradingHub(), poolRewardModel, blocksPerDay(), WrappedEtherAddr, createPoolParams);
        poolInfoMap[createPoolParams.poolId] = PoolInfo({stakedToken: createPoolParams.stakedToken, stableToken: createPoolParams.stableToken, strToken: strToken, stateFlag: PoolStatus.GENESIS});
        poolIds.push(createPoolParams.poolId);
        createPoolIds[createPoolParams.creator].push(createPoolParams.poolId);
    }

    /// #if_succeeds {:msg "The caller is committee"} shorterBone.getModule(AllyLibrary.COMMITTEE) == msg.sender;
    /// #if_succeeds {:msg "Pool flag updated"} poolInfoMap[poolId].stateFlag == IPoolGuardian.PoolStatus.RUNNING;
    function listPool(uint256 poolId) external override onlyCommittee {
        PoolInfo storage pool = poolInfoMap[poolId];
        IPool(pool.strToken).list();
        pool.stateFlag = IPoolGuardian.PoolStatus.RUNNING;
    }

    /// #if_succeeds {:msg "The caller is committee"} shorterBone.getModule(AllyLibrary.COMMITTEE) == msg.sender;
    function changeLeverageThresholds(uint256[] memory _leverageThresholds) external onlyCommittee {
        leverageThresholds = _leverageThresholds;
    }

    function getPoolIds() external view override returns (uint256[] memory _poolIds) {
        _poolIds = poolIds;
    }

    function getCreatedPoolIds(address creator) external view returns (uint256[] memory _poolIds) {
        _poolIds = createPoolIds[creator];
    }

    function getPoolInfo(uint256 poolId) external view override returns (address stakedToken, address strToken, PoolStatus stateFlag) {
        PoolInfo storage pool = poolInfoMap[poolId];
        return (pool.stakedToken, pool.strToken, pool.stateFlag);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Pool invokers setted"} forall(uint i in 0..._sigs.length-1) poolInvokers[_sigs[i]] == _implementation;
    function setPoolInvokers(bytes4[] memory _sigs, address _implementation) external isSavior {
        for (uint256 i = 0; i < _sigs.length; i++) {
            poolInvokers[_sigs[i]] = _implementation;
        }
        emit PoolInvokerChanged(msg.sender, _implementation, _sigs);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "New wrap router is not address 0"} newWrapRouter != address(0);
    /// #if_succeeds {:msg "Wrap router updated"} wrapRouter == newWrapRouter;
    function setWrapRouter(address newWrapRouter) external isSavior {
        require(newWrapRouter != address(0));
        wrapRouter = newWrapRouter;
    }

    function _checkLeverageValid(address stakedToken, uint256 leverage) internal view returns (bool res) {
        (, , uint256 tokenRatingScore) = shorterBone.getTokenInfo(stakedToken);
        for (uint256 i = 0; i < levelScoresDef.length; i++) {
            if (tokenRatingScore >= levelScoresDef[i] && leverage <= leverageThresholds[i]) {
                return true;
            }
        }
        return false;
    }

    function queryPools(address stakedToken, PoolStatus status) external view override returns (uint256[] memory) {
        uint256 poolSize = poolIds.length;
        uint256[] memory poolContainer = new uint256[](poolSize);

        uint256 resPoolCount;
        for (uint256 i = 0; i < poolSize; i++) {
            PoolInfo storage poolInfo = poolInfoMap[poolIds[i]];
            if ((stakedToken == address(0) || poolInfo.stakedToken == stakedToken) && poolInfo.stateFlag == status) {
                poolContainer[resPoolCount++] = poolIds[i];
            }
        }

        uint256[] memory resPools = new uint256[](resPoolCount);
        for (uint256 i = 0; i < resPoolCount; i++) {
            resPools[i] = poolContainer[i];
        }

        return resPools;
    }

    /// @notice Switch a pool's stateFlag to HIDING or Display.
    /// #if_succeeds {:msg "Pool state setted"} poolInfoMap[poolId].stateFlag == status;
        function setStateFlag(uint256 poolId, PoolStatus status) external override isManager {
        PoolInfo storage pool = poolInfoMap[poolId];
        pool.stateFlag = status;

        IPool(pool.strToken).setStateFlag(status);
    }

    /// #if_succeeds {:msg "PoolInvoker is not zero address"} poolInvokers[_sig] != address(0);
    function getPoolInvokers(bytes4 _sig) external view override returns (address) {
        require(poolInvokers[_sig] != address(0), "PoolGuardian: poolInvoker is zaro address");
        return poolInvokers[_sig];
    }
}
