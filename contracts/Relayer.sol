// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { Router } from "./Router.sol";
import { ProofVerifier } from "./ProofVerifier.sol";

/// @title Relayer
/// @notice Executes private swaps on behalf of users after verifying their signature and a zk proof of best execution.
/// @dev Implements an EIP‑712 based meta‑transaction flow. Users sign off‑chain orders which are relayed on‑chain
/// by a trusted relayer. Each order must include a valid zero‑knowledge proof attested by zkVerify to guarantee
/// MEV protection and best execution.
contract Relayer is EIP712, Ownable, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Types
    /// -----------------------------------------------------------------------

    /// @notice Encapsulates the data required to execute a swap on behalf of a user.
    struct SwapOrder {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
        uint256 nonce;
    }

    /// @notice EIP‑712 type hash for SwapOrder struct.
    bytes32 public immutable SWAP_TYPEHASH;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice The router used to execute swaps. Must implement executeSwap() matching Router.sol.
    Router public router;
    /// @notice Proof verifier contract that wraps zkVerify aggregation verification.
    ProofVerifier public proofVerifier;

    /// @notice Mapping of user address to the next valid nonce. Each order consumes exactly one nonce.
    mapping(address => uint256) public nonces;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when an order is successfully executed.
    /// @param user The user for whom the swap was performed.
    /// @param tokenIn Token sold.
    /// @param tokenOut Token bought.
    /// @param amountIn Amount of tokenIn spent.
    /// @param amountOutMin Minimum amount requested for tokenOut.
    /// @param outputAmount Actual amount of tokenOut received.
    event OrderExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 outputAmount
    );

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @param _router Address of the Router contract responsible for performing swaps.
    /// @param _proofVerifier Address of the ProofVerifier contract responsible for verifying aggregated proofs.
    /// @param _name Name used for the EIP‑712 domain separator (e.g. "DEXAggregator").
    /// @param _version Version used for the EIP‑712 domain separator (e.g. "1").
    constructor(
        address _router,
        address _proofVerifier,
        string memory _name,
        string memory _version
    ) EIP712(_name, _version) {
        require(_router != address(0), "Relayer: zero router address");
        require(_proofVerifier != address(0), "Relayer: zero verifier address");
        router = Router(_router);
        proofVerifier = ProofVerifier(_proofVerifier);
        // Compute the typehash for SwapOrder using keccak256 on the type string. This must match the struct layout.
        SWAP_TYPEHASH = keccak256(
            "SwapOrder(address user,address tokenIn,address tokenOut,uint256 amountIn,uint256 amountOutMin,uint256 deadline,uint256 nonce)"
        );
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    /// @notice Updates the Router contract. Only callable by the owner.
    /// @param newRouter The address of the new router.
    function setRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Relayer: zero router address");
        router = Router(newRouter);
    }

    /// @notice Updates the ProofVerifier contract. Only callable by the owner.
    /// @param newVerifier The address of the new proof verifier.
    function setProofVerifier(address newVerifier) external onlyOwner {
        require(newVerifier != address(0), "Relayer: zero verifier address");
        proofVerifier = ProofVerifier(newVerifier);
    }

    /// -----------------------------------------------------------------------
    /// Public functions
    /// -----------------------------------------------------------------------

    /// @notice Executes a swap on behalf of the user after verifying their signature and zk proof.
    /// @dev The relayer (msg.sender) is expected to call this function. It checks that the order has not
    /// expired, verifies the user's signature via EIP‑712, validates the zk proof via ProofVerifier, then
    /// calls the Router. Upon success, the user's nonce is incremented to prevent replay attacks.
    /// @param order The parameters describing the swap to perform.
    /// @param signature The EIP‑712 signature produced by the user over the order.
    /// @param domainId Domain identifier used when the proof was generated.
    /// @param aggregationId Aggregation identifier obtained when proofs were aggregated via zkVerify.
    /// @param publicInputs Public inputs array to the zk circuit. This should encode the best execution details.
    /// @param merklePath Merkle proof path to the leaf in the aggregation tree.
    /// @param leafCount Number of leaves in the aggregation tree.
    /// @param index Position of the leaf in the aggregation tree.
    function executeSwapWithProof(
        SwapOrder calldata order,
        bytes calldata signature,
        uint256 domainId,
        uint256 aggregationId,
        bytes32[] calldata publicInputs,
        bytes32[] calldata merklePath,
        uint256 leafCount,
        uint256 index
    ) external nonReentrant {
        // Ensure the order is still valid
        require(block.timestamp <= order.deadline, "Relayer: order expired");
        require(order.nonce == nonces[order.user], "Relayer: invalid nonce");

        // Verify the user's signature matches the order
        require(_verify(order, signature), "Relayer: invalid signature");

        // Verify the zk proof via the ProofVerifier contract
        bool proofValid = proofVerifier.verify(
            domainId,
            aggregationId,
            publicInputs,
            merklePath,
            leafCount,
            index
        );
        require(proofValid, "Relayer: invalid proof");

        // Increment the user's nonce to prevent replay
        nonces[order.user] = order.nonce + 1;

        // Execute the swap via Router and capture the output amount
        uint256 outputAmount = router.executeSwap(
            order.user,
            order.tokenIn,
            order.tokenOut,
            order.amountIn,
            order.amountOutMin
        );

        emit OrderExecuted(
            order.user,
            order.tokenIn,
            order.tokenOut,
            order.amountIn,
            order.amountOutMin,
            outputAmount
        );
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    /// @notice Computes the EIP‑712 digest for a SwapOrder.
    /// @param order The order to hash.
    /// @return The digest to be signed according to EIP‑712.
    function _hash(SwapOrder memory order) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                SWAP_TYPEHASH,
                order.user,
                order.tokenIn,
                order.tokenOut,
                order.amountIn,
                order.amountOutMin,
                order.deadline,
                order.nonce
            )
        );
        return _hashTypedDataV4(structHash);
    }

    /// @notice Verifies the signature for a given order.
    /// @param order The order data.
    /// @param signature Signature from the user.
    /// @return True if the recovered signer matches the order.user.
    function _verify(SwapOrder memory order, bytes calldata signature) internal view returns (bool) {
        bytes32 digest = _hash(order);
        address signer = ECDSA.recover(digest, signature);
        return signer == order.user;
    }
}