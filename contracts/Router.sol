// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Router02.sol";

/// @title Router
/// @notice Simple DEX aggregator router supporting a single underlying DEX and integrated with a Relayer.
/// @dev For demonstration purposes this router only swaps via one Uniswap V2 style router. In a full
/// implementation you would integrate multiple adapters and select the best quote off‑chain.
contract Router is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Address of the Uniswap V2 compatible router used to perform swaps.
    IUniswapV2Router02 public dexRouter;
    /// @notice Address authorised to execute swaps (e.g. the Relayer contract).
    address public relayer;

    /// @param _dexRouter Address of the underlying DEX router.
    /// @param _relayer Address allowed to call executeSwap. Can be the relayer contract.
    constructor(address _dexRouter, address _relayer) {
        require(_dexRouter != address(0), "Router: zero router address");
        require(_relayer != address(0), "Router: zero relayer address");
        dexRouter = IUniswapV2Router02(_dexRouter);
        relayer = _relayer;
    }

    /// @notice Sets a new relayer. Only owner can call.
    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Router: zero relayer address");
        relayer = _relayer;
    }

    /// @notice Sets a new DEX router. Only owner can call.
    function setDexRouter(address _dexRouter) external onlyOwner {
        require(_dexRouter != address(0), "Router: zero router address");
        dexRouter = IUniswapV2Router02(_dexRouter);
    }

    /// @notice Executes a token swap on behalf of a user. Called by the relayer after verifying proof and signature.
    /// @param user Recipient of the output tokens and the token debit address.
    /// @param tokenIn Address of the input token.
    /// @param tokenOut Address of the output token.
    /// @param amountIn Amount of input token to be swapped.
    /// @param amountOutMin Minimum acceptable amount of output token.
    function executeSwap(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant returns (uint256 amountOut) {
        require(msg.sender == relayer, "Router: only relayer");
        require(user != address(0), "Router: invalid user");

        // Pull tokens from the user. User must have approved this router for tokenIn previously.
        IERC20(tokenIn).safeTransferFrom(user, address(this), amountIn);
        // Approve the DEX router to spend input tokens
        IERC20(tokenIn).safeIncreaseAllowance(address(dexRouter), amountIn);

        // Define the swap path. For simple two token swap it's [tokenIn, tokenOut]
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Perform the swap on the DEX. Output tokens will be received by this contract.
        dexRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        // Determine the final balance of the output token and transfer to the user
        uint256 outputBalance = IERC20(tokenOut).balanceOf(address(this));
        require(outputBalance >= amountOutMin, "Router: insufficient output");
        IERC20(tokenOut).safeTransfer(user, outputBalance);
        return outputBalance;
    }
}