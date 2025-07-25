// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// Import Foundry scripting tools
import {Script} from "forge-std/Script.sol";
// Chainlink CCIP router interface for sending messages
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
// Structs and message formatting utilities for CCIP
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
// ERC20 token interface
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

/// @title BridgeTokensScript
/// @notice A Foundry script for bridging ERC20 tokens across EVM-compatible chains using Chainlink CCIP
/// @dev Uses Chainlink CCIP's IRouterClient and EVM2AnyMessage structure to send cross-chain token messages

contract BridgeTokensScript is Script {
    /// @notice Executes the cross-chain token bridge using CCIP
    /// @dev Builds the EVM2AnyMessage, estimates the fee, approves tokens, and sends the message
    /// @param receiverAddress Address to receive tokens on the destination chain
    /// @param destinationChainSelector Chain selector ID of the destination chain (from CCIP registry)
    /// @param tokenToSendAddress ERC20 token address to send
    /// @param amountToSend Amount of tokens to send
    /// @param linkTokenAddress Address of the LINK token (used for paying CCIP fees)
    /// @param routerAddress Address of the CCIP router contract
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        // Prepare the token amounts array for the message (only one token in this case)
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSendAddress, amount: amountToSend});
        // Start broadcasting transactions (Foundry VM command)
        vm.startBroadcast();
        // Construct the CCIP message to send cross-chain
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress), // receiver address on destination chain
            data: "", // no additional calldata
            tokenAmounts: tokenAmounts, // array of tokens to send
            feeToken: linkTokenAddress, // LINK token to pay the fee
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) // additional arguments (gas limit) gas limit left as 0 (default, may be overridden)
        });
        // Estimate the CCIP fee required for sending the message
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        // Approve LINK tokens for fee payment to the CCIP router
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        // Approve the ERC20 tokens to be sent to the CCIP router
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        // Send the CCIP message with tokens
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        // Stop broadcasting
        vm.stopBroadcast();
    }
}
