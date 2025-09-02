#!/usr/bin/env bash

# This script works that way:
# Update channels, packages and garbage collect old builds
# Logs output and errors with timestamps to a defined directory

# Stop script on errors, undefined variables, or failed pipes
set -euo pipefail

SELF_FILE_NAME=$(basename "$0")

# Directory setup
BASE_DIR="$HOME/.local/state/nix-maintenance-operations"
LOGS_DIR="$BASE_DIR/logs"
GENERIC_LOGS_DIR="$LOGS_DIR/generic"
ERROR_LOGS_DIR="$LOGS_DIR/errors"

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
GENERIC_LOG_FILE="$GENERIC_LOGS_DIR/generic_$TIMESTAMP.log"
ERROR_LOG_FILE="$ERROR_LOGS_DIR/error_$TIMESTAMP.log"

mkdir -p "$GENERIC_LOGS_DIR" "$ERROR_LOGS_DIR"

# Color codes for terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
# No Color
NC='\033[0m'


# Timestamp helper
function timestamp() { date +'%Y-%m-%d %H:%M:%S'; }


# Logging helpers
function log_message() {
    printf "[%s] %s\n" "$(timestamp)" "$*" | tee -a "$GENERIC_LOG_FILE";
}

function log_success() {
    printf "${GREEN}[%s] %s${NC}\n" "$(timestamp)" "$*" | tee -a "$GENERIC_LOG_FILE";
}

function log_warning() {
    printf "${ORANGE}[%s] WARNING: %s${NC}\n" "$(timestamp)" "$*" | tee -a "$GENERIC_LOG_FILE";
}

function log_error() {
    printf printf "${RED}[%s] ERROR: %s${NC}\n" "$(timestamp)" "$*" | tee -a "$ERROR_LOG_FILE" >&2;
}


# -- Track script state --
SCRIPT_FAILED=false
# Flag for trap
SCRIPT_COMPLETED=false  


# Run commands safely
run_step() {
    local description="$1"
    shift
    log_message "$description..."
    if ! "$@"; then
        log_error "Failed: $description"
        SCRIPT_FAILED=true
    fi
}


# Trap only warns if script exits without reaching completion
trap 'if [ "$SCRIPT_COMPLETED" = false ] && [ "$SCRIPT_FAILED" = false ]; then log_warning "Script exited unexpectedly"; fi' EXIT


# Run maintenance operations
log_message "=== Nix maintenance operations started ==="

run_step "Updating Nix channels" nix-channel --update
run_step "Upgrading all user installed packages" nix-env -u '*'
run_step "Running garbage collection" nix-collect-garbage -d

# Script reached successful end
SCRIPT_COMPLETED=true
log_success "=== Nix maintenance operations completed ==="


# Desktop notifications
if [ "$SCRIPT_FAILED" = true ]; then
    notify-send "Nix maintenance operations FAILED!" "Check error log: $ERROR_LOG_FILE" || true
else
    notify-send "Nix maintenance operations completed successfully!" "Logs: $GENERIC_LOG_FILE" || true
fi
