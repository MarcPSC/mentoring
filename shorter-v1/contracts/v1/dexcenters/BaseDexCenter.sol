// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../criteria/Affinity.sol";

contract BaseDexCenter is Affinity {
    mapping(address => bool) public entitledSwapRouters;
    mapping(address => bool) public isMiddleToken;

    bytes4 private constant APPROVE_SELECTOR = bytes4(keccak256(bytes("approve(address,uint256)")));
    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    constructor(address _SAVIOR) public Affinity(_SAVIOR) {}

    modifier onlyEntitledSwapRouters(address _swapRouter) {
        require(entitledSwapRouters[_swapRouter], "BaseDexCenter: swapRouter is not in entitledSwapRouters");
        _;
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Entitled swap router added"} forall(uint i in 0...newSwapRouters.length-1) entitledSwapRouters[newSwapRouters[i]];
    function addEntitledSwapRouter(address[] calldata newSwapRouters) external isSavior {
        for (uint256 i = 0; i < newSwapRouters.length; i++) {
            entitledSwapRouters[newSwapRouters[i]] = true;
        }
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "Entitled swap router removed"} forall(uint i in 0..._swapRouters.length-1) !entitledSwapRouters[_swapRouters[i]];
    function removeEntitledSwapRouter(address[] calldata _swapRouters) external isSavior {
        for (uint256 i = 0; i < _swapRouters.length; i++) {
            entitledSwapRouters[_swapRouters[i]] = false;
        }
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "middle token added"} forall(uint i in 0...newMiddleTokens.length-1) isMiddleToken[newMiddleTokens[i]];
    function addMiddleTokens(address[] calldata newMiddleTokens) external isSavior {
        uint256 middleTokenSize = newMiddleTokens.length;
        for (uint256 i = 0; i < middleTokenSize; i++) {
            isMiddleToken[newMiddleTokens[i]] = true;
        }
    }

    /// #if_succeeds {:msg "Caller is a savior"} msg.sender == SAVIOR;
    /// #if_succeeds {:msg "middle token removed"} forall(uint i in 0..._middleTokens.length-1) !isMiddleToken[_middleTokens[i]];
    function removeMiddleTokens(address[] calldata _middleTokens) external isSavior {
        uint256 middleTokenSize = _middleTokens.length;
        for (uint256 i = 0; i < middleTokenSize; i++) {
            isMiddleToken[_middleTokens[i]] = false;
        }
    }

    /// #if_succeeds {:msg "Allowance over 0"} ISRC20(token).allowance(address(this), swapRouter) > 0;
    function approve(address swapRouter, address token) internal {
        uint256 _allowance = ISRC20(token).allowance(address(this), swapRouter);
        if (_allowance > 0) {
            return;
        }
        (bool success, ) = token.call(abi.encodeWithSelector(APPROVE_SELECTOR, swapRouter, ~uint256(0)));
        require(success, "BaseDexCenter: Approve failed");
    }

    function transfer(address token, address to, uint256 amount) internal {
        (bool success, ) = token.call(abi.encodeWithSelector(TRANSFER_SELECTOR, to, amount));
        require(success, "BaseDexCenter: Transfer failed");
    }
}
