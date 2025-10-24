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
    DepositToken public theFarm; // Mock farm for testing

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    string constant DEPOSIT_TOKEN_NAME = "Test Deposit Token";
    string constant DEPOSIT_TOKEN_SYMBOL = "TDT";
    string constant TOKEN_NAME = "Test Deposit Token";
    string constant TOKEN_SYMBOL = "TDT";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);
        depositToken = new DepositToken(TOKEN_NAME, TOKEN_SYMBOL, INITIAL_SUPPLY);

        // Create a mock farm contract for testing
        theFarm = new DepositToken("Mock Farm", "MF", 0);

        // Set the mock farm as authorized minter
        depositToken.setAuthorizedMinter(address(theFarm), true);
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

    // Additional tests to achieve 100% coverage
    function testTokenNameAndSymbol() public view {
        assertEq(depositToken.name(), DEPOSIT_TOKEN_NAME);
        assertEq(depositToken.symbol(), DEPOSIT_TOKEN_SYMBOL);
    }

    function testTokenDecimals() public view {
        assertEq(depositToken.decimals(), 18);
    }

    function testTokenTotalSupply() public view {
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY);
    }

    function testTokenBalanceOf() public view {
        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(depositToken.balanceOf(user1), 0);
    }

    function testTokenTransfer() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.startPrank(owner);
        depositToken.transfer(user1, transferAmount);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(depositToken.balanceOf(user1), transferAmount);
    }

    function testTokenTransferWithInsufficientBalance() public {
        uint256 transferAmount = INITIAL_SUPPLY + 1;

        vm.startPrank(owner);
        vm.expectRevert();
        depositToken.transfer(user1, transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferToZeroAddress() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.startPrank(owner);
        vm.expectRevert();
        depositToken.transfer(address(0), transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferZeroAmount() public {
        vm.startPrank(owner);
        depositToken.transfer(user1, 0);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(depositToken.balanceOf(user1), 0);
    }

    function testTokenApprove() public {
        uint256 approveAmount = 1000 * 1e18;

        vm.startPrank(owner);
        depositToken.approve(user1, approveAmount);
        vm.stopPrank();

        assertEq(depositToken.allowance(owner, user1), approveAmount);
    }

    function testTokenApproveZeroAmount() public {
        vm.startPrank(owner);
        depositToken.approve(user1, 0);
        vm.stopPrank();

        assertEq(depositToken.allowance(owner, user1), 0);
    }

    function testTokenTransferFrom() public {
        uint256 transferAmount = 1000 * 1e18;

        // Approve first
        vm.startPrank(owner);
        depositToken.approve(user1, transferAmount);
        vm.stopPrank();

        // Transfer from
        vm.startPrank(user1);
        depositToken.transferFrom(owner, user2, transferAmount);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(depositToken.balanceOf(user2), transferAmount);
        assertEq(depositToken.allowance(owner, user1), 0);
    }

    function testTokenTransferFromWithInsufficientAllowance() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.transferFrom(owner, user2, transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferFromWithInsufficientBalance() public {
        uint256 transferAmount = INITIAL_SUPPLY + 1;

        // Approve first
        vm.startPrank(owner);
        depositToken.approve(user1, transferAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.transferFrom(owner, user2, transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferFromZeroAddress() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.transferFrom(address(0), user2, transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferFromToZeroAddress() public {
        uint256 transferAmount = 1000 * 1e18;

        // Approve first
        vm.startPrank(owner);
        depositToken.approve(user1, transferAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.transferFrom(owner, address(0), transferAmount);
        vm.stopPrank();
    }

    function testTokenTransferFromZeroAmount() public {
        // Approve first
        vm.startPrank(owner);
        depositToken.approve(user1, 1000 * 1e18);
        vm.stopPrank();

        // Transfer from with zero amount
        vm.startPrank(user1);
        depositToken.transferFrom(owner, user2, 0);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(depositToken.balanceOf(user2), 0);
    }

    function testTokenAllowance() public view {
        assertEq(depositToken.allowance(owner, user1), 0);
    }

    // Note: DepositToken doesn't have increaseAllowance/decreaseAllowance functions
    // These are standard ERC20 functions but not implemented in this contract

    function testAuthorizedMinterStatus() public view {
        assertTrue(depositToken.authorizedMinters(address(theFarm)));
        assertFalse(depositToken.authorizedMinters(user1));
    }

    function testSetAuthorizedMinterFalse() public {
        vm.startPrank(owner);
        depositToken.setAuthorizedMinter(address(theFarm), false);
        vm.stopPrank();

        assertFalse(depositToken.authorizedMinters(address(theFarm)));
    }

    function testMintWithUnauthorizedMinter() public {
        vm.startPrank(user1);
        vm.expectRevert(DepositToken.DepositToken__NotAuthorizedToMint.selector);
        depositToken.mint(user2, 1000 * 1e18);
        vm.stopPrank();
    }

    function testBurnWithUnauthorizedMinter() public {
        vm.startPrank(user1);
        vm.expectRevert(DepositToken.DepositToken__NotAuthorizedToBurn.selector);
        depositToken.burn(user2, 1000 * 1e18);
        vm.stopPrank();
    }

    function testMintWithInsufficientBalance() public {
        uint256 mintAmount = INITIAL_SUPPLY + 1;

        vm.startPrank(address(theFarm));
        // This should not revert because the mint function doesn't check total supply limits
        // The DepositToken contract allows minting beyond initial supply
        depositToken.mint(user1, mintAmount);
        vm.stopPrank();

        assertEq(depositToken.balanceOf(user1), mintAmount);
    }

    function testBurnWithInsufficientBalance() public {
        uint256 burnAmount = INITIAL_SUPPLY + 1;

        vm.startPrank(address(theFarm));
        vm.expectRevert();
        depositToken.burn(user1, burnAmount);
        vm.stopPrank();
    }

    function testMintToZeroAddress() public {
        vm.startPrank(address(theFarm));
        vm.expectRevert();
        depositToken.mint(address(0), 1000 * 1e18);
        vm.stopPrank();
    }

    function testBurnFromZeroAddress() public {
        vm.startPrank(address(theFarm));
        vm.expectRevert();
        depositToken.burn(address(0), 1000 * 1e18);
        vm.stopPrank();
    }

    function testSetAuthorizedMinterOnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        depositToken.setAuthorizedMinter(user2, true);
        vm.stopPrank();
    }
}
