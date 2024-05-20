# AVSServiceManager Deployment and Testing Guide

## Introduction

This guide provides instructions for setting up, deploying, and testing the `AVSServiceManager` on the Holesky testnet using Foundry.

## Environment Variables

Set up the following environment variables:

```sh
export HOLESKY_RPC_URL=<your_holesky_rpc_url>
export ETHERSCAN_API_KEY=<your_etherscan_api_key>
export DEPLOYER_PRIVATE_KEY=<your_deployer_private_key>
export DEPLOYER_ADDRESS=<your_deployer_address>
```

Replace `<your_holesky_rpc_url>`, `<your_etherscan_api_key>`, `<your_deployer_private_key>`, and `<your_deployer_address>` with your Holesky RPC URL, Etherscan API key, deployer private key, and deployer address, respectively.

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

# Customizing the Deployment Script

## Filling Out the User Inputs in the Script

The `CustomAVSServiceManagerSetup` script includes several user input sections that need to be customized according to your specific use case. Below are the sections you need to edit:

### Number of Quorums

Set the number of quorums:

```solidity
uint8 numQuorums = 2; // EDIT THIS for your specific use case
```

### Operator Set Params for Each Quorum

Define the parameters for each quorum. Each quorum's parameters include:

- `maxOperatorCount`: Maximum number of operators allowed in the quorum.
- `kickBIPsOfOperatorStake`: Basis points that new Operator's stake must be greater than the old Operator's stake by to kick from quorum.
- `kickBIPsOfTotalStake`: Basis points of the total stake of the quorum that an operator needs to maintain or be kicked.

Example for Quorum 1:

```solidity
operatorSetParams[0] = IRegistryCoordinator.OperatorSetParam({
    maxOperatorCount: 10, // EDIT THIS
    kickBIPsOfOperatorStake: 15000, // EDIT THIS
    kickBIPsOfTotalStake: 150 // EDIT THIS
});
```

### Strategies for Each Quorum

Select strategies for each quorum by choosing indices from the `availableStrategyAddresses` array:

```solidity
strategyAddresses[0] = availableStrategyAddresses[0]; // stETH for Quorum 1
strategyAddresses[1] = availableStrategyAddresses[1]; // rETH for Quorum 2
```

### Strategy Multipliers for Each Quorum

Define the strategy multipliers for each quorum:

```solidity
strategyMultipliers[0] = 10; // EDIT for Quorum 1
strategyMultipliers[1] = 8; // EDIT for Quorum 2
```

### Minimum Stakes for Each Quorum

Set the minimum stake required for each quorum:

```solidity
minimumStakes[0] = 1000; // EDIT for Quorum 1
minimumStakes[1] = 1000; // EDIT for Quorum 2
```

Ensure that the arrays for `strategyAddresses`, `strategyMultipliers`, and `minimumStakes` match the `numQuorums` length. Adjust these values to suit your deployment needs.
