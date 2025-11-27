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
    address owner = address(0x1234); // Owner address for testing
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT address in Arbitrum Mainnet
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address in Arbitrum Mainnet
    address UniswapV2FactoryAddress = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9; // UniswapV2Factory address in Arbitrum Mainnet

    // Common test variables
    uint256 constant AMOUNT_IN = 5 * 1e6;
    uint256 constant AMOUNT_OUT_MIN = 2 * 1e18;
    uint256 constant AMOUNT_A_MIN = AMOUNT_IN / 2 * 95 / 100;
    uint256 constant AMOUNT_B_MIN = AMOUNT_OUT_MIN * 95 / 100;
    uint256 constant DEADLINE_DURATION = 3600;
    uint256 constant FEE_BASIS_POINTS = 100;

    function setUp() public {
        app = new SwapApp(uniswapV2SwappRouterAddress, UniswapV2FactoryAddress, owner);
    }

    function testHasBeenDeployedCorrectly() public view {
        assert(app.V2Router02Address() == uniswapV2SwappRouterAddress);
    }

    function testSwapTokensCorrectly() public {
        vm.startPrank(user);
        uint256 amountOutMin = 4 * 1e18; // Different value for this test
        IERC20(USDT).approve(address(app), AMOUNT_IN);
        uint256 deadline = block.timestamp + DEADLINE_DURATION;
        address[] memory path = _getUSDTToDAIPath();

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAI).balanceOf(user);
        uint256 ownerDaiBalanceBefore = IERC20(DAI).balanceOf(owner);
        
        uint256 amountOut = app.swapTokens(AMOUNT_IN, amountOutMin, path, user, deadline);
        
        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAI).balanceOf(user);
        uint256 ownerDaiBalanceAfter = IERC20(DAI).balanceOf(owner);

        assert(usdtBalanceAfter == usdtBalanceBefore - AMOUNT_IN);
        assert(daiBalanceAfter > daiBalanceBefore);
        
        uint256 feeReceived = ownerDaiBalanceAfter - ownerDaiBalanceBefore;
        assert(feeReceived > 0);
        
        uint256 totalAmountOut = amountOut + feeReceived;
        uint256 expectedFee = (totalAmountOut * FEE_BASIS_POINTS) / 10000;
        assert(feeReceived >= expectedFee - 1 && feeReceived <= expectedFee + 1);
        
        assert(daiBalanceAfter - daiBalanceBefore == amountOut);

        vm.stopPrank();
    }

    function testAddLiquidityCorrectly() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + DEADLINE_DURATION;

        IERC20(USDT).approve(address(app), AMOUNT_IN);

        address[] memory path = _getUSDTToDAIPath();

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(user);
        uint256 ownerDaiBalanceBefore = IERC20(DAI).balanceOf(owner);

        app.addLiquidity(USDT, DAI, AMOUNT_IN, AMOUNT_OUT_MIN, path, AMOUNT_A_MIN, AMOUNT_B_MIN, deadline);

        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(user);
        uint256 ownerDaiBalanceAfter = IERC20(DAI).balanceOf(owner);

        address lpTokenAddress = IFactory(UniswapV2FactoryAddress).getPair(USDT, DAI);
        uint256 lpBalance = IERC20(lpTokenAddress).balanceOf(user);

        assert(lpBalance > 0);
        assert(usdtBalanceAfter < usdtBalanceBefore);
        
        uint256 feeReceived = ownerDaiBalanceAfter - ownerDaiBalanceBefore;
        assert(feeReceived > 0);

        vm.stopPrank();
    }

    function testRemoveLiquidityCorrectly() public {
        vm.startPrank(user);

        uint256 deadline = block.timestamp + DEADLINE_DURATION;

        IERC20(USDT).approve(address(app), AMOUNT_IN);

        address[] memory path = _getUSDTToDAIPath();

        uint256 liquidity = app.addLiquidity(USDT, DAI, AMOUNT_IN, AMOUNT_OUT_MIN, path, AMOUNT_A_MIN, AMOUNT_B_MIN, deadline);

        address lpTokenAddress = IFactory(UniswapV2FactoryAddress).getPair(USDT, DAI);

        uint256 liquidityBalance = IERC20(lpTokenAddress).balanceOf(user);

        assert(liquidity == liquidityBalance);

        uint256 usdtBalanceBefore = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceBefore = IERC20(DAI).balanceOf(user);
        uint256 lpBalanceBefore = IERC20(lpTokenAddress).balanceOf(user);

        // Approve SwapApp to transfer LP tokens from user
        IERC20(lpTokenAddress).approve(address(app), liquidity);

        app.removeLiquidity(USDT, DAI, liquidity, AMOUNT_A_MIN, AMOUNT_B_MIN, deadline);

        uint256 usdtBalanceAfter = IERC20(USDT).balanceOf(user);
        uint256 daiBalanceAfter = IERC20(DAI).balanceOf(user);
        uint256 lpBalanceAfter = IERC20(lpTokenAddress).balanceOf(user);

        assert(lpBalanceAfter == 0);
        assert(lpBalanceAfter < lpBalanceBefore);

        assert(usdtBalanceAfter > usdtBalanceBefore);
        assert(daiBalanceAfter > daiBalanceBefore);

        assert(usdtBalanceAfter - usdtBalanceBefore >= AMOUNT_A_MIN);
        assert(daiBalanceAfter - daiBalanceBefore >= AMOUNT_B_MIN);

        assert(IERC20(lpTokenAddress).balanceOf(address(app)) == 0);

        vm.stopPrank();
    }

    function testSetFeeBasisPoints() public {
        vm.startPrank(owner);
        
        assert(app.feeBasisPoints() == FEE_BASIS_POINTS);
        
        app.setFeeBasisPoints(200);
        assert(app.feeBasisPoints() == 200);
        
        vm.expectRevert("Fee cannot exceed 10%");
        app.setFeeBasisPoints(1001);
        
        vm.stopPrank();
    }

    function testSetFeeBasisPointsOnlyOwner() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        app.setFeeBasisPoints(200);
        
        vm.stopPrank();
    }

    function _getUSDTToDAIPath() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        return path;
    }
}
