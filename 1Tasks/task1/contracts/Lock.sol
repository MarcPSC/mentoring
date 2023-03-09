pragma solidity ^0.8.0;

import "../node_modules/hardhat/console.sol";

contract Lock {
    string private str = "First";

    address private contractCreator;

    constructor() {
        contractCreator = msg.sender;
    }

    function updateString(string memory _newStr) public {
        require(msg.sender == contractCreator, "Only contract creator can modify the string.");
        str = _newStr;
    }

    function getString() public view returns (string memory) {
        return str;
    }
}