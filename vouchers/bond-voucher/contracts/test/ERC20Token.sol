// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@solv/v2-solidity-utils/contracts/openzeppelin/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Token is ERC20Upgradeable {

    function initialize(
        string calldata name, 
        string calldata symbol,
        uint8 decimals
    ) external {
        __ERC20_init(name, symbol);
        _setupDecimals(decimals);
        _mint(msg.sender, 1e8 * (10 ** decimals));
    }

}