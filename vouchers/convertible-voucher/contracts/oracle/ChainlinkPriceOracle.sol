// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@solv/v2-solidity-utils/contracts/chainlink/ChainlinkClient.sol";
import "@solv/v2-solidity-utils/contracts/misc/BokkyPooBahsDateTimeLibrary.sol";
import "@solv/v2-solidity-utils/contracts/misc/StringConvertor.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/utils/EnumerableSetUpgradeable.sol";
import "../interface/IPriceOracle.sol";

contract ChainlinkPriceOracle is IPriceOracle, ChainlinkClient {
    using StringConvertor for uint256;
    using StringConvertor for bytes;
    using StringConvertor for address;
    using BokkyPooBahsDateTimeLibrary for uint256;
    using Chainlink for Chainlink.Request;

    struct Request {
        address underlying;
        bytes32 dateSignature;
    }

    event NewAdmin(
        address oldAdmin, 
        address newAdmin
    );

    event NewPendingAdmin(
        address oldPendingAdmin, 
        address newPendingAdmin
    );

    event SetPriceOracleManager(
        address oldPriceOracleManager, 
        address newPriceOracleManager
    );

    event SetJobId(
        bytes32 oldJobId,
        bytes32 newJobId
    );
 
    event SetOraclePayment(
        uint256 oldOraclePayment,
        uint256 newOraclePayment
    );

    event SetTokenId(
        address underlying,
        uint256 tokenId
    );

    event RefreshPrice(
        address underlying, 
        uint64 fromDate, 
        uint64 toDate,
        bytes32 requestId
    );

    address public admin;
    address public pendingAdmin;

    address public priceOracleManager;

    //underlying => datesig => price
    mapping(address => mapping(bytes32 => int256)) public prices;

    //underlying => cmc token id
    mapping(address => uint256) public tokenIds;

    //requestId => Request
    mapping(bytes32 => Request) public requests;

    bytes32 public JOB_ID;
    uint256 public oraclePayment;

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    modifier onlyPriceOracleManager() {
        require(msg.sender == priceOracleManager, "only priceOracleManager");
        _;
    }

    constructor(bytes32 jobId_, uint256 oraclePayment_) {
        JOB_ID = jobId_;
        admin = msg.sender;
        oraclePayment = oraclePayment_;
    }

    function refreshPrice(
        address underlying_,
        uint64 fromDate_,
        uint64 toDate_
    ) external override onlyPriceOracleManager {
        require(block.timestamp > toDate_, "premature");

        string memory fromDate = _getDateString(fromDate_);
        string memory toDate = _getDateString(toDate_);

        bytes32 dateSignature = _getDateSignature(fromDate, toDate);
        require(prices[underlying_][dateSignature] != 0, "already refreshed");

        bytes32 requestId = _requestChainlinkOracle(
            underlying_,
            fromDate,
            toDate
        );
        requests[requestId] = Request({
            underlying: underlying_,
            dateSignature: _getDateSignature(fromDate, toDate)
        });

        emit RefreshPrice(underlying_, fromDate_, toDate_, requestId);
    }

    function getPrice(
        address underlying_,
        uint64 fromDate_,
        uint64 toDate_
    ) external view override returns (int256) {
        string memory fromDate = _getDateString(fromDate_);
        string memory toDate = _getDateString(toDate_);
        bytes32 dateSignature = _getDateSignature(fromDate, toDate);
        return prices[underlying_][dateSignature];
    }

    function _getDateString(uint64 date_)
        internal
        pure
        returns (string memory)
    {
        uint256 year = uint256(date_).getYear();
        uint256 month = uint256(date_).getMonth();
        uint256 day = uint256(date_).getDay();
        return string(abi.encodePacked(year, "-", month, "-", day));
    }

    function _requestChainlinkOracle(
        address underlying_,
        string memory fromDate_,
        string memory toDate_
    ) internal returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            JOB_ID,
            address(this),
            this.fulfill.selector
        );
        uint256 tokenId = tokenIds[underlying_];
        require(tokenId > 0, "invalid underlying");
        req.addUint("tokenId", tokenId);
        req.add("from", fromDate_);
        req.add("to", toDate_);

        requestId = sendChainlinkRequest(req, oraclePayment);
    }

    function _getDateSignature(string memory fromDate_, string memory toDate_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(fromDate_, toDate_));
    }

    function fulfill(bytes32 requestId_, uint256 value_)
        public
        recordChainlinkFulfillment(requestId_)
    {
        Request memory request = requests[requestId_];
        require(request.underlying != address(0), "invalid request");
        prices[request.underlying][request.dateSignature] = int256(value_);
    }

    function setJobId(bytes32 jobId_) external onlyAdmin {
        emit SetJobId(JOB_ID, jobId_);
        JOB_ID = jobId_;
    }

    function setOraclePayment(uint256 payment_) external onlyAdmin {
        emit SetOraclePayment(oraclePayment, payment_);
        oraclePayment = payment_;
    }

    function setTokenId(address underlying_, uint256 tokenId_)
        external
        onlyAdmin
    {
        tokenIds[underlying_] = tokenId_;
        emit SetTokenId(underlying_, tokenId_);
    }

    function setPriceOracleManager(address manager_) external onlyAdmin {
        require(manager_ != address(0), "manager can not be 0 address");
        emit SetPriceOracleManager(priceOracleManager, manager_);
        priceOracleManager = manager_;
    }

    function setPendingAdmin(address newPendingAdmin) external {
        require(msg.sender == admin, "only admin");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    function acceptAdmin() external {
        require(
            msg.sender == pendingAdmin && msg.sender != address(0),
            "only pending admin"
        );

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }
}
