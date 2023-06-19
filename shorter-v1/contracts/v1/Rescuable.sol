// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import {SafeERC20 as SafeToken} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ISRC20.sol";

contract Rescuable {
    using SafeToken for ISRC20;

    address public immutable committeeContract;

    modifier onlyCommittee() {
        require(msg.sender == committeeContract, "Rescuable: Caller is not Committee");
        _;
    }

    constructor(address _committee) public {
        committeeContract = _committee;
    }

    /// #if_succeeds {:msg "Caller is Committee"} msg.sender == committeeContract;
    /// #if_succeeds {:msg "All balance withdrawn"} forall(uint i in 0...tokens.length-1) ISRC20(tokens[i]).balanceOf(address(this)) == 0;
    function emergencyWithdraw(address account, address[] memory tokens) external onlyCommittee {
        for (uint256 i = 0; i < tokens.length; i++) {
            ISRC20 token = ISRC20(tokens[i]);
            uint256 _balanceOf = token.balanceOf(address(this));
            ISRC20(token).safeTransfer(account, _balanceOf);
        }
    }

    /// #if_succeeds {:msg "Caller is Committee"} msg.sender == committeeContract;
    /// #if_succeeds {:msg "All balance withdrawn"} address(this).balance == 0;
    /// #if_succeeds {:msg "All balance added to account"} account.balance == old(address(this).balance) + old(account.balance);
    function killSelf(address account) external onlyCommittee {
        selfdestruct(payable(account));
    }
}
