# solv-v2-offering-market-core

This repository contains the core implementation of an offering market, which can be used as a template to create offering markets for different vouchers.

[`OfferingMarketCore.sol`](./contracts/OfferingMarketCore.sol): Implementation of a standard template of an offering market with mainly three abilities. 

1. Allow the market administrator to add/remove supported vouchers, update fees, add/remove whitelist, etc;
2. Allow issuers to create IVO orders;
3. Allow users to purchase from IVO orders.

[`PriceManager.sol`](./contracts/PriceManager.sol): Store and manage prices of each offering of an offering market, supporting two types of pricing: fixed price & declining price (for dutch auction).