// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/AllyLibrary.sol";
import {SafeERC20 as SafeToken} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../libraries/Path.sol";
import "../interfaces/ISRC20.sol";
import "../interfaces/v1/IAuctionHall.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/v1/ITradingHub.sol";
import "../interfaces/IPool.sol";
import "../criteria/ChainSchema.sol";
import "../storage/ThemisStorage.sol";
import "../util/BoringMath.sol";

contract AuctionHallImpl is ChainSchema, ThemisStorage, IAuctionHall {
    using BoringMath for uint256;
    using SafeToken for ISRC20;
    using Path for bytes;
    using AllyLibrary for IShorterBone;

    uint256 internal constant CLOSING_STATE = 2;
    uint256 internal constant OVERDRAWN_STATE = 4;
    uint256 internal constant CLOSED_STATE = 8;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    modifier onlyRuler() {
        require(committee.isRuler(tx.origin), "AuctionHall: Caller is not a ruler");
        _;
    }

    modifier onlyTradingHub() {
        shorterBone.assertCaller(msg.sender, AllyLibrary.TRADING_HUB);
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "TradingHub: EXPIRED");
        _;
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Caller is a ruller"} ICommittee(shorterBone.getModule(AllyLibrary.COMMITTEE)).isRuler(tx.origin);
    /// #if_succeeds {:msg "Valid amount"} auctionPositonInfoMap[position].stakedToken == WrappedEtherAddr ==> bidSize == msg.value;
    /// #if_succeeds {:msg "Valid bid size"} phase1Infos[position].bidSize >= auctionPositonInfoMap[position].totalSize ==> phase1Infos[position].flag;
    /// #if_succeeds {:msg "Valid bid size"} phase1Infos[position].bidSize >= auctionPositonInfoMap[position].totalSize ==> phase1Infos[position].flag;
    /// #if_succeeds {:msg "Phase 1 bid record take back setted"} allPhase1BidRecords[position][allPhase1BidRecords[position].length-1].takeBack == false;
    /// #if_succeeds {:msg "Phase 1 bid record bid block setted"} allPhase1BidRecords[position][allPhase1BidRecords[position].length-1].bidBlock == block.number.to64();
    /// #if_succeeds {:msg "Phase 1 bid record bidder added"} allPhase1BidRecords[position][allPhase1BidRecords[position].length-1].bidder == msg.sender;
    /// #if_succeeds {:msg "Phase 1 bid record bid size setted"} allPhase1BidRecords[position][allPhase1BidRecords[position].length-1].bidSize == bidSize;
    /// #if_succeeds {:msg "Phase 1 bid record priority fee setted"} allPhase1BidRecords[position][allPhase1BidRecords[position].length-1].priorityFee == priorityFee;
    /// #if_succeeds {:msg "Bid not created"} userLastBidBlock[msg.sender][position] == block.number;
    /// #if_succeeds {:msg "Not too many bids"} allPhase1BidRecords[position].length < 512;
    /// #if_succeeds {:msg "Position closed"} _getPositionState(position) == CLOSING_STATE;
    /// #if_succeeds {:msg "Number of user bids not over 20"} old(userBidTimes[tx.origin][position]) + 1 < 20;
    function bidTanto(address position, uint256 bidSize, uint256 priorityFee) external payable whenNotPaused onlyRuler {
        require(userBidTimes[tx.origin][position]++ < 20, "AuctionHall: User too many bids");
        require(userLastBidBlock[msg.sender][position] != block.number, "AuctionHall: already bid");
        require(allPhase1BidRecords[position].length < 512, "AuctionHall: Too many bids");
        uint256 positionState = _getPositionState(position);
        require(positionState == CLOSING_STATE, "AuctionHall: Not a closing position");
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[position];
        require(block.number.sub(auctionPositonInfo.closingBlock) <= phase1MaxBlock, "AuctionHall: Tanto is over");
        require(bidSize > 0 && bidSize <= auctionPositonInfo.totalSize, "AuctionHall: Invalid bidSize");
        Phase1Info storage phase1Info = phase1Infos[position];
        phase1Info.bidSize = phase1Info.bidSize.add(bidSize);
        phase1Info.liquidationPrice = estimateAuctionPrice(position);

        {
            if (auctionPositonInfo.stakedToken == WrappedEtherAddr) {
                require(bidSize == msg.value, "AuctionHall: Invalid amount");
                IWETH(WrappedEtherAddr).deposit{value: msg.value}();
            } else {
                shorterBone.tillIn(auctionPositonInfo.stakedToken, msg.sender, AllyLibrary.AUCTION_HALL, bidSize);
            }
            shorterBone.tillIn(ipistrToken, msg.sender, AllyLibrary.AUCTION_HALL, priorityFee);
        }

        if (phase1Info.bidSize >= auctionPositonInfo.totalSize) {
            phase1Info.flag = true;
        }

        allPhase1BidRecords[position].push(BidItem({takeBack: false, bidBlock: block.number.to64(), bidder: msg.sender, bidSize: bidSize, priorityFee: priorityFee}));
        userLastBidBlock[msg.sender][position] = block.number;
        emit BidTanto(position, msg.sender, bidSize, priorityFee);
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Caller is a ruller"} ICommittee(shorterBone.getModule(AllyLibrary.COMMITTEE)).isRuler(tx.origin);
    /// #if_succeeds {:msg "Tanto is not over"} block.number.sub(auctionPositonInfoMap[position].closingBlock) <= phase1MaxBlock;
    /// #if_succeeds {:msg "Valid bidder"} allPhase1BidRecords[position][bidIndex].bidder == msg.sender;
    /// #if_succeeds {:msg "Priority fee updated"} allPhase1BidRecords[position][bidIndex].priorityFee == old(allPhase1BidRecords[position][bidIndex].priorityFee) + (priorityFee);
    function increasePriorityFee(address position, uint256 bidIndex, uint256 priorityFee) external whenNotPaused onlyRuler {
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[position];
        require(block.number.sub(auctionPositonInfo.closingBlock) <= phase1MaxBlock, "AuctionHall: Tanto is over");
        BidItem storage bidItem = allPhase1BidRecords[position][bidIndex];
        require(bidItem.bidder == msg.sender, "AuctionHall: Invaild bidder");
        shorterBone.tillIn(ipistrToken, msg.sender, AllyLibrary.AUCTION_HALL, priorityFee);
        bidItem.priorityFee = bidItem.priorityFee.add(priorityFee);
        emit IncreasePriorityFee(position, msg.sender, bidIndex, priorityFee);
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Caller is a ruller"} ICommittee(shorterBone.getModule(AllyLibrary.COMMITTEE)).isRuler(tx.origin);
    /// #if_succeeds {:msg "Not expired"} deadline >= block.timestamp;
    /// #if_succeeds {:msg "Dex center allowed"} tradingHub.allowedDexCenter(_dexCenter);
    /// #if_succeeds {:msg "Katana is not over"} block.number.sub(auctionPositonInfoMap[position].closingBlock) > phase1MaxBlock && block.number.sub(auctionPositonInfoMap[position].closingBlock) <= auctionMaxBlock;
    /// #if_succeeds {:msg "Position closing"} _getPositionState(position) == CLOSING_STATE;
    /// #if_succeeds {:msg "Phase 1 finished"} !phase1Infos[position].flag;
    /// #if_succeeds {:msg "Phase 2 ruller setted"} phase2Infos[position].rulerAddr == msg.sender;
    /// #if_succeeds {:msg "Phase 2 flag setted"} phase2Infos[position].flag == true;
    function bidKatana(address position, address _dexCenter, bytes calldata data, uint256 deadline) external whenNotPaused ensure(deadline) onlyRuler {
        require(tradingHub.allowedDexCenter(_dexCenter), "AuctionHall: DexCenter is not allowed");
        uint256 positionState = _getPositionState(position);
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[position];
        require(block.number.sub(auctionPositonInfo.closingBlock) > phase1MaxBlock && block.number.sub(auctionPositonInfo.closingBlock) <= auctionMaxBlock, "AuctionHall: Katana is over");
        require(positionState == CLOSING_STATE, "AuctionHall: Not a closing position");
        Phase1Info storage phase1Info = phase1Infos[position];
        require(!phase1Info.flag, "AuctionHall: Position closed");

        Phase2Info storage phase2Info = phase2Infos[position];
        uint256 decimalDiff = 10 ** (auctionPositonInfo.stakedTokenDecimals.add(18).sub(auctionPositonInfo.stableTokenDecimals));
        uint256 phase1UsedUnsettledCash = phase1Info.bidSize.mul(phase1Info.liquidationPrice).div(decimalDiff);
        phase2Info.debtSize = auctionPositonInfo.totalSize.sub(phase1Info.bidSize);
        uint256 estimatePhase2UseCash = auctionPositonInfo.unsettledCash.sub(phase1UsedUnsettledCash);
        (phase2Info.usedCash, phase2Info.dexCoverReward) = _dexCover(_dexCenter, position, phase2Info.debtSize, estimatePhase2UseCash, data);
        phase2Info.rulerAddr = msg.sender;
        phase2Info.flag = true;

        _closePosition(position);
        emit AuctionFinished(position, 2);
        emit BidKatana(position, msg.sender, phase2Info.debtSize, phase2Info.usedCash, phase2Info.dexCoverReward);
    }

    function inquire() external view override returns (address[] memory closedPositions, address[] memory legacyPositions) {
        address[] memory closingPositions = tradingHub.getPositionsByState(CLOSING_STATE);

        uint256 posSize = closingPositions.length;
        address[] memory closedPosContainer = new address[](posSize);
        address[] memory abortedPosContainer = new address[](posSize);

        uint256 resClosedPosCount;
        uint256 resAbortedPosCount;
        for (uint256 i = 0; i < posSize; i++) {
            uint256 closingBlock = auctionPositonInfoMap[closingPositions[i]].closingBlock;
            if (block.number.sub(closingBlock) > phase1MaxBlock && (phase1Infos[closingPositions[i]].flag)) {
                closedPosContainer[resClosedPosCount++] = closingPositions[i];
            } else if ((block.number.sub(closingBlock) > auctionMaxBlock && !phase1Infos[closingPositions[i]].flag && !phase2Infos[closingPositions[i]].flag)) {
                abortedPosContainer[resAbortedPosCount++] = closingPositions[i];
            } else {
                uint256 positionState = _estimatePositionState(closingPositions[i]);
                if (positionState == OVERDRAWN_STATE) {
                    abortedPosContainer[resAbortedPosCount++] = closingPositions[i];
                } else if (positionState == CLOSED_STATE) {
                    closedPosContainer[resClosedPosCount++] = closingPositions[i];
                }
            }
        }

        closedPositions = new address[](resClosedPosCount);
        for (uint256 i = 0; i < resClosedPosCount; i++) {
            closedPositions[i] = closedPosContainer[i];
        }

        legacyPositions = new address[](resAbortedPosCount);
        for (uint256 i = 0; i < resAbortedPosCount; i++) {
            legacyPositions[i] = abortedPosContainer[i];
        }
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "ipi token setted"} ipistrToken == (_ipistrToken);
    /// #if_succeeds {:msg "Wrapped ether address setted"} WrappedEtherAddr == (_wrappedEtherAddr);
    /// #if_succeeds {:msg "Phase 1 max block setted"} phase1MaxBlock == (_phase1MaxBlock);
    /// #if_succeeds {:msg "Auction max block setted"} auctionMaxBlock == (_auctionMaxBlock);
    function initialize(address _shorterBone, address _ipistrToken, address _poolGuardian, address _tradingHub, address _priceOracle, address _committee, address _wrappedEtherAddr, uint256 _phase1MaxBlock, uint256 _auctionMaxBlock) external isSavior {
        require(_ipistrToken != address(0), "AuctionHall: IpistrToken is zero address");
        shorterBone = IShorterBone(_shorterBone);
        ipistrToken = _ipistrToken;
        poolGuardian = IPoolGuardian(_poolGuardian);
        tradingHub = ITradingHub(_tradingHub);
        priceOracle = IPriceOracle(_priceOracle);
        committee = ICommittee(_committee);
        WrappedEtherAddr = _wrappedEtherAddr;
        phase1MaxBlock = _phase1MaxBlock;
        auctionMaxBlock = _auctionMaxBlock;
    }

    /// #if_succeeds {:msg "Caller is trading hub"} shorterBone.getModule(AllyLibrary.TRADING_HUB) == msg.sender;
    /// #if_succeeds {:msg "Auction str pool added"} auctionPositonInfoMap[position].strPool == strPool;
    /// #if_succeeds {:msg "Auction closing block added"} auctionPositonInfoMap[position].closingBlock == closingBlock;
    function initAuctionPosition(address position, address strPool, uint256 closingBlock) external override onlyTradingHub {
        (address stakedToken, address stableToken, uint256 stakedTokenDecimals, uint256 stableTokenDecimals) = _getMetaInfo(strPool);
        (uint256 totalSize, uint256 unsettledCash) = _getPositionAssetInfo(strPool, position);
        auctionPositonInfoMap[position] = AuctionPositonInfo({strPool: strPool, stakedToken: stakedToken, stableToken: stableToken, closingBlock: closingBlock, totalSize: totalSize, unsettledCash: unsettledCash, stakedTokenDecimals: stakedTokenDecimals, stableTokenDecimals: stableTokenDecimals});

        /// #assert auctionPositonInfoMap[position].stakedToken == stakedToken;
        /// #assert auctionPositonInfoMap[position].stableToken == stableToken;
        /// #assert auctionPositonInfoMap[position].closingBlock == closingBlock;
        /// #assert auctionPositonInfoMap[position].totalSize == totalSize;
        /// #assert auctionPositonInfoMap[position].unsettledCash == unsettledCash;
        /// #assert auctionPositonInfoMap[position].stakedTokenDecimals == stakedTokenDecimals;
        /// #assert auctionPositonInfoMap[position].stableTokenDecimals == stableTokenDecimals;
        0;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "NewPriceOracle is not zero address"} newPriceOracle != address(0);
    function setPriceOracle(address newPriceOracle) external isSavior {
        require(newPriceOracle != address(0), "AuctionHallImpl: NewPriceOracle is zero address");
        priceOracle = IPriceOracle(newPriceOracle);
    }

    function retrieve(address position, uint256[] calldata bidRanks) external whenNotPaused {
        (uint256 stableTokenSize, uint256 debtTokenSize, uint256 priorityFee) = queryResidues(position, bidRanks, msg.sender);
        require(stableTokenSize.add(debtTokenSize).add(priorityFee) > 0, "AuctionHall: No asset to retrieve for now");
        _updateRulerAsset(position, msg.sender);
        (, address strToken, , ) = tradingHub.getPositionState(position);
        (, address stakedToken, , , , , , , , , , ) = IPool(strToken).getMetaInfo();

        if (stableTokenSize > 0) {
            IPool(strToken).stableTillOut(msg.sender, stableTokenSize);
        }

        if (debtTokenSize > 0) {
            if (stakedToken == poolGuardian.WrappedEtherAddr()) {
                IWETH(stakedToken).withdraw(debtTokenSize);
                msg.sender.transfer(debtTokenSize);
            } else {
                shorterBone.tillOut(stakedToken, AllyLibrary.AUCTION_HALL, msg.sender, debtTokenSize);
            }
        }

        if (priorityFee > 0) {
            shorterBone.tillOut(ipistrToken, AllyLibrary.AUCTION_HALL, msg.sender, priorityFee);
        }

        emit Retrieve(position, stableTokenSize, debtTokenSize, priorityFee);
    }

    function bidSorted(address position) public view returns (uint256[] memory _bidRanks) {
        BidItem[] memory bidItems = allPhase1BidRecords[position];

        uint256 bidItemSize = bidItems.length;
        _bidRanks = new uint256[](bidItemSize);

        for (uint256 i = 0; i < bidItemSize; i++) {
            _bidRanks[i] = i;
        }

        for (uint256 i = 0; i < bidItemSize; i++) {
            uint256 minItemIndex = bidItemSize.sub(i + 1);
            for (uint256 j = 0; j < bidItemSize.sub(i + 1); j++) {
                if (
                    bidItems[j].priorityFee < bidItems[minItemIndex].priorityFee ||
                    (bidItems[j].priorityFee == bidItems[minItemIndex].priorityFee && bidItems[j].bidBlock > bidItems[minItemIndex].bidBlock) ||
                    (bidItems[j].priorityFee == bidItems[minItemIndex].priorityFee && bidItems[j].bidBlock == bidItems[minItemIndex].bidBlock && bidItems[j].bidder > bidItems[minItemIndex].bidder)
                ) {
                    minItemIndex = j;
                }
            }

            if (minItemIndex != bidItemSize.sub(i + 1)) {
                BidItem memory tempItem = bidItems[minItemIndex];
                bidItems[minItemIndex] = bidItems[bidItemSize.sub(i + 1)];
                bidItems[bidItemSize.sub(i + 1)] = tempItem;

                uint256 temp = _bidRanks[minItemIndex];
                _bidRanks[minItemIndex] = _bidRanks[bidItemSize.sub(i + 1)];
                _bidRanks[bidItemSize.sub(i + 1)] = temp;
            }
        }
    }

    function estimateAuctionPrice(address position) public view returns (uint256) {
        (uint256 currentPrice, uint256 overdrawnPrice) = _estimatePositionPrice(position);
        currentPrice = currentPrice.mul(102).div(100);
        if (currentPrice > overdrawnPrice) {
            return overdrawnPrice;
        }
        return currentPrice;
    }

    function queryResidues(address position, uint256[] calldata bidRanks, address ruler) public view returns (uint256 stableTokenSize, uint256 debtTokenSize, uint256 priorityFee) {
        uint256 positionState = _getPositionState(position);
        if (positionState == CLOSING_STATE) {
            return (0, 0, 0);
        }

        uint256 remainingDebtSize = auctionPositonInfoMap[position].totalSize;
        Phase2Info storage phase2Info = phase2Infos[position];
        if (phase2Info.flag) {
            if (ruler == phase2Info.rulerAddr && !phase2Info.isWithdrawn) {
                stableTokenSize = phase2Info.dexCoverReward;
            }
            remainingDebtSize = remainingDebtSize.sub(phase2Info.debtSize);
        }

        (stableTokenSize, debtTokenSize, priorityFee) = _getPhase1Residues(ruler, position, remainingDebtSize, stableTokenSize, bidRanks, phase2Info.flag);
    }

    /// #if_succeeds {:msg "Set all bid items for position bidders to take back"} forall(uint i in 1...allPhase1BidRecords[position].length-1) allPhase1BidRecords[position][i].bidder == ruler && allPhase1BidRecords[position][i].takeBack == true;
    /// #if_succeeds {:msg "Set position as withdrawnable"} ruler == phase2Infos[position].rulerAddr ==> phase2Infos[position].isWithdrawn;
    function _updateRulerAsset(address position, address ruler) internal {
        if (ruler == phase2Infos[position].rulerAddr) {
            phase2Infos[position].isWithdrawn = true;
        }

        BidItem[] storage bidItems = allPhase1BidRecords[position];

        for (uint256 i = 0; i < bidItems.length; i++) {
            if (bidItems[i].bidder == ruler) {
                bidItems[i].takeBack = true;
            }
        }
    }

    /// #if_succeeds {:msg "Valid bid ranks params"} _verifyPhase1BidRanks(_position, _bidRanks);
    /// #if_succeeds {:msg "Stable token size setted"} stableTokenSize == old(stableTokenSize) + (_stableTokenSize);
    function _getPhase1Residues(address _ruler, address _position, uint256 _remainingDebtSize, uint256 _stableTokenSize, uint256[] calldata _bidRanks, bool _phase2Flag) internal view returns (uint256 stableTokenSize, uint256 debtTokenSize, uint256 priorityFee) {
        BidItem[] storage bidItems = allPhase1BidRecords[_position];
        require(_verifyPhase1BidRanks(_position, _bidRanks), "AuctionHall: Invalid bidRanks params");
        Phase1Info storage phase1Info = phase1Infos[_position];
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[_position];
        uint256 phase1BidCount = _bidRanks.length;
        stableTokenSize = stableTokenSize.add(_stableTokenSize);
        for (uint256 i = 0; i < phase1BidCount; i++) {
            uint256 wonSize;
            if (!phase1Info.flag && !_phase2Flag) {
                wonSize = 0;
            } else if (_remainingDebtSize >= bidItems[_bidRanks[i]].bidSize) {
                wonSize = bidItems[_bidRanks[i]].bidSize;
                _remainingDebtSize = _remainingDebtSize.sub(wonSize);
            } else {
                wonSize = _remainingDebtSize;
                _remainingDebtSize = 0;
            }
            if (bidItems[_bidRanks[i]].bidder == _ruler && !bidItems[_bidRanks[i]].takeBack) {
                if (wonSize == 0) {
                    debtTokenSize = debtTokenSize.add(bidItems[_bidRanks[i]].bidSize);
                    priorityFee = priorityFee.add(bidItems[_bidRanks[i]].priorityFee);
                } else {
                    debtTokenSize = debtTokenSize.add(bidItems[_bidRanks[i]].bidSize).sub(wonSize);
                    uint256 stableTokenIncreased = wonSize.mul(phase1Info.liquidationPrice).div(10 ** (auctionPositonInfo.stakedTokenDecimals.add(18).sub(auctionPositonInfo.stableTokenDecimals)));
                    stableTokenSize = stableTokenSize.add(stableTokenIncreased);
                }
            }
        }
    }

    function _getPositionState(address _position) internal view returns (uint256 positionState) {
        (, , , positionState) = tradingHub.getPositionState(_position);
    }

    function _getBatchPositionState(address[] memory _positions) internal view returns (uint256[] memory positionsState) {
        positionsState = tradingHub.getBatchPositionState(_positions);
    }

    function _getMetaInfo(address _strPool) internal view returns (address stakedToken, address stableToken, uint256 stakedTokenDecimals, uint256 stableTokenDecimals) {
        (, stakedToken, stableToken, , , , , , , stakedTokenDecimals, stableTokenDecimals, ) = IPool(_strPool).getMetaInfo();
    }

    function _getPositionAssetInfo(address _strPool, address _position) internal view returns (uint256 totalSize, uint256 unsettledCash) {
        (totalSize, unsettledCash) = IPool(_strPool).getPositionAssetInfo(_position);
    }

    function _closePosition(address position) internal {
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[position];
        shorterBone.tillOut(auctionPositonInfo.stakedToken, AllyLibrary.AUCTION_HALL, auctionPositonInfo.strPool, auctionPositonInfo.totalSize);
        tradingHub.updatePositionState(position, CLOSED_STATE);
        Phase1Info storage phase1Info = phase1Infos[position];
        uint256 phase1WonSize = phase1Info.bidSize > auctionPositonInfo.totalSize ? auctionPositonInfo.totalSize : phase1Info.bidSize;
        uint256 phase1UsedUnsettledCash = phase1WonSize.mul(phase1Info.liquidationPrice).div(10 ** (auctionPositonInfo.stakedTokenDecimals.add(18).sub(auctionPositonInfo.stableTokenDecimals)));
        IPool(auctionPositonInfo.strPool).auctionClosed(position, phase1UsedUnsettledCash, phase2Infos[position].usedCash.add(phase2Infos[position].dexCoverReward));
    }

    function _estimatePositionState(address position) internal view returns (uint256 positionState) {
        (uint256 currentPrice, uint256 overdrawnPrice) = _estimatePositionPrice(position);
        if (currentPrice > overdrawnPrice && phase1Infos[position].flag) {
            return CLOSED_STATE;
        }
        positionState = currentPrice > overdrawnPrice ? OVERDRAWN_STATE : CLOSING_STATE;
    }

    function _estimatePositionPrice(address _position) internal view returns (uint256 currentPrice, uint256 overdrawnPrice) {
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[_position];
        currentPrice = priceOracle.quote(auctionPositonInfo.stakedToken, auctionPositonInfo.stableToken);
        overdrawnPrice = auctionPositonInfo.unsettledCash.mul(10 ** (auctionPositonInfo.stakedTokenDecimals.add(18).sub(auctionPositonInfo.stableTokenDecimals))).div(auctionPositonInfo.totalSize);
    }

    function _dexCover(address _dexCenter, address _position, uint256 _amountOut, uint256 _amountInMax, bytes calldata data) internal returns (uint256 amountIn, uint256 dexCoverReward) {
        AuctionPositonInfo storage auctionPositonInfo = auctionPositonInfoMap[_position];
        uint256 currentPrice = priceOracle.quote(auctionPositonInfo.stakedToken, auctionPositonInfo.stableToken);

        uint256 estimateAmountInMax = currentPrice.mul(101).div(100).mul(_amountOut).div(10 ** (auctionPositonInfo.stakedTokenDecimals.add(18).sub(auctionPositonInfo.stableTokenDecimals)));
        uint256 amountInMax = estimateAmountInMax > _amountInMax ? _amountInMax : estimateAmountInMax;

        (amountIn, dexCoverReward) = IPool(auctionPositonInfo.strPool).dexCover(_dexCenter, _amountOut, amountInMax, data);
    }

    function _updatePhase1State(address[] calldata closedPositions) internal {
        uint256[] memory lastPositionsState = _getBatchPositionState(closedPositions);
        uint256 closingPositionSize = closedPositions.length;
        for (uint256 i = 0; i < closingPositionSize; i++) {
            if (!((block.number.sub(auctionPositonInfoMap[closedPositions[i]].closingBlock) > phase1MaxBlock && phase1Infos[closedPositions[i]].flag) || (_estimatePositionState(closedPositions[i]) == CLOSED_STATE))) {
                continue;
            }
            require(lastPositionsState[i] == CLOSING_STATE, "AuctionHall: Not a closing position");
            _closePosition(closedPositions[i]);
            emit AuctionFinished(closedPositions[i], 1);
        }
    }

    /// #if_succeeds {:msg "Valid bid ranks size"} _bidRanks.length == allPhase1BidRecords[_position].length;
    function _verifyPhase1BidRanks(address _position, uint256[] calldata _bidRanks) internal view returns (bool) {
        BidItem[] memory bidItems = allPhase1BidRecords[_position];
        require(_bidRanks.length == bidItems.length, "AuctionHall: Invalid bidRanks size");
        uint256 bidRankLoops = _bidRanks.length.sub(1);
        for (uint256 j = 0; j < bidRankLoops; j++) {
            uint256 m = _bidRanks[j + 1];
            uint256 n = _bidRanks[j];

            if (bidItems[m].priorityFee < bidItems[n].priorityFee) {
                continue;
            }

            if (bidItems[m].priorityFee == bidItems[n].priorityFee && bidItems[m].bidBlock > bidItems[n].bidBlock) {
                continue;
            }

            if (bidItems[m].priorityFee == bidItems[n].priorityFee && bidItems[m].bidBlock == bidItems[n].bidBlock && bidItems[m].bidder > bidItems[n].bidder) {
                continue;
            }

            return false;
        }
        return true;
    }
}
