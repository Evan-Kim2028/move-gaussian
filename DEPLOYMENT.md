# Gaussian Package Deployment Guide

This guide covers deploying the Gaussian package to Sui networks (testnet, devnet, mainnet).

## 📋 Prerequisites

### 1. Install Sui CLI

```bash
# Check if installed
sui --version

# If not installed, see: https://docs.sui.io/guides/developer/getting-started/sui-install
```

### 2. Create a Development Wallet

**⚠️ IMPORTANT: Use separate addresses for testnet vs mainnet!**

```bash
# Create a dedicated testnet wallet
sui client new-address ed25519 gaussian-testnet

# Save the recovery phrase securely (offline!)
# Switch to this address
sui client switch --address gaussian-testnet
```

### 3. Configure Testnet Environment

```bash
# Add testnet environment (if not exists)
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443

# Switch to testnet
sui client switch --env testnet

# Verify
sui client active-env      # Should show: testnet
sui client active-address  # Your testnet address
```

### 4. Get Testnet SUI

```bash
# Request tokens from faucet
sui client faucet

# Verify balance (need ~0.1 SUI for deployment)
sui client gas
```

---

## 🚀 Deployment Methods

### Method 1: Using the Deploy Script (Recommended)

```bash
cd packages/gaussian

# Deploy to testnet (default)
./scripts/deploy.sh testnet

# Deploy to devnet
./scripts/deploy.sh devnet

# Deploy to mainnet (requires extra confirmation)
./scripts/deploy.sh mainnet
```

The script will:
1. Run pre-flight checks (CLI version, balance, etc.)
2. Switch to the correct network
3. Build the package
4. Run all tests
5. Deploy with confirmation
6. Save deployment record to `deployments/`

### Method 2: Manual Deployment

```bash
cd packages/gaussian

# 1. Build
sui move build

# 2. Test
sui move test

# 3. Deploy
sui client publish --gas-budget 100000000
```

**Save the output!** It contains your Package ID and UpgradeCap.

---

## 📦 Post-Deployment

### Save Deployment Information

After deployment, save these critical values:

| Field | Description | Example |
|-------|-------------|---------|
| Package ID | Your deployed package address | `0x123...abc` |
| UpgradeCap ID | Required for future upgrades | `0x456...def` |
| Transaction Digest | Deployment transaction hash | `ABC123...` |

### Verify Deployment

```bash
# Check package exists
sui client object <PACKAGE_ID>

# View on explorer
# Testnet: https://testnet.suivision.xyz/package/<PACKAGE_ID>
# Mainnet: https://suivision.xyz/package/<PACKAGE_ID>
```

### Test Deployed Functions

```bash
# Call a function (example)
sui client call \
  --package <PACKAGE_ID> \
  --module gaussian \
  --function <FUNCTION_NAME> \
  --args <ARGS> \
  --gas-budget 10000000
```

---

## 🔐 Pre-Deployment Checklist

### Before Deployment

- [ ] Using a **dedicated testnet/devnet address** (not mainnet!)
- [ ] Recovery phrase stored **offline** securely
- [ ] No private keys in source code
- [ ] `.gitignore` includes all sensitive files
- [ ] All tests passing

### For Mainnet Deployment

- [ ] Thorough testing on testnet first
- [ ] Using a **separate mainnet-only address**
- [ ] UpgradeCap stored securely (controls future upgrades!)
- [ ] Deployment record backed up

---

## 🔑 Key Management

### View Your Keys

```bash
# List all addresses
sui client addresses

# Export private key (Bech32 format)
sui keytool export --key-identity <ADDRESS_OR_ALIAS>
```

### Import a Key

```bash
# Import from suiprivkey format
sui keytool import <PRIVATE_KEY> ed25519
```

### Key Storage Locations

| File | Location | Contains |
|------|----------|----------|
| Keystore | `~/.sui/sui_config/sui.keystore` | All private keys |
| Config | `~/.sui/sui_config/client.yaml` | Network configs, active address |

---

## 🔄 Upgrading the Package

If you have the UpgradeCap, you can upgrade:

```bash
sui client upgrade \
  --upgrade-capability <UPGRADE_CAP_ID> \
  --gas-budget 100000000
```

**Note:** Keep UpgradeCap secure - whoever controls it can modify the package!

---

## 🐛 Troubleshooting

### "Insufficient gas" error
```bash
# Get more testnet SUI
sui client faucet

# Or increase gas budget
sui client publish --gas-budget 200000000
```

### "Object not found" error
- Ensure you're on the correct network
- Verify the object ID is correct

### Build errors
```bash
# Clean build
rm -rf build/
sui move build
```

### Network connection issues
```bash
# Check current environment
sui client envs

# Re-add the environment
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
```

---

## 📚 Resources

- [Sui Documentation](https://docs.sui.io/)
- [Sui CLI Reference](https://docs.sui.io/references/cli)
- [Move Book](https://move-book.com/)
- [Sui Explorer (Testnet)](https://testnet.suivision.xyz/)
- [Sui Explorer (Mainnet)](https://suivision.xyz/)
- [Sui Discord - #devnet-faucet](https://discord.gg/sui)

---

## 📝 Deployment History

Deployment records are stored in `deployments/` directory (gitignored for security).

Use `deployments/template.json` as a reference for the format.
