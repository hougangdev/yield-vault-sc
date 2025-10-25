// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/DepositToken.sol";
import "../src/TheFarm.sol";
import "../src/TheVault.sol";

/**
 * @title DeployAll
 * @dev Script to deploy all contracts in the yield vault system with security enhancements
 * @notice This script deploys the complete yield vault ecosystem with proper security configurations
 */
contract DeployAll is Script {
    // Contract instances
    DepositToken public depositToken;
    TheFarm public theFarm;
    TheVault public theVault;

    // Deployment parameters
    string constant DEPOSIT_TOKEN_NAME = "Yield Vault Deposit Token";
    string constant DEPOSIT_TOKEN_SYMBOL = "YVDT";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18; // 1M tokens

    string constant RECEIPT_TOKEN_NAME = "Farm Receipt Token";
    string constant RECEIPT_TOKEN_SYMBOL = "FRT";

    // Vault configuration parameters
    string constant VAULT_NAME = "Yield Vault Token";
    string constant VAULT_SYMBOL = "YVT";

    // Security and fee parameters
    uint256 constant DEFAULT_PERFORMANCE_FEE = 100; // 1% in basis points
    uint256 constant MAX_PERFORMANCE_FEE = 1000; // 10% max in basis points

    // Auto-compounding parameters
    bool constant DEFAULT_AUTO_COMPOUND_ENABLED = true;
    uint256 constant DEFAULT_AUTO_COMPOUND_INTERVAL = 5; // 5 blocks (~1 minute for demo)
    uint256 constant DEFAULT_MIN_COMPOUND_AMOUNT = 1 * 1e18; // 1 token for demo
    uint256 constant DEFAULT_MAX_GAS_PRICE = 50 * 1e9; // 50 gwei

    // Keeper parameters
    uint256 constant DEFAULT_KEEPER_REWARD = 0.001 ether; // 0.001 ETH
    uint256 constant INITIAL_ETH_DEPOSIT = 0.01 ether; // 0.01 ETH for keeper rewards

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== YIELD VAULT DEPLOYMENT ===");
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance / 1e18, "ETH");
        console.log("Block number:", block.number);
        console.log("Block timestamp:", block.timestamp);

        // Validate deployment parameters
        require(deployer != address(0), "Invalid deployer address");
        require(bytes(DEPOSIT_TOKEN_NAME).length > 0, "Invalid token name");
        require(bytes(DEPOSIT_TOKEN_SYMBOL).length > 0, "Invalid token symbol");
        require(INITIAL_SUPPLY > 0, "Invalid initial supply");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DepositToken
        console.log("\n1. Deploying DepositToken...");
        depositToken = new DepositToken(DEPOSIT_TOKEN_NAME, DEPOSIT_TOKEN_SYMBOL, INITIAL_SUPPLY);
        console.log("[SUCCESS] DepositToken deployed at:", address(depositToken));
        console.log("  - Name:", depositToken.name());
        console.log("  - Symbol:", depositToken.symbol());
        console.log("  - Initial Supply:", depositToken.totalSupply() / 1e18, "tokens");
        console.log("  - Owner:", depositToken.owner());

        // Deploy TheFarm with DepositToken as both staking and reward token
        console.log("\n2. Deploying TheFarm...");
        theFarm = new TheFarm(
            address(depositToken), // staking token
            address(depositToken), // reward token (same as staking for auto-compound)
            RECEIPT_TOKEN_NAME,
            RECEIPT_TOKEN_SYMBOL
        );
        console.log("[SUCCESS] TheFarm deployed at:", address(theFarm));
        console.log("  - Staking Token:", address(theFarm.stakingToken()));
        console.log("  - Reward Token:", address(theFarm.rewardToken()));
        console.log("  - Reward Rate:", theFarm.REWARD_RATE(), "tokens per block");
        console.log("  - Owner:", theFarm.owner());

        // Deploy TheVault
        console.log("\n3. Deploying TheVault...");
        theVault = new TheVault(address(theFarm), address(depositToken), VAULT_NAME, VAULT_SYMBOL);
        console.log("[SUCCESS] TheVault deployed at:", address(theVault));
        console.log("  - TheFarm:", address(theVault.theFarm()));
        console.log("  - Asset:", address(theVault.asset()));
        console.log("  - Owner:", theVault.owner());

        // Configure TheVault with security and auto-compounding parameters
        console.log("\n4. Configuring TheVault parameters...");

        // Set minimum compound amount
        theVault.setMinCompoundAmount(DEFAULT_MIN_COMPOUND_AMOUNT);
        console.log("[SUCCESS] Minimum compound amount set to:", DEFAULT_MIN_COMPOUND_AMOUNT / 1e18, "tokens");

        // Set performance fee
        theVault.setPerformanceFee(DEFAULT_PERFORMANCE_FEE);
        console.log("[SUCCESS] Performance fee set to:", DEFAULT_PERFORMANCE_FEE, "basis points");
        console.log("  Percentage:", DEFAULT_PERFORMANCE_FEE / 100, "%");

        // Set fee recipient (defaults to deployer)
        theVault.setFeeRecipient(deployer);
        console.log("[SUCCESS] Fee recipient set to:", theVault.feeRecipient());

        // Configure auto-compounding parameters
        console.log("\n5. Configuring auto-compounding parameters...");

        // Set auto-compound enabled
        theVault.setAutoCompoundEnabled(DEFAULT_AUTO_COMPOUND_ENABLED);
        console.log("[SUCCESS] Auto-compounding enabled:", DEFAULT_AUTO_COMPOUND_ENABLED);

        // Set auto-compound interval
        theVault.setAutoCompoundInterval(DEFAULT_AUTO_COMPOUND_INTERVAL);
        console.log("[SUCCESS] Auto-compound interval set to:", DEFAULT_AUTO_COMPOUND_INTERVAL, "blocks");
        console.log("  Estimated time:", (DEFAULT_AUTO_COMPOUND_INTERVAL * 12) / 60, "minutes (assuming 12s blocks)");

        // Set minimum compound amount (already set above, but logging for clarity)
        console.log("[SUCCESS] Minimum compound amount:", theVault.minCompoundAmount() / 1e18, "tokens");

        // Set maximum gas price
        theVault.setMaxGasPrice(DEFAULT_MAX_GAS_PRICE);
        console.log("[SUCCESS] Maximum gas price set to:", DEFAULT_MAX_GAS_PRICE / 1e9, "gwei");

        // Configure keeper system
        console.log("\n6. Configuring keeper system...");

        // Set keeper reward
        theVault.setKeeperReward(DEFAULT_KEEPER_REWARD);
        console.log("[SUCCESS] Keeper reward set to:", DEFAULT_KEEPER_REWARD / 1e15, "milliETH");

        // Authorize deployer as initial keeper
        theVault.setKeeperAuthorization(deployer, true);
        console.log("[SUCCESS] Deployer authorized as keeper:", deployer);

        // Deposit initial ETH for keeper rewards
        theVault.depositETH{value: INITIAL_ETH_DEPOSIT}();
        console.log("[SUCCESS] Initial ETH deposited:", INITIAL_ETH_DEPOSIT / 1e15, "milliETH");
        console.log("  Vault ETH balance:", address(theVault).balance / 1e15, "milliETH");

        // Note: TheFarm doesn't need minting authorization as it doesn't mint DepositTokens
        // TheFarm only handles staking/unstaking of existing tokens
        console.log("\n7. System setup complete...");
        console.log("[SUCCESS] All contracts deployed and configured");
        console.log("[INFO] TheFarm uses existing DepositTokens (no minting required)");

        vm.stopBroadcast();

        // Comprehensive deployment verification
        console.log("\n=== DEPLOYMENT VERIFICATION ===");
        _verifyDeployment(deployer);

        // Security configuration summary
        console.log("\n=== SECURITY CONFIGURATION ===");
        _logSecurityConfig(deployer);

        // Final summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("[SUCCESS] All contracts deployed successfully");
        console.log("[SUCCESS] Security parameters configured");
        console.log("[SUCCESS] Auto-compounding parameters configured");
        console.log("[SUCCESS] Keeper system configured");
        console.log("[SUCCESS] Yield optimizer vault ready for use");

        console.log("\nContract Addresses:");
        console.log("  DepositToken:", address(depositToken));
        console.log("  TheFarm:", address(theFarm));
        console.log("  TheVault:", address(theVault));

        console.log("\n=== USAGE INSTRUCTIONS ===");
        console.log("Auto-Compounding Yield Optimizer Vault is now ready!");
        console.log("\nFor Users:");
        console.log("  1. Approve DepositToken to TheVault");
        console.log("  2. Call vault.deposit(amount, receiver) to stake");
        console.log("  3. Auto-compounding will happen automatically!");
        console.log("  4. Call vault.redeem(shares, receiver, owner) to withdraw");
        console.log("\nFor Monitoring:");
        console.log("  - Check auto-compound status: vault.getAutoCompoundStatus()");
        console.log("  - Monitor events: AutoCompoundExecuted, RewardsCollected");
        console.log("  - Manual trigger: vault.executeAutoCompound() (keepers only)");
        console.log("  - Emergency trigger: vault.emergencyAutoCompound() (anyone)");
        console.log("\nFor Keepers:");
        console.log("  - Check if ready: vault.shouldExecuteAutoCompound()");
        console.log("  - Execute: vault.executeAutoCompound() (earns reward)");
        console.log("  - Fund vault: vault.depositETH()");
        console.log("\nFor Governance:");
        console.log("  - Adjust parameters: setAutoCompoundInterval(), setMinCompoundAmount()");
        console.log("  - Control fees: setPerformanceFee(), setFeeRecipient()");
        console.log("  - Manage keepers: setKeeperAuthorization(), setKeeperReward()");
        console.log("  - Emergency: setAutoCompoundEnabled(false)");
        console.log("\nFor Rewards Distribution:");
        console.log("  - Deposit rewards: theFarm.depositRewards(amount)");
        console.log("  - Check farm balance: theFarm.getRewardTokenBalance()");
        console.log("  - Monitor farm events: RewardsDeposited, RewardsUpdated");
    }

    /**
     * @dev Verify that all contracts are properly deployed and configured
     */
    function _verifyDeployment(address deployer) internal view {
        // Verify DepositToken
        require(address(depositToken) != address(0), "DepositToken not deployed");
        require(depositToken.totalSupply() == INITIAL_SUPPLY, "Invalid DepositToken supply");
        require(depositToken.owner() != address(0), "DepositToken owner not set");

        // Verify TheFarm
        require(address(theFarm) != address(0), "TheFarm not deployed");
        require(address(theFarm.stakingToken()) == address(depositToken), "Invalid staking token");
        require(address(theFarm.rewardToken()) == address(depositToken), "Invalid reward token");
        require(theFarm.owner() != address(0), "TheFarm owner not set");

        // Verify TheVault
        require(address(theVault) != address(0), "TheVault not deployed");
        require(address(theVault.theFarm()) == address(theFarm), "Invalid TheFarm reference");
        require(address(theVault.asset()) == address(depositToken), "Invalid asset reference");
        require(theVault.owner() != address(0), "TheVault owner not set");

        // Verify auto-compounding configuration
        require(theVault.autoCompoundEnabled() == DEFAULT_AUTO_COMPOUND_ENABLED, "Invalid auto-compound enabled");
        require(theVault.autoCompoundInterval() == DEFAULT_AUTO_COMPOUND_INTERVAL, "Invalid auto-compound interval");
        require(theVault.minCompoundAmount() == DEFAULT_MIN_COMPOUND_AMOUNT, "Invalid min compound amount");
        require(theVault.maxCompoundGasPrice() == DEFAULT_MAX_GAS_PRICE, "Invalid max gas price");

        // Verify keeper configuration
        require(theVault.keeperReward() == DEFAULT_KEEPER_REWARD, "Invalid keeper reward");
        require(theVault.authorizedKeepers(deployer), "Deployer not authorized as keeper");
        require(address(theVault).balance >= INITIAL_ETH_DEPOSIT, "Insufficient ETH for keeper rewards");

        console.log("[SUCCESS] All contracts verified successfully");
    }

    /**
     * @dev Log the security configuration for transparency
     */
    function _logSecurityConfig(address deployer) internal view {
        console.log("Security Features Enabled:");
        console.log("  [ENABLED] SafeERC20 operations throughout");
        console.log("  [ENABLED] Reentrancy protection");
        console.log("  [ENABLED] Access control (Ownable)");
        console.log("  [ENABLED] Input validation");
        console.log("  [ENABLED] Custom error handling");
        console.log("  [ENABLED] Event indexing for off-chain monitoring");

        console.log("\nVault Configuration:");
        console.log("  - Minimum compound amount:", theVault.minCompoundAmount() / 1e18, "tokens");
        console.log("  - Performance fee:", theVault.performanceFee(), "basis points");
        console.log("  - Max performance fee:", theVault.MAX_PERFORMANCE_FEE(), "basis points");
        console.log("  - Fee recipient:", theVault.feeRecipient());

        console.log("\nAuto-Compounding Configuration:");
        console.log("  - Auto-compound enabled:", theVault.autoCompoundEnabled());
        console.log("  - Compound interval:", theVault.autoCompoundInterval(), "blocks");
        console.log("  - Min compound amount:", theVault.minCompoundAmount() / 1e18, "tokens");
        console.log("  - Max gas price:", theVault.maxCompoundGasPrice() / 1e9, "gwei");
        console.log("  - Last compound block:", theVault.lastAutoCompoundBlock());
        console.log("  - Next compound block:", theVault.getNextAutoCompoundBlock());

        console.log("\nKeeper System Configuration:");
        console.log("  - Keeper reward:", theVault.keeperReward() / 1e15, "milliETH");
        console.log("  - Vault ETH balance:", address(theVault).balance / 1e15, "milliETH");
        console.log("  - Deployer authorized:", theVault.authorizedKeepers(deployer));
        console.log("  - Max keeper reward: 10.0 milliETH (hardcoded limit)");

        console.log("\nFarm Configuration:");
        console.log("  - Reward rate:", theFarm.REWARD_RATE(), "tokens per block");
        console.log("  - Staking token:", address(theFarm.stakingToken()));
        console.log("  - Reward token:", address(theFarm.rewardToken()));
        console.log("  - Total staked:", theFarm.totalStaked() / 1e18, "tokens");
        console.log("  - Last reward block:", theFarm.lastRewardBlock());
    }
}
