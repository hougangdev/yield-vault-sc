# Yield Vault DApp

A decentralized yield farming application built with Solidity smart contracts and Foundry framework. Users can stake deposit tokens to earn reward tokens with automated vault management and compound growth.

## 🚀 Features

### Smart Contract Features

- **Farm Rewards**: 10 reward tokens per block distributed to stakers
- **Receipt Token System**: Users receive receipt tokens (1:1) representing their stake
- **ERC4626 Vault**: Standard vault interface for deposit/withdraw operations
- **Auto-Compounding**: Automated reward collection and restaking for compound growth
- **Performance Fees**: Configurable fee on harvested rewards (max 10%)
- **Keeper System**: Authorized keepers can trigger compounds and earn rewards
- **Gas Optimization**: Configurable gas price limits and minimum compound amounts

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
   - **Deployed Address (Sepolia)**: `0x735de2703e15e7b33Be509512e2bbEB444674430`

2. **TheFarm.sol** - Main staking contract

   - Users stake deposit tokens and receive receipt tokens (1:1 ratio)
   - Earns 10 reward tokens per block
   - Receipt tokens represent user's stake and are burned on withdrawal
   - Automatic reward calculation based on blocks
   - Reward claiming functionality
   - **Deployed Address (Sepolia)**: `0x383a9c0910b9329Bf041ccDeBe26A5b3DDca9CCF`

3. **TheVault.sol** - ERC4626 compliant vault management

   - Collects rewards from TheFarm for users
   - Tracks user shares in the vault
   - Automatic restaking when threshold is met
   - Emergency withdrawal functions
   - ERC4626 standard compliance for vault operations
   - **Deployed Address (Sepolia)**: `0x68f3522b3d953a146b879e42d8ddC06Ba5A300b4`

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

#### Deploy All Contracts to Sepolia

```bash
make deploy-all
```

#### Fund Farm with Rewards

```bash
make fund-farm
```

#### Send YVDT Tokens and Authorize Auto-Compounding

```bash
make send-yvdt-and-authorize
```

This will:

- Send 1000 YVDT tokens to address `0x34846BF00C64A56A5FB10a9EE7717aBC7887FEdf`
- Authorize the address as a keeper for auto-compounding

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

**User Functions:**

- `stake(uint256 amount)` - Stake deposit tokens, receive receipt tokens (1:1 ratio)
- `unstake(uint256 amount)` - Burn receipt tokens, receive deposit tokens back
- `claimRewards()` - Claim accumulated rewards

**Admin Functions (Owner Only):**

- `setRewardToken(address _rewardToken)` - Update reward token address
- `depositRewards(uint256 amount)` - Deposit reward tokens to contract
- `emergencyWithdrawRewards(uint256 amount)` - Emergency withdraw reward tokens

**View Functions:**

- `getPendingRewards(address user)` - View pending rewards for a user
- `getStakingTokenBalance()` - Get contract's staking token balance
- `getRewardTokenBalance()` - Get contract's reward token balance
- `updateReward()` - Update accumulated rewards per share

### TheVault Functions (ERC4626)

**User Functions:**

- `deposit(uint256 assets, address receiver)` - Deposit assets and receive vault shares
- `redeem(uint256 shares, address receiver, address owner)` - Redeem vault shares for assets
- `executeAutoCompound()` - Execute auto-compounding (anyone can call)
- `emergencyAutoCompound()` - Execute auto-compound with relaxed checks (authorized keepers)

**Admin Functions (Owner Only):**

- `setPerformanceFee(uint256 fee_)` - Set performance fee in BPS (max 10%)
- `setFeeRecipient(address recipient_)` - Set fee recipient address
- `setAutoCompoundEnabled(bool enabled)` - Enable/disable auto-compounding
- `setAutoCompoundInterval(uint256 interval_)` - Set blocks between compounds
- `setMinCompoundAmount(uint256 amount_)` - Set minimum amount to compound
- `setMaxGasPrice(uint256 gasPrice_)` - Set maximum gas price for compounds
- `setKeeperAuthorization(address keeper, bool authorized)` - Authorize/revoke keepers
- `setKeeperReward(uint256 reward_)` - Set keeper reward amount
- `withdrawETH(uint256 amount)` - Withdraw contract ETH
- `emergencyWithdraw(address token, uint256 amount)` - Emergency withdraw any token
- `depositETH()` - Receive ETH deposits (payable)

**View Functions:**

- `totalAssets()` - Get total assets managed by vault (ERC4626 standard)
- `shouldExecuteAutoCompound()` - Check if auto-compound should execute
- `getAutoCompoundStatus()` - Get auto-compound configuration and status
- `getNextAutoCompoundBlock()` - Get block when next compound can execute
- `getTotalRewardsCollected()` - Get total rewards collected by vault
- `getRewardTokenBalance()` - Get vault's reward token balance
- `getStakingTokenBalance()` - Get vault's staking token balance
- `getPendingRewardsInFarm()` - Get pending rewards in TheFarm

**ERC4626 Standard Functions:**

- `convertToShares(uint256 assets)` - Convert assets to shares
- `convertToAssets(uint256 shares)` - Convert shares to assets
- `previewDeposit(uint256 assets)` - Preview shares from deposit
- `previewRedeem(uint256 shares)` - Preview assets from redemption

### DepositToken Functions

**Authorized Minter Functions:**

- `mint(address to, uint256 amount)` - Mint tokens to address
- `burn(address from, uint256 amount)` - Burn tokens from address

**Admin Functions (Owner Only):**

- `setAuthorizedMinter(address minter, bool authorized)` - Authorize/revoke minter
- `burnFromSelf(uint256 amount)` - Burn own tokens (for staking)

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

### For Users

1. **Deposit**: Deposit DepositTokens into TheVault using `deposit()` - receive vault shares
2. **Auto-Compounding**: Rewards automatically compound when conditions are met
3. **Monitor**: Track your vault share growth as rewards compound
4. **Withdraw**: Redeem vault shares using `redeem()` to receive DepositTokens back

### For TheVault Contract

1. **Initial Setup**: Deploy contracts and authorize TheFarm to mint/burn DepositTokens
2. **Auto-Compound Triggers**: Anyone can call `executeAutoCompound()` when conditions are met
3. **Reward Collection**: Vault harvests rewards from TheFarm
4. **Fee Distribution**: Performance fee sent to fee recipient
5. **Reinvestment**: Remaining rewards restaked to grow vault share price

### Auto-Compounding Conditions

Auto-compounding executes when:

- Auto-compound is enabled
- Block interval has passed (default: 100 blocks)
- Minimum amount threshold reached (default: 10 tokens)
- Gas price is below maximum (default: 50 gwei)
- Keeper has sufficient ETH balance for gas (if calling `emergencyAutoCompound()`)
