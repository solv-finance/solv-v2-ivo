# solv-v2-flexible-date-vesting-voucher

This repository contains smart contracts for the Flexible Date Vesting Voucher.

[`FlexibleDateVestingVoucher`](./contracts/FlexibleDateVestingVoucher.sol): The core implementation of the Flexible Date Vesting Voucher, inheriting from [`VoucherCore`](../voucher-core/contracts/VoucherCore.sol).

[`FlexibleDateVestingPool`](./contracts/FlexibleDateVestingPool.sol): The Vesting Pool is responsible for managing voucher slots, including creating slots when new offerings are issued, maintaining slot status for querying and updating. Besides, the Vesting Pool is also used as a vault of the underlying ERC20 asset, interacting with the Vesting Voucher contract so as to mint standard Vesting Vouchers to users when they claim.

[`IVNFTDescriptor`](./contracts/interface/IVNFTDescriptor.sol): VNFTDescriptor is used as a tool to describe a Voucher in terms of three interfaces: `contractURI`, `slotURI` and `tokenURI`.