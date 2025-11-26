// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

/// @title IVerifyProofAggregation
/// @notice Interface to interact with the zkVerify proof aggregation contract.
/// @dev This interface mirrors the proxy contract deployed on networks such as Base Sepolia.
interface IVerifyProofAggregation {
    /// @notice Verifies an aggregation of zero‑knowledge proofs.
    /// @param _domainId Identifier assigned to the domain/circuit under which the proofs were generated.
    /// @param _aggregationId ID assigned by zkVerify when proofs were aggregated (obtained from aggregation.json).
    /// @param _leaf Digest of the public inputs, proving system ID, verification key and version hash.
    /// @param _merklePath The Merkle path to the leaf within the aggregation tree.
    /// @param _leafCount Number of leaves in the aggregation tree.
    /// @param _index Position of the leaf in the aggregation tree.
    /// @return True if the aggregation proof is valid, false otherwise.
    function verifyProofAggregation(
        uint256 _domainId,
        uint256 _aggregationId,
        bytes32 _leaf,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index
    ) external view returns (bool);
}