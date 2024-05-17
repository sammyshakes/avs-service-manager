// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AVSServiceManager, IAVSDirectory, IPaymentCoordinator, IServiceManager} from "../src/AVSServiceManager.sol";
import {RegistryCoordinator, IRegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry, IStakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {IIndexRegistry} from "@eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";
import {IPauserRegistry} from "@eigenlayer/src/contracts/interfaces/IPauserRegistry.sol";
import {EmptyContract} from "../src/mocks/EmptyContract.sol";

contract CustomAVSServiceManagerSetup is Script {
    ProxyAdmin public proxyAdmin;
    EmptyContract public emptyContract;

    AVSServiceManager public avsServiceManager;
    RegistryCoordinator public registryCoordinator;
    BLSApkRegistry public blsApkRegistry;
    IndexRegistry public indexRegistry;
    StakeRegistry public stakeRegistry;

    uint256 _deployerPrivateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));

    function run() external {
        vm.startBroadcast(_deployerPrivateKey);

        // Define addresses for core contracts and strategies
        address proxyAdminOwner = address(0x001);
        address avsDirectory = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
        address paymentCoordinator = 0x0000000000000000000000000000000000000003;
        address delegationManager = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
        address pauserRegistryAddress = 0x0000000000000000000000000000000000000006;

        // Define strategy addresses
        address[] memory strategyAddresses = new address[](10);
        strategyAddresses[0] = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3; // stETH
        strategyAddresses[1] = 0x3A8fBdf9e77DFc25d09741f51d3E181b25d0c4E0; // rETH
        strategyAddresses[2] = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9; // WETH
        strategyAddresses[3] = 0x05037A81BD7B4C9E0F7B430f1F2A22c31a2FD943; // lsETH
        strategyAddresses[4] = 0x9281ff96637710Cd9A5CAcce9c6FAD8C9F54631c; // sfrxETH
        strategyAddresses[5] = 0x31B6F59e1627cEfC9fA174aD03859fC337666af7; // ETHx
        strategyAddresses[6] = 0x46281E3B7fDcACdBa44CADf069a94a588Fd4C6Ef; // osETH
        strategyAddresses[7] = 0x70EB4D3c164a6B4A5f908D4FBb5a9cAfFb66bAB6; // cbETH
        strategyAddresses[8] = 0xaccc5A86732BE85b5012e8614AF237801636F8e5; // mETH
        strategyAddresses[9] = 0x7673a47463F80c6a3553Db9E54c8cDcd5313d0ac; // ankrETH

        uint32 defaultMaxOperatorCount = 10;
        uint16 defaultKickBIPsOfOperatorStake = 15000;
        uint16 defaultKickBIPsOfTotalStake = 150;
        uint8 numQuorums = 5;
        uint96 minimumStake = 1000;
        uint96 strategyMultiplier = 1;

        proxyAdmin = new ProxyAdmin();
        emptyContract = new EmptyContract();

        avsServiceManager =
            AVSServiceManager(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        registryCoordinator = RegistryCoordinator(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), ""))
        );

        blsApkRegistry =
            BLSApkRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        indexRegistry =
            IndexRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        stakeRegistry =
            StakeRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        StakeRegistry stakeRegistryImplementation =
            new StakeRegistry(IRegistryCoordinator(address(registryCoordinator)), IDelegationManager(delegationManager));

        IndexRegistry indexRegistryImplementation =
            new IndexRegistry(IRegistryCoordinator(address(registryCoordinator)));

        BLSApkRegistry blsApkRegistryImplementation =
            new BLSApkRegistry(IRegistryCoordinator(address(registryCoordinator)));

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(stakeRegistry))), address(stakeRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))), address(indexRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsApkRegistry))), address(blsApkRegistryImplementation)
        );

        RegistryCoordinator registryCoordinatorImplementation = new RegistryCoordinator(
            IServiceManager(address(avsServiceManager)),
            IStakeRegistry(address(stakeRegistry)),
            IBLSApkRegistry(address(blsApkRegistry)),
            IIndexRegistry(address(indexRegistry))
        );

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
            minimumStakes[i] = minimumStake;
        }

        IStakeRegistry.StrategyParams[][] memory strategyParams = new IStakeRegistry.StrategyParams[][](numQuorums);
        for (uint8 i = 0; i < numQuorums; i++) {
            strategyParams[i] = new IStakeRegistry.StrategyParams[](1);
            strategyParams[i][0] = IStakeRegistry.StrategyParams({
                strategy: IStrategy(strategyAddresses[i % strategyAddresses.length]),
                multiplier: strategyMultiplier
            });
        }

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(registryCoordinator))),
            address(registryCoordinatorImplementation),
            abi.encodeWithSelector(
                RegistryCoordinator.initialize.selector,
                proxyAdminOwner,
                proxyAdminOwner,
                proxyAdminOwner,
                IPauserRegistry(pauserRegistryAddress),
                0,
                operatorSetParams,
                minimumStakes,
                strategyParams
            )
        );

        AVSServiceManager avsServiceManagerImplementation = new AVSServiceManager(
            IAVSDirectory(avsDirectory),
            IPaymentCoordinator(paymentCoordinator),
            IRegistryCoordinator(address(registryCoordinator)),
            IStakeRegistry(address(stakeRegistry))
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(avsServiceManager))), address(avsServiceManagerImplementation)
        );

        vm.stopBroadcast();
    }
}
