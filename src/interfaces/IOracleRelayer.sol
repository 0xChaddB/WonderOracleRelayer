// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IOracleRelayer
 * @notice Interface for the main Oracle Relayer contract that aggregates price feeds from multiple protocols
 * @dev Routes price queries to appropriate protocol wrappers based on configured priority rules
 */
interface IOracleRelayer {
    
    /**
     * @notice Emitted when a wrapper is set for a specific token pair
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @param wrapper Address of the wrapper contract to use for this pair
     */
    event PairWrapperSet(address indexed tokenA, address indexed tokenB, address wrapper);
    
    /**
     * @notice Emitted when a wrapper is set for a specific token
     * @param token Token address
     * @param wrapper Address of the wrapper contract to use for this token
     */
    event TokenWrapperSet(address indexed token, address wrapper);

    /**
     * @notice Emitted when the default wrapper is set
     * @param wrapper Address of the default wrapper contract
     */
    event DefaultWrapperSet(address wrapper);

    /**
     * @notice Thrown when a non-governor attempts to call a restricted function
     */
    error IOracleRelayer_Unauthorized();

    /**
     * @notice Thrown when an invalid wrapper address is provided
     */
    error IOracleRelayer_InvalidWrapper();

    /**
     * @notice Thrown when no suitable wrapper is found for a token pair
     */
    error IOracleRelayer_NoWrapperFound();

    /**
     * @notice Gets the amount of output tokens for a given input
     * @dev Routes to the appropriate wrapper based on priority: pair > token > default
     * @param _tokenIn Address of the input token
     * @param _amountIn Amount of input tokens
     * @param _tokenOut Address of the output token
     * @return _amountOut Amount of output tokens
     */
    function getAmountOut(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut
    ) external view returns (uint256 _amountOut);

    /**
     * @notice Sets a wrapper for a specific token pair
     * @dev Only callable by governor. Takes priority over token and default wrappers
     * @param _tokenA First token in the pair
     * @param _tokenB Second token in the pair
     * @param _wrapper Address of the wrapper to use for this pair
     */
    function setPairWrapper(
        address _tokenA,
        address _tokenB,
        address _wrapper
    ) external;

    /**
     * @notice Sets a wrapper for a specific token
     * @dev Only callable by governor. Takes priority over default wrapper but not pair wrappers
     * @param _token Token address
     * @param _wrapper Address of the wrapper to use for this token
     */
    function setTokenWrapper(
        address _token,
        address _wrapper
    ) external;

    /**
     * @notice Sets the default wrapper for all unspecified pairs
     * @dev Only callable by governor. Used when no pair or token wrapper is configured
     * @param _wrapper Address of the default wrapper
     */
    function setDefaultWrapper(address _wrapper) external;

    /**
     * @notice Gets the configured wrapper for a specific token pair
     * @param _tokenA First token in the pair
     * @param _tokenB Second token in the pair
     * @return _wrapper Address of the wrapper for this pair, or address(0) if none set
     */
    function getPairWrapper(address _tokenA, address _tokenB) external view returns (address _wrapper);
    
    /**
     * @notice Gets the configured wrapper for a specific token
     * @param _token Token address
     * @return _wrapper Address of the wrapper for this token, or address(0) if none set
     */
    function getTokenWrapper(address _token) external view returns (address _wrapper);
    
    /**
     * @notice Gets the default wrapper
     * @return _wrapper Address of the default wrapper
     */
    function getDefaultWrapper() external view returns (address _wrapper);
}