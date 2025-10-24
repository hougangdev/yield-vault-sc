# Yield Vault DApp

A decentralized yield farming application built with Solidity smart contracts and Foundry framework. Users can stake deposit tokens to earn reward tokens with automated vault management and compound growth.

## 🚀 Features

### Smart Contract Features

- **Farm Rewards**: 10 reward tokens per block
- **Receipt Token System**: Users receive receipt tokens representing their stake
- **Automated Vault Management**: Collects and restakes rewards for compound growth
- **Flexible Token Support**: Any ERC20 token can be used as reward token
- **Reward Distribution**: Proportional reward distribution based on stake amount

### Core Components

The yield vault system consists of three integrated contracts:

- **DepositToken**: ERC20 token used for staking with authorized mint/burn
- **TheFarm**: Main staking contract with receipt token functionality
- **TheVault**: Automated reward collection and restaking system

## 📋 Contract Architecture

### Core Contracts

1. **DepositToken.sol** - ERC20 staking token

   - Standard ERC20 functionality
   - Authorized minting/burning for staking contracts
   - Owner-controlled access management
   - Initial supply distribution

2. **TheFarm.sol** - Main staking contract

   - Users stake deposit tokens and receive receipt tokens (1:1 ratio)
   - Earns 10 reward tokens per block
   - Receipt tokens represent user's stake and are burned on withdrawal
   - Automatic reward calculation based on blocks
   - Reward claiming functionality

3. **TheVault.sol** - ERC4626 compliant vault management

   - Collects rewards from TheFarm for users
   - Tracks user shares in the vault
   - Automatic restaking when threshold is met
   - Emergency withdrawal functions
   - ERC4626 standard compliance for vault operations

## 🛠️ Development

Built with Foundry - a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Foundry Tools

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools)
- **Cast**: Swiss army knife for interacting with EVM smart contracts
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network
- **Chisel**: Fast, utilitarian, and verbose Solidity REPL

## 📚 Documentation

- [Foundry Book](https://book.getfoundry.sh/)

## 🚀 Usage

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Private key set in environment variables (`PRIVATE_KEY`)
- Testnet ETH for deployment

### Development Commands

#### Build

```bash
forge build
```

#### Test

```bash
forge test
```

#### Format Code

```bash
forge fmt
```

#### Gas Snapshots

```bash
forge snapshot
```

#### Local Development

```bash
anvil
```

### Deployment

#### Deploy All Contracts

```bash
forge script script/DeployAll.s.sol --rpc-url <RPC_URL> --broadcast --verify
```

#### Individual Contract Deployment

```bash
# Deploy DepositToken
forge script script/DeployDepositToken.s.sol --rpc-url <RPC_URL> --broadcast

# Deploy TheFarm
forge script script/DeployTheFarm.s.sol --rpc-url <RPC_URL> --broadcast

# Deploy TheVault
forge script script/DeployTheVault.s.sol --rpc-url <RPC_URL> --broadcast
```

### Contract Interaction

#### Using Cast

```bash
# Deposit assets into vault
cast send <vault_address> "deposit(uint256,address)" <amount> <receiver_address> --private-key <private_key> --rpc-url <rpc_url>

# Redeem vault shares
cast send <vault_address> "redeem(uint256,address,address)" <shares> <receiver_address> <owner_address> --private-key <private_key> --rpc-url <rpc_url>

# Check vault total assets
cast call <vault_address> "totalAssets()" --rpc-url <rpc_url>
```

## 🔧 Smart Contract Functions

### TheFarm Functions

- `stake(uint256 amount)` - Stake deposit tokens, receive receipt tokens
- `unstake(uint256 amount)` - Burn receipt tokens, receive deposit tokens back
- `claimRewards()` - Claim accumulated rewards
- `getPendingRewards(address user)` - View pending rewards for a user
- `setRewardToken(address _rewardToken)` - Update reward token (owner only)

### TheVault Functions (ERC4626)

- `deposit(uint256 assets, address receiver)` - Deposit assets and receive vault shares
- `redeem(uint256 shares, address receiver, address owner)` - Redeem vault shares for assets
- `collectUserRewards(address user)` - Collect rewards for a specific user
- `collectMultipleUserRewards(address[] users)` - Collect rewards for multiple users
- `restakeRewards(uint256 amount)` - Manually restake collected rewards
- `totalAssets()` - Get total assets managed by the vault
- `convertToShares(uint256 assets)` - Convert assets to shares
- `convertToAssets(uint256 shares)` - Convert shares to assets
- `previewDeposit(uint256 assets)` - Preview deposit operation
- `previewRedeem(uint256 shares)` - Preview redeem operation
- `setAutoRestakeThreshold(uint256 _threshold)` - Update auto-restake threshold (owner only)

### DepositToken Functions

- `mint(address to, uint256 amount)` - Mint tokens (authorized contracts only)
- `burn(address from, uint256 amount)` - Burn tokens (authorized contracts only)
- `setAuthorizedMinter(address minter, bool authorized)` - Manage authorized minters (owner only)

## 📊 Testing

Run comprehensive tests:

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/TheFarm.t.sol

# Run with verbose output
forge test -vvv
```

## 💡 Usage Flow

1. **Initial Setup**: Deploy all contracts and authorize TheFarm to mint/burn DepositTokens
2. **User Staking**: Users approve and stake DepositTokens to receive receipt tokens
3. **Reward Accumulation**: Rewards accumulate at 10 tokens per block
4. **Vault Management**: TheVault collects rewards and restakes for compound growth
5. **Withdrawal**: Users unstake by burning receipt tokens to receive DepositTokens back
