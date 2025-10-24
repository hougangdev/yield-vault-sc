// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/DepositToken.sol";

/**
 * @title DeployDepositToken
 * @dev Script to deploy DepositToken contract
 */
contract DeployDepositToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        DepositToken depositToken = new DepositToken("Yield Vault Deposit Token", "YVDT", 1000000 * 1e18);

        vm.stopBroadcast();

        console.log("DepositToken deployed at:", address(depositToken));
    }
}
