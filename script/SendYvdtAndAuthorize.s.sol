// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/DepositToken.sol";
import "../src/TheVault.sol";

/**
 * @title SendYvdtAndAuthorize
 * @dev Script to send YVDT tokens and authorize address for auto-compounding
 * @notice This script mints YVDT tokens and sets up keeper authorization
 */
contract SendYvdtAndAuthorize is Script {
    // From latest deployment on Sepolia
    address constant DEPOSIT_TOKEN = 0x735de2703e15e7b33Be509512e2bbEB444674430;
    address constant THE_VAULT = 0x68f3522b3d953a146b879e42d8ddC06Ba5A300b4;

    // Test address to receive tokens and authorization
    address constant TEST_ADDRESS = 0x34846BF00C64A56A5FB10a9EE7717aBC7887FEdf;

    // Amount to send (1000 YVDT tokens)
    uint256 constant AMOUNT = 1000 * 1e18;

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== SEND YVDT AND AUTHORIZE SCRIPT ===");
        console.log("Deployer address:", deployer);
        console.log("Test address:", TEST_ADDRESS);
        console.log("Amount:", AMOUNT / 1e18, "YVDT tokens");

        DepositToken depositToken = DepositToken(DEPOSIT_TOKEN);
        TheVault theVault = TheVault(THE_VAULT);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Authorize deployer as minter if not already authorized
        console.log("\nStep 1: Checking minter authorization...");
        bool isMinter = depositToken.authorizedMinters(deployer);
        console.log("Is deployer authorized to mint?", isMinter);

        if (!isMinter) {
            console.log("Authorizing deployer as minter...");
            depositToken.setAuthorizedMinter(deployer, true);
            console.log("[SUCCESS] Deployer is now authorized to mint");
        }

        // Step 2: Mint YVDT tokens to test address
        console.log("\nStep 2: Minting YVDT tokens to test address...");
        depositToken.mint(TEST_ADDRESS, AMOUNT);
        uint256 balance = depositToken.balanceOf(TEST_ADDRESS);
        console.log("[SUCCESS] Test address balance:", balance / 1e18, "YVDT tokens");

        // Step 3: Authorize test address as keeper for auto-compounding
        console.log("\nStep 3: Authorizing test address as keeper...");
        theVault.setKeeperAuthorization(TEST_ADDRESS, true);
        console.log("[SUCCESS] Test address is now authorized as keeper");

        bool isAuthorized = theVault.authorizedKeepers(TEST_ADDRESS);
        console.log("Verification - Is keeper authorized?", isAuthorized);

        // Step 4: Display auto-compound status
        console.log("\nStep 4: Auto-compound status:");
        (
            bool enabled,
            uint256 lastBlock,
            uint256 interval,
            uint256 minAmount,
            uint256 maxGasPrice,
            uint256 blocksUntilNext
        ) = theVault.getAutoCompoundStatus();

        console.log("  - Auto-compound enabled:", enabled);
        console.log("  - Last compound block:", lastBlock);
        console.log("  - Compound interval:", interval, "blocks");
        console.log("  - Min compound amount:", minAmount);
        console.log("  - Max gas price:", maxGasPrice);
        console.log("  - Blocks until next:", blocksUntilNext);

        console.log("\n=== SCRIPT COMPLETE ===");
        console.log("Test address now has", balance / 1e18, "YVDT tokens");
        console.log("Test address can now execute auto-compounding");

        vm.stopBroadcast();
    }
}
