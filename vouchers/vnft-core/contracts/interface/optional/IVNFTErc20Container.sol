// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./IUnderlyingContainer.sol";

interface IVNFTErc20Container is IUnderlyingContainer {
    function units2UnderlyingAmount(uint256 units)
        external
        view
        returns (uint256 underlyingAmount);

    function underlyingAmount2Units(uint256 underlyingAmount)
        external
        view
        returns (uint256 units);
}
