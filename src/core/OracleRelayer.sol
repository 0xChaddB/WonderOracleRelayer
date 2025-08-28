// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IOracleRelayer} from "../interfaces/IOracleRelayer.sol";
import {IWrapper} from "../interfaces/IWrapper.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title OracleRelayer
 * @notice Main contract that routes price queries to appropriate protocol wrappers
 * @dev Implements priority-based routing: pair rules > token rules > default wrapper
 */
contract OracleRelayer is IOracleRelayer, AccessControl {

    /// @dev Role identifier for governance functions
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @dev Maps pair keys to their designated wrapper contracts
    mapping(bytes32 => address) private _pairWrappers;
    
    /// @dev Maps individual tokens to their designated wrapper contracts
    mapping(address => address) private _tokenWrappers;
    
    /// @dev Default wrapper used when no specific pair or token wrapper is configured
    address private _defaultWrapper;

    /**
     * @notice Initializes the OracleRelayer and sets deployer as governor
     * @dev Grants both DEFAULT_ADMIN_ROLE and GOVERNOR_ROLE to msg.sender
     */
    constructor() payable {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function setPairWrapper(
        address _tokenA,
        address _tokenB,
        address _wrapper
    ) external onlyRole(GOVERNOR_ROLE) {
        if (_wrapper == address(0)) revert IOracleRelayer_InvalidWrapper();

        bytes32 pairKey = _getPairKey(_tokenA, _tokenB);
        _pairWrappers[pairKey] = _wrapper;

        emit PairWrapperSet(_tokenA, _tokenB, _wrapper);
    }

    /**
     * @dev Generates a unique key for a token pair by ordering addresses consistently
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return Deterministic bytes32 key for the pair
     */
    function _getPairKey(address tokenA, address tokenB) private pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function getAmountOut(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut
    ) external view returns (uint256 _amountOut) {
        // Input validation
        if (_tokenIn == address(0) || _tokenOut == address(0)) {
            revert IOracleRelayer_InvalidToken();
        }

        // Priority 1: Check for pair-specific wrapper
        bytes32 pairKey = _getPairKey(_tokenIn, _tokenOut);
        address wrapper = _pairWrappers[pairKey];
        if (wrapper != address(0)) {
            return IWrapper(wrapper).getAmountOut(_tokenIn, _amountIn, _tokenOut);
        }

        // Priority 2: Check for input token wrapper
        wrapper = _tokenWrappers[_tokenIn];
        if (wrapper != address(0)) {
            return IWrapper(wrapper).getAmountOut(_tokenIn, _amountIn, _tokenOut);
        }

        // Priority 3: Use default wrapper
        if (_defaultWrapper != address(0)) {
            return IWrapper(_defaultWrapper).getAmountOut(_tokenIn, _amountIn, _tokenOut);
        }

        // No suitable wrapper found
        revert IOracleRelayer_NoWrapperFound();
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function setTokenWrapper(
        address _token,
        address _wrapper
    ) external onlyRole(GOVERNOR_ROLE) {
        if (_wrapper == address(0)) revert IOracleRelayer_InvalidWrapper();

        _tokenWrappers[_token] = _wrapper;
        emit TokenWrapperSet(_token, _wrapper);
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function setDefaultWrapper(address _wrapper) external onlyRole(GOVERNOR_ROLE) {
        if (_wrapper == address(0)) revert IOracleRelayer_InvalidWrapper();

        _defaultWrapper = _wrapper;
        emit DefaultWrapperSet(_wrapper);
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function getPairWrapper(
        address _tokenA,
        address _tokenB
    ) external view returns (address _wrapper) {
        bytes32 pairKey = _getPairKey(_tokenA, _tokenB);
        return _pairWrappers[pairKey];
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function getTokenWrapper(address _token) external view returns (address _wrapper) {
        return _tokenWrappers[_token];
    }

    /**
     * @inheritdoc IOracleRelayer
     */
    function getDefaultWrapper() external view returns (address _wrapper) {
        return _defaultWrapper;
    }

}