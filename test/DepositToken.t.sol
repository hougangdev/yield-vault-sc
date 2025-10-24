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

    function testCustomErrors() public {
        // Test DepositToken__NotAuthorizedToMint error
        vm.expectRevert(DepositToken.DepositToken__NotAuthorizedToMint.selector);
        depositToken.mint(user1, 1000 * 1e18);

        // Test DepositToken__NotAuthorizedToBurn error
        vm.expectRevert(DepositToken.DepositToken__NotAuthorizedToBurn.selector);
        depositToken.burn(owner, 1000 * 1e18);

        // Test DepositToken__InvalidAmount error
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        vm.expectRevert(DepositToken.DepositToken__InvalidAmount.selector);
        depositToken.mint(user1, 0);

        // Test DepositToken__InvalidAddress error
        vm.expectRevert(DepositToken.DepositToken__InvalidAddress.selector);
        depositToken.mint(address(0), 1000 * 1e18);
    }

    function testBurnFromSelf() public {
        uint256 burnAmount = 1000 * 1e18;

        vm.startPrank(owner);
        depositToken.burnFromSelf(burnAmount);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testBurnFromSelfZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(DepositToken.DepositToken__InvalidAmount.selector);
        depositToken.burnFromSelf(0);
        vm.stopPrank();
    }

    function testSetAuthorizedMinterZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(DepositToken.DepositToken__InvalidAddress.selector);
        depositToken.setAuthorizedMinter(address(0), true);
        vm.stopPrank();
    }

    function testBurnZeroAmount() public {
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        vm.expectRevert(DepositToken.DepositToken__InvalidAmount.selector);
        depositToken.burn(owner, 0);
    }

    function testBurnZeroAddress() public {
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        vm.expectRevert(DepositToken.DepositToken__InvalidAddress.selector);
        depositToken.burn(address(0), 1000 * 1e18);
    }

    function testMintZeroAmount() public {
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        vm.expectRevert(DepositToken.DepositToken__InvalidAmount.selector);
        depositToken.mint(user1, 0);
    }

    function testMintZeroAddress() public {
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(this), true);
        vm.stopPrank();

        vm.expectRevert(DepositToken.DepositToken__InvalidAddress.selector);
        depositToken.mint(address(0), 1000 * 1e18);
    }

    function testOnlyOwnerCanSetAuthorizedMinter() public {
        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.setAuthorizedMinter(user1, true);
        vm.stopPrank();
    }

    function testAuthorizedMinterEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit DepositToken.AuthorizedMinter(user1, true);
        depositToken.setAuthorizedMinter(user1, true);
        vm.stopPrank();
    }

    function testInitialSupplyZero() public {
        vm.startPrank(owner);
        DepositToken zeroSupplyToken = new DepositToken("Zero Token", "ZT", 0);
        vm.stopPrank();

        assertEq(zeroSupplyToken.totalSupply(), 0);
        assertEq(zeroSupplyToken.balanceOf(owner), 0);
    }
}
