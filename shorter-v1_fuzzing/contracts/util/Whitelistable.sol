// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.6.12;

import "./Ownable.sol";

contract Whitelistable is Ownable {
    address public whitelister;
    mapping(address => bool) internal whitelisted;

    event Whitelisted(address indexed _account);
    event UnWhitelisted(address indexed _account);
    event WhitelisterChanged(address indexed newWhitelister);

    modifier onlyWhitelister() {
        require(msg.sender == whitelister, "Whitelistable: Caller is not in the whitelist");
        _;
    }

    modifier inWhitelist(address _account) {
        require(whitelisted[_account], "Whitelistable: Account is in whitelist");
        _;
    }

    modifier notWhitelisted(address _account) {
        require(!whitelisted[_account], "Whitelistable: Account not in whitelist");
        _;
    }

    /// #if_succeeds {:msg "Whitelister updated"} whitelisted[_account];
    function whitelist(address _account) external onlyWhitelister {
        whitelisted[_account] = true;
        emit Whitelisted(_account);
    }

    /// #if_succeeds {:msg "Whitelister updated"} !whitelisted[_account];
    function unWhitelist(address _account) external onlyWhitelister {
        whitelisted[_account] = false;
        emit UnWhitelisted(_account);
    }

    /// #if_succeeds {:msg "Caller is not the owner"} msg.sender == this.owner();
    /// #if_succeeds {:msg "valid address"} _newWhitelister != address(0);
    /// #if_succeeds {:msg "Whitelister updated"} whitelister == _newWhitelister;
    function updateWhitelister(address _newWhitelister) external onlyOwner {
        require(_newWhitelister != address(0), "Whitelistable: Invalid address");
        whitelister = _newWhitelister;
        emit WhitelisterChanged(whitelister);
    }
}
