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
 * @dev ERC4626-compliant auto-compound yield optimizer vault.
 * Users deposit the staking token; the vault stakes into TheFarm.
 * Rewards are harvested to the vault, fee taken, remainder restaked.
 * Share price rises with yield; no mint-on-harvest dilution.
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
                                 STATE
    //////////////////////////////////////////////////////////////*/
    TheFarm public immutable theFarm;
    IERC20 public immutable rewardToken; // == asset()
    IERC20 public immutable stakingToken; // == asset()

    // Performance fee in BPS (100 = 1%)
    uint256 public performanceFee = 100;
    uint256 public constant MAX_PERFORMANCE_FEE = 1000; // 10% max
    uint256 private constant BASIS_POINTS = 10000;
    address public feeRecipient;

    // Auto-compounding / keeper config
    bool public autoCompoundEnabled = true;
    uint256 public lastAutoCompoundBlock;
    uint256 public autoCompoundInterval = 100; // blocks
    uint256 public minCompoundAmount = 10 * 1e18; // tokens (wei)
    uint256 public maxCompoundGasPrice = 50 * 1e9; // 50 gwei

    mapping(address => bool) public authorizedKeepers;
    uint256 public keeperReward = 0.001 ether;
    uint256 public constant MAX_KEEPER_REWARD = 0.01 ether;

    // stats
    uint256 public totalRewardsCollected;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RewardsCollected(uint256 indexed amount);
    event PerformanceFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event EmergencyWithdraw(address indexed token, uint256 indexed amount);
    event AutoCompoundEnabled(bool indexed enabled);
    event AutoCompoundIntervalUpdated(uint256 indexed oldInterval, uint256 indexed newInterval);
    event MinCompoundAmountUpdated(uint256 indexed oldAmount, uint256 indexed newAmount);
    event MaxGasPriceUpdated(uint256 indexed oldPrice, uint256 indexed newPrice);
    event AutoCompoundExecuted(uint256 indexed totalCompounded, uint256 indexed blockNumber);
    event AutoCompoundSkipped(string indexed reason);
    event KeeperAuthorized(address indexed keeper, bool indexed authorized);
    event KeeperRewardUpdated(uint256 indexed oldReward, uint256 indexed newReward);
    event KeeperRewardPaid(address indexed keeper, uint256 indexed amount);
    event ETHDeposited(address indexed depositor, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _theFarm, address _asset, string memory name, string memory symbol)
        ERC4626(IERC20(_asset))
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        if (_theFarm == address(0) || _asset == address(0)) revert TheVault__InvalidAddress();

        theFarm = TheFarm(_theFarm);
        stakingToken = IERC20(_asset);

        // Reward must equal staking token to support restaking without swaps
        IERC20 _reward = theFarm.rewardToken();
        require(address(_reward) == _asset, "Vault: reward must equal asset");
        rewardToken = _reward;

        feeRecipient = msg.sender;
        lastAutoCompoundBlock = block.number;
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    function setPerformanceFee(uint256 fee_) external onlyOwner {
        if (fee_ > MAX_PERFORMANCE_FEE) revert TheVault__InvalidAmount();
        uint256 old = performanceFee;
        performanceFee = fee_;
        emit PerformanceFeeUpdated(old, fee_);
    }

    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        if (feeRecipient_ == address(0)) revert TheVault__InvalidAddress();
        address old = feeRecipient;
        feeRecipient = feeRecipient_;
        emit FeeRecipientUpdated(old, feeRecipient_);
    }

    function setAutoCompoundEnabled(bool enabled) external onlyOwner {
        autoCompoundEnabled = enabled;
        emit AutoCompoundEnabled(enabled);
    }

    function setAutoCompoundInterval(uint256 interval_) external onlyOwner {
        if (interval_ == 0) revert TheVault__InvalidAmount();
        uint256 old = autoCompoundInterval;
        autoCompoundInterval = interval_;
        emit AutoCompoundIntervalUpdated(old, interval_);
    }

    function setMinCompoundAmount(uint256 amount_) external onlyOwner {
        uint256 old = minCompoundAmount;
        minCompoundAmount = amount_;
        emit MinCompoundAmountUpdated(old, amount_);
    }

    function setMaxGasPrice(uint256 gasPrice_) external onlyOwner {
        uint256 old = maxCompoundGasPrice;
        maxCompoundGasPrice = gasPrice_;
        emit MaxGasPriceUpdated(old, gasPrice_);
    }

    function setKeeperAuthorization(address keeper, bool authorized) external onlyOwner {
        if (keeper == address(0)) revert TheVault__InvalidAddress();
        authorizedKeepers[keeper] = authorized;
        emit KeeperAuthorized(keeper, authorized);
    }

    function setKeeperReward(uint256 reward_) external onlyOwner {
        if (reward_ > MAX_KEEPER_REWARD) revert TheVault__InvalidAmount();
        uint256 old = keeperReward;
        keeperReward = reward_;
        emit KeeperRewardUpdated(old, reward_);
    }

    /**
     * @dev Deposit native token to fund keeper rewards
     */
    function depositETH() external payable {
        if (msg.value == 0) revert TheVault__InvalidAmount();
        emit ETHDeposited(msg.sender, msg.value);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        if (amount == 0 || amount > address(this).balance) revert TheVault__InvalidAmount();
        payable(owner()).transfer(amount);
    }

    /**
     * @dev Emergency token rescue (owner)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert TheVault__InvalidAddress();
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             ERC-4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Include staked funds in totalAssets by counting farm receipt tokens (1:1 with underlying)
     */
    function totalAssets() public view override returns (uint256) {
        // tokens idle in vault + tokens staked in farm (represented by farm receipt balance)
        return IERC20(asset()).balanceOf(address(this)) + theFarm.balanceOf(address(this));
    }

    /**
     * @dev Override _deposit to stake assets and trigger auto-compounding
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // Call parent implementation first
        super._deposit(caller, receiver, assets, shares);

        // Only stake if there are assets to stake
        if (assets > 0) {
            // Stake the deposited assets
            IERC20(asset()).forceApprove(address(theFarm), assets);
            theFarm.stake(assets);

            // Check and trigger auto-compounding
            _checkAndTriggerAutoCompound();
        }
    }

    /**
     * @dev Override _withdraw to unstake assets and trigger auto-compounding
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // Only unstake if there are assets to unstake
        if (assets > 0) {
            // Unstake before withdrawing
            theFarm.unstake(assets);

            // Check and trigger auto-compounding
            _checkAndTriggerAutoCompound();
        }

        // Call parent implementation
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                          COMPOUNDING / KEEPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Keeper entrypoint: harvest rewards -> take fee -> restake
     */
    function executeAutoCompound() external nonReentrant {
        if (!authorizedKeepers[msg.sender]) {
            emit AutoCompoundSkipped("Unauthorized keeper");
            return;
        }
        _compoundCore(true); // pay keeper if funded
    }

    /**
     * @dev Anyone can force compounding (no keeper reward)
     */
    function emergencyAutoCompound() external nonReentrant {
        _compoundCore(false);
    }

    /**
     * @dev Internal compound: runs checks, harvests, fees, restakes
     */
    function _compoundCore(bool payKeeper) internal {
        if (!autoCompoundEnabled) {
            emit AutoCompoundSkipped("Auto-compounding disabled");
            return;
        }
        if (block.number < lastAutoCompoundBlock + autoCompoundInterval) {
            emit AutoCompoundSkipped("Interval not reached");
            return;
        }
        if (maxCompoundGasPrice > 0 && tx.gasprice > maxCompoundGasPrice) {
            emit AutoCompoundSkipped("Gas price too high");
            return;
        }

        // 1) Harvest rewards owed to this vault from TheFarm
        theFarm.claimRewards();

        // 2) Use harvested reward balance (== asset)
        uint256 harvested = rewardToken.balanceOf(address(this));
        if (harvested < minCompoundAmount) {
            emit AutoCompoundSkipped("Insufficient rewards");
            return;
        }

        // 3) Take performance fee in tokens (simple)
        uint256 feeAmount = (harvested * performanceFee) / BASIS_POINTS;
        if (feeAmount > 0) {
            rewardToken.safeTransfer(feeRecipient, feeAmount);
        }

        // 4) Restake the remainder
        uint256 toStake = harvested - feeAmount;
        if (toStake > 0) {
            IERC20(asset()).forceApprove(address(theFarm), toStake);
            theFarm.stake(toStake);
            totalRewardsCollected += toStake;
            emit RewardsCollected(toStake);
        }

        lastAutoCompoundBlock = block.number;
        emit AutoCompoundExecuted(toStake, block.number);

        // 5) Pay keeper tip if requested and funded
        if (payKeeper && keeperReward > 0 && address(this).balance >= keeperReward) {
            payable(msg.sender).transfer(keeperReward);
            emit KeeperRewardPaid(msg.sender, keeperReward);
        }
    }

    /**
     * @dev Lightweight check for bots
     */
    function shouldExecuteAutoCompound() external view returns (bool shouldExecute, string memory reason) {
        if (!autoCompoundEnabled) return (false, "Auto-compounding disabled");
        if (block.number < lastAutoCompoundBlock + autoCompoundInterval) return (false, "Interval not reached");
        if (maxCompoundGasPrice > 0 && tx.gasprice > maxCompoundGasPrice) return (false, "Gas price too high");

        // simulate post-harvest balance by reading current; keeper can call even if 0 then skip
        uint256 bal = rewardToken.balanceOf(address(this));
        if (bal < minCompoundAmount) return (false, "Insufficient rewards");

        return (true, "Ready to execute");
    }

    /**
     * @dev Internal opportunistic trigger (called after deposit/withdraw)
     */
    function _checkAndTriggerAutoCompound() internal {
        if (!autoCompoundEnabled) return;
        if (block.number < lastAutoCompoundBlock + autoCompoundInterval) return;
        if (maxCompoundGasPrice > 0 && tx.gasprice > maxCompoundGasPrice) return;

        // Note: harvest can be expensive; we only attempt if current balance >= min threshold
        // (You could also attempt to harvest here, but that affects UX; keeping it conservative.)
        if (rewardToken.balanceOf(address(this)) < minCompoundAmount) return;

        // do not pay keeper on internal triggers
        _compoundCore(false);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getAutoCompoundStatus()
        external
        view
        returns (
            bool enabled,
            uint256 lastBlock,
            uint256 interval,
            uint256 minAmount,
            uint256 maxGasPrice,
            uint256 blocksUntilNext
        )
    {
        enabled = autoCompoundEnabled;
        lastBlock = lastAutoCompoundBlock;
        interval = autoCompoundInterval;
        minAmount = minCompoundAmount;
        maxGasPrice = maxCompoundGasPrice;

        blocksUntilNext = block.number >= lastAutoCompoundBlock + autoCompoundInterval
            ? 0
            : (lastAutoCompoundBlock + autoCompoundInterval) - block.number;
    }

    function getNextAutoCompoundBlock() external view returns (uint256) {
        return lastAutoCompoundBlock + autoCompoundInterval;
    }

    function getTotalRewardsCollected() external view returns (uint256) {
        return totalRewardsCollected;
    }

    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function getStakingTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }
}
