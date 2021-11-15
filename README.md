# solv-v2-ivo

Solv Protocol is the decentralized platform for creating, managing and trading Financial NFTs.

This repository contains the core smart contracts for IVO (Initial Voucher Offering) on SOLV offering marketpalce.

## Structure

### commons

[`commons`](./commons) contains the common modules used for other smart contracts.

- [`solidity-utils`](./commons/solidity-utils): A library for smart contract development, including authority management, token transferring, string converter, etc.

- [`upgrade-proxy`](./commons/upgrade-proxy): Smart contracts for the upgrade proxy pattern, introduced from Openzeppelin.

- [`solver`](./commons/sovler): The global manager of SOLV products, controlling and verifying user permissions to operate on SOLV vouchers as well as SOLV markets.

### vouchers

[`vouchers`](./vouchers) contains smart contracts for a collection of different kind of Vouchers, along with the standard implementations of `VNFT`(ERC-3525) and `Voucher`.

- [`vnft-core`](./vouchers/vnft-core): Describes the basic and optional interfaces for `VNFT`, as well as a standard implementation of `VNFT`.

- [`voucher-core`](./vouchers/voucher-core): Describes a standard implementation of a basic `Voucher` as the template to create Vouchers for different scenarios.

- [`flexible-date-vesting-voucher`](./vouchers/flexible-date-vesting-voucher): Contains smart contracts for the Flexible Date Vesting Voucher, which is used to represent a vesting plan with an undetermined start date. Once the date is settled, you will get a standard Vesting Voucher as the Voucher described.


### markets

[`markets`](./markets) contains smart contracts for the SOLV offering markets.

- [`offering-market-core`](./markets/offering-market-core): Core implementation of an offering market, which can be used as a template to create offering markets for different vouchers.

- [`vesting-offering-market`](./markets/vesting-offering-market): Contains smart contracts for the Vesting Offering Market, which is used for the IVO of standard Vesting Vouchers as well as Flexible Date Vesting Vouchers.