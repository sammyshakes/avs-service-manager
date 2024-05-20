// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RegistryCoordinator, ISignatureUtils} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import "../src/mocks/EmptyContract.sol";

contract RegisterOperatorScript is Script {
    RegistryCoordinator public registryCoordinator;

    function run() external {
        uint256 _deployerPrivateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
        address _registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR");

        // Start the deployment script
        vm.startBroadcast(_deployerPrivateKey);

        registryCoordinator = RegistryCoordinator(_registryCoordinator);

        // Mock data for registering an operator
        address operator = 0x0000000000000000000000000000000000000007;
        bytes32 operatorId = keccak256(abi.encodePacked(operator));
        bytes memory quorumNumbers = abi.encodePacked(uint8(1), uint8(2));
        string memory socket = "127.0.0.1";
        IBLSApkRegistry.PubkeyRegistrationParams memory params;
        params.pubkeyRegistrationSignature = BN254.G1Point(0, 0);
        params.pubkeyG1 = BN254.G1Point(0, 0);
        params.pubkeyG2 = BN254.G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)]);
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        // Register operator
        registryCoordinator.registerOperator(quorumNumbers, socket, params, operatorSignature);

        // Deregister operator
        registryCoordinator.deregisterOperator(quorumNumbers);
    }
}
