// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "../../util/Ownable.sol";
import "../Rescuable.sol";

contract GrandetieImpl is Ownable, Rescuable {
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("approve(address,uint256)")));

    constructor(address _committee) public Rescuable(_committee) {}

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    function approve(
        address token,
        address spender,
        uint256 amount
    ) external onlyOwner returns (bool) {
        (bool success, ) = token.call(abi.encodeWithSelector(SELECTOR, spender, amount));
        /// #assert success;
        require(success, "Grandetie: Approve failed");
    }
}
