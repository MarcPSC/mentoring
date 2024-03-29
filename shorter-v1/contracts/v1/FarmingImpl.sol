// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SafeERC20 as SafeToken} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../libraries/AllyLibrary.sol";
import "../libraries/TickMath.sol";
import "../libraries/LiquidityAmounts.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/uniswapv2/IUniswapV2Pair.sol";
import "../interfaces/uniswapv3/IUniswapV3Pool.sol";
import "../interfaces/uniswapv3/INonfungiblePositionManager.sol";
import "../interfaces/IShorterBone.sol";
import "../interfaces/v1/IFarming.sol";
import "../interfaces/v1/model/IFarmingRewardModel.sol";
import "../interfaces/v1/model/IGovRewardModel.sol";
import "../interfaces/v1/model/IPoolRewardModel.sol";
import "../interfaces/v1/model/ITradingRewardModel.sol";
import "../interfaces/v1/model/IVoteRewardModel.sol";
import "../criteria/ChainSchema.sol";
import "../storage/FarmingStorage.sol";
import "../util/BoringMath.sol";

contract FarmingImpl is ChainSchema, FarmingStorage, IFarming {
    using SafeToken for ISRC20;
    using BoringMath for uint256;

    uint256 public TOKEN_0_DECIMAL_SCALER;
    uint256 public TOKEN_1_DECIMAL_SCALER;
    uint256 public TOKEN_LP_DECIMAL;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Ipistr token setted"} ipistrToken == _ipistrToken;
    /// #if_succeeds {:msg "Decimal scaller setted"} ISRC20(uniswapV3Pool.token0()).decimals() == 18 ==> TOKEN_0_DECIMAL_SCALER == 1e12;
    /// #if_succeeds {:msg "Decimal scaller setted"} ISRC20(uniswapV3Pool.token0()).decimals() != 18 ==> TOKEN_0_DECIMAL_SCALER == 1e22;
    /// #if_succeeds {:msg "Decimal scaller setted"} ISRC20(uniswapV3Pool.token1()).decimals() == 18 ==> TOKEN_1_DECIMAL_SCALER == 1e12;
    /// #if_succeeds {:msg "Decimal scaller setted"} ISRC20(uniswapV3Pool.token1()).decimals() != 18 ==> TOKEN_1_DECIMAL_SCALER == 1e22;
    /// #if_succeeds {:msg "Supported"} (ISRC20(uniswapV3Pool.token0()).decimals() + (ISRC20(uniswapV3Pool.token1()).decimals()))/(2) * (2) == ISRC20(uniswapV3Pool.token0()).decimals() + (ISRC20(uniswapV3Pool.token1()).decimals());
    /// #if_succeeds {:msg "Token lp decimal setted"} TOKEN_LP_DECIMAL == (ISRC20(uniswapV3Pool.token0()).decimals() + (ISRC20(uniswapV3Pool.token1()).decimals())) / (2);;
    function initialize(address _shorterBone, address _nonfungiblePositionManager, address _uniswapV3Pool, address _ipistrToken) external isSavior {
        shorterBone = IShorterBone(_shorterBone);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        ipistrToken = _ipistrToken;
        uniswapV3Pool = IUniswapV3Pool(_uniswapV3Pool);

        address token0 = uniswapV3Pool.token0();
        address token1 = uniswapV3Pool.token1();
        uint256 decimals0 = ISRC20(token0).decimals();
        uint256 decimals1 = ISRC20(token1).decimals();

        TOKEN_0_DECIMAL_SCALER = decimals0 == 18 ? 1e12 : 1e22;
        TOKEN_1_DECIMAL_SCALER = decimals1 == 18 ? 1e12 : 1e22;
        uint256 decimalslp = (decimals0.add(decimals1)).div(2);
        require(decimalslp.mul(2) == decimals0.add(decimals1), "Farming: unSupported");
        TOKEN_LP_DECIMAL = decimalslp;
    }

    // amountA: Uniswap pool token0 Amount
    // amountB: Uniswap pool token1 Amount
    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Token id setted"} tokenId == _tokenId;
    /// #if_succeeds {:msg "mintLiquidityValue is not zero"} liquidity.mul(poolInfoMap[tokenId].midPrice.div(1e12)).div(10 ** (TOKEN_LP_DECIMAL.sub(12))) > 0;
    /// #if_succeeds {:msg "Slippage not too large"} liquidity > minLiquidity;
    /// #if_succeeds {:msg "User ammount updated"} tokenUserInfoMap[tokenId][msg.sender].amount == tokenUserInfoMap[tokenId][msg.sender].amount+(liquidity);
    /// #if_succeeds {:msg "Token 0 debt updated"} tokenUserInfoMap[tokenId][msg.sender].token0Debt == (poolInfoMap[tokenId].token0PerLp*(tokenUserInfoMap[tokenId][msg.sender].amount))/(TOKEN_0_DECIMAL_SCALER);
    /// #if_succeeds {:msg "Token 1 debt updated"} tokenUserInfoMap[tokenId][msg.sender].token1Debt == (poolInfoMap[tokenId].token1PerLp*(tokenUserInfoMap[tokenId][msg.sender].amount))/(TOKEN_1_DECIMAL_SCALER);
    /// #if_succeeds {:msg "EOA required"} msg.sender == tx.origin;
    function stake(uint256 tokenId, uint256 amountA, uint256 amountB, uint256 minLiquidity) external whenNotPaused onlyEOA returns (uint256 liquidity) {
        require(tokenId == _tokenId, "Farming: Invalid tokenId");
        _updatePool(tokenId);
        PoolInfo storage pool = poolInfoMap[tokenId];
        (, uint256 token0Reward, uint256 token1Reward) = getUserInfo(msg.sender, tokenId);
        if (token0Reward > 0) {
            shorterBone.tillOut(pool.token0, AllyLibrary.FARMING, msg.sender, token0Reward);
        }
        if (token1Reward > 0) {
            shorterBone.tillOut(pool.token1, AllyLibrary.FARMING, msg.sender, token1Reward);
        }
        shorterBone.tillIn(pool.token0, msg.sender, AllyLibrary.FARMING, amountA);
        shorterBone.tillIn(pool.token1, msg.sender, AllyLibrary.FARMING, amountB);
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseLiquidityParams = INonfungiblePositionManager.IncreaseLiquidityParams({tokenId: tokenId, amount0Desired: amountA, amount1Desired: amountB, amount0Min: 0, amount1Min: 0, deadline: block.timestamp});
        (uint128 _liquidity, uint256 amount0, uint256 amount1) = nonfungiblePositionManager.increaseLiquidity(increaseLiquidityParams);
        liquidity = uint256(_liquidity);
        require(liquidity > minLiquidity, "Farming: Slippage too large");
        farmingRewardModel.harvestByPool(msg.sender);
        UserInfo storage userInfo = tokenUserInfoMap[tokenId][msg.sender];
        userInfo.amount = userInfo.amount.add(liquidity);
        userInfo.token0Debt = pool.token0PerLp.mul(userInfo.amount).div(TOKEN_0_DECIMAL_SCALER);
        userInfo.token1Debt = pool.token1PerLp.mul(userInfo.amount).div(TOKEN_1_DECIMAL_SCALER);
        uint256 mintLiquidityValue = liquidity.mul(pool.midPrice.div(1e12)).div(10 ** (TOKEN_LP_DECIMAL.sub(12)));
        require(mintLiquidityValue > 0, "Farming: mintLiquidityValue is zero");
        userStakedAmount[msg.sender] = userStakedAmount[msg.sender].add(mintLiquidityValue);

        emit Stake(msg.sender, tokenId, liquidity, amount0, amount1);
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "valid withdraw amount"} tokenUserInfoMap[tokenId][msg.sender].amount >= liquidity;
    /// #if_succeeds {:msg "User ammount updated"} tokenUserInfoMap[tokenId][msg.sender].amount == tokenUserInfoMap[tokenId][msg.sender].amount-(liquidity);
    /// #if_succeeds {:msg "Token 0 debt updated"} tokenUserInfoMap[tokenId][msg.sender].token0Debt == (poolInfoMap[tokenId].token0PerLp*(tokenUserInfoMap[tokenId][msg.sender].amount))/(TOKEN_0_DECIMAL_SCALER);
    /// #if_succeeds {:msg "Token 1 debt updated"} tokenUserInfoMap[tokenId][msg.sender].token1Debt == (poolInfoMap[tokenId].token1PerLp*(tokenUserInfoMap[tokenId][msg.sender].amount))/(TOKEN_1_DECIMAL_SCALER);
    /// #if_succeeds {:msg "EOA required"} msg.sender == tx.origin;
    function unStake(uint256 tokenId, uint256 liquidity, uint256 amount0Min, uint256 amount1Min) external whenNotPaused onlyEOA {
        UserInfo storage userInfo = tokenUserInfoMap[tokenId][msg.sender];
        require(userInfo.amount >= liquidity, "Farming: Invalid withdraw amount");
        _updatePool(tokenId);
        PoolInfo storage pool = poolInfoMap[tokenId];
        (, uint256 token0Reward, uint256 token1Reward) = getUserInfo(msg.sender, tokenId);
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams = INonfungiblePositionManager.DecreaseLiquidityParams({tokenId: tokenId, liquidity: uint128(liquidity), amount0Min: amount0Min, amount1Min: amount1Min, deadline: block.timestamp});
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.decreaseLiquidity(decreaseLiquidityParams);
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({tokenId: tokenId, recipient: address(this), amount0Max: uint128(amount0), amount1Max: uint128(amount1)});
        (amount0, amount1) = nonfungiblePositionManager.collect(collectParams);
        farmingRewardModel.harvestByPool(msg.sender);
        userInfo.amount = userInfo.amount.sub(liquidity);
        userInfo.token0Debt = pool.token0PerLp.mul(userInfo.amount).div(TOKEN_0_DECIMAL_SCALER);
        userInfo.token1Debt = pool.token1PerLp.mul(userInfo.amount).div(TOKEN_1_DECIMAL_SCALER);
        uint256 burnLiquidityValue = liquidity.mul(pool.midPrice.div(1e12)).div(10 ** (TOKEN_LP_DECIMAL.sub(12)));
        userStakedAmount[msg.sender] = userStakedAmount[msg.sender].sub(burnLiquidityValue);
        shorterBone.tillOut(pool.token0, AllyLibrary.FARMING, msg.sender, amount0.add(token0Reward));
        shorterBone.tillOut(pool.token1, AllyLibrary.FARMING, msg.sender, amount1.add(token1Reward));
        emit UnStake(msg.sender, tokenId, liquidity, amount0, amount1);
    }

    function _updatePool(uint256 tokenId) internal {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({tokenId: tokenId, recipient: address(this), amount0Max: uint128(0) - 1, amount1Max: uint128(0) - 1});
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(collectParams);
        (, , , , , , , uint128 _liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
        if (_liquidity > 0) {
            PoolInfo storage pool = poolInfoMap[tokenId];
            pool.token0PerLp = pool.token0PerLp.add(amount0.mul(TOKEN_0_DECIMAL_SCALER).div(uint256(_liquidity)));
            pool.token1PerLp = pool.token1PerLp.add(amount1.mul(TOKEN_1_DECIMAL_SCALER).div(uint256(_liquidity)));
        }
    }

    function getUserInfo(address user, uint256 tokenId) public view returns (uint256 stakedAmount, uint256 token0Rewards, uint256 token1Rewards) {
        UserInfo storage userInfo = tokenUserInfoMap[tokenId][user];
        PoolInfo storage pool = poolInfoMap[tokenId];
        stakedAmount = userInfo.amount;
        if (stakedAmount > 0) {
            (, , , , , , , uint128 _liquidity, , , uint256 tokensOwed0, uint256 tokensOwed1) = nonfungiblePositionManager.positions(tokenId);
            uint256 token0PerLp = pool.token0PerLp.add(tokensOwed0.mul(TOKEN_0_DECIMAL_SCALER).div(uint256(_liquidity)));
            uint256 token1PerLp = pool.token1PerLp.add(tokensOwed1.mul(TOKEN_1_DECIMAL_SCALER).div(uint256(_liquidity)));
            token0Rewards = (token0PerLp.mul(stakedAmount).div(TOKEN_0_DECIMAL_SCALER)).sub(userInfo.token0Debt);
            token1Rewards = (token1PerLp.mul(stakedAmount).div(TOKEN_1_DECIMAL_SCALER)).sub(userInfo.token1Debt);
        }
    }

    function getUserStakedAmount(address user) external view override returns (uint256 userStakedAmount_) {
        userStakedAmount_ = userStakedAmount[user];
    }

    function allPendingRewards(
        address user
    )
        public
        view
        returns (
            uint256 govRewards,
            uint256 farmingRewards,
            uint256 voteAgainstRewards,
            uint256 tradingRewards,
            uint256 stakedRewards,
            uint256 creatorRewards,
            uint256 voteRewards,
            uint256[] memory tradingRewardPools,
            uint256[] memory stakedRewardPools,
            uint256[] memory createRewardPools,
            uint256[] memory voteRewardPools
        )
    {
        (tradingRewards, tradingRewardPools) = tradingRewardModel.pendingReward(user);
        govRewards = govRewardModel.pendingReward(user);
        voteAgainstRewards = voteRewardModel.pendingReward(user);
        (uint256 unLockRewards_, uint256 rewards_) = farmingRewardModel.pendingReward(user);
        farmingRewards = unLockRewards_.add(rewards_);
        (stakedRewards, creatorRewards, voteRewards, stakedRewardPools, createRewardPools, voteRewardPools) = poolRewardModel.pendingReward(user);
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "EOA required"} msg.sender == tx.origin;
    function harvestAll(uint256 govRewards, uint256 farmingRewards, uint256 voteAgainstRewards, uint256[] memory tradingRewardPools, uint256[] memory stakedRewardPools, uint256[] memory createRewardPools, uint256[] memory voteRewardPools) external whenNotPaused onlyEOA {
        uint256 rewards;
        if (tradingRewardPools.length > 0) {
            rewards = rewards.add(tradingRewardModel.harvest(msg.sender, tradingRewardPools));
        }

        if (govRewards > 0) {
            rewards = rewards.add(govRewardModel.harvest(msg.sender));
        }

        if (farmingRewards > 0) {
            farmingRewardModel.harvest(msg.sender);
        }

        if (voteAgainstRewards > 0) {
            rewards = rewards.add(voteRewardModel.harvest(msg.sender));
        }

        if (stakedRewardPools.length > 0 || createRewardPools.length > 0 || voteRewardPools.length > 0) {
            rewards = rewards.add(poolRewardModel.harvest(msg.sender, stakedRewardPools, createRewardPools, voteRewardPools));
        }

        shorterBone.mintByAlly(AllyLibrary.FARMING, msg.sender, rewards);
    }

    function getAmountsForLiquidity(uint256 tokenId, uint128 liquidity) public view returns (address token0, address token1, uint256 amount0, uint256 amount1) {
        uint160 sqrtRatioX96;
        uint160 sqrtRatioAX96;
        uint160 sqrtRatioBX96;
        (sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, token0, token1) = _getSqrtRatioByTokenId(tokenId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    function _getSqrtRatioByTokenId(uint256 tokenId) internal view returns (uint160 sqrtRatioX96, uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, address token0, address token1) {
        int24 tickLower;
        int24 tickUpper;
        (, , token0, token1, , tickLower, tickUpper, , , , , ) = nonfungiblePositionManager.positions(tokenId);
        (sqrtRatioX96, , , , , , ) = uniswapV3Pool.slot0();
        sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
    }

    function getBaseAmountsForLiquidity(uint160 sqrtRatioX96, uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity) external pure returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) external pure returns (int256 tick) {
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function setRewardModel(address _tradingRewardModel, address _farmingRewardModel, address _govRewardModel, address _poolRewardModel, address _voteRewardModel) external isSavior {
        tradingRewardModel = ITradingRewardModel(_tradingRewardModel);
        farmingRewardModel = IFarmingRewardModel(_farmingRewardModel);
        govRewardModel = IGovRewardModel(_govRewardModel);
        poolRewardModel = IPoolRewardModel(_poolRewardModel);
        voteRewardModel = IVoteRewardModel(_voteRewardModel);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function createPool(INonfungiblePositionManager.MintParams calldata params) external isSavior {
        shorterBone.tillIn(params.token0, msg.sender, AllyLibrary.FARMING, params.amount0Desired);
        shorterBone.tillIn(params.token1, msg.sender, AllyLibrary.FARMING, params.amount1Desired);
        (uint256 tokenId, uint128 liquidity, , ) = nonfungiblePositionManager.mint(params);
        uint256 midPrice = _setPoolInfo(tokenId);
        UserInfo storage userInfo = tokenUserInfoMap[tokenId][msg.sender];
        userInfo.amount = userInfo.amount.add(uint256(liquidity));
        uint256 mintLiquidityValue = uint256(liquidity).mul(midPrice.div(1e12)).div(10 ** (TOKEN_LP_DECIMAL.sub(12)));
        /// #assert mintLiquidityValue > 0;
        require(mintLiquidityValue > 0, "Farming: mintLiquidityValue is zero");
        userStakedAmount[msg.sender] = userStakedAmount[msg.sender].add(mintLiquidityValue);
    }

    function getPirceBySqrtPriceX96(uint160 sqrtPriceX96, address token0, address token1, address quoteToken) public view returns (uint256 price) {
        uint256 token0Decimals = uint256(ISRC20(token0).decimals());
        uint256 token1Decimals = uint256(ISRC20(token1).decimals());
        uint256 token0Price;
        uint256 sqrtDecimals = uint256(18).add(token0Decimals).sub(token1Decimals).div(2);
        if (sqrtDecimals.mul(2) == uint256(18).add(token0Decimals).sub(token1Decimals)) {
            uint256 sqrtPrice = uint256(sqrtPriceX96).mul(10 ** sqrtDecimals).div(2 ** 96);
            token0Price = sqrtPrice.mul(sqrtPrice);
        } else {
            uint256 sqrtPrice = uint256(sqrtPriceX96).mul(10 ** (sqrtDecimals + 1)).div(2 ** 96);
            token0Price = sqrtPrice.mul(sqrtPrice).div(10);
        }
        if (token0 == quoteToken) {
            price = token0Price;
        } else {
            price = uint256(1e36).div(token0Price);
        }
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Token id setted"} _tokenId == tokenId;
    function setTokenId(uint256 tokenId) external isSavior {
        _tokenId = tokenId;
    }

    function getTokenId() external view override returns (uint256) {
        return _tokenId;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function setPoolInfo(uint256 tokenId) external isSavior {
        _setPoolInfo(tokenId);
    }

    /// #if_succeeds {:msg "Token 0 debt updated"} tokenUserInfoMap[tokenId][user].token0Debt == poolInfoMap[tokenId].token0PerLp * (tokenUserInfoMap[tokenId][user].amount)/(TOKEN_0_DECIMAL_SCALER);
    /// #if_succeeds {:msg "Token 1 debt updated"} tokenUserInfoMap[tokenId][user].token1Debt == poolInfoMap[tokenId].token1PerLp * (tokenUserInfoMap[tokenId][user].amount)/(TOKEN_1_DECIMAL_SCALER);
    function harvest(uint256 tokenId, address user) external override {
        UserInfo storage userInfo = tokenUserInfoMap[tokenId][user];
        _updatePool(tokenId);
        PoolInfo storage pool = poolInfoMap[tokenId];
        (, uint256 token0Reward, uint256 token1Reward) = getUserInfo(user, tokenId);
        if (token0Reward > 0) {
            shorterBone.tillOut(pool.token0, AllyLibrary.FARMING, user, token0Reward);
        }
        if (token1Reward > 0) {
            shorterBone.tillOut(pool.token1, AllyLibrary.FARMING, user, token1Reward);
        }

        userInfo.token0Debt = pool.token0PerLp.mul(userInfo.amount).div(TOKEN_0_DECIMAL_SCALER);
        userInfo.token1Debt = pool.token1PerLp.mul(userInfo.amount).div(TOKEN_1_DECIMAL_SCALER);
    }

    /// #if_succeeds {:msg "pool mid price setted"} poolInfoMap[tokenId].midPrice == midPrice;
    /// #if_succeeds {:msg "pool token 0 perLp setted"} poolInfoMap[tokenId].token0PerLp == 0;
    /// #if_succeeds {:msg "pool token 1 perLp setted"} poolInfoMap[tokenId].token1PerLp == 0;
    function _setPoolInfo(uint256 tokenId) internal returns (uint256 midPrice) {
        (, , address token0, address token1, uint24 _fee, int24 tickLower, int24 tickUpper, , , , , ) = nonfungiblePositionManager.positions(tokenId);
        int24 midTick = (tickUpper >> 1) + (tickLower >> 1);
        uint160 sqrtMPriceX96 = TickMath.getSqrtRatioAtTick(midTick);
        uint160 sqrtAPriceX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtBPriceX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        uint256 lowerPrice;
        uint256 upperPrice;
        (lowerPrice, upperPrice, midPrice) = _getLpPriceInfo(sqrtMPriceX96, sqrtAPriceX96, sqrtBPriceX96, token0, token1);
        poolInfoMap[tokenId] = PoolInfo({token0: token0, token1: token1, fee: uint256(_fee), midPrice: midPrice, lowerPrice: lowerPrice, upperPrice: upperPrice, token0PerLp: 0, token1PerLp: 0});
    }

    function _getLpPriceInfo(uint160 sqrtMPriceX96, uint160 sqrtAPriceX96, uint160 sqrtBPriceX96, address token0, address token1) internal view returns (uint256 lowerPrice, uint256 upperPrice, uint256 midPrice) {
        uint256 price0 = getPirceBySqrtPriceX96(sqrtAPriceX96, token0, token1, ipistrToken);
        uint256 price1 = getPirceBySqrtPriceX96(sqrtBPriceX96, token0, token1, ipistrToken);
        midPrice = getPirceBySqrtPriceX96(sqrtMPriceX96, token0, token1, ipistrToken);
        lowerPrice = price0 > price1 ? price1 : price0;
        upperPrice = price0 > price1 ? price0 : price1;
    }
}
