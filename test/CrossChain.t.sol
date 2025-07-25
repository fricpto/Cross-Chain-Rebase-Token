// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {console, Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

// Tests to include
// Test you can bridge tokens - check the balance is correct
// test you can bridge a portion of tokens - check balances are correct
// test you can bridge and then bridge back all balance - check balances
// test you can bridge and then bridge back a portion - check balances

contract CrossChainTest is Test {
    uint256 private sepoliaFork;
    uint256 private arbSepoliaFork;
    uint256 private SEND_VALUE = 1e5;

    CCIPLocalSimulatorFork private ccipLocalSimulatorFork;
    RebaseTokenPool private sepoliaPool;
    RebaseTokenPool private arbSepoliaPool;
    RebaseToken private sepoliaToken;
    RebaseToken private arbSepoliaToken;
    Vault private vault;
    address private alice = makeAddr("alice");
    address private owner = makeAddr("owner");
    Register.NetworkDetails private sepoliaNetworkDetails;
    Register.NetworkDetails private arbSepoliaNetworkDetails;

    function setUp() public {
        // 1. Setup the Sepolia and arb forks
        sepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        // vm.makePersistent is used to make the ccipLocalSimulatorFork address persistent across forks
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        //  Register.NetworkDetails is a struct that stores network details (such as chain selector, router address, link address, wrapped native address, or CCIP test tokens), and getNetworkDetails pulls network details based on chain IDs
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        // 2. Deploy and configure on the source chain: Sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        // deploy the vault

        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        // add rewards to the vault
        // vm.deal(address(vault), 1e18);
        // Set pool on the token contract for permissions on Sepolia
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        sepoliaToken.grantMintAndBurnRole(address(vault));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        // Link token to pool in the token admin registry on Sepolia
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaPool)
        );
        vm.stopPrank();

        // 3. Deploy and configure on the destination chain: Arbitrum
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        // Set pool on the token contract for permissions on Arbitrum
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken)
        );
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        // Link token to pool in the token admin registry on arb-Sepolia
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );
        vm.stopPrank();
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    )
        /*         Register.NetworkDetails memory remoteNetworkDetails */
        public
    {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(address(remotePool));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        TokenPool(localPool).applyChainUpdates(remoteChainSelectorsToRemove, chains);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remote
    ) public {
        vm.selectFork(localFork);
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(alice), // abi.encode(receiver address) for dest EVM chains
            data: "", // Data payload We don't need any data for this example
            tokenAmounts: tokenAmounts, // Token transfers  this needs to be of type EVMTokenAmount[] as you could send multiple tokens
            feeToken: localNetworkDetails.linkAddress, // Address of feeToken. address(0) means you will send msg.value.The token used to pay for the fee
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: false})) // Populate this with _argsToBytes(EVMExtraArgsV2) We don't need any extra args for this example
        });
        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(alice, fee);
        vm.prank(alice);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(alice);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(alice);
        vm.prank(alice);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(alice);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        // uint256 localUserInterestRate = localToken.getUserInterestRate(alice);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceBefore = remote.balanceOf(alice);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remote.balanceOf(alice);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        // uint256 remoteUserInterestRate = remote.getUserInterestRate(alice);
        // assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(alice, SEND_VALUE);
        vm.prank(alice);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(alice), SEND_VALUE);
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );
        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            arbSepoliaToken.balanceOf(alice),
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaToken,
            sepoliaToken
        );
    }
}
