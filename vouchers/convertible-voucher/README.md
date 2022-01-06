# solv-v2-convertible-voucher

This repository contains smart contracts for Convertible Voucher.

[`ConvertibleVoucher`](./contracts/ConvertibleVoucher.sol): The core implementation of Convertible Voucher, inheriting from [`VoucherCore`](../voucher-core/contracts/VoucherCore.sol). The contract implements all functionalities of "Convertible Voucher", including minting, claiming, transferring, splitting, merging, etc.

[`ConvertiblePool`](./contracts/ConvertiblePool.sol): Convertible Pool is responsible for managing voucher slots, including creating new slots, maintaining slot status for querying and updating. On the other hand, Convertible Pool is used as a vault of the underlying ERC20 asset as well as fund currencies. Besides, Convertible Pool also handles price settlement on maturity date by querying price from oracle.

[`IVNFTDescriptor`](./contracts/interface/IVNFTDescriptor.sol): VNFTDescriptor is used as a tool to describe a Voucher in terms of three interfaces: `contractURI`, `slotURI` and `tokenURI`.

[`PriceOracleManager`](./contracts/oracle/PriceOracleManager.sol): PriceOracleManager provides the abilities of setting designated oracles and pricing periods for any vouchers, and querying average prices according to tokenId of a voucher or maturity of a slot.

[`ChainlinkPriceOracle`](./contracts/oracle/ChainlinkPriceOracle.sol): ChainlinkPriceOracle provides the abilities of querying token prices from Chainlink adaptors, as well as maintaining historical price querying results. 