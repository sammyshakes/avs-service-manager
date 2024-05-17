# AVSServiceManager Deployment and Testing Guide

## Introduction

This guide provides instructions for setting up, deploying, and testing the `AVSServiceManager` on the Holesky testnet using Foundry.

## Environment Variables

Set up the following environment variables:

```sh
export HOLESKY_RPC_URL=<your_holesky_rpc_url>
export ETHERSCAN_API_KEY=<your_etherscan_api_key>
export DEPLOYER_PRIVATE_KEY=<your_deployer_private_key>
```

Replace `<your_holesky_rpc_url>`, `<your_etherscan_api_key>`, and `<your_deployer_private_key>` with your Holesky RPC URL, Etherscan API key, and deployer private key, respectively.

## Running Tests

To run the tests, use the following command:

```sh
forge test -vvvv --rpc-url $HOLESKY_RPC_URL
```

## Running the Deployment Script

To deploy the `AVSServiceManager` using the provided script, run the following command:

```sh
forge script script/CustomAVSServiceManagerSetup.s.sol -vvvv --rpc-url $HOLESKY_RPC_URL --via-ir --legacy
```

> NOTE: The deployer account must have sufficient holesky testnet funds to deploy the smart contract.
