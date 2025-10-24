// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DepositToken
 * @dev ERC20 token used for staking in TheFarm contract
 * @notice This token can be minted and burned by authorized contracts
 */
contract DepositToken is ERC20, Ownable {
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
     * @param minter Address to authorize/revoke
     * @param authorized True to authorize, false to revoke
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinter(minter, authorized);
    }

    /**
     * @dev Mint tokens to a specific address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(authorizedMinters[msg.sender], "DepositToken: Not authorized to mint");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens from a specific address
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        require(authorizedMinters[msg.sender], "DepositToken: Not authorized to burn");
        _burn(from, amount);
    }

    /**
     * @dev Burn tokens from caller's balance
     * @param amount Amount of tokens to burn
     */
    function burnFromSelf(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
