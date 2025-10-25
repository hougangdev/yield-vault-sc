// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/TheVault.sol";

/**
 * @title UpdateDemoConfig
 * @dev Script to update the deployed vault with demo-friendly settings for faster auto-compounding
 * @notice This reduces the auto-compound interval to 5 blocks for demo purposes
 */
contract UpdateDemoConfig is Script {
    // Deployed contract address on Sepolia
    address constant VAULT_ADDRESS = 0x30bd7526e85ac4dC2141073F3C8F487B42973E81;

    // Demo configuration - faster auto-compounding for demonstration
    uint256 constant DEMO_AUTO_COMPOUND_INTERVAL = 5; // 5 blocks (~1 minute)
    uint256 constant DEMO_MIN_COMPOUND_AMOUNT = 1 * 1e18; // 1 token

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== UPDATING VAULT CONFIGURATION FOR DEMO ===");
        console.log("Deployer:", deployer);
        console.log("Vault Address:", VAULT_ADDRESS);
        console.log("Current block:", block.number);

        TheVault vault = TheVault(VAULT_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        // Check current settings
        console.log("\nCurrent Configuration:");
        console.log("  - Auto-compound interval:", vault.autoCompoundInterval(), "blocks");
        console.log("  - Min compound amount:", vault.minCompoundAmount() / 1e18, "tokens");
        console.log("  - Auto-compound enabled:", vault.autoCompoundEnabled());

        // Update to demo settings
        console.log("\nUpdating to demo configuration...");

        // Set shorter interval for demo
        vault.setAutoCompoundInterval(DEMO_AUTO_COMPOUND_INTERVAL);
        console.log("[SUCCESS] Auto-compound interval set to:", DEMO_AUTO_COMPOUND_INTERVAL, "blocks");
        console.log("  Estimated time: ~1 minute (assuming 12s blocks)");

        // Set lower minimum amount for demo
        vault.setMinCompoundAmount(DEMO_MIN_COMPOUND_AMOUNT);
        console.log("[SUCCESS] Minimum compound amount set to:", DEMO_MIN_COMPOUND_AMOUNT / 1e18, "tokens");

        vm.stopBroadcast();

        // Verify new settings
        console.log("\nNew Configuration:");
        console.log("  - Auto-compound interval:", vault.autoCompoundInterval(), "blocks");
        console.log("  - Min compound amount:", vault.minCompoundAmount() / 1e18, "tokens");

        console.log("\n=== DEMO CONFIGURATION COMPLETE ===");
        console.log("[SUCCESS] Auto-compounding now runs every 5 blocks for faster demonstration");
        console.log("[INFO] The vault will automatically compound rewards more frequently");
    }
}
