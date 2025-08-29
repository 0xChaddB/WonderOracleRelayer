// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IWrapper} from "../interfaces/IWrapper.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

/**
 * @title UniswapV2Wrapper
 * @notice Wrapper for getting price quotes from Uniswap V2 pools
 * @dev Implements x*y=k AMM formula for price calculations
 */
contract UniswapV2Wrapper is IWrapper {
    
    /// @dev Uniswap V2 factory address (Mainnet)
    IUniswapV2Factory public constant UNISWAP_V2_FACTORY = 
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    /// @dev Custom errors
    error UniswapV2Wrapper_PairNotFound();
    error UniswapV2Wrapper_InsufficientLiquidity();
    error UniswapV2Wrapper_InvalidToken();

    /**
     * @inheritdoc IWrapper
     */
    function getAmountOut(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut
    ) external view returns (uint256 _amountOut) {
        // 1. Input validation
        if (_tokenIn == address(0) || _tokenOut == address(0)) {
            revert UniswapV2Wrapper_InvalidToken();
        }
        // 2. Get pair address 
        address pairAddress = UNISWAP_V2_FACTORY.getPair(_tokenIn, _tokenOut);
        if (pairAddress == address(0)) {
            revert UniswapV2Wrapper_PairNotFound();
        }
        // 3. Get reserves from pair
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        // 4. Figure out token order and apply formula
        (address token0, ) = _getOrderedTokens(_tokenIn, _tokenOut);
        (uint256 reserveIn, uint256 reserveOut) = _tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // 5. Calculate the return 
        return _getAmountOut(_amountIn, reserveIn, reserveOut);
    }

    /**
     * @inheritdoc IWrapper
     */
    function isAvailable(
        address _tokenIn,
        address _tokenOut
    ) external view returns (bool _isAvailable) {
        address pairAddress = UNISWAP_V2_FACTORY.getPair(_tokenIn, _tokenOut);
        return pairAddress != address(0);
    }

    /**
     * @inheritdoc IWrapper
     */
    function getProtocolName() external pure returns (string memory _protocolName) {
        return "UniswapV2";
    }

    /**
     * @dev Helper function to get ordered token addresses
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return token0 The smaller address
     * @return token1 The larger address
     */
    function _getOrderedTokens(
        address tokenA,
        address tokenB
    ) private pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @dev Calculates output amount using Uniswap V2 formula
     * @param amountIn Input amount
     * @param reserveIn Input token reserves
     * @param reserveOut Output token reserves
     * @return amountOut Calculated output amount
     */
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');

        // Apply 0.3% fee (multiply by 997, divide by 1000)
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = reserveOut * amountInWithFee;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        amountOut = numerator / denominator;
    }
}