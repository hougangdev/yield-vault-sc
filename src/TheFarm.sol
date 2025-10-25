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
 *         In this implementation, rewardToken == stakingToken to support auto-compounding without swaps.
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
    error TheFarm__InvalidAddress();

    // Staking token (deposit token)
    IERC20 public immutable stakingToken;

    // Reward token (must equal staking token in this design)
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
        uint256 rewardDebt; // Reward debt
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
        // Enforce reward == staking token for auto-compound compatibility
        require(_stakingToken == _rewardToken, "Farm: reward must equal staking");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardBlock = block.number;
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Update reward token (must stay equal to stakingToken)
     */
    function setRewardToken(address rewardToken_) external onlyOwner {
        if (rewardToken_ == address(0)) revert TheFarm__InvalidRewardToken();
        require(rewardToken_ == address(stakingToken), "Farm: reward must equal staking");
        address oldToken = address(rewardToken);
        rewardToken = IERC20(rewardToken_);
        emit RewardTokenUpdated(oldToken, rewardToken_);
    }

    /**
     * @dev Deposit reward tokens to the contract (for distribution)
     */
    function depositRewards(uint256 amount) external {
        if (amount == 0) revert TheFarm__InvalidAmount();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsDeposited(amount);
    }

    /**
     * @dev Emergency function to withdraw reward tokens (only owner)
     */
    function emergencyWithdrawRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(owner(), amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Update reward variables (MasterChef pattern)
     */
    function updateReward() public {
        if (block.number <= lastRewardBlock) return;

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 blocksPassed = block.number - lastRewardBlock;
        uint256 reward = blocksPassed * REWARD_RATE;

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardBlock = block.number;

        emit RewardsUpdated(accRewardPerShare, lastRewardBlock);
    }

    /**
     * @dev Stake deposit tokens and receive receipt tokens (MasterChef pattern)
     */
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert TheFarm__InvalidAmount();

        updateReward();
        UserInfo storage user = userInfo[msg.sender];

        // Pay pending rewards first
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
            if (pending > 0 && rewardToken.balanceOf(address(this)) >= pending) {
                rewardToken.safeTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        totalStaked += amount;

        // Mint receipt tokens (1:1)
        _mint(msg.sender, amount);
        emit Staked(msg.sender, amount, amount);
    }

    /**
     * @dev Unstake by burning receipt tokens
     */
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert TheFarm__InvalidAmount();
        if (balanceOf(msg.sender) < amount) revert TheFarm__InsufficientReceiptTokens();

        updateReward();
        UserInfo storage user = userInfo[msg.sender];
        if (user.amount < amount) revert TheFarm__InsufficientStakedAmount();

        // Pay pending rewards
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        if (pending > 0 && rewardToken.balanceOf(address(this)) >= pending) {
            rewardToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }

        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        totalStaked -= amount;

        _burn(msg.sender, amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount, amount);
    }

    /**
     * @dev Claim pending rewards for msg.sender
     */
    function claimRewards() external nonReentrant {
        updateReward();
        UserInfo storage user = userInfo[msg.sender];

        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        if (pending == 0) return;

        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        if (rewardToken.balanceOf(address(this)) < pending) {
            revert TheFarm__InsufficientRewardTokens();
        }
        rewardToken.safeTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }

    /**
     * @dev View: pending rewards for user
     */
    function getPendingRewards(address userAddr) external view returns (uint256) {
        UserInfo memory user = userInfo[userAddr];

        uint256 currentAcc = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * REWARD_RATE;
            currentAcc += (reward * PRECISION) / totalStaked;
        }

        return (user.amount * currentAcc) / PRECISION - user.rewardDebt;
    }

    /**
     * @dev Convenience: underlying staking token balance held by the farm
     */
    function getStakingTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    /**
     * @dev Convenience: reward token balance held by the farm
     */
    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
}
