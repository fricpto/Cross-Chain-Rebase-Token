// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// Foundry's scripting utility
import {Script} from "forge-std/Script.sol";
// Chainlink CCIP TokenPool contract
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
// CCIP rate limiter library for configuring rate limiting
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

/// @title ConfigurePoolScript
/// @notice A Foundry script to configure a CCIP TokenPool with a remote pool and rate limiter settings
/// @dev This script sets up the remote pool mapping and optional rate limits for inbound and outbound messages

contract ConfigurePoolScript is Script {
    /// @notice Executes the configuration of a TokenPool by registering a remote pool and token
    /// @dev Applies rate limiting settings using Chainlink's RateLimiter library
    /// @param localPool The address of the TokenPool contract to configure
    /// @param remoteChainSelector The CCIP selector ID of the remote chain
    /// @param remotePool The address of the remote TokenPool on the destination chain
    /// @param remoteToken The address of the corresponding token on the destination chain
    /// @param outboundRateLimiterIsEnabled Whether outbound rate limiting should be enabled
    /// @param outboundRateLimiterCapacity Maximum allowed outbound capacity
    /// @param outboundRateLimiterRate Rate at which outbound capacity refills
    /// @param inboundRateLimiterIsEnabled Whether inbound rate limiting should be enabled
    /// @param inboundRateLimiterCapacity Maximum allowed inbound capacity
    /// @param inboundRateLimiterRate Rate at which inbound capacity refills
    /**
     * @notice Performs these operations:
     * 1. Prepares chain configuration update
     * 2. Configures rate limiter parameters
     * 3. Applies updates to the TokenPool contract
     */
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outboundRateLimiterIsEnabled,
        uint128 outboundRateLimiterCapacity,
        uint128 outboundRateLimiterRate,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        // Begin broadcast to simulate a transaction (Foundry-specific)
        vm.startBroadcast();
        // Prepare chain configuration update - adding one chain configuration
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        // Encode remote pool address for CCIP compatibility
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        // Populate chain configuration parameters
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteToken),
            // Outbound rate limiter config (local -> remote)
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }),
            // Inbound rate limiter config (remote -> local)
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });

        // Prepare empty removal list (no chains being removed in this update)
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        TokenPool(localPool).applyChainUpdates(remoteChainSelectorsToRemove, chainsToAdd);
        // Stop broadcasting after configuration
        vm.stopBroadcast();
    }
}
