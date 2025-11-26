// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IVerifyProofAggregation } from "./interfaces/IVerifyProofAggregation.sol";

/// @title ProofVerifier
/// @notice Helper contract to compute leaf digests and call zkVerify to validate aggregated proofs.
/// @dev Stores immutable proving system ID, version hash, verification key hash and zkVerify contract address.
contract ProofVerifier {
    /// @notice Immutable hash of the verification key registered with zkVerify for this circuit.
    bytes32 public immutable vkey;
    /// @notice Immutable proving system identifier used for this circuit (e.g. keccak256("groth16")).
    bytes32 public immutable PROVING_SYSTEM_ID;
    /// @notice Immutable hash of the prover version (e.g. sha256("circom:1.0.0")).
    bytes32 public immutable VERSION_HASH;
    /// @notice Address of the zkVerify proxy contract used for verification.
    IVerifyProofAggregation public immutable zkVerify;

    /// @param zkVerifyAddress Address of the zkVerify contract on the target network.
    /// @param vkeyHash Hash of the verification key registered with zkVerify.
    /// @param provingSystem String identifier of the proving system (e.g. "groth16", "risc0").
    /// @param proverVersion Version string of the prover used to generate proofs.
    constructor(
        address zkVerifyAddress,
        bytes32 vkeyHash,
        string memory provingSystem,
        string memory proverVersion
    ) {
        require(zkVerifyAddress != address(0), "ProofVerifier: zero zkVerify address");
        zkVerify = IVerifyProofAggregation(zkVerifyAddress);
        vkey = vkeyHash;
        PROVING_SYSTEM_ID = keccak256(abi.encodePacked(provingSystem));
        VERSION_HASH = sha256(abi.encodePacked(proverVersion));
    }

    /// @notice Verifies a leaf within an aggregated proof via zkVerify.
    /// @param domainId Domain identifier assigned when proofs were generated.
    /// @param aggregationId Aggregation ID returned by zkVerify during proof submission.
    /// @param publicInputs Array of public inputs used by the circuit; hashed internally.
    /// @param merklePath Merkle path to the proof leaf within the aggregation tree.
    /// @param leafCount Total number of leaves in the aggregation tree.
    /// @param index Index of the leaf being verified.
    /// @return True if the proof is valid, false otherwise.
    function verify(
        uint256 domainId,
        uint256 aggregationId,
        bytes32[] calldata publicInputs,
        bytes32[] calldata merklePath,
        uint256 leafCount,
        uint256 index
    ) external view returns (bool) {
        // Hash the public inputs into a single digest
        bytes32 inputsHash = keccak256(abi.encodePacked(publicInputs));
        // Compose the leaf digest according to zkVerify spec
        bytes32 leaf = keccak256(
            abi.encodePacked(
                PROVING_SYSTEM_ID,
                vkey,
                VERSION_HASH,
                inputsHash
            )
        );
        // Delegate verification to the zkVerify contract
        return zkVerify.verifyProofAggregation(domainId, aggregationId, leaf, merklePath, leafCount, index);
    }
}