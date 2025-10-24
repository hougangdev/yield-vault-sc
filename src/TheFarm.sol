// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TheFarm
 * @dev MasterChef-style staking contract where users stake deposit tokens and earn rewards
 * @notice Users receive receipt tokens representing their stake and earn 10 reward tokens per block
 */
contract TheFarm is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error TheFarm__InvalidRewardToken();
    error TheFarm__InvalidAmount();
    error TheFarm__InsufficientReceiptTokens();
    error TheFarm__InsufficientStakedAmount();
    error TheFarm__InsufficientRewardTokens();
    error TheFarm__TransferFailed();
    error TheFarm__InvalidAddress();

    // Staking token (deposit token)
    IERC20 public immutable stakingToken;

    // Reward token (any ERC20 token)
    IERC20 public rewardToken;

    // Reward rate: 10 tokens per block
    uint256 public constant REWARD_RATE = 10 * 1e18;

    // Constants for precision calculations
    uint256 private constant PRECISION = 1e18;

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
    }

    mapping(address => UserInfo) public userInfo;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint256 amount, uint256 receiptAmount);
    event Unstaked(address indexed user, uint256 amount, uint256 receiptAmount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);
    event RewardsDeposited(uint256 indexed amount);
    event RewardsUpdated(uint256 indexed accRewardPerShare, uint256 indexed lastRewardBlock);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _stakingToken, address _rewardToken, string memory receiptName, string memory receiptSymbol)
        ERC20(receiptName, receiptSymbol)
        Ownable(msg.sender)
    {
        if (_stakingToken == address(0)) revert TheFarm__InvalidAddress();
        if (_rewardToken == address(0)) revert TheFarm__InvalidRewardToken();

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardBlock = block.number;
    }

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Update reward token (only owner)
     * @param rewardToken_ New reward token address
     */
    function setRewardToken(address rewardToken_) external onlyOwner {
        if (rewardToken_ == address(0)) revert TheFarm__InvalidRewardToken();
        address oldToken = address(rewardToken);
        rewardToken = IERC20(rewardToken_);
        emit RewardTokenUpdated(oldToken, rewardToken_);
    }

    /**
     * @dev Update reward variables (MasterChef pattern)
     * @notice This function updates the accumulated rewards per share
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

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardBlock = block.number;

        // Emit event for state change
        emit RewardsUpdated(accRewardPerShare, lastRewardBlock);
    }

    /**
     * @dev Stake deposit tokens and receive receipt tokens (MasterChef pattern)
     * @param amount Amount of deposit tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert TheFarm__InvalidAmount();

        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards before updating user info
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
            if (pending > 0) {
                // Transfer pending rewards to user
                if (rewardToken.balanceOf(address(this)) >= pending) {
                    rewardToken.safeTransfer(msg.sender, pending);
                    emit RewardClaimed(msg.sender, pending);
                }
            }
        }

        // Transfer staking tokens from user
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update user info
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

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
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        if (pending > 0) {
            // Transfer pending rewards to user
            if (rewardToken.balanceOf(address(this)) >= pending) {
                rewardToken.safeTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }

        // Update user info
        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

        // Update total staked
        totalStaked -= amount;

        // Burn receipt tokens
        _burn(msg.sender, amount);

        // Transfer deposit tokens back to user
        stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, amount);
    }

    /**
     * @dev Claim pending rewards (MasterChef pattern)
     */
    function claimRewards() external nonReentrant {
        updateReward();

        UserInfo storage user = userInfo[msg.sender];

        // Calculate pending rewards
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;

        if (pending > 0) {
            // Update reward debt
            user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;

            // Ensure contract has enough reward tokens
            if (rewardToken.balanceOf(address(this)) < pending) {
                revert TheFarm__InsufficientRewardTokens();
            }

            rewardToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }
    }

    /**
     * @dev Get pending rewards for a user (MasterChef pattern)
     * @param user User address
     * @return Pending reward amount
     */
    function getPendingRewards(address user) external view returns (uint256) {
        UserInfo memory userData = userInfo[user];

        uint256 currentAccRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * REWARD_RATE;
            currentAccRewardPerShare += (reward * PRECISION) / totalStaked;
        }

        uint256 pending = (userData.amount * currentAccRewardPerShare) / PRECISION - userData.rewardDebt;
        return pending;
    }

    /**
     * @dev Deposit reward tokens to the contract (for distribution)
     * @param amount Amount of reward tokens to deposit
     */
    function depositRewards(uint256 amount) external {
        if (amount == 0) revert TheFarm__InvalidAmount();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsDeposited(amount);
    }

    /**
     * @dev Emergency function to withdraw reward tokens (only owner)
     * @param amount Amount of reward tokens to withdraw
     */
    function emergencyWithdrawRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(owner(), amount);
    }

    /**
     * @dev Get contract's balance of reward tokens
     * @return Balance of reward tokens
     */
    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    /**
     * @dev Get contract's balance of staking tokens
     * @return Balance of staking tokens
     */
    function getStakingTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }
}
