// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RegistryCoordinator, ISignatureUtils} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";
import {IAVSDirectory} from "@eigenlayer/src/contracts/interfaces/IAVSDirectory.sol";

contract RegisterOperatorScript is Script {
    RegistryCoordinator public registryCoordinator;
    IDelegationManager public delegationManager;
    IAVSDirectory public avsDirectory;

    function run() external {
        uint256 _deployerPrivateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
        address _registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR");
        address _delegationManager = vm.envAddress("DELEGATION_MANAGER");
        address _avsDirectory = vm.envAddress("AVS_DIRECTORY");

        registryCoordinator = RegistryCoordinator(_registryCoordinator);
        delegationManager = IDelegationManager(_delegationManager);
        avsDirectory = IAVSDirectory(_avsDirectory);

        uint256 numberOfOperators = 5; // Change this to the number of operators you want to register
        (uint256[] memory privateKeys, address[] memory operators, BN254.G1Point[] memory publicKeys) =
            _generateOperators(_deployerPrivateKey, numberOfOperators);

        for (uint256 i = 0; i < numberOfOperators; i++) {
            vm.startBroadcast(privateKeys[i]);
            _registerWithDelegationManager(operators[i]);
            require(delegationManager.isOperator(operators[i]), "Operator not registered with delegation manager");
            _registerOperator(
                abi.encodePacked(uint8(i + 1)), operators[i], privateKeys[i], publicKeys[i], _avsDirectory
            );
            vm.stopBroadcast();
        }

        vm.startBroadcast(_deployerPrivateKey);
        for (uint256 i = 0; i < numberOfOperators; i++) {
            _registerOperator(
                abi.encodePacked(uint8(i + 1)), operators[i], privateKeys[i], publicKeys[i], _avsDirectory
            );
        }
        vm.stopBroadcast();
    }

    function _generateOperators(uint256 deployerPrivateKey, uint256 numberOfOperators)
        internal
        view
        returns (uint256[] memory, address[] memory, BN254.G1Point[] memory)
    {
        uint256[] memory privateKeys = new uint256[](numberOfOperators);
        address[] memory operators = new address[](numberOfOperators);
        BN254.G1Point[] memory publicKeys = new BN254.G1Point[](numberOfOperators);

        for (uint256 i = 0; i < numberOfOperators; i++) {
            privateKeys[i] = generateValidPrivateKey(i, deployerPrivateKey);
            operators[i] = vm.addr(privateKeys[i]);
            publicKeys[i] = generatePublicKey(privateKeys[i]);
        }

        return (privateKeys, operators, publicKeys);
    }

    function generateValidPrivateKey(uint256 index, uint256 deployerPrivateKey) internal pure returns (uint256) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(index, deployerPrivateKey))) % BN254.FR_MODULUS;
        require(privateKey > 0 && privateKey < BN254.FR_MODULUS, "Invalid private key");
        return privateKey;
    }

    function generatePublicKey(uint256 privateKey) internal view returns (BN254.G1Point memory) {
        BN254.G1Point memory g1 = BN254.generatorG1();
        return BN254.scalar_mul(g1, privateKey);
    }

    function _registerWithDelegationManager(address operator) internal {
        delegationManager.registerAsOperator(
            IDelegationManager.OperatorDetails({
                earningsReceiver: operator,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks: 0
            }),
            ""
        );
    }

    function _registerOperator(
        bytes memory quorumNumbers,
        address operator,
        uint256 operatorPrivateKey,
        BN254.G1Point memory operatorPublicKey,
        address avsDirectoryAddress
    ) internal {
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            _getOperatorSignature(operator, avsDirectoryAddress, bytes32(0), type(uint256).max, operatorPrivateKey);

        // Generate realistic G2 public key
        BN254.G2Point memory operatorPublicKeyG2 = BN254.generatorG2();

        registryCoordinator.registerOperator(
            quorumNumbers,
            "127.0.0.1",
            IBLSApkRegistry.PubkeyRegistrationParams({
                pubkeyRegistrationSignature: BN254.G1Point(0, 0),
                pubkeyG1: operatorPublicKey,
                pubkeyG2: operatorPublicKeyG2
            }),
            operatorSignature
        );
    }

    function _getOperatorSignature(
        address operatorToSign,
        address avsDirectoryAddress,
        bytes32 salt,
        uint256 expiry,
        uint256 operatorPrivateKey
    ) internal view returns (ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        bytes32 digestHash =
            avsDirectory.calculateOperatorAVSRegistrationDigestHash(operatorToSign, avsDirectoryAddress, salt, expiry);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, digestHash);
        operatorSignature.signature = abi.encodePacked(r, s, v);
        operatorSignature.salt = salt;
        operatorSignature.expiry = expiry;

        return operatorSignature;
    }
}
