// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor() ERC20("Tether", "USDT") public {
    }

    function mint(address user, uint232 amount) public {
        _mint(user, amount);
    }
}