# solidity-liquidity-pool

SwapApp is a smart contract that facilitates token swapping and liquidity provision using Uniswap V2 Router. The contract allows performing swaps between tokens (especially USDT and DAI) and adding liquidity to Uniswap V2 pools.

## Features

- **Token Swapping**: Swap tokens using Uniswap V2 Router with slippage protection
- **Add Liquidity**: Automatically adds liquidity to a USDT/DAI pool, performing a swap of half the tokens before adding liquidity
- **Security**: Uses OpenZeppelin's SafeERC20 for secure token transfers
- **Events**: Emits events to track swaps and liquidity additions

## Contract

### SwapApp.sol

The main contract that implements the following functions:

- `swapTokens()`: Swaps exact tokens for other tokens using Uniswap V2 Router
- `addLiquidity()`: Adds liquidity to a USDT/DAI pool, automatically swapping half of the tokens

### Constructor Parameters

- `V2Router02_`: Address of the Uniswap V2 Router02 contract
- `USDT_`: Address of the USDT token
- `DAI_`: Address of the DAI token

## Testing

Tests are configured to run on Arbitrum Mainnet using fork testing:

```shell
$ forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc
```

### Included Tests

- `testHasBeenDeployedCorrectly()`: Verifies that the contract has been deployed correctly
- `testSwapTokensCorrectly()`: Verifies that token swapping works correctly
- `testAddLiquidityCorrectly()`: Verifies that liquidity addition works correctly

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

- OpenZeppelin Contracts (SafeERC20, IERC20)
- Forge Std (for testing)

## License

MIT
