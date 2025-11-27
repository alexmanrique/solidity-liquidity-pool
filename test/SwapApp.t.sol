// SPDX-License-Identifier: MIT
// forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc
pragma solidity ^0.8.30;

import "../lib/forge-std/src/Test.sol";
import {SwapApp} from "../src/SwapApp.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";

contract SwapAppTest is Test {
    SwapApp app;
    address uniswapV2SwappRouterAddress = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address user = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Address with USDT in Arbitrum Mainnet
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT address in Arbitrum Mainnet
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address in Arbitrum Mainnet
    address UniswapV2FactoryAddress = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9; // UniswapV2Factory address in Arbitrum Mainnet

    function setUp() public {
        app = new SwapApp(uniswapV2SwappRouterAddress, USDT, DAI, UniswapV2FactoryAddress);
    }

    function testHasBeenDeployedCorrectly() public view {
        assert(app.V2Router02Address() == uniswapV2SwappRouterAddress);
    }

    function testSwapTokensCorrectly() public {
        vm.startPrank(user);
        uint256 amountIn = 5 * 1e6;
        uint256 amountOutMin = 4 * 1e18;
        IERC20(USDT).approve(address(app), amountIn);
        uint256 deadline = block.timestamp + 3600; // Current timestamp + 1 hour
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAI).balanceOf(user);
        app.swapTokens(amountIn, amountOutMin, path, user, deadline);
        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAI).balanceOf(user);

        assert(usdtBalanceAfter == usdtBalanceBefore - amountIn);
        assert(daiBalanceAfter > daiBalanceBefore);

        vm.stopPrank();
    }

    function testAddLiquidityCorrectly() public {
        vm.startPrank(user);
        uint256 amountIn = 5 * 1e6;
        // amountOutMin debe ser realista para un swap de amountIn/2 (2.5e6 USDT)
        // Basado en el trace, el output real es ~2.5e18 DAI, así que usamos 2e18 como mínimo
        uint256 amountOutMin = 2 * 1e18;

        uint256 amountAMin_ = amountIn / 2 * 99 / 100;
        uint256 amountBMin_ = amountOutMin * 99 / 100;

        IERC20(USDT).approve(address(app), amountIn);
        uint256 deadline = block.timestamp + 3600; // Current timestamp + 1 hour
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        app.addLiquidity(amountIn, amountOutMin, path, amountAMin_, amountBMin_, deadline);
        vm.stopPrank();
    }

    function testRemoveLiquidityCorrectly() public {
        vm.startPrank(user);
        uint256 amountIn_ = 5 * 1e6;
       
        uint256 amountOutMin_ = 2 * 1e18;

        uint256 amountAMin_ = amountIn_ / 2 * 99 / 100;
        uint256 amountBMin_ = amountOutMin_ * 99 / 100;

        IERC20(USDT).approve(address(app), amountIn_);
        uint256 deadline = block.timestamp + 3600; // Current timestamp + 1 hour
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        
        uint256 liquidity = app.addLiquidity(amountIn_, amountOutMin_, path, amountAMin_, amountBMin_, deadline);

        address lpTokenAddress = IFactory(UniswapV2FactoryAddress).getPair(USDT, DAI);
        
        uint256 liquidityBalance = IERC20(lpTokenAddress).balanceOf(user);
        
        assert(liquidity == liquidityBalance);

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAI).balanceOf(user);
        uint256 lpBalanceBefore = IERC20(lpTokenAddress).balanceOf(user);

        // Approve SwapApp to transfer LP tokens from user
        IERC20(lpTokenAddress).approve(address(app), liquidity);

        app.removeLiquidity(liquidity, amountAMin_, amountBMin_, deadline);

        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAI).balanceOf(user);
        uint256 lpBalanceAfter = IERC20(lpTokenAddress).balanceOf(user);

        // Verify LP tokens were burned/transferred
        assert(lpBalanceAfter == 0); // LP tokens should be burned after removeLiquidity
        assert(lpBalanceAfter < lpBalanceBefore); // LP balance should decrease

        // Verify user received tokens back
        assert(usdtBalanceAfter > usdtBalanceBefore); // User should receive USDT back
        assert(daiBalanceAfter > daiBalanceBefore); // User should receive DAI back

        // Verify amounts received meet minimum requirements
        assert(usdtBalanceAfter - usdtBalanceBefore >= amountAMin_); // USDT received should meet minimum
        assert(daiBalanceAfter - daiBalanceBefore >= amountBMin_); // DAI received should meet minimum

        // Verify SwapApp contract doesn't hold LP tokens after operation
        assert(IERC20(lpTokenAddress).balanceOf(address(app)) == 0); // SwapApp should not hold LP tokens

        vm.stopPrank();
    } 
}
