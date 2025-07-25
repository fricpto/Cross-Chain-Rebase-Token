// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IRebaseToken.sol";

/// @title Vault Contract
/// @author fricpto
/// @notice Accepts ETH deposits and mints interest-bearing rebase tokens in exchange.
/// @dev This contract integrates with a rebasing ERC20 token, allowing users to deposit ETH and receive a matching amount of rebase tokens.
/// Users can later redeem those tokens for ETH. The contract can also receive external ETH as rewards.

contract Vault {
    // Pass the token contract to the constructor
    // create a deposit function that mints tokens to the user that is equal to the amount of ETH the user has sent
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create a way to add rewards to the vault
    /// @notice The rebase token contract used for minting and burning
    IRebaseToken private immutable i_rebaseToken;

    /// @notice Emitted when a user deposits ETH into the Vault
    /// @param user The address of the user who deposited
    /// @param amount The amount of ETH deposited
    event Deposit(address indexed user, uint256 amount);
    /// @notice Emitted when a user redeems their rebase tokens for ETH
    /// @param user The address of the user who redeemed
    /// @param amount The amount of ETH redeemed
    event Redeem(address indexed user, uint256 amount);
    /// @notice Thrown when the ETH transfer during redemption fails

    error Vault__RedeemFailed();

    /// @notice Constructs the Vault with a reference to the rebasing token contract
    /// @param _rebaseToken The address of the rebasing token contract

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    // allows the contract to receive rewards
    /// @notice Fallback function to accept ETH (e.g. for rewards or manual funding)
    /// @dev Enables the contract to receive ETH directly (used for reward injection)

    receive() external payable {}

    /// @notice Allows users to deposit ETH and mint an equivalent amount of rebase tokens
    /// @dev Mints tokens using the current interest rate from the rebase token contract
    /// Emits a {Deposit} event
    function deposit() external payable {
        // Mint tokens to sender, equal to the ETH sent, using current interest rate
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Redeems rebase tokens for an equivalent amount of ETH
    /// @dev Burns the sender's tokens and sends ETH back
    /// @param _amount The amount of tokens to redeem. Use `type(uint256).max` to redeem the full balance.
    /// Emits a {Redeem} event

    /**
     * @dev redeems rebase token for the underlying asset
     * @param _amount the amount being redeemed
     *
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn the rebase tokens from sender
        i_rebaseToken.burn(msg.sender, _amount);
        // executes redeem of the underlying asset
        // Attempt to send ETH back to the user
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /// @notice Returns the address of the rebase token associated with this Vault
    /// @return The address of the rebase token

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
