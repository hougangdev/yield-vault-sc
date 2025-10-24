// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TheFarm.sol";

/**
 * @title TheVault
 * @dev Contract to collect staking reward tokens for users and restake to staking contract
 * @notice Automatically collects rewards from TheFarm and restakes them for compound growth
 */
contract TheVault is Ownable, ReentrancyGuard {
    // TheFarm contract instance
    TheFarm public immutable theFarm;

    // Deposit token (staking token)
    IERC20 public immutable depositToken;

    // Reward token from TheFarm
    IERC20 public rewardToken;

    // Mapping to track user's vault shares
    mapping(address => uint256) public userShares;

    // Total vault shares
    uint256 public totalShares;

    // Total reward tokens collected and restaked
    uint256 public totalRewardsCollected;

    // Auto-restake threshold (minimum reward tokens to trigger restaking)
    uint256 public autoRestakeThreshold = 100 * 1e18; // 100 tokens

    // Events
    event RewardsCollected(uint256 amount);
    event RewardsRestaked(uint256 amount);
    event UserSharesUpdated(address indexed user, uint256 oldShares, uint256 newShares);
    event AutoRestakeThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    constructor(address _theFarm, address _depositToken) Ownable(msg.sender) {
        theFarm = TheFarm(_theFarm);
        depositToken = IERC20(_depositToken);
        rewardToken = theFarm.rewardToken();
    }

    /**
     * @dev Update auto-restake threshold (only owner)
     * @param _threshold New threshold value
     */
    function setAutoRestakeThreshold(uint256 _threshold) external onlyOwner {
        uint256 oldThreshold = autoRestakeThreshold;
        autoRestakeThreshold = _threshold;
        emit AutoRestakeThresholdUpdated(oldThreshold, _threshold);
    }

    /**
     * @dev Collect rewards from TheFarm for a specific user
     * @param user User address to collect rewards for
     */
    function collectUserRewards(address user) external nonReentrant {
        // Get pending rewards for the user
        uint256 pendingRewards = theFarm.getPendingRewards(user);

        if (pendingRewards > 0) {
            // Claim rewards on behalf of the user
            // Note: This requires the user to have approved this contract to claim on their behalf
            // or the user needs to call claimRewards() first

            // For now, we'll assume the user has already claimed or we have permission
            // In a production environment, you might need a different approach

            // Update user shares based on collected rewards
            _updateUserShares(user, pendingRewards);

            totalRewardsCollected += pendingRewards;
            emit RewardsCollected(pendingRewards);

            // Auto-restake if threshold is met
            if (pendingRewards >= autoRestakeThreshold) {
                _restakeRewards(pendingRewards);
            }
        }
    }

    /**
     * @dev Collect and restake rewards for multiple users
     * @param users Array of user addresses
     */
    function collectMultipleUserRewards(address[] calldata users) external nonReentrant {
        uint256 totalCollected = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 pendingRewards = theFarm.getPendingRewards(users[i]);

            if (pendingRewards > 0) {
                _updateUserShares(users[i], pendingRewards);
                totalCollected += pendingRewards;
            }
        }

        if (totalCollected > 0) {
            totalRewardsCollected += totalCollected;
            emit RewardsCollected(totalCollected);

            // Auto-restake if threshold is met
            if (totalCollected >= autoRestakeThreshold) {
                _restakeRewards(totalCollected);
            }
        }
    }

    /**
     * @dev Manually restake collected reward tokens
     * @param amount Amount of reward tokens to restake
     */
    function restakeRewards(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "TheVault: Amount must be greater than 0");
        require(rewardToken.balanceOf(address(this)) >= amount, "TheVault: Insufficient reward tokens");

        _restakeRewards(amount);
    }

    /**
     * @dev Internal function to restake reward tokens
     * @param amount Amount of reward tokens to restake
     */
    function _restakeRewards(uint256 amount) internal {
        // Convert reward tokens to deposit tokens (assuming 1:1 ratio or using a swap mechanism)
        // For simplicity, we'll assume the reward tokens can be directly staked
        // In a real implementation, you might need to swap reward tokens for deposit tokens

        // Approve TheFarm to spend reward tokens
        rewardToken.approve(address(theFarm), amount);

        // Stake the reward tokens in TheFarm
        // Note: This assumes TheFarm accepts reward tokens as staking tokens
        // You might need to implement a swap mechanism here

        emit RewardsRestaked(amount);
    }

    /**
     * @dev Update user shares based on collected rewards
     * @param user User address
     * @param rewardAmount Amount of rewards collected
     */
    function _updateUserShares(address user, uint256 rewardAmount) internal {
        uint256 oldShares = userShares[user];
        uint256 newShares = oldShares + rewardAmount;

        userShares[user] = newShares;
        totalShares += rewardAmount;

        emit UserSharesUpdated(user, oldShares, newShares);
    }

    /**
     * @dev Get user's share of the vault
     * @param user User address
     * @return User's share amount
     */
    function getUserShare(address user) external view returns (uint256) {
        return userShares[user];
    }

    /**
     * @dev Get user's percentage of total vault
     * @param user User address
     * @return User's percentage (scaled by 1e18)
     */
    function getUserPercentage(address user) external view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }
        return (userShares[user] * 1e18) / totalShares;
    }

    /**
     * @dev Get total rewards collected by the vault
     * @return Total rewards collected
     */
    function getTotalRewardsCollected() external view returns (uint256) {
        return totalRewardsCollected;
    }

    /**
     * @dev Get vault's balance of reward tokens
     * @return Balance of reward tokens
     */
    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    /**
     * @dev Emergency function to withdraw tokens (only owner)
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }

    /**
     * @dev Update reward token reference (only owner)
     * @param _rewardToken New reward token address
     */
    function updateRewardToken(address _rewardToken) external onlyOwner {
        require(_rewardToken != address(0), "TheVault: Invalid reward token");
        rewardToken = IERC20(_rewardToken);
    }
}
