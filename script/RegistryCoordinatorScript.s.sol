// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    RegistryCoordinator,
    IRegistryCoordinator,
    ISignatureUtils
} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IPauserRegistry} from "@eigenlayer/src/contracts/interfaces/IPauserRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import "../src/mocks/EmptyContract.sol";

contract RegistryCoordinatorScript is Script {
    RegistryCoordinator public registryCoordinator;
    RegistryCoordinator public registryCoordinatorImplementation;
    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    function run() external {
        IServiceManager avsServiceManager = IServiceManager(0x0000000000000000000000000000000000000002);
        IStakeRegistry stakeRegistry = IStakeRegistry(0x0000000000000000000000000000000000000003);
        IBLSApkRegistry blsApkRegistry = IBLSApkRegistry(0x0000000000000000000000000000000000000004);
        IIndexRegistry indexRegistry = IIndexRegistry(0x0000000000000000000000000000000000000005);
        IPauserRegistry pauserRegistry = IPauserRegistry(0x0000000000000000000000000000000000000006);

        // Start the deployment script
        vm.startBroadcast();

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin();

        // Deploy EmptyContract
        emptyContract = new EmptyContract();

        // Deploy the implementation contract
        registryCoordinatorImplementation =
            new RegistryCoordinator(avsServiceManager, stakeRegistry, blsApkRegistry, indexRegistry);

        // Deploy the proxy and point it to the implementation contract
        registryCoordinator = RegistryCoordinator(
            address(
                new TransparentUpgradeableProxy(address(registryCoordinatorImplementation), address(proxyAdmin), "")
            )
        );

        // Mock data for initialization
        uint32 defaultMaxOperatorCount = 10;
        uint16 defaultKickBIPsOfOperatorStake = 15000;
        uint16 defaultKickBIPsOfTotalStake = 150;
        uint8 numQuorums = 192;

        IRegistryCoordinator.OperatorSetParam[] memory operatorSetParams =
            new IRegistryCoordinator.OperatorSetParam[](numQuorums);
        for (uint8 i = 0; i < numQuorums; i++) {
            operatorSetParams[i] = IRegistryCoordinator.OperatorSetParam({
                maxOperatorCount: defaultMaxOperatorCount,
                kickBIPsOfOperatorStake: defaultKickBIPsOfOperatorStake,
                kickBIPsOfTotalStake: defaultKickBIPsOfTotalStake
            });
        }

        uint96[] memory minimumStakes = new uint96[](numQuorums);
        for (uint8 i = 0; i < numQuorums; i++) {
            minimumStakes[i] = 1000;
        }

        IStakeRegistry.StrategyParams[][] memory strategyParams = new IStakeRegistry.StrategyParams[][](numQuorums);
        for (uint8 i = 0; i < numQuorums; i++) {
            strategyParams[i] = new IStakeRegistry.StrategyParams[](1);
            strategyParams[i][0] = IStakeRegistry.StrategyParams({
                strategy: IStrategy(address(0x0000000000000000000000000000000000000008)), // Use IStrategy directly
                multiplier: 1
            });
        }

        // Initialize the proxy with mock data
        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(registryCoordinator))),
            address(registryCoordinatorImplementation),
            abi.encodeWithSelector(
                RegistryCoordinator.initialize.selector,
                address(this), // _initialOwner
                address(this), // _churnApprover
                address(this), // _ejector
                pauserRegistry, // _pauserRegistry
                0, // _initialPausedStatus
                operatorSetParams, // _operatorSetParams
                minimumStakes, // _minimumStakes
                strategyParams // _strategyParams
            )
        );

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
