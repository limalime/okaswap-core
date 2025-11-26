// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";

/// @title Quoter
/// @notice Provides quoting functionality to discover the best output amount across multiple DEX routers.
/// @dev This contract is stateless and can be called off‑chain via eth_call. It assumes a simple two‑token
/// swap path of [tokenIn, tokenOut] on Uniswap V2–compatible routers.
contract Quoter {
    /// @notice Computes the maximum output amount obtainable from a list of DEX routers for a given input amount.
    /// @param routers Array of router addresses implementing the Uniswap V2 `getAmountsOut` function.
    /// @param tokenIn Address of the input token.
    /// @param tokenOut Address of the output token.
    /// @param amountIn Amount of input token to swap.
    /// @return bestAmountOut The highest amountOut returned by any router in the list.
    /// @return bestRouter The address of the router that yields the highest amountOut.
    function quote(
        address[] calldata routers,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 bestAmountOut, address bestRouter) {
        uint256 maxOut = 0;
        address chosenRouter = address(0);

        for (uint256 i = 0; i < routers.length; i++) {
            address routerAddr = routers[i];
            if (routerAddr == address(0)) {
                continue;
            }
            // Build a simple path [tokenIn, tokenOut]
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
            try IUniswapV2Router02(routerAddr).getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
                if (amounts.length >= 2 && amounts[amounts.length - 1] > maxOut) {
                    maxOut = amounts[amounts.length - 1];
                    chosenRouter = routerAddr;
                }
            } catch {
                // ignore failures from misconfigured routers
                continue;
            }
        }
        return (maxOut, chosenRouter);
    }
}