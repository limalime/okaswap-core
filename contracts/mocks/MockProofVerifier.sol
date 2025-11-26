// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title MockProofVerifier
/// @notice A mock proof verifier that always returns true for testing purposes.
contract MockProofVerifier {
    /// @notice Mimics the verify function signature expected by Relayer and ProofVerifier.
    /// @return Always returns true to bypass zk proof verification in tests.
    function verify(
        uint256 /*domainId*/,
        uint256 /*aggregationId*/,
        bytes32[] calldata /*publicInputs*/,
        bytes32[] calldata /*merklePath*/,
        uint256 /*leafCount*/,
        uint256 /*index*/
    ) external pure returns (bool) {
        return true;
    }
}