// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV2Wrapper} from "../src/wrappers/UniswapV2Wrapper.sol";
import {OracleRelayer} from "../src/core/OracleRelayer.sol";
import {IWrapper} from "../src/interfaces/IWrapper.sol";

/**
 * @title UniswapV2WrapperTest
 * @notice Test suite for UniswapV2Wrapper functionality
 * @dev Uses mainnet fork to test against real Uniswap V2 pools
 */
contract UniswapV2WrapperTest is Test {
    UniswapV2Wrapper public wrapper;
    OracleRelayer public oracle;
    
    // Mainnet token addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    
    // Test amounts
    uint256 constant ONE_ETH = 1 ether;
    uint256 constant ONE_THOUSAND_USDC = 1000 * 10**6; // USDC has 6 decimals
    uint256 constant ONE_HUNDRED_DAI = 100 * 10**18; // DAI has 18 decimals
    
    function setUp() public {
        // Fork mainnet at a recent block
        uint256 forkId = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_500_000);
        
        // Deploy contracts
        wrapper = new UniswapV2Wrapper();
        oracle = new OracleRelayer();
        
        // Setup oracle with UniswapV2 as default for testing
        oracle.setDefaultWrapper(address(wrapper));
    }
    
    /**
     * @notice Test that wrapper correctly identifies available pairs
     */
    function testIsAvailable() public view {
        // Test existing pairs
        assertTrue(wrapper.isAvailable(WETH, USDC), "WETH/USDC should be available");
        assertTrue(wrapper.isAvailable(DAI, USDC), "DAI/USDC should be available");
        assertTrue(wrapper.isAvailable(WETH, DAI), "WETH/DAI should be available");
        
        // Test with reversed order (should still work)
        assertTrue(wrapper.isAvailable(USDC, WETH), "USDC/WETH should be available");
        
        // Test non-existent pair (using made up address)
        address fakeToken = address(0x1234567890123456789012345678901234567890);
        assertFalse(wrapper.isAvailable(fakeToken, WETH), "Fake token pair should not be available");
    }
    
    /**
     * @notice Test the protocol name getter
     */
    function testGetProtocolName() public view {
        assertEq(wrapper.getProtocolName(), "UniswapV2", "Protocol name should be UniswapV2");
    }
    
    /**
     * @notice Test price calculation for WETH/USDC pair
     */
    function testGetAmountOut_WETH_USDC() public view {
        uint256 amountOut = wrapper.getAmountOut(WETH, ONE_ETH, USDC);
        
        console2.log("Swapping 1 WETH for USDC:");
        console2.log("Amount out:", amountOut);
        console2.log("Price per ETH:", amountOut / 10**6); // Convert to human readable
        
        // Sanity check: 1 ETH should be worth between $1000-$5000 USDC
        assertGt(amountOut, 1000 * 10**6, "1 ETH should be worth more than 1000 USDC");
        assertLt(amountOut, 5000 * 10**6, "1 ETH should be worth less than 5000 USDC");
    }
    
    /**
     * @notice Test price calculation for DAI/USDC pair (stablecoin pair)
     */
    function testGetAmountOut_DAI_USDC() public view {
        uint256 amountOut = wrapper.getAmountOut(DAI, ONE_HUNDRED_DAI, USDC);
        
        console2.log("Swapping 100 DAI for USDC:");
        console2.log("Amount out:", amountOut);
        console2.log("Effective rate:", amountOut * 100 / 10**6); // Should be close to 100
        
        // Stablecoins should trade near 1:1 (allowing for decimals difference)
        // 100 DAI should give roughly 100 USDC (minus fees and slippage)
        assertGt(amountOut, 95 * 10**6, "Should get at least 95 USDC for 100 DAI");
        assertLt(amountOut, 105 * 10**6, "Should get at most 105 USDC for 100 DAI");
    }
    
    /**
     * @notice Test that reversed token order gives inverse price
     */
    function testGetAmountOut_Reversed() public {
        // Get price in one direction
        uint256 wethToUsdc = wrapper.getAmountOut(WETH, ONE_ETH, USDC);
        
        // Now get reverse price (how much WETH for that amount of USDC)
        uint256 usdcToWeth = wrapper.getAmountOut(USDC, wethToUsdc, WETH);
        
        console2.log("Round trip test:");
        console2.log("1 WETH ->", wethToUsdc, "USDC");
        console2.log(wethToUsdc, "USDC ->", usdcToWeth, "WETH");
        
        // Due to fees, we should get back less than 1 ETH (0.6% total fees for round trip)
        assertLt(usdcToWeth, ONE_ETH, "Should lose some due to fees");
        assertGt(usdcToWeth, ONE_ETH * 993 / 1000, "Should get back at least 99.3% due to fees");
    }
    
    /**
     * @notice Test that wrapper reverts for non-existent pairs
     */
    function testRevert_PairNotFound() public {
        address fakeToken = address(0x1234567890123456789012345678901234567890);
        
        vm.expectRevert(UniswapV2Wrapper.UniswapV2Wrapper_PairNotFound.selector);
        wrapper.getAmountOut(fakeToken, 1 ether, WETH);
    }
    
    /**
     * @notice Test that wrapper reverts for invalid token addresses
     */
    function testRevert_InvalidToken() public {
        vm.expectRevert(UniswapV2Wrapper.UniswapV2Wrapper_InvalidToken.selector);
        wrapper.getAmountOut(address(0), 1 ether, WETH);
        
        vm.expectRevert(UniswapV2Wrapper.UniswapV2Wrapper_InvalidToken.selector);
        wrapper.getAmountOut(WETH, 1 ether, address(0));
    }
    
    /**
     * @notice Test integration with OracleRelayer
     */
    function testIntegrationWithOracle() public {
        // Setup: Set UniswapV2 as the wrapper for DAI token
        oracle.setTokenWrapper(DAI, address(wrapper));
        
        // Test: Query through the oracle
        uint256 amountOut = oracle.getAmountOut(DAI, ONE_HUNDRED_DAI, UNI);
        
        console2.log("Oracle routing test (DAI -> UNI):");
        console2.log("Amount out:", amountOut);
        
        // Should get some UNI tokens for 100 DAI
        assertGt(amountOut, 0, "Should receive some UNI tokens");
    }
    
    /**
     * @notice Test gas consumption
     */
    function testGasConsumption() public {
        uint256 gasBefore = gasleft();
        wrapper.getAmountOut(WETH, ONE_ETH, USDC);
        uint256 gasUsed = gasBefore - gasleft();
        
        console2.log("Gas used for getAmountOut:", gasUsed);
        assertLt(gasUsed, 100_000, "Should use less than 100k gas");
    }
}