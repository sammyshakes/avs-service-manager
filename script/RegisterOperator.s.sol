// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RegistryCoordinator, ISignatureUtils} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";

contract RegisterOperatorScript is Script {
    RegistryCoordinator public registryCoordinator;
    IDelegationManager public delegationManager;

    function run() external {
        uint256 _deployerPrivateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
        address _registryCoordinator = vm.envAddress("REGISTRY_COORDINATOR");
        address _delegationManager = vm.envAddress("DELEGATION_MANAGER");

        // Start the deployment script
        vm.startBroadcast(_deployerPrivateKey);

        registryCoordinator = RegistryCoordinator(_registryCoordinator);
        delegationManager = IDelegationManager(_delegationManager);

        // Configure operator details
        uint256 numberOfOperators = 5; // Change this to the number of operators you want to register
        address[] memory operators = new address[](numberOfOperators);
        uint256[] memory operatorPrivateKeys = new uint256[](numberOfOperators);
        bytes32[] memory operatorIds = new bytes32[](numberOfOperators);
        bytes[] memory quorumNumbersArray = new bytes[](numberOfOperators);
        string memory socket = "127.0.0.1";
        IBLSApkRegistry.PubkeyRegistrationParams memory params;

        // Initialize mock BLS public key params
        params.pubkeyRegistrationSignature = BN254.G1Point(0, 0);
        params.pubkeyG1 = BN254.G1Point(0, 0);
        params.pubkeyG2 = BN254.G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)]);

        for (uint256 i = 0; i < numberOfOperators; i++) {
            operatorPrivateKeys[i] = uint256(keccak256(abi.encodePacked(i, _deployerPrivateKey + 1)));
            operators[i] = vm.addr(operatorPrivateKeys[i]);
            operatorIds[i] = keccak256(abi.encodePacked(operators[i]));
            quorumNumbersArray[i] = abi.encodePacked(uint8(i + 1));

            // Register operator with Delegation Manager
            _registerWithDelegationManager(operators[i]);
        }

        // Register operators with RegistryCoordinator
        for (uint256 i = 0; i < numberOfOperators; i++) {
            _registerOperator(quorumNumbersArray[i], operators[i], operatorPrivateKeys[i]);
        }

        vm.stopBroadcast();
    }

    function _registerWithDelegationManager(address operator) internal {
        // Register operator to EigenLayer
        delegationManager.registerAsOperator(
            IDelegationManager.OperatorDetails({
                earningsReceiver: operator,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks: 0
            }),
            ""
        );
    }

    function _registerOperator(bytes memory quorumNumbers, address operator, uint256 operatorPrivateKey) internal {
        // Get operator signature
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature = _getOperatorSignature(
            operator,
            address(registryCoordinator),
            bytes32(0), // emptySalt
            type(uint256).max, // maxExpiry
            operatorPrivateKey
        );

        // Register operator
        registryCoordinator.registerOperator(
            quorumNumbers,
            "127.0.0.1",
            IBLSApkRegistry.PubkeyRegistrationParams({
                pubkeyRegistrationSignature: BN254.G1Point(0, 0),
                pubkeyG1: BN254.G1Point(0, 0),
                pubkeyG2: BN254.G2Point([uint256(0), uint256(0)], [uint256(0), uint256(0)])
            }),
            operatorSignature
        );
    }

    function _getOperatorSignature(
        address operatorToSign,
        address avs,
        bytes32 salt,
        uint256 expiry,
        uint256 operatorPrivateKey
    ) internal view returns (ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        operatorSignature.salt = salt;
        operatorSignature.expiry = expiry;

        // Calculate the EIP-712 hash
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("EigenLayer")),
                keccak256(bytes("1")),
                block.chainid,
                address(registryCoordinator)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("OperatorRegistration(address operator,address avs,bytes32 salt,uint256 expiry)"),
                operatorToSign,
                avs,
                salt,
                expiry
            )
        );

        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign the digest hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, digestHash);
        operatorSignature.signature = abi.encodePacked(r, s, v);

        return operatorSignature;
    }
}
