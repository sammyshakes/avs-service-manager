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
    address _deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");

    function run() external {
        vm.startBroadcast(_deployerPrivateKey);

        // Define addresses for core contracts and strategies
        address paymentCoordinator = address(0x002);

        // Holesky deployed EigenLayer contracts
        address avsDirectory = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
        address delegationManager = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;

        // Define strategy addresses
        address[] memory availableStrategyAddresses = new address[](10);
        availableStrategyAddresses[0] = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3; // stETH
        availableStrategyAddresses[1] = 0x3A8fBdf9e77DFc25d09741f51d3E181b25d0c4E0; // rETH
        availableStrategyAddresses[2] = 0x80528D6e9A2BAbFc766965E0E26d5aB08D9CFaF9; // WETH
        availableStrategyAddresses[3] = 0x05037A81BD7B4C9E0F7B430f1F2A22c31a2FD943; // lsETH
        availableStrategyAddresses[4] = 0x9281ff96637710Cd9A5CAcce9c6FAD8C9F54631c; // sfrxETH
        availableStrategyAddresses[5] = 0x31B6F59e1627cEfC9fA174aD03859fC337666af7; // ETHx
        availableStrategyAddresses[6] = 0x46281E3B7fDcACdBa44CADf069a94a588Fd4C6Ef; // osETH
        availableStrategyAddresses[7] = 0x70EB4D3c164a6B4A5f908D4FBb5a9cAfFb66bAB6; // cbETH
        availableStrategyAddresses[8] = 0xaccc5A86732BE85b5012e8614AF237801636F8e5; // mETH
        availableStrategyAddresses[9] = 0x7673a47463F80c6a3553Db9E54c8cDcd5313d0ac; // ankrETH

        /////////// USER INPUTS ///////////
        // Define the number of quorums
        uint8 numQuorums = 2; // EDIT THIS for your specific use case

        IRegistryCoordinator.OperatorSetParam[] memory operatorSetParams =
            new IRegistryCoordinator.OperatorSetParam[](numQuorums);
        address[] memory strategyAddresses = new address[](numQuorums);
        uint96[] memory strategyMultipliers = new uint96[](numQuorums);
        uint96[] memory minimumStakes = new uint96[](numQuorums);

        /////////////////////////////////
        // CREATE OPERATOR SET PARAMS FOR QUORUMS
        // Edit parameters for your specific use case.
        //
        // maxOperatorCount: Maximum number of operators allowed in the quorum
        // kickBIPsOfOperatorStake: Basis points that new Operator's stake must be greater than the old Operator's stake by to kick from quorum
        // kickBIPsOfTotalStake: Basis points of the total stake of the quorum that an operator needs to maintain or be kicked

        // Operator Set Params for Quorum 1
        operatorSetParams[0] = IRegistryCoordinator.OperatorSetParam({
            maxOperatorCount: 10, // EDIT THIS
            kickBIPsOfOperatorStake: 15000, // EDIT THIS
            kickBIPsOfTotalStake: 150 // EDIT THIS
        });
        // Operator Set Params for Quorum 2
        operatorSetParams[1] = IRegistryCoordinator.OperatorSetParam({
            maxOperatorCount: 20, // EDIT THIS
            kickBIPsOfOperatorStake: 5000, // EDIT THIS
            kickBIPsOfTotalStake: 100 // EDIT THIS
        });
        // Operator Set Params for Quorum 3
        // operatorSetParams[2] = IRegistryCoordinator.OperatorSetParam({
        //     maxOperatorCount: 30,
        //     kickBIPsOfOperatorStake: 10000,
        //     kickBIPsOfTotalStake: 200
        // });

        /////////////////////////////////
        // CREATE STRATEGIES FOR QUORUMS
        // Enter the index of the availableStrategyAddresses array above to create a strategy
        strategyAddresses[0] = availableStrategyAddresses[0]; // stETH for Quorum 1
        strategyAddresses[1] = availableStrategyAddresses[1]; // rETH for Quorum 2
        // strategyAddresses[2] = availableStrategyAddresses[2]; // WETH for Quorum 3

        /////////////////////////////////
        // CREATE STRATEGY MULTIPLIERS FOR QUORUMS
        // Enter the strategy multiplier for each quorum
        strategyMultipliers[0] = 10; // EDIT for Quorum 1
        strategyMultipliers[1] = 8; // EDIT for Quorum 2
        // strategyMultipliers[2] = 1; // EDIT for Quorum 3

        // DEFINE MINIMUM STAKES FOR EACH QUORUM
        // Set the minimum stake for each quorum
        minimumStakes[0] = 1000; // EDIT for Quorum 1
        minimumStakes[1] = 1000; // EDIT for Quorum 2
        // minimumStakes[2] = 1000; // EDIT for Quorum 3

        /////////// END USER INPUTS ///////////

        // Arrays must be the length of the number of quorums
        require(strategyAddresses.length == numQuorums, "Strategy addresses length mismatch");
        require(strategyMultipliers.length == numQuorums, "Strategy multipliers length mismatch");
        require(minimumStakes.length == numQuorums, "Minimum stakes length mismatch");

        // prepare input arrays for deployment
        IStakeRegistry.StrategyParams[][] memory strategyParams = new IStakeRegistry.StrategyParams[][](numQuorums);
        for (uint8 i = 0; i < numQuorums; i++) {
            strategyParams[i] = new IStakeRegistry.StrategyParams[](1);
            strategyParams[i][0] = IStakeRegistry.StrategyParams({
                strategy: IStrategy(strategyAddresses[i]),
                multiplier: strategyMultipliers[i]
            });
        }

        // Deploy initial proxies
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

        // Deploy implementations
        StakeRegistry stakeRegistryImplementation =
            new StakeRegistry(IRegistryCoordinator(address(registryCoordinator)), IDelegationManager(delegationManager));

        IndexRegistry indexRegistryImplementation =
            new IndexRegistry(IRegistryCoordinator(address(registryCoordinator)));

        BLSApkRegistry blsApkRegistryImplementation =
            new BLSApkRegistry(IRegistryCoordinator(address(registryCoordinator)));

        // Upgrade proxies
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(stakeRegistry))), address(stakeRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))), address(indexRegistryImplementation)
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsApkRegistry))), address(blsApkRegistryImplementation)
        );

        // Deploy and upgrade RegistryCoordinator
        RegistryCoordinator registryCoordinatorImplementation = new RegistryCoordinator(
            IServiceManager(address(avsServiceManager)),
            IStakeRegistry(address(stakeRegistry)),
            IBLSApkRegistry(address(blsApkRegistry)),
            IIndexRegistry(address(indexRegistry))
        );

        proxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(registryCoordinator))),
            address(registryCoordinatorImplementation),
            abi.encodeWithSelector(
                RegistryCoordinator.initialize.selector,
                _deployerAddress,
                _deployerAddress,
                _deployerAddress,
                IPauserRegistry(address(0x003)),
                0,
                operatorSetParams,
                minimumStakes,
                strategyParams
            )
        );

        // Deploy and upgrade AVSServiceManager
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
