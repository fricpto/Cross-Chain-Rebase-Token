// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Token Deployment and Configuration Scripts
 * @dev Foundry scripts for deploying and configuring CCIP-compatible rebase tokens and related infrastructure
 *
 * @notice This file contains multiple scripts that:
 * - Deploy core components (tokens, pools, vaults)
 * - Configure CCIP admin registries
 * - Set up permissioned roles
 *
 * Scripts are designed for use with Chainlink's CCIP Local Simulator environment
 */
contract TokenAndPoolDeployer is Script {
    /**
     * @dev Deploys core token infrastructure
     * @return rebaseToken Deployed RebaseToken contract
     * @return rebaseTokenPool Deployed RebaseTokenPool contract
     *
     * @notice Performs:
     * 1. Gets current network details from CCIP simulator
     * 2. Deploys new RebaseToken
     * 3. Deploys RebaseTokenPool connected to:
     *    - The deployed token
     *    - CCIP Router
     *    - RMN Proxy
     *
     * @dev Role assignments and registry configurations are handled in separate scripts
     */
    function run() public returns (RebaseToken rebaseToken, RebaseTokenPool rebaseTokenPool) {
        // Initialize CCIP local simulator environment
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        // Deploy rebaseable token
        rebaseToken = new RebaseToken();
        // Deploy token pool connected to CCIP infrastructure
        rebaseTokenPool = new RebaseTokenPool(
            IERC20(address(rebaseToken)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        // NOTE: Role assignments commented out - use separate role scripts
        // rebaseToken.grantMintAndBurnRole(address(rebaseTokenPool));

        // RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(rebaseToken));
        // TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(rebaseToken));
        // TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(rebaseToken), address(rebaseTokenPool));
        vm.stopBroadcast();
        return (rebaseToken, rebaseTokenPool);
    }
}
/**
 * @title Role Configuration Script
 * @dev Grants mint/burn role to token pool
 */

contract SetRole is Script {
    function run(address _rebaseToken, address _rebaseTokenPool) public {
        grantRole(_rebaseToken, _rebaseTokenPool);
    }
    /**
     * @dev Main execution function
     * @dev Internal implementation of role granting
     * @param _rebaseToken Address of the RebaseToken contract
     * @param _rebaseTokenPool Address of the token pool contract
     */

    function grantRole(address _rebaseToken, address _rebaseTokenPool) public {
        vm.startBroadcast();
        // Grant pool minting/burning privileges on token
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(_rebaseTokenPool));
        vm.stopBroadcast();
    }
}

/**
 * @title Registry Admin Registration Script
 * @dev Registers token as admin in CCIP registry module
 */
contract SetRegistryModuleOwnerCustom is Script {
    /**
     * @dev Main execution function
     * @param _rebaseToken Address of the token contract to register
     */
    function run(address _rebaseToken) public {
        setRegistryModuleOwnerCustom(_rebaseToken);
    }

    /**
     * @dev Internal implementation of admin registration
     * @param _rebaseToken Token contract to register as admin
     */
    function setRegistryModuleOwnerCustom(address _rebaseToken) public {
        // Get current CCIP network configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        // IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(_rebaseTokenPool));
        // Register token contract as admin via owner privileges
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(_rebaseToken)
        );
        // TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(_rebaseToken));
        // TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(_rebaseToken), address(_rebaseTokenPool));
        vm.stopBroadcast();
    }
}

/**
 * @title Admin Role Acceptance Script
 * @dev Completes admin role acceptance in token admin registry
 */
contract SetTokenAdminRegistryToAcceptAdminRole is Script {
    /**
     * @dev Main execution function
     * @param _rebaseToken Token contract accepting admin role
     */
    function run(address _rebaseToken) public {
        acceptAdminRole(_rebaseToken);
    }

    /**
     * @dev Internal implementation of role acceptance
     * @param _rebaseToken Token contract accepting the role
     */
    function acceptAdminRole(address _rebaseToken) public {
        // Get current CCIP network configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        // Finalize admin role acceptance in registry
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(_rebaseToken));
        vm.stopBroadcast();
    }
}

/**
 * @title Pool Registration Script
 * @dev Links token pool to token in admin registry
 */
contract SetTokenAdminRegistryToSetPool is Script {
    /**
     * @dev Main execution function
     * @param _rebaseToken Token contract address
     * @param _rebaseTokenPool Token pool address
     */
    function run(address _rebaseToken, address _rebaseTokenPool) public {
        setPool(_rebaseToken, _rebaseTokenPool);
    }

    /**
     * @dev Internal implementation of pool registration
     * @param _rebaseToken Token contract address
     * @param _rebaseTokenPool Pool contract address
     */
    function setPool(address _rebaseToken, address _rebaseTokenPool) public {
        // Get current CCIP network configuration
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        // Register token pool for specified token
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(_rebaseToken), address(_rebaseTokenPool)
        );
        vm.stopBroadcast();
    }
}

/**
 * @title Vault Deployment Script
 * @dev Deploys vault contract and configures token permissions
 */
contract VaultDeployer is Script {
    /**
     * @dev Deploys and configures a new vault
     * @param _iRebaseToken Address of the rebase token contract
     * @return vault Newly deployed Vault contract
     */
    function run(address _iRebaseToken) public returns (Vault vault) {
        // Deploy vault connected to token
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_iRebaseToken));
        // Grant vault mint/burn privileges on token
        IRebaseToken(_iRebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
