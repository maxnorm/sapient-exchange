# Sapient Exchange

Sapient Exchange is a decentralized exchange (DEX) that allows users to trade cryptocurrencies. 

It is built on top of the Facet-Based Diamond System. ([EIP-8153](https://eips.ethereum.org/EIPS/eip-8153))

**Docs:** [compose.diamonds](https://compose.diamonds) · [Foundry book](https://book.getfoundry.sh/)

## Prerequisites

[Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil).

## Quick start

```bash
git clone <repo> && cd sapient-exchange
forge build
forge test
```

## Commands

```bash
# Build
forge build

# Test
forge test

# Format
forge fmt

# Gas snapshots
forge snapshot

# Local node (run in another terminal for local deploy)
anvil

# Deploy (local: start anvil first)
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url http://127.0.0.1:8545 --broadcast

# Deploy (live)
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast

# Verify deployment (read-only)
forge script script/VerifyDeployment.s.sol:VerifyDeployment --rpc-url <RPC_URL>
```
