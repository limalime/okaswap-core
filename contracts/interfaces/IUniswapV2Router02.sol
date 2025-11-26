// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2;

/// @title IUniswapV2Router02
/// @notice Interface for interacting with Uniswap V2 style routers. Only the
/// functions used by this MVP are included.
interface IUniswapV2Router02 {
    /// @notice Swaps an exact amount of input tokens for a minimum amount of output tokens.
    /// @param amountIn Amount of input token being swapped.
    /// @param amountOutMin Minimum acceptable amount of the output token.
    /// @param path Array of token addresses representing the swap path.
    /// @param to Recipient of the output tokens.
    /// @param deadline Unix timestamp by which the transaction must be mined.
    /// @return amounts Array of token amounts for each step in the path.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Returns the amounts out for a given input amount and swap path.
    /// @param amountIn Amount of input token.
    /// @param path Array of token addresses representing the swap path.
    /// @return amounts Array of token amounts for each step in the path.
    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);
}