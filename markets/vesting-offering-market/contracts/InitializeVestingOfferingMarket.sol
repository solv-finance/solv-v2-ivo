// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@solv/v2-offering-market-core/contracts/OfferingMarketCore.sol";

interface IStandardVestingVoucher {
    function mint(
        uint64 term_,
        uint256 amount_,
        uint64[] calldata maturities_,
        uint32[] calldata percentages_,
        string memory originalInvestor_
    ) external returns (uint256 slot, uint256 voucherId);
}

interface IFlexibleDateVestingVoucher {
    function mint(
        address issuer_,
        uint8 claimType_,
        uint64 latestClaimVestingTime_,
        uint64[] calldata terms_,
        uint32[] calldata percentages_,
        uint256 vestingAmount_
    ) external returns (uint256 slot, uint256 tokenId);
}

interface ERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract InitializeVestingOfferingMarket is OfferingMarketCore {
    enum TimeType {
        LATEST_START_TIME,
        ON_BUY,
        UNDECIDED
    }

    struct MintParameter {
        Constants.ClaimType claimType;
        uint64 latestStartTime;
        TimeType timeType;
        uint64[] terms;
        uint32[] percentages;
    }

    //key: offeringId
    mapping(uint24 => MintParameter) public mintParameters;

    function offeringType() public view virtual override returns (uint8) {
        return 1;
    }

    function marketName() public view virtual override returns (string memory) {
        return "Initialize Offering Voucher Market";
    }

    function offer(
        address voucher_,
        address currency_,
        uint128 units_,
        uint128 min_,
        uint128 max_,
        uint32 startTime_,
        uint32 endTime_,
        bool useAllowList_,
        PriceManager.PriceType priceType_,
        bytes calldata priceData_,
        MintParameter calldata mintParameter_
    ) external returns (uint24 offeringId) {
        Market memory market = markets[voucher_];

        if (mintParameter_.timeType == TimeType.UNDECIDED) {
            require(
                market.voucherType ==
                    Constants.VoucherType.FLEXIBLE_DATE_VESTING,
                "only offering voucher support undecided time"
            );
        }

        require(
            mintParameter_.terms.length == mintParameter_.percentages.length,
            "invalid terms and percentages"
        );
        if (
            mintParameter_.claimType == Constants.ClaimType.ONE_TIME ||
            mintParameter_.claimType == Constants.ClaimType.LINEAR
        ) {
            require(
                mintParameter_.percentages.length == 1 &&
                    mintParameter_.percentages[0] == Constants.FULL_PERCENTAGE,
                "invalid percentages"
            );
        } else if (mintParameter_.claimType == Constants.ClaimType.STAGED) {
            require(
                mintParameter_.percentages.length > 1,
                "invalid percentages"
            );
            uint256 sumOfPercentages = 0;
            for (uint256 i = 0; i < mintParameter_.percentages.length; i++) {
                sumOfPercentages += mintParameter_.percentages[i];
            }
            require(
                sumOfPercentages == Constants.FULL_PERCENTAGE,
                "invalid percentages"
            );
        }

        ERC20TransferHelper.doTransferIn(market.asset, msg.sender, units_);

        offeringId = OfferingMarketCore._offer(
            voucher_,
            currency_,
            units_,
            min_,
            max_,
            startTime_,
            endTime_,
            useAllowList_,
            priceType_,
            priceData_
        );
        mintParameters[offeringId] = mintParameter_;
    }

    function _mintVoucher(uint24 offeringId_, uint128 units_)
        internal
        virtual
        override
        returns (uint256 voucherId)
    {
        Offering memory offering = offerings[offeringId_];
        MintParameter memory parameter = mintParameters[offeringId_];
        ERC20(markets[offering.voucher].asset).approve(
            markets[offering.voucher].voucherPool,
            units_
        );
        if (parameter.timeType != TimeType.UNDECIDED) {
            uint64 term;
            uint64[] memory maturities = new uint64[](parameter.terms.length);
            IStandardVestingVoucher vestingVoucher = IStandardVestingVoucher(
                offering.voucher
            );
            uint64 startTime = parameter.timeType == TimeType.LATEST_START_TIME
                ? parameter.latestStartTime
                : uint64(block.timestamp);
            if (parameter.claimType == Constants.ClaimType.ONE_TIME) {
                maturities[0] = startTime + parameter.terms[0];
                term = 0;
            } else {
                for (uint256 i = 0; i < parameter.terms.length; i++) {
                    //term[0] is not be included
                    if (i > 0) {
                        term += parameter.terms[i];
                    }
                    maturities[i] = startTime + term;
                }
            }
            (, voucherId) = vestingVoucher.mint(
                term,
                units_,
                maturities,
                parameter.percentages,
                "IVO"
            );
        } else {
            IFlexibleDateVestingVoucher offeringVoucher = IFlexibleDateVestingVoucher(
                    offering.voucher
                );
            (, voucherId) = offeringVoucher.mint(
                offering.issuer,
                uint8(parameter.claimType),
                parameter.latestStartTime,
                parameter.terms,
                parameter.percentages,
                units_
            );
        }
    }

    function _refund(uint24 offeringId_, uint128 units_)
        internal
        virtual
        override
    {
        ERC20TransferHelper.doTransferOut(
            markets[offerings[offeringId_].voucher].asset,
            payable(offerings[offeringId_].issuer),
            units_
        );
    }

    function isSupportVoucherType(Constants.VoucherType voucherType_)
        public
        pure
        override
        returns (bool)
    {
        return (voucherType_ == Constants.VoucherType.FLEXIBLE_DATE_VESTING ||
            voucherType_ == Constants.VoucherType.STANDARD_VESTING);
    }
}