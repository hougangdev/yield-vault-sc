// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DepositToken.sol";
import "../src/TheFarm.sol";
import "../src/TheVault.sol";

/**
 * @title TheFarmTest
 * @dev Comprehensive test suite for the yield vault system
 */
contract TheFarmTest is Test {
    DepositToken public depositToken;
    TheFarm public theFarm;
    TheVault public theVault;

    // Test accounts
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    // Test parameters
    string constant DEPOSIT_TOKEN_NAME = "Test Deposit Token";
    string constant DEPOSIT_TOKEN_SYMBOL = "TDT";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;

    string constant RECEIPT_TOKEN_NAME = "Test Farm Receipt Token";
    string constant RECEIPT_TOKEN_SYMBOL = "TFRT";

    function setUp() public {
        // Deploy contracts
        vm.startPrank(owner);

        depositToken = new DepositToken(DEPOSIT_TOKEN_NAME, DEPOSIT_TOKEN_SYMBOL, INITIAL_SUPPLY);

        theFarm = new TheFarm(
            address(depositToken),
            address(depositToken), // Using deposit token as reward token for testing
            RECEIPT_TOKEN_NAME,
            RECEIPT_TOKEN_SYMBOL
        );

        theVault = new TheVault(address(theFarm), address(depositToken));

        // Authorize TheFarm to mint/burn DepositTokens
        depositToken.setAuthorizedMinter(address(theFarm), true);

        vm.stopPrank();

        // Distribute tokens to test users
        vm.startPrank(owner);
        depositToken.transfer(user1, 10000 * 1e18);
        depositToken.transfer(user2, 10000 * 1e18);
        vm.stopPrank();

        // Approve TheFarm to spend tokens
        vm.startPrank(user1);
        depositToken.approve(address(theFarm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        depositToken.approve(address(theFarm), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialSetup() public {
        assertEq(depositToken.name(), DEPOSIT_TOKEN_NAME);
        assertEq(depositToken.symbol(), DEPOSIT_TOKEN_SYMBOL);
        assertEq(depositToken.totalSupply(), INITIAL_SUPPLY);

        assertEq(address(theFarm.stakingToken()), address(depositToken));
        assertEq(address(theFarm.rewardToken()), address(depositToken));
        assertEq(theFarm.REWARD_RATE(), 10 * 1e18);

        assertEq(address(theVault.theFarm()), address(theFarm));
        assertEq(address(theVault.depositToken()), address(depositToken));
    }

    function testStaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        uint256 user1BalanceBefore = depositToken.balanceOf(user1);
        uint256 farmBalanceBefore = depositToken.balanceOf(address(theFarm));

        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Check balances
        assertEq(depositToken.balanceOf(user1), user1BalanceBefore - stakeAmount);
        assertEq(depositToken.balanceOf(address(theFarm)), farmBalanceBefore + stakeAmount);

        // Check receipt tokens
        assertEq(theFarm.balanceOf(user1), stakeAmount);
        assertEq(theFarm.totalStaked(), stakeAmount);

        // Check user info
        (uint256 amount, uint256 rewardDebt, uint256 pendingRewards) = theFarm.userInfo(user1);
        assertEq(amount, stakeAmount);
        assertEq(rewardDebt, 0); // Should be 0 initially
        assertEq(pendingRewards, 0);
    }

    function testRewardAccumulation() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Mine some blocks to accumulate rewards
        vm.roll(block.number + 10);

        // Check pending rewards
        uint256 pendingRewards = theFarm.getPendingRewards(user1);
        assertEq(pendingRewards, 10 * 1e18 * 10); // 10 blocks * 10 tokens per block

        // User2 stakes
        vm.startPrank(user2);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Mine more blocks
        vm.roll(block.number + 5);

        // Check pending rewards for both users
        uint256 user1Pending = theFarm.getPendingRewards(user1);
        uint256 user2Pending = theFarm.getPendingRewards(user2);

        // User1 should have more rewards (staked longer)
        assertTrue(user1Pending > user2Pending);
    }

    function testUnstaking() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        uint256 user1BalanceBefore = depositToken.balanceOf(user1);
        uint256 farmBalanceBefore = depositToken.balanceOf(address(theFarm));

        // User1 unstakes
        vm.startPrank(user1);
        theFarm.unstake(stakeAmount);
        vm.stopPrank();

        // Check balances
        assertEq(depositToken.balanceOf(user1), user1BalanceBefore + stakeAmount);
        assertEq(depositToken.balanceOf(address(theFarm)), farmBalanceBefore - stakeAmount);

        // Check receipt tokens
        assertEq(theFarm.balanceOf(user1), 0);
        assertEq(theFarm.totalStaked(), 0);
    }

    function testClaimRewards() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Mine blocks to accumulate rewards
        vm.roll(block.number + 10);

        // Deposit rewards to the farm (simulating reward distribution)
        vm.startPrank(owner);
        depositToken.transfer(address(theFarm), 1000 * 1e18);
        vm.stopPrank();

        uint256 user1BalanceBefore = depositToken.balanceOf(user1);

        // User1 claims rewards
        vm.startPrank(user1);
        theFarm.claimRewards();
        vm.stopPrank();

        uint256 user1BalanceAfter = depositToken.balanceOf(user1);
        uint256 expectedRewards = 10 * 1e18 * 10; // 10 blocks * 10 tokens per block

        assertEq(user1BalanceAfter, user1BalanceBefore + expectedRewards);
    }

    function testVaultRewardCollection() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Mine blocks to accumulate rewards
        vm.roll(block.number + 10);

        // Deposit rewards to the farm
        vm.startPrank(owner);
        depositToken.transfer(address(theFarm), 1000 * 1e18);
        vm.stopPrank();

        // User1 claims rewards (simulating vault collection)
        vm.startPrank(user1);
        theFarm.claimRewards();
        vm.stopPrank();

        // Check vault functionality
        uint256 totalRewardsCollected = theVault.getTotalRewardsCollected();
        assertEq(totalRewardsCollected, 0); // Should be 0 initially

        // Test vault share tracking
        uint256 userShare = theVault.getUserShare(user1);
        assertEq(userShare, 0); // Should be 0 initially
    }

    function testMultipleUsersStaking() public {
        uint256 stakeAmount1 = 1000 * 1e18;
        uint256 stakeAmount2 = 2000 * 1e18;

        // Both users stake
        vm.startPrank(user1);
        theFarm.stake(stakeAmount1);
        vm.stopPrank();

        vm.startPrank(user2);
        theFarm.stake(stakeAmount2);
        vm.stopPrank();

        // Check total staked
        assertEq(theFarm.totalStaked(), stakeAmount1 + stakeAmount2);

        // Check individual balances
        assertEq(theFarm.balanceOf(user1), stakeAmount1);
        assertEq(theFarm.balanceOf(user2), stakeAmount2);

        // Mine blocks and check rewards distribution
        vm.roll(block.number + 5);

        uint256 user1Pending = theFarm.getPendingRewards(user1);
        uint256 user2Pending = theFarm.getPendingRewards(user2);

        // User2 should have more rewards (staked more)
        assertTrue(user2Pending > user1Pending);

        // Check proportional rewards
        uint256 totalRewards = 10 * 1e18 * 5; // 5 blocks * 10 tokens per block
        uint256 expectedUser1Rewards = (totalRewards * stakeAmount1) / (stakeAmount1 + stakeAmount2);
        uint256 expectedUser2Rewards = (totalRewards * stakeAmount2) / (stakeAmount1 + stakeAmount2);

        assertEq(user1Pending, expectedUser1Rewards);
        assertEq(user2Pending, expectedUser2Rewards);
    }

    function testReceiptTokenFunctionality() public {
        uint256 stakeAmount = 1000 * 1e18;

        // User1 stakes
        vm.startPrank(user1);
        theFarm.stake(stakeAmount);
        vm.stopPrank();

        // Check receipt token properties
        assertEq(theFarm.name(), RECEIPT_TOKEN_NAME);
        assertEq(theFarm.symbol(), RECEIPT_TOKEN_SYMBOL);
        assertEq(theFarm.totalSupply(), stakeAmount);
        assertEq(theFarm.balanceOf(user1), stakeAmount);

        // User1 unstakes
        vm.startPrank(user1);
        theFarm.unstake(stakeAmount);
        vm.stopPrank();

        // Check receipt tokens are burned
        assertEq(theFarm.balanceOf(user1), 0);
        assertEq(theFarm.totalSupply(), 0);
    }
}
