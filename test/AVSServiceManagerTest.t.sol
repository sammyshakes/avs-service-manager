// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import "../src/AVSServiceManager.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import "../src/mocks/EmptyContract.sol";

contract AVSServiceManagerTest is Test {
    AVSServiceManager public avsServiceManager;
    AVSServiceManager public avsServiceManagerImplementation;

    ProxyAdmin public proxyAdmin;
    address public proxyAdminOwner = address(0x001);

    EmptyContract public emptyContract;

    //get input addresses from proxy in env vars
    IAVSDirectory public avsDirectory;
    IPaymentCoordinator public paymentCoordinator;

    IRegistryCoordinator public registryCoordinator;
    IRegistryCoordinator public registryCoordinatorImplementation;

    IBLSApkRegistry public blsApkRegistry;
    IBLSApkRegistry public blsApkRegistryImplementation;

    IIndexRegistry public indexRegistry;
    IIndexRegistry public indexRegistryImplementation;

    IStakeRegistry public stakeRegistry;
    IStakeRegistry public stakeRegistryImplementation;

    address public delegationManager = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
    address public strategyManager = 0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6;

    function setUp() public {
        vm.startPrank(proxyAdminOwner);
        proxyAdmin = new ProxyAdmin();

        emptyContract = new EmptyContract();

        avsDirectory = IAVSDirectory(0x055733000064333CaDDbC92763c58BF0192fFeBf);

        // deploy proxies with empty contracts for now
        // Deploy ServiceManager proxy
        avsServiceManager =
            AVSServiceManager(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // deploy registryCoordinator proxy
        registryCoordinator = RegistryCoordinator(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), ""))
        );

        // deploy blsApkRegistry proxy
        blsApkRegistry =
            BLSApkRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // deploy indexRegistry proxy
        indexRegistry =
            IndexRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // deploy stakeRegistry proxy
        stakeRegistry =
            StakeRegistry(address(new TransparentUpgradeableProxy(address(emptyContract), address(proxyAdmin), "")));

        // Deploy Implementations and upgrade respective proxies
        // deploy stakeRegistryImplementation
        stakeRegistryImplementation =
            new StakeRegistry(IRegistryCoordinator(address(registryCoordinator)), IDelegationManager(delegationManager));

        //upgrade stakeRegistry proxy
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(stakeRegistry))), address(stakeRegistryImplementation)
        );

        // deploy indexRegistryImplementation
        indexRegistryImplementation = new IndexRegistry(IRegistryCoordinator(address(registryCoordinator)));

        //upgrade indexRegistry proxy
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))), address(indexRegistryImplementation)
        );

        // deploy blsApkRegistryImplementation
        blsApkRegistryImplementation = new BLSApkRegistry(IRegistryCoordinator(address(registryCoordinator)));

        //upgrade blsApkRegistry proxy
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsApkRegistry))), address(blsApkRegistryImplementation)
        );

        registryCoordinatorImplementation = new RegistryCoordinator(
            IServiceManager(address(avsServiceManager)),
            IStakeRegistry(address(stakeRegistry)),
            IBLSApkRegistry(address(blsApkRegistry)),
            IIndexRegistry(address(indexRegistry))
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
                strategy: IStrategy(address(0x0000000000000000000000000000000000000008)),
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
                IPauserRegistry(address(6)), // _pauserRegistry
                0, // _initialPausedStatus
                operatorSetParams, // _operatorSetParams
                minimumStakes, // _minimumStakes
                strategyParams // _strategyParams
            )
        );

        avsServiceManagerImplementation = new AVSServiceManager(
            IAVSDirectory(avsDirectory),
            IPaymentCoordinator(address(0)),
            IRegistryCoordinator(address(registryCoordinator)),
            IStakeRegistry(address(stakeRegistry))
        );

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(avsServiceManager))), address(avsServiceManagerImplementation)
        );

        assertEq(avsServiceManager.owner(), address(0));
        vm.stopPrank();
    }

    function testInitializaServiceManager() public view {
        assertEq(avsServiceManager.owner(), address(0));
    }
}
