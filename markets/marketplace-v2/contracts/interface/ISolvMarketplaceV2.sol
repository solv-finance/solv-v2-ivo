// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@solv/v2-offering-market-core/contracts/PriceManager.sol";

interface ISolvMarketplaceV2 {
    
    enum FeeType {
        BY_AMOUNT,
        FIXED
    }

    enum FeePayType {
        SELLER_PAY,
        BUYER_PAY
    }

    enum WhitelistType {
        NONE,
        PROJECT,
        SALE
    }

    struct WhitelistParams {
        WhitelistType whitelistType;
        address[] saleWhitelist;
        uint256[] purchaseLimits;
    }

    event Publish(
        address indexed icToken,
        address indexed seller,
        uint256 indexed tokenId,
        uint24 saleId,
        uint8 priceType,
        uint256 units,
        uint256 startTime,
        address currency,
        uint256 min,
        uint256 max,
        WhitelistType whitelistType
    );

    event Remove(
        address indexed icToken,
        address indexed seller,
        uint24 indexed saleId,
        uint256 total,
        uint256 saled
    );

    event FixedPriceSet(
        address indexed icToken,
        uint24 indexed saleId,
        uint256 indexed tokenId,
        uint8 priceType,
        uint128 lastPrice
    );

    event DecliningPriceSet(
        address indexed icToken,
        uint24 indexed saleId,
        uint256 indexed tokenId,
        uint128 highest,
        uint128 lowest,
        uint32 duration,
        uint32 interval
    );

    event Traded(
        address indexed buyer,
        uint24 indexed saleId,
        address indexed icToken,
        uint256 tokenId,
        uint24 tradeId,
        uint32 tradeTime,
        address currency,
        uint8 priceType,
        uint128 price,
        uint256 tradedUnits,
        uint256 tradedAmount,
        uint8 feePayType,
        uint128 fee
    );

    function publishSale(
        address voucher_, 
        uint256 tokenId_,
        address currency_,
        uint256 min_,
        uint256 max_,
        uint32 startTime_,
        PriceManager.PriceType priceType_,
        bytes calldata priceData_,
        WhitelistParams calldata whitelistParams_
    ) 
        external 
        returns (uint24 saleId);

    function buyByAmount(uint24 saleId_, uint256 amount_)
        external
        payable
        returns (uint256 units_);

    function buyByUnits(uint24 saleId_, uint256 units_)
        external
        payable
        returns (uint256 amount_, uint128 fee_);

    function remove(uint24 saleId_) external;

    function totalSalesOfICToken(address icToken_)
        external
        view
        returns (uint256);

    function saleIdOfICTokenByIndex(address icToken_, uint256 index_)
        external
        view
        returns (uint256);

    function getPrice(uint24 saleId_) external view returns (uint128);
}
