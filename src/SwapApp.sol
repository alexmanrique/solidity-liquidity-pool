// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IV2Router02} from "./interfaces/IV2Router02.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract SwapApp is Ownable {
    using SafeERC20 for IERC20;
    address public V2Router02Address;
    address public UniswapV2FactoryAddress;
    uint256 public feeBasisPoints;
    mapping(address => bool) public blacklist;
    
    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address tokenA, address tokenB, uint256 liquidity);
    event RemoveLiquidity(address tokenA, address tokenB, uint256 liquidity);
    event FeeCollected(address token, address owner, uint256 feeAmount);
    event AddressBlacklisted(address indexed account);
    event AddressRemovedFromBlacklist(address indexed account);

    constructor(address V2Router02_, address UniswapV2Factory_, address owner_)
        Ownable(owner_)
    {
        V2Router02Address = V2Router02_;
        UniswapV2FactoryAddress = UniswapV2Factory_;
        feeBasisPoints = 100;
    }

    function swapTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        public
        returns (uint256 amountOut)
    {
        require(!blacklist[msg.sender], "Address is blacklisted");
        require(!blacklist[to], "Recipient address is blacklisted");
        
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).approve(V2Router02Address, amountIn);
        
        uint256[] memory amountOuts =
            IV2Router02(V2Router02Address).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
        
        uint256 totalAmountOut = amountOuts[amountOuts.length - 1];
        address tokenOut = path[path.length - 1];
        
        uint256 feeAmount = (totalAmountOut * feeBasisPoints) / 10000;
        uint256 amountToUser = totalAmountOut - feeAmount;
        
        if (feeAmount > 0) {
            IERC20(tokenOut).safeTransfer(owner(), feeAmount);
            emit FeeCollected(tokenOut, owner(), feeAmount);
        }
        
        IERC20(tokenOut).safeTransfer(to, amountToUser);
        
        emit SwapTokens(path[0], tokenOut, amountIn, amountToUser);

        return amountToUser;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] calldata path_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external returns (uint256 liquidity) {
        require(!blacklist[msg.sender], "Address is blacklisted");
        
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountIn_ / 2);
        uint256 swapedAmount = swapTokens(amountIn_ / 2, amountOutMin_, path_, address(this), deadline_);

        IERC20(tokenA).approve(V2Router02Address, amountIn_ / 2);
        IERC20(tokenB).approve(V2Router02Address, swapedAmount);

        (,, liquidity) = IV2Router02(V2Router02Address)
            .addLiquidity(tokenA, tokenB, amountIn_ / 2, swapedAmount, amountAMin_, amountBMin_, msg.sender, deadline_);

        emit AddLiquidity(tokenA, tokenB, liquidity);

        return liquidity;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external {
        require(!blacklist[msg.sender], "Address is blacklisted");
        
        address lpTokenAddress = IFactory(UniswapV2FactoryAddress).getPair(tokenA, tokenB);

        // First, transfer LP tokens from the user to this contract
        IERC20(lpTokenAddress).safeTransferFrom(msg.sender, address(this), liquidityAmount_);

        // Then approve the router to spend the LP tokens
        IERC20(lpTokenAddress).approve(V2Router02Address, liquidityAmount_);

        // Finally, call removeLiquidity which will transfer tokens back to msg.sender
        IV2Router02(V2Router02Address)
            .removeLiquidity(tokenA, tokenB, liquidityAmount_, amountAMin_, amountBMin_, msg.sender, deadline_);

        emit RemoveLiquidity(tokenA, tokenB, liquidityAmount_);
    }

    /**
     * @notice Allows the owner to change the fee
     * @param newFeeBasisPoints New fee in basis points (100 = 1%)
     */
    function setFeeBasisPoints(uint256 newFeeBasisPoints) external onlyOwner {
        require(newFeeBasisPoints <= 1000, "Fee cannot exceed 10%");
        feeBasisPoints = newFeeBasisPoints;
    }

    /**
     * @notice Adds an address to the blacklist
     * @param account Address to blacklist
     */
    function addToBlacklist(address account) external onlyOwner {
        require(account != address(0), "Cannot blacklist zero address");
        require(!blacklist[account], "Address already blacklisted");
        blacklist[account] = true;
        emit AddressBlacklisted(account);
    }

    /**
     * @notice Removes an address from the blacklist
     * @param account Address to remove from blacklist
     */
    function removeFromBlacklist(address account) external onlyOwner {
        require(blacklist[account], "Address not blacklisted");
        blacklist[account] = false;
        emit AddressRemovedFromBlacklist(account);
    }
}
