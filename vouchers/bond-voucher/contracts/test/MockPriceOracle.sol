// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV2V3Interface.sol";
import "hardhat/console.sol";
import "../interface/IPriceOracle.sol";
import "@solv/v2-solidity-utils/contracts/misc/BokkyPooBahsDateTimeLibrary.sol";

contract MockPriceOracle is IPriceOracle {
    using BokkyPooBahsDateTimeLibrary for uint256;

    event NewAdmin(address oldAdmin, address newAdmin);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    address public admin;
    address public pendingAdmin;

    //underlying => price
    mapping(address => int256) public refrencePrices;

    //underlying => datesig => price
    mapping(address => mapping(bytes32 => int256)) public prices;

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function _setRefrencePrice(address underlying_, int256 price_)
        public
        onlyAdmin
    {
        refrencePrices[underlying_] = price_;
    }

    function refreshPrice(
        address underlying_,
        address anchor_,
        uint64 fromDate_,
        uint64 toDate_
    ) external override {
        anchor_;
        bytes32 dateSignature = _getDateSignature(
            _getDateString(fromDate_), _getDateString(toDate_)
        );

        int256 refrencePrice = refrencePrices[underlying_] == 0
            ? 100000000
            : refrencePrices[underlying_];

        uint256 random = uint256(
            keccak256(abi.encodePacked(underlying_, toDate_))
        );
        console.log("random:", random);
        uint256 currentPrice = uint256(refrencePrice);
        console.log("currentPrice:", currentPrice);
        //价格精度为8位，随机增加的范围是在当前价格的涨跌50%之间，因此，获取一个随机涨跌比例
        uint256 percent = random % 100; //获得0-100%的涨跌
        console.log("percent:", percent);
        //uint256 halfPercent = percent / 2; //获得0-50%的涨跌率
        //console.log("halfPercent:", halfPercent);
        uint256 up = random % 2;
        console.log("up:", up);
        uint256 changePrice = (currentPrice * percent) / 100;
        console.log("changePrice:", changePrice);
        int256 price;
        if (up == 0) {
            price = int256(currentPrice - changePrice);
        } else {
            price = int256(currentPrice + changePrice);
        }

        prices[underlying_][dateSignature] = price;
    }

    function _getDateString(uint64 date_)
        internal
        pure
        returns (string memory)
    {
        uint256 year = uint256(date_).getYear();
        uint256 month = uint256(date_).getMonth();
        uint256 day = uint256(date_).getDay();
        return string(abi.encode(year, "-", month, "-", day));
    }

    function _getDateSignature(string memory fromDate_, string memory toDate_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(fromDate_, toDate_));
    }

    function getPrice(
        address underlying_,
        address anchor_,
        uint64 fromDate_,
        uint64 toDate_
    ) external view override returns (int256) {
        anchor_;
        string memory fromDate = _getDateString(fromDate_);
        string memory toDate = _getDateString(toDate_);
        bytes32 dateSignature = _getDateSignature(fromDate, toDate);
        return prices[underlying_][dateSignature];
    }
}
