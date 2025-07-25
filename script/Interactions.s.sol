// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import Foundry scripting base
import {Script} from "forge-std/Script.sol";
// Import Vault contract
import {Vault} from "../src/Vault.sol";

/// @title DepositScript
/// @notice Foundry script to deposit 0.01 ETH into a Vault contract
/// @dev Uses Foundry's vm scripting environment to simulate or broadcast transactions
contract DepositScript is Script {
    // Constant value to send during deposit (0.01 ETH)
    uint256 private constant SEND_VALUE = 0.01 ether;

    /**
     * @notice Deposits funds to the specified vault.
     * @param vault The address of the vault contract.
     */
    function depositFunds(address vault) public payable {
        Vault(payable(vault)).deposit{value: SEND_VALUE}();
    }

    /**
     * @notice Runs the deposit script.
     * @param vault The address of the vault contract.
     */
    function run(address vault) external payable {
        depositFunds(vault);
    }
}

/// @title RedeemScript
/// @notice Foundry script to redeem all available rebase tokens from a Vault
/// @dev Sends a redemption request for the caller’s full token balance

contract RedeemScript is Script {
    /**
     * @notice Redeems all tokens held by the caller from the Vault.
     * @dev Calls `redeem(type(uint256).max)` to signal full balance redemption.
     * @param vault The address of the deployed Vault contract.
     */
    function redeemFunds(address vault) public {
        // Redeem from the vault
        Vault(payable(vault)).redeem(type(uint256).max);
    }

    /**
     * @notice Entry point for the redeem script.
     * @dev Initiates redemption transaction using Foundry’s broadcast tools.
     * @param vault The address of the deployed Vault contract.
     */
    function run(address vault) external {
        redeemFunds(vault);
    }
}
