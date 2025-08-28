// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;


/**
   * @title IWrapper
   * @notice Interface for protocol-specific price feed wrappers
   * @dev All wrapper implementations must conform to this interface
*/
interface IWrapper {


    error IWrapper_InvalidToken();
    error IWrapper_InsufficientLiquidity();
    error IWrapper_PairNotSupported();

    /**
       * @notice Calculates the amount of output tokens for a given input
       * @dev Implementation varies by protocol (AMM formula, oracle feed, etc.)
       * @param _tokenIn Address of the input token
       * @param _amountIn Amount of input tokens (in input token decimals)
       * @param _tokenOut Address of the output token
       * @return _amountOut Amount of output tokens (in output token decimals)
    */
    function getAmountOut(address _tokenIn, uint256 _amountIn, address _tokenOut) external view returns(uint256 _amountOut);


    /**
     * @notice Checks if the wrapper supports a specific token pair
     * @dev Used to verify if a wrapper can provide pricing for a given pair before calling getAmountOut
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @return _isAvailable True if the pair is supported by this wrapper, false otherwise
     */
    function isAvailable(address _tokenIn, address _tokenOut) external view returns (bool _isAvailable);
    
    /**
     * @notice Returns the name of the protocol this wrapper integrates with
     * @dev Useful for debugging, monitoring, and identifying which protocol provided a price
     * @return _protocolName The human-readable name of the protocol (e.g., "UniswapV2", "Curve", "Chainlink")
     */
    function getProtocolName() external view returns (string memory _protocolName);
    
}