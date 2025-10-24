// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/TheVault.sol";
import "../src/TheFarm.sol";
import "../src/DepositToken.sol";

/**
 * @title DeployTheVault
 * @dev Script to deploy TheVault contract
 */
contract DeployTheVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DepositToken
        DepositToken depositToken = new DepositToken("Yield Vault Deposit Token", "YVDT", 1000000 * 1e18);

        // Deploy TheFarm
        TheFarm theFarm = new TheFarm(
            address(depositToken),
            address(depositToken), // Using deposit token as reward token
            "Farm Receipt Token",
            "FRT"
        );

        // Deploy TheVault
        TheVault theVault = new TheVault(address(theFarm), address(depositToken), "Yield Vault Token", "YVT");

        // Authorize TheFarm to mint/burn DepositTokens
        depositToken.setAuthorizedMinter(address(theFarm), true);

        vm.stopBroadcast();

        console.log("DepositToken deployed at:", address(depositToken));
        console.log("TheFarm deployed at:", address(theFarm));
        console.log("TheVault deployed at:", address(theVault));
    }
}
