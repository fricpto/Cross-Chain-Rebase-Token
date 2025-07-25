# **Cross-Chain Rebase Token**
## 🌉 **Overview**

This project implements a cross-chain rebase token that allows users to deposit ETH in exchange for rebase tokens whose balances increase over time. These tokens are:

* **Time-based rebasing**: User balances grow linearly with time.

* **Action-triggered minting**: Rebase updates are triggered by user actions like depositing, transferring, redeeming, or bridging.

* **Cross-chain enabled**: Built with Chainlink CCIP, allowing token transfers across chains.

* **Incentivized early adoption**: Interest rates decrease over time, rewarding users who deposit or bridge earlier.

## 💸 **Interest Rate Mechanics**
* Each user’s deposit gets **locked into the global interest rate** at the time of entry.

* Interest rates are **individualized per user** but derived from a global rate.

* The **global interest rate only decreases**, promoting early deposits and early bridging.

* Bridging "locks in" your interest rate—your high yield follows you, even if the protocol rate drops later.

* Rebase tokens **do not accrue yield during bridging**.

* All **deposits/withdrawals happen only on L1**.



# 🛠 Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - Confirm with: git --version
- [foundry](https://getfoundry.sh/)
  - Confirm with: forge --version

## Quickstart

```
git clone https://github.com/fricpto/Cross-Chain-Rebase-Token
cd Cross-Chain-Rebase-Token
forge build
```


# 🚀 Usage
## Start a Local Node

```bash
anvil
```

# Deploy Locally

In another terminal:

```bash
forge script script/Deployer.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

## Deploy to Testnet/Mainnet

[Deployment to a Testnet or Mainnet](#deployment-to-a-testnet-or-mainnet)

## 🧪 **Testing**

```
forge test
```

### Code Coverage
```bash
forge coverage
forge coverage --report debug
```
# 🌐 Deployment to a Testnet or Mainnet

## 1. Setup environment variables

* Create a **.env** file based on **.env**.example with:

* **PRIVATE_KEY:** Your wallet's private key (preferably one with no real funds — for development only).

* **SEPOLIA_RPC_URL**: A Sepolia testnet RPC URL (get one from [Alchemy](https://alchemy.com/?a=673c802981)).

* Optionally, **ETHERSCAN_API_KEY** to verify contracts on Etherscan.

## 2. Get testnet ETH

Use  [faucets.chain.link](https://faucets.chain.link/) to get Sepolia ETH.

## 3. Deploy

```bash
forge script script/Deployer.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key <your_private_key> --broadcast
```

# 🔁 **Automated Bridge Setup: `bridgeToZksync.sh`**

You can use the provided script `bridgeToZksync.sh` to **automate the full cross-chain deployment and configuration** between **Sepolia Ethereum** and **zkSync Era Testnet** using **Chainlink CCIP**.

## ✅ What It Does
🧱 **zkSync Deployment**:
* Deploys `RebaseToken`

* Deploys `RebaseTokenPool` with CCIP integration

* Grants `mint/burn` roles to the pool

* Configures CCIP roles and registry

🧱 **Sepolia Deployment**:
* Deploys `RebaseToken` and `TokenPool` using Foundry scripts

* Grants permissions and registers CCIP config

* Deploys and funds the `Vault` contract

🔗 **Cross-Chain Setup**:
* Links the two pools (Sepolia ↔ zkSync)

* Configures rate limiters for inbound/outbound traffic

* Establishes Chainlink chain selectors

🚀 **Bridging Execution**:
* Initiates a token transfer from Sepolia → zkSync
* Verifies balances before and after bridge

🔧 **Technical Details**
* Uses Foundry for smart contract deployment

* Uses `cast` for CLI-based interactions

* Fully integrated with **Chainlink CCIP**

* Supports zkSync-specific flags (**--zksync**, **--legacy**)

* Handles **ERC-20** and **native ETH** bridging

* Automates address parsing and flag passing

## 🌐 Network Specs

- **zkSync Era Testnet**:

  - Chain Selector: **6898391096552792247**

  - CCIP Router: **0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16**

  - LINK Token: **0x23A1aFD896c8c8876AF46aDc38521f4432658d1e**

- **Sepolia Testnet**:

  - Chain Selector: **16015286601757825753**

  - CCIP Router: **0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59**

  - LINK Token: **0x779877A7B0D9E8603169DdbD7836e478b4624789**

## 🧪 Workflow Summary
**1.** Deploy contracts on zkSync

**2.** Deploy contracts on Sepolia

**3.** Configure cross-chain CCIP registry & limiters

**4.** Fund vault with ETH

**5.** Execute bridge transfer

**6.** Verify balances post-bridge

# ⛽ Gas Estimation
```bash
forge snapshot
```
See `.gas-snapshot` for results.

# 🧼 Formatting
```bash
forge fmt
```

# 📌 Design Assumptions
* Interest rates are locked at deposit time

* Global interest rate only decreases

* Bridging freezes rebase accrual

* Must manually bridge interest delta back to L1

* Users can only deposit and withdraw on L1

