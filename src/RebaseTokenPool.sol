// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import base TokenPool contract from Chainlink's CCIP
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
// Import Pool struct definitions
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
// Interface for interacting with a rebasing token (custom token interface)
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
// Standard ERC20 interface
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
// ERC20 implementation
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title RebaseTokenPool
/// @author fricpto
/// @notice A CCIP-compatible TokenPool for rebasing tokens that burns on the source chain and mints on the destination chain
/// @dev Interacts with a custom IRebaseToken to track and transfer user interest rate across chains

contract RebaseTokenPool is TokenPool {
    /// @notice Constructor for RebaseTokenPool
    /// @param token The ERC20-compatible token (rebasing) to be used in the pool
    /// @param allowlist Array of allowed sender addresses
    /// @param rmnProxy Address of the RMN (Routing Message Network) proxy
    /// @param router Address of the CCIP router
    constructor(IERC20 token, address[] memory allowlist, address rmnProxy, address router)
        TokenPool(token, 18, allowlist, rmnProxy, router)
    {}

    /// @notice Locks or burns tokens on the source chain for cross-chain transfer
    /// @dev Burns the tokens and retrieves the user's interest rate to pass to the destination chain
    /// @param lockOrBurnIn Struct containing the sender, amount, and remote chain info
    /// @return lockOrBurnOut Struct with destination token and encoded user interest rate

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        // Perform base validation from TokenPool
        _validateLockOrBurn(lockOrBurnIn);
        // Get the user's current interest rate from the rebasing token before burning
        // Burn the tokens on the source chain. This returns their userAccumulatedInterest before the tokens were burned (in case all tokens were burned, we don't want to send 0 cross-chain)
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        // Burn the specified amount of tokens from this contract (previously transferred here via approval)
        //uint256 currentInterestRate = IRebaseToken(address(i_token)).getInterestRate();
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount); // CCIP works like this: do token approval,send tokens to CCIP,CCIP will send the tokens to the token pool
        // Prepare data for the destination chain:
        // - Address of destination token (mapped to remoteChainSelector)
        // - Encoded userInterestRate for accurate minting
        // encode a function call to pass the caller's info to the destination pool and update it
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /// @notice Releases or mints tokens on the destination chain after cross-chain transfer
    /// @dev Decodes interest rate from the source chain and mints rebasing tokens to the receiver
    /// @param releaseOrMintIn Struct containing amount, receiver address, and source pool data
    /// @return Struct with final minted/released amount on the destination chain

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        // Validate the input using base contract logic
        _validateReleaseOrMint(releaseOrMintIn);
        address receiver = releaseOrMintIn.receiver;
        // Decode the interest rate passed from the source chain
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        // Mint the tokens to the receiver with the original interest rate
        // Mint rebasing tokens to the receiver on the destination chain
        // This will also mint any interest that has accrued since the last time the user's balance was updated.
        IRebaseToken(address(i_token)).mint(receiver, releaseOrMintIn.amount, userInterestRate);
        // Return output with minted token amount (same as input amount)
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
