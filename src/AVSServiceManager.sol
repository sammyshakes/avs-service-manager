// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@eigenlayer-middleware/src/ServiceManagerBase.sol";

contract AVSServiceManager is ServiceManagerBase {
    constructor(
        IAVSDirectory _avsDirectory,
        IPaymentCoordinator _paymentCoordinator,
        IRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry
    ) ServiceManagerBase(_avsDirectory, _paymentCoordinator, _registryCoordinator, _stakeRegistry) {}

    function initializaServiceManager(address initialOwner) external {
        __ServiceManagerBase_init(initialOwner);
    }
}
