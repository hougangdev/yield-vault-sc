// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/TheVault.sol";
import "../src/TheFarm.sol";
import "../src/DepositToken.sol";

/**
 * @title TheVaultTest
 * @dev Basic test suite for TheVault contract
 */
contract TheVaultTest is Test {
    DepositToken public depositToken;
    TheFarm public theFarm;
    TheVault public theVault;

    address public owner = address(0x1);
    address public user1 = address(0x2);

    string constant DEPOSIT_TOKEN_NAME = "Test Deposit Token";
    string constant DEPOSIT_TOKEN_SYMBOL = "TDT";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;

    string constant RECEIPT_TOKEN_NAME = "Test Farm Receipt Token";
    string constant RECEIPT_TOKEN_SYMBOL = "TFRT";

    function setUp() public {
        vm.startPrank(owner);

        depositToken = new DepositToken(DEPOSIT_TOKEN_NAME, DEPOSIT_TOKEN_SYMBOL, INITIAL_SUPPLY);

        theFarm = new TheFarm(address(depositToken), address(depositToken), RECEIPT_TOKEN_NAME, RECEIPT_TOKEN_SYMBOL);

        theVault = new TheVault(address(theFarm), address(depositToken), "Test Vault Token", "TVT");

        depositToken.setAuthorizedMinter(address(theFarm), true);

        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(address(theVault.theFarm()), address(theFarm));
        assertEq(address(theVault.asset()), address(depositToken));
        assertEq(theVault.getTotalRewardsCollected(), 0);
        assertEq(theVault.balanceOf(user1), 0);
    }

    function testAutoRestakeThreshold() public {
        uint256 newThreshold = 500 * 1e18;

        vm.startPrank(owner);
        theVault.setAutoRestakeThreshold(newThreshold);
        vm.stopPrank();

        assertEq(theVault.autoRestakeThreshold(), newThreshold);
    }

    function testGetUserPercentage() public view {
        uint256 percentage = theVault.balanceOf(user1);
        assertEq(percentage, 0); // Should be 0 when no shares
    }
}
