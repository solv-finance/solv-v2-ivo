// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@solv/v2-solidity-utils/contracts/access/AdminControl.sol";
import "@solv/v2-solidity-utils/contracts/misc/Constants.sol";
import "@solv/v2-solidity-utils/contracts/misc/StringConvertor.sol";
import "@solv/v2-solidity-utils/contracts/helpers/ERC20TransferHelper.sol";
import "@solv/v2-solidity-utils/contracts/helpers/VNFTTransferHelper.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/utils/ReentrancyGuardUpgradeable.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/utils/EnumerableSetUpgradeable.sol";
import "@solv/v2-solidity-utils/contracts/openzeppelin/token/ERC20/IERC20.sol";
import "@solv/v2-vnft-core/contracts/interface/optional/IUnderlyingContainer.sol";
import "./interface/IFlexibleDateVestingPool.sol";
import "./interface/external/IICToken.sol";

contract FlexibleDateVestingPool is
    IFlexibleDateVestingPool,
    AdminControl,
    ReentrancyGuardUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using StringConvertor for address;
    using StringConvertor for uint64;
    using StringConvertor for uint64[];
    using StringConvertor for uint32[];

    /// @dev slot => SlotDetail
    mapping(uint256 => SlotDetail) internal _slotDetails;

    mapping(address => EnumerableSetUpgradeable.UintSet) internal _issuerSlots;

    address public underlyingVestingVoucher;
    address public underlyingToken;

    address public manager;

    uint256 public totalAmount;
    mapping(uint256 => uint256) public amountOfSlot;

    modifier onlyManager() {
        require(_msgSender() == manager, "only manager");
        _;
    }

    function initialize(address underlyingVestingVoucher_)
        external
        initializer
    {
        AdminControl.__AdminControl_init(_msgSender());
        underlyingVestingVoucher = underlyingVestingVoucher_;
        underlyingToken = IUnderlyingContainer(underlyingVestingVoucher)
            .underlying();
    }

    function createSlot(
        address issuer_,
        uint8 claimType_,
        uint64 latestStartTime_,
        uint64[] calldata terms_,
        uint32[] calldata percentages_
    ) external onlyManager returns (uint256 slot) {
        slot = getSlot(
            issuer_,
            claimType_,
            latestStartTime_,
            terms_,
            percentages_
        );
        require(!_slotDetails[slot].isValid, "slot already existed");
        require(
            terms_.length == percentages_.length,
            "invalid terms and percentages"
        );

        uint256 sumOfPercentages = 0;
        for (uint256 i = 0; i < percentages_.length; i++) {
            sumOfPercentages += percentages_[i];
        }
        require(
            sumOfPercentages == Constants.FULL_PERCENTAGE,
            "not full percentage"
        );

        require(
            (claimType_ == uint8(Constants.ClaimType.LINEAR) &&
                percentages_.length == 1) ||
                (claimType_ == uint8(Constants.ClaimType.ONE_TIME) &&
                    percentages_.length == 1) ||
                (claimType_ == uint8(Constants.ClaimType.STAGED) &&
                    percentages_.length > 1),
            "invalid params"
        );

        _slotDetails[slot] = SlotDetail({
            issuer: issuer_,
            claimType: claimType_,
            startTime: 0,
            latestStartTime: latestStartTime_,
            terms: terms_,
            percentages: percentages_,
            isValid: true
        });

        _issuerSlots[issuer_].add(slot);

        emit CreateSlot(
            slot,
            issuer_,
            claimType_,
            latestStartTime_,
            terms_,
            percentages_
        );
    }

    function mint(
        address minter_,
        uint256 slot_,
        uint256 vestingAmount_
    ) external onlyManager {
        ERC20TransferHelper.doTransferIn(
            underlyingToken,
            minter_,
            vestingAmount_
        );
        amountOfSlot[slot_] += vestingAmount_;
        totalAmount += vestingAmount_;
        emit Mint(minter_, slot_, vestingAmount_);
    }

    function claim(
        uint256 slot_,
        address to_,
        uint256 claimAmount
    ) external onlyManager {
        if (claimAmount > amountOfSlot[slot_]) {
            claimAmount = amountOfSlot[slot_];
        }
        amountOfSlot[slot_] -= claimAmount;
        totalAmount -= claimAmount;

        SlotDetail storage slotDetail = _slotDetails[slot_];
        uint64 finalTerm = slotDetail.claimType ==
            uint8(Constants.ClaimType.LINEAR)
            ? slotDetail.terms[0]
            : slotDetail.claimType == uint8(Constants.ClaimType.ONE_TIME)
            ? 0
            : stagedTermsToVestingTerm(slotDetail.terms);
        uint64 startTime = slotDetail.startTime > 0
            ? slotDetail.startTime
            : slotDetail.latestStartTime;

        uint64[] memory maturities = new uint64[](slotDetail.terms.length);
        maturities[0] = startTime + slotDetail.terms[0];
        for (uint256 i = 1; i < maturities.length; i++) {
            maturities[i] = maturities[i - 1] + slotDetail.terms[i];
        }

        IERC20(underlyingToken).approve(
            address(IICToken(underlyingVestingVoucher).vestingPool()),
            claimAmount
        );
        (, uint256 vestingVoucherId) = IICToken(underlyingVestingVoucher).mint(
            finalTerm,
            claimAmount,
            maturities,
            slotDetail.percentages,
            ""
        );
        VNFTTransferHelper.doTransferOut(
            address(underlyingVestingVoucher),
            to_,
            vestingVoucherId
        );
        emit Claim(slot_, to_, claimAmount);
    }

    function setStartTime(
        address setter_,
        uint256 slot_,
        uint64 startTime_
    ) external onlyManager {
        SlotDetail storage slotDetail = _slotDetails[slot_];
        require(slotDetail.isValid, "invalid slot");
        require(setter_ == slotDetail.issuer, "only issuer");
        require(
            startTime_ <= slotDetail.latestStartTime,
            "exceeds latestStartTime"
        );
        if (slotDetail.startTime > 0) {
            require(block.timestamp < slotDetail.startTime, "unchangeable");
        }

        emit SetStartTime(slot_, slotDetail.startTime, startTime_);
        slotDetail.startTime = startTime_;
    }

    function isClaimable(uint256 slot_) external view returns (bool) {
        SlotDetail storage slotDetail = _slotDetails[slot_];
        return
            (slotDetail.isValid &&
                (slotDetail.startTime == 0 &&
                    block.timestamp >= slotDetail.latestStartTime)) ||
            (slotDetail.startTime > 0 &&
                block.timestamp >= slotDetail.startTime);
    }

    function getSlot(
        address issuer_,
        uint8 claimType_,
        uint64 latestStartTime_,
        uint64[] calldata terms_,
        uint32[] calldata percentages_
    ) public view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        underlyingToken,
                        underlyingVestingVoucher,
                        issuer_,
                        claimType_,
                        latestStartTime_,
                        terms_,
                        percentages_
                    )
                )
            );
    }

    function getSlotDetail(uint256 slot_)
        external
        view
        returns (SlotDetail memory)
    {
        return _slotDetails[slot_];
    }

    function getIssuerSlots(address issuer_)
        external
        view
        returns (uint256[] memory slots)
    {
        slots = new uint256[](_issuerSlots[issuer_].length());
        for (uint256 i = 0; i < slots.length; i++) {
            slots[i] = _issuerSlots[issuer_].at(i);
        }
    }

    function getIssuerSlotDetails(address issuer_)
        external
        view
        returns (SlotDetail[] memory slotDetails)
    {
        slotDetails = new SlotDetail[](_issuerSlots[issuer_].length());
        for (uint256 i = 0; i < slotDetails.length; i++) {
            slotDetails[i] = _slotDetails[_issuerSlots[issuer_].at(i)];
        }
    }

    function slotProperties(uint256 slot_)
        external
        view
        returns (string memory)
    {
        SlotDetail storage slotDetail = _slotDetails[slot_];
        return
            string(
                abi.encodePacked(
                    abi.encodePacked(
                        '{"underlyingToken":"',
                        underlyingToken.addressToString(),
                        '","underlyingVesting":"',
                        underlyingVestingVoucher.addressToString(),
                        '","claimType:"',
                        _parseClaimType(slotDetail.claimType),
                        '","terms:"',
                        slotDetail.terms.uintArray2str(),
                        '","percentages:"',
                        slotDetail.percentages.percentArray2str()
                    ),
                    abi.encodePacked(
                        '","issuer":"',
                        slotDetail.issuer.addressToString(),
                        '","startTime:"',
                        slotDetail.startTime.toString(),
                        '","latestStartTime:"',
                        slotDetail.latestStartTime.toString(),
                        '"}'
                    )
                )
            );
    }

    function setManager(address newManager_) external onlyAdmin {
        emit NewManager(manager, newManager_);
        manager = newManager_;
    }

    function stagedTermsToVestingTerm(uint64[] memory terms_)
        private
        pure
        returns (uint64 vestingTerm)
    {
        for (uint256 i = 1; i < terms_.length; i++) {
            vestingTerm += terms_[i];
        }
    }

    function _parseClaimType(uint8 claimTypeInNum_)
        private
        pure
        returns (string memory)
    {
        return
            claimTypeInNum_ == 0 ? "LINEAR" : claimTypeInNum_ == 1
                ? "ONE_TIME"
                : claimTypeInNum_ == 2
                ? "STAGED"
                : "UNKNOWN";
    }
}
