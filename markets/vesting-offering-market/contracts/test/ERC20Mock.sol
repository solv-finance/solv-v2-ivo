// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory minters
    ) ERC20(name, symbol) {
        uint256 amount = 100000000 * 1e18; //decimals 18
        _mint(msg.sender, amount);
        for (uint256 i = 0; i < minters.length; i++) {
            _mint(minters[i], amount);
        }
    }
}
