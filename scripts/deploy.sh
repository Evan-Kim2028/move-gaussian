#!/usr/bin/env bash
#
# deploy.sh - Sui Move Package Deployment Script for Gaussian
#
# Usage:
#   ./scripts/deploy.sh [testnet|mainnet|devnet]
#
# Prerequisites:
#   - Sui CLI installed and configured
#   - Wallet with sufficient SUI balance
#   - Package builds successfully
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOYMENTS_DIR="$PACKAGE_DIR/deployments"

# Default network
NETWORK="${1:-testnet}"

# Gas budget (in MIST, 1 SUI = 10^9 MIST)
GAS_BUDGET="${GAS_BUDGET:-100000000}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

confirm() {
    read -r -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check Sui CLI
    if ! command -v sui &> /dev/null; then
        log_error "Sui CLI not found. Please install it first."
        exit 1
    fi
    
    SUI_VERSION=$(sui --version)
    log_info "Sui CLI version: $SUI_VERSION"
    
    # Check current environment
    CURRENT_ENV=$(sui client active-env 2>/dev/null || echo "unknown")
    log_info "Current environment: $CURRENT_ENV"
    
    # Check active address
    ACTIVE_ADDRESS=$(sui client active-address 2>/dev/null || echo "unknown")
    log_info "Active address: $ACTIVE_ADDRESS"
    
    # Check balance
    log_info "Checking balance..."
    sui client gas
    
    echo ""
}

# =============================================================================
# Switch Network
# =============================================================================

switch_network() {
    log_info "Switching to $NETWORK network..."
    
    case "$NETWORK" in
        testnet)
            RPC_URL="https://fullnode.testnet.sui.io:443"
            ;;
        mainnet)
            RPC_URL="https://fullnode.mainnet.sui.io:443"
            ;;
        devnet)
            RPC_URL="https://fullnode.devnet.sui.io:443"
            ;;
        *)
            log_error "Unknown network: $NETWORK. Use testnet, mainnet, or devnet."
            exit 1
            ;;
    esac
    
    # Check if environment exists, create if not
    if ! sui client envs 2>/dev/null | grep -q "$NETWORK"; then
        log_info "Creating $NETWORK environment..."
        sui client new-env --alias "$NETWORK" --rpc "$RPC_URL"
    fi
    
    # Switch to the network
    sui client switch --env "$NETWORK"
    log_success "Switched to $NETWORK"
    
    echo ""
}

# =============================================================================
# Build Package
# =============================================================================

build_package() {
    log_info "Building package..."
    cd "$PACKAGE_DIR"
    
    if sui move build; then
        log_success "Build successful"
    else
        log_error "Build failed"
        exit 1
    fi
    
    echo ""
}

# =============================================================================
# Run Tests
# =============================================================================

run_tests() {
    log_info "Running tests..."
    cd "$PACKAGE_DIR"
    
    if sui move test; then
        log_success "All tests passed"
    else
        log_error "Tests failed"
        if ! confirm "Tests failed. Continue with deployment anyway?"; then
            exit 1
        fi
    fi
    
    echo ""
}

# =============================================================================
# Deploy Package
# =============================================================================

deploy_package() {
    log_info "Deploying to $NETWORK..."
    cd "$PACKAGE_DIR"
    
    # Show deployment summary
    echo ""
    echo "=============================================="
    echo "  DEPLOYMENT SUMMARY"
    echo "=============================================="
    echo "  Network:     $NETWORK"
    echo "  Package:     gaussian"
    echo "  Gas Budget:  $GAS_BUDGET MIST"
    echo "  Deployer:    $(sui client active-address)"
    echo "=============================================="
    echo ""
    
    # Mainnet requires extra confirmation
    if [ "$NETWORK" = "mainnet" ]; then
        log_warning "⚠️  You are about to deploy to MAINNET!"
        log_warning "⚠️  This will use REAL SUI tokens!"
        if ! confirm "Are you absolutely sure you want to continue?"; then
            log_info "Deployment cancelled."
            exit 0
        fi
    else
        if ! confirm "Proceed with deployment?"; then
            log_info "Deployment cancelled."
            exit 0
        fi
    fi
    
    # Perform deployment
    log_info "Publishing package..."
    
    DEPLOY_OUTPUT=$(sui client publish --gas-budget "$GAS_BUDGET" --json 2>&1) || {
        log_error "Deployment failed!"
        echo "$DEPLOY_OUTPUT"
        exit 1
    }
    
    log_success "Deployment successful!"
    
    # Parse and display results
    echo ""
    echo "=============================================="
    echo "  DEPLOYMENT RESULTS"
    echo "=============================================="
    echo "$DEPLOY_OUTPUT" | jq -r '
        "  Transaction Digest: \(.digest)",
        "  Package ID: \(.objectChanges[] | select(.type == "published") | .packageId)",
        "  Upgrade Cap: \(.objectChanges[] | select(.objectType | contains("UpgradeCap")) | .objectId)"
    ' 2>/dev/null || echo "$DEPLOY_OUTPUT"
    echo "=============================================="
    
    # Save deployment record
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    DEPLOYMENT_FILE="$DEPLOYMENTS_DIR/${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
    
    echo "$DEPLOY_OUTPUT" | jq --arg network "$NETWORK" --arg timestamp "$TIMESTAMP" --arg sui_version "$SUI_VERSION" '
    {
        network: $network,
        package_id: (.objectChanges[] | select(.type == "published") | .packageId),
        upgrade_cap_id: (.objectChanges[] | select(.objectType | contains("UpgradeCap")) | .objectId),
        transaction_digest: .digest,
        deployer_address: .transaction.data.sender,
        deployed_at: $timestamp,
        sui_version: $sui_version,
        gas_used: .effects.gasUsed,
        raw_output: .
    }' > "$DEPLOYMENT_FILE" 2>/dev/null || {
        log_warning "Could not parse deployment output to JSON"
        echo "$DEPLOY_OUTPUT" > "$DEPLOYMENT_FILE"
    }
    
    log_success "Deployment record saved to: $DEPLOYMENT_FILE"
    log_warning "Remember: This file contains deployment info - don't commit to public repos!"
    
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          Gaussian Package Deployment Script               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    preflight_checks
    switch_network
    build_package
    run_tests
    deploy_package
    
    log_success "🎉 Deployment complete!"
    echo ""
}

main "$@"
