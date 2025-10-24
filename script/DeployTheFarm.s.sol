// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/TheFarm.sol";
import "../src/DepositToken.sol";

/**
 * @title DeployTheFarm
 * @dev Script to deploy TheFarm contract
 */
contract DeployTheFarm is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DepositToken first
        DepositToken depositToken = new DepositToken("Yield Vault Deposit Token", "YVDT", 1000000 * 1e18);

        // Deploy TheFarm
        TheFarm theFarm = new TheFarm(
            address(depositToken),
            address(depositToken), // Using deposit token as reward token
            "Farm Receipt Token",
            "FRT"
        );

        // Authorize TheFarm to mint/burn DepositTokens
        depositToken.setAuthorizedMinter(address(theFarm), true);

        vm.stopBroadcast();

        console.log("DepositToken deployed at:", address(depositToken));
        console.log("TheFarm deployed at:", address(theFarm));
    }
}
