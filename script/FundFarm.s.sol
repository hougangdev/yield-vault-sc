// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/DepositToken.sol";
import "../src/TheFarm.sol";

/**
 * @title FundFarm
 * @dev Script to mint deposit tokens and fund TheFarm with rewards
 * @notice This script mints tokens to the deployer and deposits them into the farm
 */
contract FundFarm is Script {
    // Contract addresses - update these from your deployment
    address constant DEPOSIT_TOKEN = 0xbec3c112CB6cEBe57AB9E429437Dc566509B602A;
    address constant THE_FARM = 0xBDe94Bf7f0a045aB422880bd3Da4080396A3Bfab;

    // Amount to mint and deposit (adjust as needed)
    uint256 constant AMOUNT_TO_MINT = 10_000_000 * 1e18; // 10M tokens

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== FUND FARM SCRIPT ===");
        console.log("Deployer address:", deployer);
        console.log("DepositToken address:", DEPOSIT_TOKEN);
        console.log("TheFarm address:", THE_FARM);
        console.log("Amount to mint:", AMOUNT_TO_MINT / 1e18, "tokens");

        DepositToken depositToken = DepositToken(DEPOSIT_TOKEN);
        TheFarm theFarm = TheFarm(THE_FARM);

        vm.startBroadcast(deployerPrivateKey);

        // Check if deployer is authorized to mint
        bool isAuthorized = depositToken.authorizedMinters(deployer);
        console.log("\nIs deployer authorized to mint?", isAuthorized);

        if (!isAuthorized) {
            // First, authorize the deployer as a minter (only owner can do this)
            console.log("\nStep 1: Authorizing deployer as minter...");
            depositToken.setAuthorizedMinter(deployer, true);
            console.log("[SUCCESS] Deployer is now authorized to mint");
        }

        // Check current farm balance
        uint256 farmBalance = theFarm.getStakingTokenBalance();
        console.log("\nCurrent farm balance:", farmBalance / 1e18, "tokens");

        // Check pending rewards in farm
        uint256 pendingRewards = theFarm.getPendingRewards(THE_FARM);
        console.log("Pending rewards in farm:", pendingRewards / 1e18, "tokens");

        // Mint tokens to the deployer
        console.log("\nStep 2: Minting tokens to deployer...");
        depositToken.mint(deployer, AMOUNT_TO_MINT);
        console.log("[SUCCESS] Minted", AMOUNT_TO_MINT / 1e18, "tokens to deployer");

        uint256 deployerBalance = depositToken.balanceOf(deployer);
        console.log("Deployer balance:", deployerBalance / 1e18, "tokens");

        // Approve farm to spend tokens
        console.log("\nStep 3: Approving farm to spend tokens...");
        depositToken.approve(THE_FARM, AMOUNT_TO_MINT);
        console.log("[SUCCESS] Farm approved to spend", AMOUNT_TO_MINT / 1e18, "tokens");

        uint256 allowance = depositToken.allowance(deployer, THE_FARM);
        console.log("Allowance:", allowance / 1e18, "tokens");

        // Deposit all tokens into the farm as rewards
        console.log("\nStep 4: Depositing tokens into farm as rewards...");
        theFarm.depositRewards(AMOUNT_TO_MINT);
        console.log("[SUCCESS] Deposited", AMOUNT_TO_MINT / 1e18, "tokens into farm");

        // Check final farm balance
        uint256 finalFarmBalance = theFarm.getStakingTokenBalance();
        console.log("\nFinal farm balance:", finalFarmBalance / 1e18, "tokens");
        console.log("Increase:", (finalFarmBalance - farmBalance) / 1e18, "tokens");

        console.log("\n=== SCRIPT COMPLETE ===");
        console.log("Farm is now funded with", finalFarmBalance / 1e18, "tokens");
        console.log("You can now withdraw from the vault!");

        vm.stopBroadcast();
    }
}
