// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DepositToken
 * @dev ERC20 token used for staking in TheFarm contract
 * @notice This token can be minted and burned by authorized contracts
 */
contract DepositToken is ERC20, Ownable {
    // Custom errors
    error DepositToken__NotAuthorizedToMint();
    error DepositToken__NotAuthorizedToBurn();
    error DepositToken__InvalidAddress();
    error DepositToken__InvalidAmount();

    // Mapping to track authorized minters/burners
    mapping(address => bool) public authorizedMinters;

    // Events
    event AuthorizedMinter(address indexed minter, bool authorized);

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /**
     * @dev Authorize or revoke minting privileges for an address
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        if (minter == address(0)) revert DepositToken__InvalidAddress();
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinter(minter, authorized);
    }

    /**
     * @dev Mint tokens to a specific address
     */
    function mint(address to, uint256 amount) external {
        if (!authorizedMinters[msg.sender]) revert DepositToken__NotAuthorizedToMint();
        if (to == address(0)) revert DepositToken__InvalidAddress();
        if (amount == 0) revert DepositToken__InvalidAmount();
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from a specific address
     */
    function burn(address from, uint256 amount) external {
        if (!authorizedMinters[msg.sender]) revert DepositToken__NotAuthorizedToBurn();
        if (from == address(0)) revert DepositToken__InvalidAddress();
        if (amount == 0) revert DepositToken__InvalidAmount();
        _burn(from, amount);
    }

    /**
     * @dev Burn tokens from caller's balance
     */
    function burnFromSelf(uint256 amount) external {
        if (amount == 0) revert DepositToken__InvalidAmount();
        _burn(msg.sender, amount);
    }
}
