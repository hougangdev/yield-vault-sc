// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DepositToken.sol";
import "../src/TheFarm.sol";
import "../src/TheVault.sol";

/**
 * @title DeployAll
 * @dev Script to deploy all contracts in the yield vault system
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

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DepositToken
        console.log("Deploying DepositToken...");
        depositToken = new DepositToken(DEPOSIT_TOKEN_NAME, DEPOSIT_TOKEN_SYMBOL, INITIAL_SUPPLY);
        console.log("DepositToken deployed at:", address(depositToken));

        // For this example, we'll use DepositToken as the reward token too
        // In production, you might want to use a different reward token
        address rewardToken = address(depositToken);

        // Deploy TheFarm
        console.log("Deploying TheFarm...");
        theFarm = new TheFarm(
            address(depositToken), // staking token
            rewardToken, // reward token
            RECEIPT_TOKEN_NAME,
            RECEIPT_TOKEN_SYMBOL
        );
        console.log("TheFarm deployed at:", address(theFarm));

        // Deploy TheVault
        console.log("Deploying TheVault...");
        theVault = new TheVault(address(theFarm), address(depositToken));
        console.log("TheVault deployed at:", address(theVault));

        // Authorize TheFarm to mint/burn DepositTokens
        console.log("Authorizing TheFarm to mint/burn DepositTokens...");
        depositToken.setAuthorizedMinter(address(theFarm), true);

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("DepositToken:", address(depositToken));
        console.log("TheFarm:", address(theFarm));
        console.log("TheVault:", address(theVault));
        console.log("Reward Token:", rewardToken);
        console.log("Initial Supply:", INITIAL_SUPPLY);

        // Verify deployment
        console.log("\n=== Verification ===");
        console.log("DepositToken name:", depositToken.name());
        console.log("DepositToken symbol:", depositToken.symbol());
        console.log("DepositToken total supply:", depositToken.totalSupply());
        console.log("TheFarm staking token:", address(theFarm.stakingToken()));
        console.log("TheFarm reward token:", address(theFarm.rewardToken()));
        console.log("TheFarm reward rate:", theFarm.REWARD_RATE());
        console.log("TheVault theFarm:", address(theVault.theFarm()));
        console.log("TheVault depositToken:", address(theVault.depositToken()));
    }
}
