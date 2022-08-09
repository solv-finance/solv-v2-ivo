// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@solv/v2-solidity-utils/contracts/misc/Constants.sol";
import "@solv/v2-solidity-utils/contracts/access/AdminControl.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/math/SafeMathUpgradeable.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/utils/EnumerableSetUpgradeable.sol";
import "@solv/v2-solidity-utils/contracts/math/SafeMathUpgradeable128.sol";
import "@solv/v2-solidity-utils/contracts/helpers/VNFTTransferHelper.sol";
import "@solv/v2-solidity-utils/contracts/helpers/ERC20TransferHelper.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/utils/ReentrancyGuardUpgradeable.sol";
import "@solv/v2-solver/contracts/interface/ISolver.sol";
import "./interface/ISolvMarketplaceV2.sol";

interface IVNFT {
    function unitsInToken(uint256 tokenId)
        external
        view
        returns (uint256 units);
}

contract SolvMarketplaceV2 is
    ISolvMarketplaceV2,
    PriceManager,
    AdminControl,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    event NewSolver(ISolver oldSolver, ISolver newSolver);

    event AddMarket(
        address indexed voucher,
        uint8 decimals,
        uint8 feePayType,
        uint8 feeType,
        uint128 feeAmount,
        uint16 feeRate
    );

    event RemoveMarket(address indexed voucher);

    event SetCurrency(address indexed currency, bool enable);

    event WithdrawFee(address voucher, uint256 reduceAmount);

    struct Sale {
        uint256 tokenId;
        uint256 total;  // sale units
        uint256 units;  // current units
        uint256 min;    // min units
        uint256 max;    // max units
        address voucher;   // sale asset
        address currency;  // pay currency
        address seller;
        uint32 startTime;
        PriceManager.PriceType priceType;
        WhitelistType whitelistType;  // 0 - no limit; 1 - project whitelist; 2 - sale whitelist
        uint24 saleId;
        bool isValid;
    }

    struct Market {
        uint8 decimals;
        FeeType feeType;
        FeePayType feePayType;
        uint128 feeAmount;
        uint16 feeRate;
        bool isValid;
    }

    //saleId => struct Sale
    mapping(uint24 => Sale) public sales;

    // voucher => Market
    mapping(address => Market) public markets;

    EnumerableSetUpgradeable.AddressSet internal _currencies;
    EnumerableSetUpgradeable.AddressSet internal _vouchers;

    // voucher => saleId
    mapping(address => EnumerableSetUpgradeable.UintSet) internal _voucherSales;

    // whitelist set by project manager, which can be shared by multiple sales
    mapping(address => EnumerableSetUpgradeable.AddressSet) internal _projectWhitelist;

    // managers with authorities to set project whitelist of a voucher market
    mapping(address => EnumerableSetUpgradeable.AddressSet) internal _projectManagers;

    // whitelist set by the seller of a sale, which cannot be shared by other sales
    mapping(uint24 => mapping(address => uint256)) internal _saleWhitelist;

    // records of user purchased units from an order
    mapping(uint24 => mapping(address => uint256)) internal _saleRecords;

    ISolver public solver;
    uint24 public nextSaleId;
    uint24 public nextTradeId;

    modifier onlyProjectManager(address voucher_) {
        require(
            msg.sender == admin ||
                _projectManagers[voucher_].contains(msg.sender),
            "only manager"
        );
        _;
    }

    function initialize(ISolver solver_) external initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        AdminControl.__AdminControl_init(msg.sender);
        nextSaleId = 1;
        nextTradeId = 1;
        _setSolver(solver_);
    }

    function currencies() external view returns (address[] memory currencies_) {
        currencies_ = new address[](_currencies.length());
        for (uint256 i = 0; i < _currencies.length(); i++) {
            currencies_[i] = _currencies.at(i);
        }
    }

    function vouchers() external view returns (address[] memory vouchers_) {
        vouchers_ = new address[](_vouchers.length());
        for (uint256 i = 0; i < _vouchers.length(); i++) {
            vouchers_[i] = _vouchers.at(i);
        }
    }

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
        override
        returns (uint24 saleId)
    {
        uint256 err = solver.operationAllowed(
            "publishSale", 
            abi.encode(
                voucher_, tokenId_, _msgSender(), currency_, startTime_, 
                whitelistParams_.whitelistType, priceType_, priceData_
            )
        );
        require(err == 0, "Solver: not allowed");

        saleId = _publish(
            _msgSender(),
            voucher_,
            tokenId_,
            currency_,
            priceType_,
            min_,
            max_,
            startTime_,
            whitelistParams_.whitelistType
        );

        _setPrice(sales[saleId], priceType_, priceData_);

        setPurchaseLimit(saleId, whitelistParams_.saleWhitelist, whitelistParams_.purchaseLimits);
    }

    function _setPrice(
        Sale memory sale_,
        PriceManager.PriceType priceType_,
        bytes memory priceData_
    ) internal {
        if (priceType_ == PriceManager.PriceType.FIXED) {
            uint128 price = abi.decode(priceData_, (uint128));
            PriceManager.setFixedPrice(sale_.saleId, price);

            emit FixedPriceSet(
                sale_.voucher,
                sale_.saleId,
                sale_.tokenId,
                uint8(priceType_),
                price
            );
        } else {
            (
                uint128 highest, uint128 lowest, uint32 duration, uint32 interval
            ) 
                = abi.decode(priceData_, (uint128, uint128, uint32, uint32));
            PriceManager.setDecliningPrice(
                sale_.saleId,
                sale_.startTime,
                highest,
                lowest,
                duration,
                interval
            );

            emit DecliningPriceSet(
                sale_.voucher,
                sale_.saleId,
                sale_.tokenId,
                highest,
                lowest,
                duration,
                interval
            );
        }
    }

    function _publish(
        address seller_,
        address voucher_,
        uint256 tokenId_,
        address currency_,
        PriceManager.PriceType priceType_,
        uint256 min_,
        uint256 max_,
        uint32 startTime_,
        WhitelistType whitelistType_
    ) internal returns (uint24 saleId) {
        require(markets[voucher_].isValid, "unsupported voucher");
        require(_currencies.contains(currency_), "unsupported currency");
        if (max_ > 0) {
            require(min_ <= max_, "min > max");
        }

        VNFTTransferHelper.doTransferIn(voucher_, seller_, tokenId_);

        IVNFT vnft = IVNFT(voucher_);
        uint256 units = vnft.unitsInToken(tokenId_);
        // require(units <= uint128(-1), "exceeds uint128 max");

        saleId = _generateNextSaleId();

        sales[saleId] = Sale({
            saleId: saleId,
            seller: msg.sender,
            tokenId: tokenId_,
            total: units,
            units: units,
            startTime: startTime_,
            min: min_,
            max: max_,
            voucher: voucher_,
            currency: currency_,
            priceType: priceType_,
            whitelistType: whitelistType_,
            isValid: true
        });
        Sale storage sale = sales[saleId];
        _voucherSales[voucher_].add(saleId);
        emit Publish(
            sale.voucher,
            sale.seller,
            sale.tokenId,
            saleId,
            uint8(sale.priceType),
            sale.units,
            sale.startTime,
            sale.currency,
            sale.min,
            sale.max,
            sale.whitelistType
        );
        solver.operationVerify(
            "publish",
            abi.encode(
                sale.voucher,
                sale.tokenId,
                sale.seller,
                sale.currency,
                sale.saleId,
                sale.units
            )
        );

        return saleId;
    }

    function buyByAmount(uint24 saleId_, uint256 amount_)
        external
        payable
        virtual
        override
        returns (uint256 units_)
    {
        Sale storage sale = sales[saleId_];
        address buyer = msg.sender;
        uint128 fee = _getFee(sale.voucher, amount_);
        uint128 price = PriceManager.price(sale.priceType, sale.saleId);
        // uint256 units256;
        if (markets[sale.voucher].feePayType == FeePayType.BUYER_PAY) {
            amount_ = amount_.sub(fee, "fee exceeds amount");
            units_ = amount_
                .mul(10 ** markets[sale.voucher].decimals)
                .div(uint256(price));
        } else {
            units_ = amount_
                .mul(10 ** markets[sale.voucher].decimals)
                .div(uint256(price));
        }
        // require(units256 <= uint128(-1), "exceeds uint128 max");
        // units_ = uint128(units256);

        uint256 err = solver.operationAllowed(
            "buyByAmount",
            abi.encode(
                sale.voucher,
                sale.tokenId,
                saleId_,
                buyer,
                sale.currency,
                amount_,
                units_,
                price
            )
        );
        require(err == 0, "solver not allowed");

        _buy(buyer, sale, amount_, units_, price, fee);
        return units_;
    }

    function buyByUnits(uint24 saleId_, uint256 units_)
        external
        payable
        virtual
        override
        returns (uint256 amount_, uint128 fee_)
    {
        Sale storage sale = sales[saleId_];
        if (markets[sale.voucher].feePayType == FeePayType.BUYER_PAY) {
            require(sale.currency != Constants.ETH_ADDRESS, "buyByUnits unsupported");
        }

        address buyer = msg.sender;
        uint128 price = PriceManager.price(sale.priceType, sale.saleId);

        amount_ = units_.mul(uint256(price)).div(10 ** markets[sale.voucher].decimals);

        fee_ = _getFee(sale.voucher, amount_);

        uint256 err = solver.operationAllowed(
            "buyByUnits",
            abi.encode(
                sale.voucher,
                sale.tokenId,
                saleId_,
                buyer,
                sale.currency,
                amount_,
                units_,
                price
            )
        );
        require(err == 0, "solver not allowed");

        _buy(buyer, sale, amount_, units_, price, fee_);
        return (amount_, fee_);
    }

    struct BuyLocalVar {
        uint256 transferInAmount;
        uint256 transferOutAmount;
        FeePayType feePayType;
    }

    function _buy(
        address buyer_,
        Sale storage sale_,
        uint256 amount_,
        uint256 units_,
        uint128 price_,
        uint128 fee_
    ) internal {
        require(sale_.isValid, "invalid saleId");
        require(block.timestamp >= sale_.startTime, "not yet on sale");

        // uint128 purchased = _saleRecords[sale_.saleId][buyer_].add(units_);
        _saleRecords[sale_.saleId][buyer_] = _saleRecords[sale_.saleId][buyer_].add(units_);

        if (sale_.whitelistType == WhitelistType.SALE) {
            require(_saleWhitelist[sale_.saleId][buyer_] > 0, "not in sale whitelist");
            require(
                _saleRecords[sale_.saleId][buyer_] <= _saleWhitelist[sale_.saleId][buyer_], 
                "over purchase upper limit"
            );

        } else {
            if (sale_.whitelistType == WhitelistType.PROJECT) {
                require(_projectWhitelist[sale_.voucher].contains(buyer_), "not in project whitelist");
            }

            // Sale with project whitelist or without any whitelist should follow the min/max restrictions
            require(
                sale_.units <= sale_.min || units_ >= sale_.min, 
                "below purchase lower limit"
            );
            require(
                sale_.max == 0 || _saleRecords[sale_.saleId][buyer_] <= sale_.max, 
                "over purchase upper limit"
            );
        }

        sale_.units = sale_.units.sub(units_, "insufficient units for sale");
        BuyLocalVar memory vars;
        vars.feePayType = markets[sale_.voucher].feePayType;

        if (vars.feePayType == FeePayType.BUYER_PAY) {
            vars.transferInAmount = amount_.add(fee_);
            vars.transferOutAmount = amount_;
        } else if (vars.feePayType == FeePayType.SELLER_PAY) {
            vars.transferInAmount = amount_;
            vars.transferOutAmount = amount_.sub(fee_, "fee exceeds amount");
        } else {
            revert("unsupported feePayType");
        }

        ERC20TransferHelper.doTransferIn(
            sale_.currency,
            buyer_,
            vars.transferInAmount
        );

        if (units_ == IVNFT(sale_.voucher).unitsInToken(sale_.tokenId)) {
            VNFTTransferHelper.doTransferOut(
                sale_.voucher,
                buyer_,
                sale_.tokenId
            );
        } else {
            VNFTTransferHelper.doTransferOut(
                sale_.voucher,
                buyer_,
                sale_.tokenId,
                units_
            );
        }
        ERC20TransferHelper.doTransferOut(
            sale_.currency,
            payable(sale_.seller),
            vars.transferOutAmount
        );

        emit Traded(
            buyer_,
            sale_.saleId,
            sale_.voucher,
            sale_.tokenId,
            _generateNextTradeId(),
            uint32(block.timestamp),
            sale_.currency,
            uint8(sale_.priceType),
            price_,
            units_,
            amount_,
            uint8(vars.feePayType),
            fee_
        );

        solver.operationVerify(
            "buy",
            abi.encode(
                sale_.voucher,
                sale_.tokenId,
                sale_.saleId,
                buyer_,
                sale_.seller,
                amount_,
                units_,
                price_,
                fee_
            )
        );

        if (sale_.units == 0) {
            emit Remove(
                sale_.voucher,
                sale_.seller,
                sale_.saleId,
                sale_.total,
                sale_.total - sale_.units
            );
            delete sales[sale_.saleId];
        }
    }

    function purchasedUnits(uint24 saleId_, address buyer_)
        external
        view
        returns (uint256)
    {
        return _saleRecords[saleId_][buyer_];
    }

    function remove(uint24 saleId_) public virtual override {
        Sale memory sale = sales[saleId_];
        require(sale.isValid, "invalid sale");
        require(sale.seller == msg.sender, "only seller");

        uint256 err = solver.operationAllowed(
            "remove",
            abi.encode(sale.voucher, sale.tokenId, sale.saleId, sale.seller)
        );
        require(err == 0, "solver not allowed");

        VNFTTransferHelper.doTransferOut(
            sale.voucher,
            sale.seller,
            sale.tokenId
        );

        emit Remove(
            sale.voucher,
            sale.seller,
            sale.saleId,
            sale.total,
            sale.total - sale.units
        );
        delete sales[saleId_];
    }

    function _getFee(address voucher_, uint256 amount)
        internal
        view
        returns (uint128)
    {
        Market storage market = markets[voucher_];
        if (market.feeType == FeeType.FIXED) {
            return market.feeAmount;
        } else if (market.feeType == FeeType.BY_AMOUNT) {
            uint256 fee = amount.mul(uint256(market.feeRate)).div(
                uint256(Constants.FULL_PERCENTAGE)
            );
            require(fee <= uint128(-1), "Fee: exceeds uint128 max");
            return uint128(fee);
        } else {
            revert("unsupported feeType");
        }
    }

    function getPrice(uint24 saleId_)
        public
        view
        virtual
        override
        returns (uint128)
    {
        return PriceManager.price(sales[saleId_].priceType, saleId_);
    }

    function totalSalesOfICToken(address voucher_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _voucherSales[voucher_].length();
    }

    function saleIdOfICTokenByIndex(address voucher_, uint256 index_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _voucherSales[voucher_].at(index_);
    }

    function _generateNextSaleId() internal returns (uint24) {
        return nextSaleId++;
    }

    function _generateNextTradeId() internal returns (uint24) {
        return nextTradeId++;
    }

    function _addMarket(
        address voucher_,
        uint8 decimals_,
        uint8 feePayType_,
        uint8 feeType_,
        uint128 feeAmount_,
        uint16 feeRate_
    ) external onlyAdmin {
        require(voucher_ != address(0), "voucher can not be 0 address");
        require(feeRate_ <= Constants.FULL_PERCENTAGE, "invalid fee rate");

        markets[voucher_].isValid = true;
        markets[voucher_].decimals = decimals_;
        markets[voucher_].feePayType = FeePayType(feePayType_);
        markets[voucher_].feeType = FeeType(feeType_);
        markets[voucher_].feeAmount = feeAmount_;
        markets[voucher_].feeRate = feeRate_;

        _vouchers.add(voucher_);

        emit AddMarket(
            voucher_,
            decimals_,
            feePayType_,
            feeType_,
            feeAmount_,
            feeRate_
        );
    }

    function _removeMarket(address voucher_) external onlyAdmin {
        require(_vouchers.contains(voucher_), "voucher not exists");
        _vouchers.remove(voucher_);
        delete markets[voucher_];
        emit RemoveMarket(voucher_);
    }

    function _setCurrency(address currency_, bool enable_) external onlyAdmin {
        _currencies.add(currency_);
        emit SetCurrency(currency_, enable_);
    }

    function _withdrawFee(address currency_, uint256 reduceAmount_)
        external
        onlyAdmin
    {
        ERC20TransferHelper.doTransferOut(
            currency_,
            payable(admin),
            reduceAmount_
        );
        emit WithdrawFee(currency_, reduceAmount_);
    }

    function addProjectWhitelist(
        address voucher_,
        address[] calldata addresses_,
        bool resetExisting_
    ) external onlyProjectManager(voucher_) {
        require(markets[voucher_].isValid, "unsupported voucher");
        EnumerableSetUpgradeable.AddressSet storage set = _projectWhitelist[
            voucher_
        ];

        if (resetExisting_) {
            while (set.length() != 0) {
                set.remove(set.at(0));
            }
        }

        for (uint256 i = 0; i < addresses_.length; i++) {
            set.add(addresses_[i]);
        }
    }

    function removeProjectWhitelist(
        address voucher_,
        address[] calldata addresses_
    ) external onlyProjectManager(voucher_) {
        require(markets[voucher_].isValid, "unsupported voucher");
        EnumerableSetUpgradeable.AddressSet storage set = _projectWhitelist[
            voucher_
        ];
        for (uint256 i = 0; i < addresses_.length; i++) {
            set.remove(addresses_[i]);
        }
    }

    function isBuyerAllowed(address voucher_, address buyer_)
        external
        view
        returns (bool)
    {
        return _projectWhitelist[voucher_].contains(buyer_);
    }

    function getPurchaseLimit(uint24 saleId_, address buyer_) public view returns (uint256) {
        return _saleWhitelist[saleId_][buyer_];
    }

    function setPurchaseLimit(
        uint24 saleId_, 
        address[] calldata whitelist_, 
        uint256[] calldata purchaseLimits_
    ) 
        public 
    {
        Sale storage sale = sales[saleId_];
        require(sale.isValid, "invalid saleId");
        require(_msgSender() == sale.seller, "only seller");
        require(whitelist_.length == purchaseLimits_.length, "array lengths must match in quantity");

        uint256 size = whitelist_.length;
        for (uint256 i = 0; i < size; i++) {
            _saleWhitelist[saleId_][whitelist_[i]] = purchaseLimits_[i];
        }
    }

    function setProjectManager(
        address voucher_,
        address[] calldata managers_,
        bool resetExisting_
    ) external onlyAdmin {
        require(markets[voucher_].isValid, "unsupported voucher");
        EnumerableSetUpgradeable.AddressSet storage set = _projectManagers[
            voucher_
        ];
        if (resetExisting_) {
            while (set.length() != 0) {
                set.remove(set.at(0));
            }
        }

        for (uint256 i = 0; i < managers_.length; i++) {
            set.add(managers_[i]);
        }
    }

    function projectManager(address voucher_, uint256 index_)
        external
        view
        returns (address)
    {
        return _projectManagers[voucher_].at(index_);
    }

    function _setSolver(ISolver newSolver_) public virtual onlyAdmin {
        ISolver oldSolver = solver;
        require(newSolver_.isSolver(), "invalid solver");
        solver = newSolver_;

        emit NewSolver(oldSolver, newSolver_);
    }

}
