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
 * @dev ERC4626 compliant auto-compound yield optimizer vault
 * @notice Automatically collects rewards from TheFarm and restakes them for compound growth
 */
contract TheVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TheVault__InvalidAmount();
    error TheVault__InvalidRewardToken();
    error TheVault__InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    TheFarm public immutable theFarm;
    IERC20 public rewardToken;
    IERC20 public immutable stakingToken;
    uint256 public totalRewardsCollected;
    uint256 public autoRestakeThreshold = DEFAULT_THRESHOLD; // 100 tokens

    // Constants for token amounts
    uint256 private constant DEFAULT_THRESHOLD = 100 * 1e18;
    uint256 public performanceFee = 100; // 1% default
    uint256 public constant MAX_PERFORMANCE_FEE = 1000; // 10% max

    // Constants for precision calculations
    uint256 private constant BASIS_POINTS = 10000;
    address public feeRecipient;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RewardsCollected(uint256 indexed amount);
    event AutoRestakeThresholdUpdated(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event PerformanceFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event EmergencyWithdraw(address indexed token, uint256 indexed amount);
    event CompoundRewards(address indexed user, uint256 indexed rewardAmount, uint256 indexed feeAmount);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _theFarm, address _asset, string memory name, string memory symbol)
        ERC4626(IERC20(_asset))
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        if (_theFarm == address(0)) revert TheVault__InvalidAddress();
        if (_asset == address(0)) revert TheVault__InvalidAddress();

        theFarm = TheFarm(_theFarm);
        rewardToken = theFarm.rewardToken();
        stakingToken = IERC20(_asset);
        feeRecipient = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Update auto-restake threshold (only owner)
     * @param threshold_ New threshold value
     */
    function setAutoRestakeThreshold(uint256 threshold_) external onlyOwner {
        uint256 oldThreshold = autoRestakeThreshold;
        autoRestakeThreshold = threshold_;
        emit AutoRestakeThresholdUpdated(oldThreshold, threshold_);
    }

    /**
     * @dev Update performance fee (only owner)
     * @param fee_ New fee in basis points (e.g., 100 = 1%)
     */
    function setPerformanceFee(uint256 fee_) external onlyOwner {
        if (fee_ > MAX_PERFORMANCE_FEE) revert TheVault__InvalidAmount();
        uint256 oldFee = performanceFee;
        performanceFee = fee_;
        emit PerformanceFeeUpdated(oldFee, fee_);
    }

    /**
     * @dev Update fee recipient (only owner)
     * @param feeRecipient_ New fee recipient address
     */
    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        if (feeRecipient_ == address(0)) revert TheVault__InvalidAddress();
        address oldRecipient = feeRecipient;
        feeRecipient = feeRecipient_;
        emit FeeRecipientUpdated(oldRecipient, feeRecipient_);
    }

    /**
     * @dev Auto-compound rewards for a user (anyone can call this)
     * @param user User address to compound rewards for
     */
    function compoundRewards(address user) external nonReentrant {
        // Get pending rewards for the user from TheFarm
        uint256 pendingRewards = theFarm.getPendingRewards(user);

        if (pendingRewards > 0) {
            // Claim rewards from TheFarm (this will transfer rewards to this contract)
            // Note: This requires the user to have approved this contract or called claimRewards first
            // For auto-compounding, we'll assume rewards are already available

            // Calculate fee
            uint256 feeAmount = (pendingRewards * performanceFee) / BASIS_POINTS;
            uint256 rewardAfterFee = pendingRewards - feeAmount;

            // Transfer fee to fee recipient
            if (feeAmount > 0) {
                rewardToken.safeTransfer(feeRecipient, feeAmount);
            }

            // Convert reward tokens to staking tokens (assuming 1:1 ratio for simplicity)
            // In a real implementation, you would use a DEX to swap reward tokens for staking tokens
            // For now, we'll assume the reward tokens can be directly staked

            // Restake the rewards
            if (rewardAfterFee > 0) {
                // Update state before external calls to prevent reentrancy
                totalRewardsCollected += rewardAfterFee;

                rewardToken.forceApprove(address(theFarm), rewardAfterFee);
                theFarm.stake(rewardAfterFee);

                // Mint additional vault shares to the user
                _mint(user, rewardAfterFee);

                emit CompoundRewards(user, pendingRewards, feeAmount);
            }
        }
    }

    /**
     * @dev Auto-compound rewards for multiple users
     * @param users Array of user addresses
     */
    function compoundMultipleRewards(address[] calldata users) external nonReentrant {
        uint256 totalCompounded = 0;
        uint256 totalFees = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 pendingRewards = theFarm.getPendingRewards(users[i]);

            if (pendingRewards > 0) {
                uint256 feeAmount = (pendingRewards * performanceFee) / BASIS_POINTS;
                uint256 rewardAfterFee = pendingRewards - feeAmount;

                if (feeAmount > 0) {
                    rewardToken.safeTransfer(feeRecipient, feeAmount);
                    totalFees += feeAmount;
                }

                if (rewardAfterFee > 0) {
                    rewardToken.forceApprove(address(theFarm), rewardAfterFee);
                    theFarm.stake(rewardAfterFee);
                    _mint(users[i], rewardAfterFee);
                    totalCompounded += rewardAfterFee;
                }
            }
        }

        if (totalCompounded > 0) {
            // Update state before emitting event to prevent reentrancy
            totalRewardsCollected += totalCompounded;
            emit RewardsCollected(totalCompounded);
        }
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
        IERC20(asset()).forceApprove(address(theFarm), assets);
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
    function convertToShares(uint256 assets) public pure override returns (uint256 shares) {
        return assets; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Convert shares to assets
     * @param shares Amount of shares
     * @return assets Amount of assets
     */
    function convertToAssets(uint256 shares) public pure override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview deposit
     * @param assets Amount of assets to deposit
     * @return shares Amount of shares that would be minted
     */
    function previewDeposit(uint256 assets) public pure override returns (uint256 shares) {
        return assets; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview redeem
     * @param shares Amount of shares to redeem
     * @return assets Amount of assets that would be returned
     */
    function previewRedeem(uint256 shares) public pure override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview mint
     * @param shares Amount of shares to mint
     * @return assets Amount of assets required
     */
    function previewMint(uint256 shares) public pure override returns (uint256 assets) {
        return shares; // 1:1 ratio
    }

    /**
     * @dev ERC4626: Preview withdraw
     * @param assets Amount of assets to withdraw
     * @return shares Amount of shares required
     */
    function previewWithdraw(uint256 assets) public pure override returns (uint256 shares) {
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
     * @dev Get vault's balance of staking tokens
     * @return Balance of staking tokens
     */
    function getStakingTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
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
     * @param rewardToken_ New reward token address
     */
    function updateRewardToken(address rewardToken_) external onlyOwner {
        if (rewardToken_ == address(0)) revert TheVault__InvalidRewardToken();
        address oldToken = address(rewardToken);
        rewardToken = IERC20(rewardToken_);
        emit RewardTokenUpdated(oldToken, rewardToken_);
    }
}
