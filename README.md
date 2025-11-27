# solidity-liquidity-pool

SwapApp is a smart contract that facilitates token swapping and liquidity provision using Uniswap V2 Router. The contract allows performing swaps between any tokens and adding liquidity to any Uniswap V2 pool pairs.

## Features

- **Token Swapping**: Swap any tokens using Uniswap V2 Router with slippage protection
- **Add Liquidity**: Automatically adds liquidity to any token pair pool, performing a swap of half the tokens before adding liquidity
- **Remove Liquidity**: Remove liquidity from any token pair pool, returning both tokens to the user
- **Generic Design**: Works with any ERC20 token pair, not limited to specific tokens
- **Fee System**: The contract owner collects a fee (default 1%) on every token swap, calculated from the output amount
- **Owner Controls**: The contract owner can adjust the fee percentage (up to 10% maximum)
- **Blacklist System**: The contract owner can blacklist addresses to prevent them from using swap and liquidity functions
- **Security**: Uses OpenZeppelin's SafeERC20 for secure token transfers and Ownable for access control
- **Events**: Emits events to track swaps, liquidity additions, fee collections, and blacklist changes

## Contract

### SwapApp.sol

The main contract that implements the following functions:

- `swapTokens(amountIn, amountOutMin, path, to, deadline)`: Swaps exact tokens for other tokens using Uniswap V2 Router. Automatically deducts a fee from the output amount and transfers it to the contract owner. Works with any token pair specified in the path. Requires that both `msg.sender` and `to` addresses are not blacklisted.
- `addLiquidity(tokenA, tokenB, amountIn_, amountOutMin_, path_, amountAMin_, amountBMin_, deadline_)`: Adds liquidity to any token pair pool, automatically swapping half of the tokens. The internal swap also incurs the fee. The caller specifies which tokens to use. Requires that `msg.sender` is not blacklisted.
- `removeLiquidity(tokenA, tokenB, liquidityAmount_, amountAMin_, amountBMin_, deadline_)`: Removes liquidity from any token pair pool, returning both tokens to the user. The caller specifies which tokens to remove liquidity from. Requires that `msg.sender` is not blacklisted.
- `setFeeBasisPoints(newFeeBasisPoints)`: Allows the contract owner to change the fee percentage (only callable by owner, maximum 10%)
- `addToBlacklist(account)`: Adds an address to the blacklist, preventing it from using swap and liquidity functions (only callable by owner)
- `removeFromBlacklist(account)`: Removes an address from the blacklist, allowing it to use swap and liquidity functions again (only callable by owner)

### Constructor Parameters

- `V2Router02_`: Address of the Uniswap V2 Router02 contract
- `UniswapV2Factory_`: Address of the Uniswap V2 Factory contract
- `owner_`: Address of the contract owner who will receive swap fees

**Note**: The contract is generic and does not require specific token addresses at deployment. Token addresses are provided by users when calling `addLiquidity()` and `removeLiquidity()` functions.

## Fee System

The contract implements a fee mechanism where the owner collects a percentage of each token swap:

- **Default Fee**: 1% (100 basis points) of the output amount
- **Fee Calculation**: The fee is calculated from the total output amount after the swap completes
- **Fee Collection**: The fee is automatically transferred to the contract owner's address
- **Fee Adjustment**: The owner can change the fee using `setFeeBasisPoints()`, with a maximum limit of 10% (1000 basis points)
- **Fee Application**: Fees are applied to all swaps, including internal swaps performed during `addLiquidity()`

### How Fees Work

1. When a user calls `swapTokens()`, the contract:

   - Receives tokens from the user
   - Performs the swap via Uniswap V2 Router (receiving tokens to the contract)
   - Calculates the fee: `feeAmount = (totalAmountOut * feeBasisPoints) / 10000`
   - Transfers the fee to the owner
   - Transfers the remaining amount to the user

2. The fee is deducted from the output tokens, not the input tokens
3. The `FeeCollected` event is emitted whenever a fee is collected

## Blacklist System

The contract implements a blacklist mechanism that allows the owner to restrict certain addresses from using the swap and liquidity functions:

- **Purpose**: Prevent specific addresses from interacting with swap and liquidity functions for security or compliance reasons
- **Access Control**: Only the contract owner can add or remove addresses from the blacklist
- **Scope**: Blacklisted addresses cannot:
  - Call `swapTokens()` (both as sender and as recipient)
  - Call `addLiquidity()`
  - Call `removeLiquidity()`

### How Blacklist Works

1. **Adding to Blacklist**: The owner calls `addToBlacklist(account)` to blacklist an address

   - Validates that the address is not zero address
   - Validates that the address is not already blacklisted
   - Sets the blacklist status to `true`
   - Emits `AddressBlacklisted` event

2. **Removing from Blacklist**: The owner calls `removeFromBlacklist(account)` to remove an address from the blacklist

   - Validates that the address is currently blacklisted
   - Sets the blacklist status to `false`
   - Emits `AddressRemovedFromBlacklist` event

3. **Checking Blacklist**: All swap and liquidity functions check the blacklist before execution:
   - `swapTokens()` checks both `msg.sender` and `to` addresses
   - `addLiquidity()` checks `msg.sender`
   - `removeLiquidity()` checks `msg.sender`
   - If any checked address is blacklisted, the transaction reverts with "Address is blacklisted" or "Recipient address is blacklisted"

### Blacklist Events

- `AddressBlacklisted(address indexed account)`: Emitted when an address is added to the blacklist
- `AddressRemovedFromBlacklist(address indexed account)`: Emitted when an address is removed from the blacklist

## Testing

Tests are configured to run on Arbitrum Mainnet using fork testing:

```shell
$ forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc
```

### Included Tests

**Core Functionality:**

- `testHasBeenDeployedCorrectly()`: Verifies that the contract has been deployed correctly
- `testSwapTokensCorrectly()`: Verifies that token swapping works correctly and that fees are collected by the owner
- `testAddLiquidityCorrectly()`: Verifies that liquidity addition works correctly and that fees are collected on internal swaps
- `testRemoveLiquidityCorrectly()`: Verifies that liquidity removal works correctly

**Fee Management:**

- `testSetFeeBasisPoints()`: Verifies that the owner can change the fee and that the maximum fee limit is enforced
- `testSetFeeBasisPointsOnlyOwner()`: Verifies that only the owner can change the fee

**Blacklist Management:**

- `testAddToBlacklist()`: Verifies that the owner can add addresses to the blacklist
- `testAddToBlacklistOnlyOwner()`: Verifies that only the owner can add addresses to the blacklist
- `testAddToBlacklistZeroAddress()`: Verifies that zero address cannot be blacklisted
- `testAddToBlacklistAlreadyBlacklisted()`: Verifies that already blacklisted addresses cannot be added again
- `testRemoveFromBlacklist()`: Verifies that the owner can remove addresses from the blacklist
- `testRemoveFromBlacklistOnlyOwner()`: Verifies that only the owner can remove addresses from the blacklist
- `testRemoveFromBlacklistNotBlacklisted()`: Verifies that non-blacklisted addresses cannot be removed
- `testUserCanOperateAfterRemovedFromBlacklist()`: Verifies that addresses can operate normally after being removed from the blacklist

**Blacklist Enforcement:**

- `testSwapTokensBlacklistedUser()`: Verifies that blacklisted users cannot perform swaps
- `testSwapTokensBlacklistedRecipient()`: Verifies that tokens cannot be sent to blacklisted recipient addresses
- `testAddLiquidityBlacklistedUser()`: Verifies that blacklisted users cannot add liquidity
- `testRemoveLiquidityBlacklistedUser()`: Verifies that blacklisted users cannot remove liquidity

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

For fork testing (Arbitrum):

```shell
$ forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Dependencies

- OpenZeppelin Contracts (SafeERC20, IERC20, Ownable)
- Forge Std (for testing)

## License

MIT
