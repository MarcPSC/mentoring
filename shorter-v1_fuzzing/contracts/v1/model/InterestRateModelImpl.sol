// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "../../interfaces/v1/model/IInterestRateModel.sol";
import "../../interfaces/IShorterBone.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/v1/IPoolGuardian.sol";
import "../../criteria/ChainSchema.sol";
import "../../storage/model/InterestRateModelStorage.sol";
import "../../util/BoringMath.sol";

contract InterestRateModelImpl is ChainSchema, InterestRateModelStorage, IInterestRateModel {
    using BoringMath for uint256;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    function getBorrowRate(uint256 poolId, uint256 userBorrowCash) external view override returns (uint256 fundingFeePerBlock) {
        uint256 _annualized = getBorrowApy(poolId);
        fundingFeePerBlock = userBorrowCash.mul(_annualized).div(uint256(365).mul(blocksPerDay()));
    }

    function getBorrowApy(uint256 poolId) public view returns (uint256 annualized_) {
        (uint256 totalBorrowAmount, uint256 totalStakedAmount) = _getPoolInfo(poolId);

        if (totalStakedAmount == 0) {
            return 0;
        }

        uint256 utilization = totalBorrowAmount.mul(1e18).div(totalStakedAmount);

        annualized_ = annualized;
        if (utilization < kink) {
            annualized_ = annualized_.add(utilization.mul(multiplier).div(1e18));
        } else {
            annualized_ = annualized_.add(kink.mul(multiplier).div(1e18));
            annualized_ = annualized_.add((utilization.sub(kink)).mul(jumpMultiplier).div(1e18));
        }
    }

    function _getPoolInfo(uint256 _poolId) internal view returns (uint256 totalBorrowAmount_, uint256 totalStakedAmount_) {
        (, address strToken, ) = poolGuardian.getPoolInfo(_poolId);
        (, , , address wrappedToken, , , , , , , , ) = IPool(strToken).getMetaInfo();

        uint256 _totalSupply = ISRC20(strToken).totalSupply();
        uint256 reserves = ISRC20(wrappedToken).balanceOf(strToken);

        totalBorrowAmount_ = reserves > _totalSupply ? 0 : _totalSupply.sub(reserves);
        totalStakedAmount_ = totalBorrowAmount_.add(wrapRouter.controvertibleAmounts(strToken));
    }

        /// #if_succeeds {:msg "Multiplier updated"} multiplier == _multiplier;
    function setMultiplier(uint256 _multiplier) external isKeeper {
        multiplier = _multiplier;
    }

        /// #if_succeeds {:msg "Jump multiplier updated"} jumpMultiplier == _jumpMultiplier;
    function setJumpMultiplier(uint256 _jumpMultiplier) external isKeeper {
        jumpMultiplier = _jumpMultiplier;
    }

        /// #if_succeeds {:msg "Kink updated"} kink == _kink;
    function setKink(uint256 _kink) external isKeeper {
        kink = _kink;
    }

        /// #if_succeeds {:msg "Annualized updated"} annualized == _annualized;
    function setAnnualized(uint256 _annualized) external isKeeper {
        annualized = _annualized;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    function setWrapRouter(address newWrapRouter) external isSavior {
        wrapRouter = IWrapRouter(newWrapRouter);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Multiplier setted"} multiplier == 500000;
    /// #if_succeeds {:msg "Jump multiplier setted"} jumpMultiplier == 2500000;
    /// #if_succeeds {:msg "Kink setted"} kink == 8 * 1e17;
    /// #if_succeeds {:msg "Annualized setted"} annualized == 1e5;
    /// #if_succeeds {:msg "Initialized"} _initialized;
    function initialize(address _poolGuardian, address _shorterBone) external isSavior {
        require(!_initialized, "InterestRate: Already initialized");

        shorterBone = IShorterBone(_shorterBone);
        poolGuardian = IPoolGuardian(_poolGuardian);
        multiplier = 500000;
        jumpMultiplier = 2500000;
        kink = 8 * 1e17;
        annualized = 1e5;

        _initialized = true;
    }
}
