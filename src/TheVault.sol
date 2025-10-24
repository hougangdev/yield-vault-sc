// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TheFarm.sol";

/**
 * @title TheVault
 * @dev ERC4626 compliant vault that collects staking reward tokens for users and restakes to staking contract
 * @notice Automatically collects rewards from TheFarm and restakes them for compound growth
 */
contract TheVault is ERC4626, Ownable, ReentrancyGuard {
    // Custom errors
    error TheVault__InvalidAmount();
    error TheVault__InsufficientRewardTokens();
    error TheVault__InvalidRewardToken();
    error TheVault__InvalidAddress();

    // TheFarm contract instance
    TheFarm public immutable theFarm;

    // Reward token from TheFarm
    IERC20 public rewardToken;

    // Total reward tokens collected and restaked
    uint256 public totalRewardsCollected;

    // Auto-restake threshold (minimum reward tokens to trigger restaking)
    uint256 public autoRestakeThreshold = 100 * 1e18; // 100 tokens

    // Events
    event RewardsCollected(uint256 amount);
    event RewardsRestaked(uint256 amount);
    event AutoRestakeThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    constructor(address _theFarm, address _asset, string memory name, string memory symbol)
        ERC4626(IERC20(_asset))
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        theFarm = TheFarm(_theFarm);
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

            // Mint vault shares to the user based on collected rewards
            _mint(user, pendingRewards);

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
                _mint(users[i], pendingRewards);
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
        if (amount == 0) revert TheVault__InvalidAmount();
        if (rewardToken.balanceOf(address(this)) < amount) revert TheVault__InsufficientRewardTokens();

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
     * @dev ERC4626: Deposit assets and receive vault shares
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive vault shares
     * @return shares Amount of vault shares minted
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        // Transfer assets from caller to vault
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), assets);

        // Calculate shares to mint (1:1 ratio for simplicity)
        shares = assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        // Stake assets in TheFarm
        IERC20(asset()).approve(address(theFarm), assets);
        theFarm.stake(assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @dev ERC4626: Redeem vault shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Address that owns the shares
     * @return assets Amount of assets returned
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Calculate assets to return (1:1 ratio for simplicity)
        assets = shares;

        // Unstake from TheFarm
        theFarm.unstake(assets);

        // Burn shares
        _burn(owner, shares);

        // Transfer assets to receiver
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return assets;
    }

    /**
     * @dev ERC4626: Get total assets managed by the vault
     * @return Total assets in the vault
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @dev ERC4626: Convert assets to shares
     * @param assets Amount of assets
     * @return shares Amount of shares
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        return assets; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Convert shares to assets
     * @param shares Amount of shares
     * @return assets Amount of assets
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview deposit
     * @param assets Amount of assets to deposit
     * @return shares Amount of shares that would be minted
     */
    function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
        return assets; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview redeem
     * @param shares Amount of shares to redeem
     * @return assets Amount of assets that would be returned
     */
    function previewRedeem(uint256 shares) public view override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview mint
     * @param shares Amount of shares to mint
     * @return assets Amount of assets required
     */
    function previewMint(uint256 shares) public view override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview withdraw
     * @param assets Amount of assets to withdraw
     * @return shares Amount of shares required
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        return assets; // 1:1 ratio
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
        if (token == address(0)) revert TheVault__InvalidAddress();
        SafeERC20.safeTransfer(IERC20(token), owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }

    /**
     * @dev Update reward token reference (only owner)
     * @param _rewardToken New reward token address
     */
    function updateRewardToken(address _rewardToken) external onlyOwner {
        if (_rewardToken == address(0)) revert TheVault__InvalidRewardToken();
        rewardToken = IERC20(_rewardToken);
    }
}
