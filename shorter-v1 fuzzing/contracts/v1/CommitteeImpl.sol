// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../libraries/AllyLibrary.sol";
import "../interfaces/v1/IPoolGuardian.sol";
import "../interfaces/governance/ICommittee.sol";
import "../interfaces/v1/model/IGovRewardModel.sol";
import "../criteria/ChainSchema.sol";
import "../storage/CommitteStorage.sol";
import "../util/BoringMath.sol";

contract CommitteeImpl is ChainSchema, CommitteStorage, ICommittee {
    using BoringMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using AllyLibrary for IShorterBone;

    uint256 public constant MAX_POOL_CREATION_FEE = 500000;

    constructor(address _SAVIOR) public ChainSchema(_SAVIOR) {}

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Stable token setted"} stableToken == _stableToken;
    /// #if_succeeds {:msg "Max voting days setted"} maxVotingDays == 2;
    /// #if_succeeds {:msg "Proposal fee setted"} proposalFee == 1e22;
    /// #if_succeeds {:msg "Ruler threshold setted"} rulerThreshold == 1e9;
    /// #if_succeeds {:msg "Comitee proposal threshold setted"} committeeProposalThreshold == 50;
    /// #if_succeeds {:msg "Pool proposal threshold setted"} poolProposalThreshold == 10;
    function initialize(address _shorterBone, address _ipistrToken, address _stableToken) external isSavior {
        shorterBone = IShorterBone(_shorterBone);
        ipistrToken = IIpistrToken(_ipistrToken);
        stableToken = _stableToken;
        maxVotingDays = 2;
        proposalFee = 1e22;
        rulerThreshold = 1e9;
        committeeProposalThreshold = 50;
        poolProposalThreshold = 10;
    }

    /// @notice User deposit IPISTR into committee pool
    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Sufficient ammount of ipistr token to deposit"} amount <= ipistrToken.spendableBalanceOf(msg.sender);
    /// #if_succeeds {:msg "Staked amount updated"} _rulerDataMap[msg.sender].stakedAmount == old(_rulerDataMap[msg.sender].stakedAmount) + (amount);
    /// #if_succeeds {:msg "Total ipi staked share updated"} totalIpistrStakedShare == old(totalIpistrStakedShare) + (amount);
    /// #if_succeeds {:msg "EOA required"} msg.sender == tx.origin;
    function deposit(uint256 amount) external override whenNotPaused onlyEOA {
        uint256 spendableBalanceOf = ipistrToken.spendableBalanceOf(msg.sender);
        require(amount <= spendableBalanceOf, "Committee: Insufficient amount");

        shorterBone.tillIn(address(ipistrToken), msg.sender, AllyLibrary.COMMITTEE, amount);
        IGovRewardModel(shorterBone.getGovRewardModel()).harvest(msg.sender);

        RulerData storage rulerData = _rulerDataMap[msg.sender];
        rulerData.stakedAmount = rulerData.stakedAmount.add(amount);
        totalIpistrStakedShare = totalIpistrStakedShare.add(amount);

        emit DepositCommittee(msg.sender, amount, rulerData.stakedAmount);
    }

    /// @notice Withdraw IPISTR from committee vault
    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Suficient token staked"} _rulerDataMap[msg.sender].stakedAmount >= _rulerDataMap[msg.sender].voteShareLocked.add(amount);
    /// #if_succeeds {:msg "Staked amount updated"} _rulerDataMap[msg.sender].stakedAmount == old(_rulerDataMap[msg.sender].stakedAmount) - (amount);
    /// #if_succeeds {:msg "Total ipi staked updated"} totalIpistrStakedShare == old(totalIpistrStakedShare) - (amount);
    /// #if_succeeds {:msg "EOA required"} msg.sender == tx.origin;
    function withdraw(uint256 amount) external override whenNotPaused onlyEOA {
        RulerData storage rulerData = _rulerDataMap[msg.sender];
        require(rulerData.stakedAmount >= rulerData.voteShareLocked.add(amount), "Committee: Insufficient amount");

        IGovRewardModel(shorterBone.getGovRewardModel()).harvest(msg.sender);

        rulerData.stakedAmount = rulerData.stakedAmount.sub(amount);
        totalIpistrStakedShare = totalIpistrStakedShare.sub(amount);

        shorterBone.tillOut(address(ipistrToken), AllyLibrary.COMMITTEE, msg.sender, amount);

        emit WithdrawCommittee(msg.sender, amount, rulerData.stakedAmount);
    }

    /// @notice Specified for the proposal of pool type
    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Stable token in whitelist"} stableTokenWhitelist[_stableTokenAddr];
    /// #if_succeeds {:msg "Valid staked token"} _stakedTokenAddr != IPoolGuardian(shorterBone.getPoolGuardian()).WrappedEtherAddr();
    /// #if_succeeds {:msg "VAlid pool creation fee"} _poolCreationFee <= MAX_POOL_CREATION_FEE;
    /// #if_succeeds {:msg "Pool not found"} old(proposalGallery[proposalCount].startBlock) == 0;
    /// #if_succeeds {:msg "Valid duration"} _durationDays > 0 && _durationDays <= 1000;
    /// #if_succeeds {:msg "Proposal id added"} proposalGallery[proposalCount].id == uint32(proposalCount);
    /// #if_succeeds {:msg "Proposal proposer added"} proposalGallery[proposalCount].proposer == msg.sender;
    /// #if_succeeds {:msg "Proposal catagory setted"} proposalGallery[proposalCount].catagory == 1;
    /// #if_succeeds {:msg "Proposal start block setted"} proposalGallery[proposalCount].startBlock == block.number.to64();
    /// #if_succeeds {:msg "Proposal end block setted"} proposalGallery[proposalCount].endBlock == (block.number + (blocksPerDay() * (maxVotingDays))).to64();
    /// #if_succeeds {:msg "Proposal for shares setted"} proposalGallery[proposalCount].forShares == 0;
    /// #if_succeeds {:msg "Proposal against shares setted"} proposalGallery[proposalCount].againstShares == 0;
    /// #if_succeeds {:msg "Proposal status setted"} proposalGallery[proposalCount].status == ProposalStatus.Active;
    /// #if_succeeds {:msg "Proposal displayable setted"} proposalGallery[proposalCount].displayable == true;
    /// #if_succeeds {:msg "Proposal token contract setted"} address(_stakedTokenAddr) != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) ==> poolMetersMap[proposalCount].tokenContract == _stakedTokenAddr;
    /// #if_succeeds {:msg "Proposal token contract setted"} address(_stakedTokenAddr) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) ==> poolMetersMap[proposalCount].tokenContract == IPoolGuardian(shorterBone.getPoolGuardian()).WrappedEtherAddr();
    /// #if_succeeds {:msg "Proposal leverage setted"} poolMetersMap[proposalCount].leverage == _leverage.to32();
    /// #if_succeeds {:msg "Proposal duration setted"} poolMetersMap[proposalCount].durationDays == _durationDays.to32();
    function createPoolProposal(address _stakedTokenAddr, address _stableTokenAddr, uint256 _leverage, uint256 _durationDays, uint256 _maxCapacity, uint256 _poolCreationFee) external chainReady whenNotPaused {
        require(stableTokenWhitelist[_stableTokenAddr], "Committee: stableToken is not in the whitelist");
        address WrappedEtherAddr = IPoolGuardian(shorterBone.getPoolGuardian()).WrappedEtherAddr();
        require(_stakedTokenAddr != WrappedEtherAddr, "Committee: Invalid stakedToken");
        require(_poolCreationFee <= MAX_POOL_CREATION_FEE, "Committee: Invalid poolCreationFee");
        if (address(_stakedTokenAddr) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            _stakedTokenAddr = WrappedEtherAddr;
        }
        (bool inWhiteList, , ) = shorterBone.getTokenInfo(_stakedTokenAddr);
        /// #assert inWhiteList;
        require(inWhiteList, "Committee: Invalid stakedToken");
        require(_durationDays > 0 && _durationDays <= 1000, "Committee: Invalid duration");
        proposalCount = proposalCount.add(block.timestamp.add(1).sub(block.timestamp.div(30).mul(30)));
        require(proposalGallery[proposalCount].startBlock == 0, "Committee: Existing proposal found");
        proposalIds.push(proposalCount);
        shorterBone.revenue(address(ipistrToken), msg.sender, proposalFee, IShorterBone.IncomeType.PROPOSAL_FEE);
        IPoolGuardian(shorterBone.getPoolGuardian()).addPool(IPool.CreatePoolParams({stakedToken: _stakedTokenAddr, stableToken: stableToken, creator: msg.sender, leverage: _leverage, durationDays: _durationDays, poolId: proposalCount, maxCapacity: _maxCapacity, poolCreationFee: _poolCreationFee}));
        proposalGallery[proposalCount] = Proposal({id: uint32(proposalCount), proposer: msg.sender, catagory: 1, startBlock: block.number.to64(), endBlock: block.number.add(blocksPerDay().mul(maxVotingDays)).to64(), forShares: 0, againstShares: 0, status: ProposalStatus.Active, displayable: true});
        poolMetersMap[proposalCount] = PoolMeters({tokenContract: _stakedTokenAddr, leverage: _leverage.to32(), durationDays: _durationDays.to32()});

        emit PoolProposalCreated(proposalCount, msg.sender);
    }

    /// @notice Specified for the proposal of community type
    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Correct parameters"} targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length;
    /// #if_succeeds {:msg "Valid actions"} targets.length > 0 && targets.length <= 10;
    /// #if_succeeds {:msg "Proposal doesn't exists"} old(proposalGallery[proposalCount].startBlock) == 0;
    /// #if_succeeds {:msg "Proposal id added"} proposalGallery[proposalCount].id == uint32(proposalCount);
    /// #if_succeeds {:msg "Proposal proposer added"} proposalGallery[proposalCount].proposer == msg.sender;
    /// #if_succeeds {:msg "Proposal catagory setted"} proposalGallery[proposalCount].catagory == 2;
    /// #if_succeeds {:msg "Proposal start block setted"} proposalGallery[proposalCount].startBlock == block.number.to64();
    /// #if_succeeds {:msg "Proposal end block setted"} proposalGallery[proposalCount].endBlock == (block.number + (blocksPerDay() * (maxVotingDays))).to64();
    /// #if_succeeds {:msg "Proposal for shares setted"} proposalGallery[proposalCount].forShares == 0;
    /// #if_succeeds {:msg "Proposal against shares setted"} proposalGallery[proposalCount].againstShares == 0;
    /// #if_succeeds {:msg "Proposal status setted"} proposalGallery[proposalCount].status == ProposalStatus.Active;
    /// #if_succeeds {:msg "Proposal displayable setted"} proposalGallery[proposalCount].displayable == true;
    /// #if_succeeds {:msg "All targets added to proposal"} forall(uint i in 0...communityProposalGallery[proposalCount].targets.length-1) communityProposalGallery[proposalCount].targets[i] == targets[i];
    /// #if_succeeds {:msg "All values added to proposal"} forall(uint i in 0...communityProposalGallery[proposalCount].values.length-1) communityProposalGallery[proposalCount].values[i] == values[i];
    function createCommunityProposal(address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description, string memory title) external chainReady whenNotPaused {
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "Committee: Parameters mismatch");
        require(targets.length > 0 && targets.length <= 10, "Committee: Invalid actions");
        proposalCount = proposalCount.add(block.timestamp.add(1).sub(block.timestamp.div(30).mul(30)));
        require(proposalGallery[proposalCount].startBlock == 0, "Committee: Existing proposal found");
        proposalIds.push(proposalCount);
        shorterBone.revenue(address(ipistrToken), msg.sender, proposalFee, IShorterBone.IncomeType.PROPOSAL_FEE);

        proposalGallery[proposalCount] = Proposal({id: uint32(proposalCount), proposer: msg.sender, catagory: 2, startBlock: block.number.to64(), endBlock: block.number.add(blocksPerDay().mul(maxVotingDays)).to64(), forShares: 0, againstShares: 0, status: ProposalStatus.Active, displayable: true});
        communityProposalGallery[proposalCount] = CommunityProposal({targets: targets, values: values, signatures: signatures, calldatas: calldatas});

        emit CommunityProposalCreated(proposalCount, msg.sender, description, title);
    }

    /// #if_succeeds {:msg "Contract is not be paused"} !this.paused();
    /// #if_succeeds {:msg "Caller is a ruller"} _isRuler(msg.sender);
    /// #if_succeeds {:msg "Proposal is open"} uint256(proposalGallery[proposalId].endBlock) > block.number;
    /// #if_succeeds {:msg "Proposal is active"} proposalGallery[proposalId].status == ProposalStatus.Active;
    /// #if_succeeds {:msg "Valid votet share"} voteShare > 0;
    /// #if_succeeds {:msg "Suficient voting power"} _rulerDataMap[msg.sender].stakedAmount- (_rulerDataMap[msg.sender].voteShareLocked) >= voteShare;
    /// #if_succeeds {:msg "Added positive share votes"} direction ==> proposalGallery[proposalId].forShares == voteShare + old(proposalGallery[proposalId].forShares);
    /// #if_succeeds {:msg "Locked share vote power for user"} direction ==> userLockedShare[proposalId][msg.sender].forShares == old(userLockedShare[proposalId][msg.sender].forShares) + (voteShare);
    /// #if_succeeds {:msg "Added negative share votes"} !direction ==> proposalGallery[proposalId].againstShares == voteShare + old(proposalGallery[proposalId].againstShares);
    /// #if_succeeds {:msg "Locked share vote power for user"} !direction ==> userLockedShare[proposalId][msg.sender].againstShares == old(userLockedShare[proposalId][msg.sender].againstShares) + (voteShare);
    function vote(uint256 proposalId, bool direction, uint256 voteShare) external whenNotPaused {
        require(_isRuler(msg.sender), "Committee: Caller is not a ruler");

        Proposal storage proposal = proposalGallery[proposalId];
        require(uint256(proposal.endBlock) > block.number, "Committee: Proposal was closed");

        require(proposal.status == ProposalStatus.Active, "Committee: Not an active proposal");
        require(voteShare > 0, "Committee: Invalid voteShare");

        // Lock the vote power after voting
        RulerData storage rulerData = _rulerDataMap[msg.sender];

        uint256 availableVotePower = rulerData.stakedAmount.sub(rulerData.voteShareLocked);
        require(availableVotePower >= voteShare, "Committee: Insufficient voting power");

        proposalVoters[proposalId].add(msg.sender);

        //Lock user's vote power
        rulerData.voteShareLocked = rulerData.voteShareLocked.add(voteShare);

        VoteShares storage userVoteShare = userLockedShare[proposalId][msg.sender];

        if (direction) {
            proposal.forShares = voteShare.add(proposal.forShares);
            forVoteProposals[msg.sender].add(proposalId);
            userVoteShare.forShares = userVoteShare.forShares.add(voteShare);
            bool _finished = ((uint256(proposal.forShares) >= totalIpistrStakedShare.mul(poolProposalThreshold).div(100)) && uint256(proposal.catagory) == uint256(1)) ||
                ((uint256(proposal.forShares) >= totalIpistrStakedShare.mul(committeeProposalThreshold).div(100)) && uint256(proposal.catagory) == uint256(2));
            if (_finished) {
                _updateProposalStatus(proposalId, ProposalStatus.Passed);
                _makeProposalQueued(proposal);
                _unlockRulerVotingShare(proposal.id);
            }
        } else {
            proposal.againstShares = voteShare.add(proposal.againstShares);
            againstVoteProposals[msg.sender].add(proposalId);
            userVoteShare.againstShares = userVoteShare.againstShares.add(voteShare);
            bool _finished = ((uint256(proposal.againstShares) >= totalIpistrStakedShare.mul(poolProposalThreshold).div(100)) && uint256(proposal.catagory) == uint256(1)) ||
                ((uint256(proposal.againstShares) >= totalIpistrStakedShare.mul(committeeProposalThreshold).div(100)) && uint256(proposal.catagory) == uint256(2));
            if (_finished) {
                _updateProposalStatus(proposalId, ProposalStatus.Failed);
                _unlockRulerVotingShare(proposal.id);
            }
        }

        emit ProposalVoted(proposal.id, msg.sender, direction, voteShare);
    }

    function getQueuedProposals() external view override returns (uint256[] memory _queuedProposals, uint256[] memory _failedProposals) {
        uint256 queueProposalSize = queuedProposals.length();
        _queuedProposals = new uint256[](queueProposalSize);
        for (uint256 i = 0; i < queueProposalSize; i++) {
            _queuedProposals[i] = queuedProposals.at(i);
        }

        uint256 failedProposalIndex;
        uint256 proposalLen = proposalIds.length;
        uint256[] memory failedProposals = new uint256[](proposalLen);
        for (uint256 i = 0; i < proposalLen; i++) {
            if (proposalGallery[proposalIds[i]].status == ProposalStatus.Active && uint256(proposalGallery[proposalIds[i]].endBlock) < block.number) {
                failedProposals[failedProposalIndex++] = proposalIds[i];
            }
        }

        _failedProposals = new uint256[](failedProposalIndex);
        for (uint256 i = 0; i < failedProposalIndex; i++) {
            _failedProposals[i] = failedProposals[i];
        }
    }

    /// @notice Judge Ruler role
    function isRuler(address account) external view override returns (bool) {
        return _isRuler(account);
    }

    function getUserShares(address account) external view override returns (uint256 totalShare, uint256 lockedShare) {
        RulerData storage rulerData = _rulerDataMap[account];
        totalShare = rulerData.stakedAmount;
        lockedShare = rulerData.voteShareLocked;
    }

    function _executeTransaction(address target, uint256 value, string memory signature, bytes memory data) internal returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, ) = target.call{value: value}(callData);
        /// #assert success;

        require(success, "Committee: Transaction execution reverted");
    }

    function getVoteProposals(address account, uint256 catagory) external view override returns (uint256[] memory _poolForProposals, uint256[] memory _poolAgainstProposals) {
        uint256 poolForProposalsIndex;
        uint256 forProposalSize = forVoteProposals[account].length();
        uint256[] memory _forProposals = new uint256[](forProposalSize);

        for (uint256 i = 0; i < forProposalSize; i++) {
            uint256 proposalId = forVoteProposals[account].at(i);
            if (proposalGallery[proposalId].catagory == catagory) {
                _forProposals[poolForProposalsIndex++] = proposalId;
            }
        }

        uint256 poolAgainstProposalsIndex;
        uint256 againstProposalSize = againstVoteProposals[account].length();
        uint256[] memory _againstProposals = new uint256[](againstProposalSize);

        for (uint256 i = 0; i < againstProposalSize; i++) {
            uint256 proposalId = againstVoteProposals[account].at(i);
            if (proposalGallery[proposalId].catagory == catagory) {
                _againstProposals[poolAgainstProposalsIndex++] = proposalId;
            }
        }

        _poolForProposals = new uint256[](poolForProposalsIndex);
        for (uint256 i = 0; i < poolForProposalsIndex; i++) {
            _poolForProposals[i] = _forProposals[i];
        }

        _poolAgainstProposals = new uint256[](poolAgainstProposalsIndex);
        for (uint256 i = 0; i < poolAgainstProposalsIndex; i++) {
            _poolAgainstProposals[i] = _againstProposals[i];
        }
    }

    function getForShares(address account, uint256 proposalId) external view override returns (uint256 voteShare, uint256 totalShare) {
        if (proposalGallery[proposalId].status == ProposalStatus.Executed) {
            voteShare = userLockedShare[proposalId][account].forShares;
            totalShare = proposalGallery[proposalId].forShares;
        }
    }

    function getAgainstShares(address account, uint256 proposalId) external view override returns (uint256 voteShare, uint256 totalShare) {
        if (proposalGallery[proposalId].status == ProposalStatus.Failed) {
            voteShare = userLockedShare[proposalId][account].againstShares;
            totalShare = proposalGallery[proposalId].againstShares;
        }
    }

    function getCommunityProposalInfo(uint256 proposalId) external view returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory) {
        CommunityProposal storage communityProposal = communityProposalGallery[proposalId];
        return (communityProposal.targets, communityProposal.values, communityProposal.signatures, communityProposal.calldatas);
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Stable tokens white list flag setted"} forall(uint i in 1..._stableTokenAddrs.length-1) stableTokenWhitelist[_stableTokenAddrs[i]] == flag;
    function setStableTokenWhitelist(address[] memory _stableTokenAddrs, bool flag) external isSavior {
        uint256 updateStableTokenSize = _stableTokenAddrs.length;
        for (uint256 i = 0; i < updateStableTokenSize; i++) {
            stableTokenWhitelist[_stableTokenAddrs[i]] = flag;
        }
    }

    /// @notice Set voting period
    /// @param _maxVotingDays new maximum voting days
    /// #if_succeeds {:msg "CAller is committee"} msg.sender == address(this);
    /// #if_succeeds {:msg "Valid voting days"} _maxVotingDays > 1;
    /// #if_succeeds {:msg "Max voting days setted"} maxVotingDays == _maxVotingDays;
    function setVotingDays(uint256 _maxVotingDays) external {
        require(msg.sender == address(this), "Committee: Caller is not Committee");
        require(_maxVotingDays > 1, "Committee: Invalid voting days");
        maxVotingDays = _maxVotingDays;

        emit VotingMaxDaysSet(_maxVotingDays);
    }

    /// @notice Tweak the proposal submission fee
    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Proposal fee setted"} proposalFee == _proposalFee;
    function setProposalFee(uint256 _proposalFee) external isSavior {
        proposalFee = _proposalFee;
    }

    /// @notice Set the ruler threshold
    /// #if_succeeds {:msg "Caller is commitee"} msg.sender == address(this);
    /// #if_succeeds {:msg "Valid ruler threshold"} newRulerThreshold > 0 && newRulerThreshold <= 1e12;
    /// #if_succeeds {:msg "Ruler threshols updated"} rulerThreshold == newRulerThreshold;
    function setRulerThreshold(uint256 newRulerThreshold) external {
        require(msg.sender == address(this), "Committee: Caller is not Committee");
        require(newRulerThreshold > 0 && newRulerThreshold <= 1e12, "Committee: Invalid ruler threshold");
        uint256 oldRulerThreshold = rulerThreshold;
        rulerThreshold = newRulerThreshold;

        emit RulerThresholdSet(oldRulerThreshold, newRulerThreshold);
    }

    /// @notice Switch proposal's display state
    /// #if_succeeds {:msg "Proposal visibility updated"} proposalGallery[proposalId].displayable == displayable;
        function changeProposalVisibility(uint256 proposalId, bool displayable) external isManager {
        proposalGallery[proposalId].displayable = displayable;
    }

    /// #if_succeeds {:msg "Caller is committe"} msg.sender == address(this);
    /// #if_succeeds {:msg "Committee proposal threshold updated"} committeeProposalThreshold == threshold;
    function setCommitteeProposalQuorum(uint256 threshold) external {
        require(msg.sender == address(this), "Committee: Caller is not Committee");
        committeeProposalThreshold = threshold;
    }

    /// #if_succeeds {:msg "Caller is committe"} msg.sender == address(this);
    /// #if_succeeds {:msg "Pool proposal threshold updated"} poolProposalThreshold == threshold;
    function setPoolProposalQuorum(uint256 threshold) external {
        require(msg.sender == address(this), "Committee: Caller is not Committee");
        poolProposalThreshold = threshold;
    }

    /// #if_succeeds {:msg "Proposal added to queue"} proposal.status == ProposalStatus.Passed && proposal.catagory == 1 ==> queuedProposals.contains(proposal.id);
    function _makeProposalQueued(Proposal storage proposal) internal {
        if (proposal.status != ProposalStatus.Passed) {
            return;
        }

        _updateProposalStatus(proposal.id, ProposalStatus.Queued);

        if (proposal.catagory == 1) {
            queuedProposals.add(proposal.id);
        }
    }

    function _unlockRulerVotingShare(uint256 proposalId) internal {
        uint256 voterCount = proposalVoters[proposalId].length();
        for (uint256 i = 0; i < voterCount; i++) {
            address voter = proposalVoters[proposalId].at(i);
            uint256 lockedShare = userLockedShare[proposalId][voter].forShares.add(userLockedShare[proposalId][voter].againstShares);
            _rulerDataMap[voter].voteShareLocked = _rulerDataMap[voter].voteShareLocked.sub(lockedShare);
        }
    }

    function _isRuler(address account) internal view returns (bool) {
        return _rulerDataMap[account].stakedAmount.mul(1e12).div(rulerThreshold) > totalIpistrStakedShare;
    }

    /// #if_succeeds {:msg "Proposal status updated"} proposalGallery[proposalId].status == ps;
    function _updateProposalStatus(uint256 proposalId, ProposalStatus ps) internal {
        proposalGallery[proposalId].status = ps;
        emit ProposalStatusChanged(proposalId, uint256(ps));
    }
}
