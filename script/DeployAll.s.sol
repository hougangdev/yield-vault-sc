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
    uint256 constant DEFAULT_AUTO_RESTAKE_THRESHOLD = 100 * 1e18; // 100 tokens
    uint256 constant DEFAULT_PERFORMANCE_FEE = 100; // 1% in basis points
    uint256 constant MAX_PERFORMANCE_FEE = 1000; // 10% max in basis points

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

        // For this example, we'll use DepositToken as the reward token too
        // In production, you might want to use a different reward token
        address rewardToken = address(depositToken);

        // Deploy TheFarm
        console.log("\n2. Deploying TheFarm...");
        theFarm = new TheFarm(
            address(depositToken), // staking token
            rewardToken, // reward token
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

        // Configure TheVault with security parameters
        console.log("\n4. Configuring TheVault security parameters...");

        // Set auto-restake threshold
        theVault.setAutoRestakeThreshold(DEFAULT_AUTO_RESTAKE_THRESHOLD);
        console.log("[SUCCESS] Auto-restake threshold set to:", DEFAULT_AUTO_RESTAKE_THRESHOLD / 1e18, "tokens");

        // Set performance fee
        theVault.setPerformanceFee(DEFAULT_PERFORMANCE_FEE);
        console.log("[SUCCESS] Performance fee set to:", DEFAULT_PERFORMANCE_FEE, "basis points");
        console.log("  Percentage:", DEFAULT_PERFORMANCE_FEE / 100, "%");

        // Set fee recipient (defaults to deployer)
        theVault.setFeeRecipient(deployer);
        console.log("[SUCCESS] Fee recipient set to:", theVault.feeRecipient());

        // Authorize TheFarm to mint/burn DepositTokens
        console.log("\n5. Setting up authorization...");
        depositToken.setAuthorizedMinter(address(theFarm), true);
        console.log("[SUCCESS] TheFarm authorized to mint/burn DepositTokens");
        console.log("  - Authorized:", depositToken.authorizedMinters(address(theFarm)));

        vm.stopBroadcast();

        // Comprehensive deployment verification
        console.log("\n=== DEPLOYMENT VERIFICATION ===");
        _verifyDeployment();

        // Security configuration summary
        console.log("\n=== SECURITY CONFIGURATION ===");
        _logSecurityConfig();

        // Final summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("[SUCCESS] All contracts deployed successfully");
        console.log("[SUCCESS] Security parameters configured");
        console.log("[SUCCESS] Authorization set up");
        console.log("[SUCCESS] System ready for use");

        console.log("\nContract Addresses:");
        console.log("  DepositToken:", address(depositToken));
        console.log("  TheFarm:", address(theFarm));
        console.log("  TheVault:", address(theVault));
    }

    /**
     * @dev Verify that all contracts are properly deployed and configured
     */
    function _verifyDeployment() internal view {
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

        // Verify authorization
        require(depositToken.authorizedMinters(address(theFarm)), "TheFarm not authorized");

        console.log("[SUCCESS] All contracts verified successfully");
    }

    /**
     * @dev Log the security configuration for transparency
     */
    function _logSecurityConfig() internal view {
        console.log("Security Features Enabled:");
        console.log("  [ENABLED] SafeERC20 operations throughout");
        console.log("  [ENABLED] Reentrancy protection");
        console.log("  [ENABLED] Access control (Ownable)");
        console.log("  [ENABLED] Input validation");
        console.log("  [ENABLED] Custom error handling");
        console.log("  [ENABLED] Event indexing for off-chain monitoring");

        console.log("\nVault Configuration:");
        console.log("  - Auto-restake threshold:", theVault.autoRestakeThreshold() / 1e18, "tokens");
        console.log("  - Performance fee:", theVault.performanceFee(), "basis points");
        console.log("  - Max performance fee:", theVault.MAX_PERFORMANCE_FEE(), "basis points");
        console.log("  - Fee recipient:", theVault.feeRecipient());

        console.log("\nFarm Configuration:");
        console.log("  - Reward rate:", theFarm.REWARD_RATE(), "tokens per block");
        console.log("  - Staking token:", address(theFarm.stakingToken()));
        console.log("  - Reward token:", address(theFarm.rewardToken()));
        console.log("  - Total staked:", theFarm.totalStaked() / 1e18, "tokens");
    }
}
