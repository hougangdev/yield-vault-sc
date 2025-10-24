// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/DepositToken.sol";

/**
 * @title DepositTokenTest
 * @dev Basic test suite for DepositToken contract
 */
contract DepositTokenTest is Test {
    DepositToken public depositToken;

    address public owner = address(0x1);
    address public user1 = address(0x2);

    string constant TOKEN_NAME = "Test Deposit Token";
    string constant TOKEN_SYMBOL = "TDT";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);
        depositToken = new DepositToken(TOKEN_NAME, TOKEN_SYMBOL, INITIAL_SUPPLY);
        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(depositToken.name(), TOKEN_NAME);
        assertEq(depositToken.symbol(), TOKEN_SYMBOL);
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testMint() public {
        uint256 mintAmount = 1000 * 1e18;

        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        // Now mint from the test contract
        depositToken.mint(user1, mintAmount);

        assertEq(depositToken.balanceOf(user1), mintAmount);
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function testBurn() public {
        uint256 burnAmount = 1000 * 1e18;

        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        // Now burn from the test contract
        depositToken.burn(owner, burnAmount);

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }
}
