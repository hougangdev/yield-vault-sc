// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TheFarm
 * @dev Staking contract where users stake deposit tokens and earn rewards
 * @notice Users receive receipt tokens representing their stake and earn 10 reward tokens per block
 */
contract TheFarm is ERC20, Ownable, ReentrancyGuard {
    // Custom errors
    error TheFarm__InvalidRewardToken();
    error TheFarm__InvalidAmount();
    error TheFarm__InsufficientReceiptTokens();
    error TheFarm__InsufficientStakedAmount();
    error TheFarm__InsufficientRewardTokens();
    error TheFarm__TransferFailed();

    // Staking token (deposit token)
    IERC20 public immutable stakingToken;

    // Reward token (any ERC20 token)
    IERC20 public rewardToken;

    // Reward rate: 10 tokens per block
    uint256 public constant REWARD_RATE = 10 * 1e18;

    // Last block when rewards were calculated
    uint256 public lastRewardBlock;

    // Accumulated rewards per share (scaled by 1e18)
    uint256 public accRewardPerShare;

    // Total staked amount
    uint256 public totalStaked;

    // User staking info
    struct UserInfo {
        uint256 amount; // Amount staked
        uint256 rewardDebt; // Reward debt (for calculating pending rewards)
        uint256 pendingRewards; // Pending rewards to be claimed
    }

    mapping(address => UserInfo) public userInfo;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 receiptAmount);
    event Unstaked(address indexed user, uint256 amount, uint256 receiptAmount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);

    constructor(address _stakingToken, address _rewardToken, string memory receiptName, string memory receiptSymbol)
        ERC20(receiptName, receiptSymbol)
        Ownable(msg.sender)
    {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardBlock = block.number;
    }

    /**
     * @dev Update reward token (only owner)
     * @param _rewardToken New reward token address
     */
    function setRewardToken(address _rewardToken) external onlyOwner {
        if (_rewardToken == address(0)) revert TheFarm__InvalidRewardToken();
        address oldToken = address(rewardToken);
        rewardToken = IERC20(_rewardToken);
        emit RewardTokenUpdated(oldToken, _rewardToken);
    }

    /**
     * @dev Update reward variables
     */
    function updateReward() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksPassed = block.number - lastRewardBlock;
        uint256 reward = blocksPassed * REWARD_RATE;

        accRewardPerShare += (reward * 1e18) / totalStaked;
        lastRewardBlock = block.number;
    }

    /**
     * @dev Stake deposit tokens and receive receipt tokens
     * @param amount Amount of deposit tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert TheFarm__InvalidAmount();

        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards before updating user info
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
            user.pendingRewards += pending;
        }

        // Transfer staking tokens from user
        if (!stakingToken.transferFrom(msg.sender, address(this), amount)) {
            revert TheFarm__TransferFailed();
        }

        // Update user info
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        // Update total staked
        totalStaked += amount;

        // Mint receipt tokens (1:1 ratio)
        _mint(msg.sender, amount);

        emit Staked(msg.sender, amount, amount);
    }

    /**
     * @dev Unstake deposit tokens by burning receipt tokens
     * @param amount Amount of receipt tokens to burn (and deposit tokens to unstake)
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert TheFarm__InvalidAmount();
        if (balanceOf(msg.sender) < amount) revert TheFarm__InsufficientReceiptTokens();

        updateReward();

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount < amount) revert TheFarm__InsufficientStakedAmount();

        // Calculate pending rewards
        uint256 pending = (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
        user.pendingRewards += pending;

        // Update user info
        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        // Update total staked
        totalStaked -= amount;

        // Burn receipt tokens
        _burn(msg.sender, amount);

        // Transfer deposit tokens back to user
        if (!stakingToken.transfer(msg.sender, amount)) {
            revert TheFarm__TransferFailed();
        }

        emit Unstaked(msg.sender, amount, amount);
    }

    /**
     * @dev Claim pending rewards
     */
    function claimRewards() external nonReentrant {
        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards
        uint256 pending = (user.amount * accRewardPerShare) / 1e18 - user.rewardDebt;
        user.pendingRewards += pending;

        // Update reward debt
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e18;

        // Transfer rewards if any
        if (user.pendingRewards > 0) {
            uint256 rewardAmount = user.pendingRewards;
            user.pendingRewards = 0;

            // Ensure contract has enough reward tokens
            if (rewardToken.balanceOf(address(this)) < rewardAmount) {
                revert TheFarm__InsufficientRewardTokens();
            }

            if (!rewardToken.transfer(msg.sender, rewardAmount)) {
                revert TheFarm__TransferFailed();
            }
            emit RewardClaimed(msg.sender, rewardAmount);
        }
    }

    /**
     * @dev Get pending rewards for a user
     * @param user User address
     * @return Pending reward amount
     */
    function getPendingRewards(address user) external view returns (uint256) {
        UserInfo memory userData = userInfo[user];

        uint256 currentAccRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * REWARD_RATE;
            currentAccRewardPerShare += (reward * 1e18) / totalStaked;
        }

        uint256 pending = (userData.amount * currentAccRewardPerShare) / 1e18 - userData.rewardDebt;
        return userData.pendingRewards + pending;
    }

    /**
     * @dev Deposit reward tokens to the contract (for distribution)
     * @param amount Amount of reward tokens to deposit
     */
    function depositRewards(uint256 amount) external {
        if (amount == 0) revert TheFarm__InvalidAmount();
        if (!rewardToken.transferFrom(msg.sender, address(this), amount)) {
            revert TheFarm__TransferFailed();
        }
    }

    /**
     * @dev Emergency function to withdraw reward tokens (only owner)
     * @param amount Amount of reward tokens to withdraw
     */
    function emergencyWithdrawRewards(uint256 amount) external onlyOwner {
        if (!rewardToken.transfer(owner(), amount)) {
            revert TheFarm__TransferFailed();
        }
    }
}
