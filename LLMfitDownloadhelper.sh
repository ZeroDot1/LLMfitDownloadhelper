#!/usr/bin/env bash
# ==============================================================================
# Application:   LLMfitDownloadhelper
# Author:        ZeroDot1
# Version:       1.6
# Platform:      Universal (Arch Linux & Ubuntu compatible)
# License:       GNU AGPLv3 (https://gnu.org)
#
# Copyright (C) 2026 ZeroDot1
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
VERSION="1.6"
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
LLMFIT_LIMIT="${LLMFIT_LIMIT:-500}"

# ------------------------------------------------------------------------------
# TUI Color Palette
# ------------------------------------------------------------------------------
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------
error_exit() {
    echo -e "${RED}${BOLD}Error:${NC} $*" >&2
    exit 1
}

info() {
    echo -e "${BLUE}::${NC} $*"
}

warn() {
    echo -e "${YELLOW}!!${NC} $*"
}

success() {
    echo -e "${GREEN}==>${NC} $*"
}

cleanup() {
    # Placeholder for future cleanup tasks
    true
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------

# System requires Bash 4+ (for `pipefail`)
if (( BASH_VERSINFO[0] < 4 )); then
    error_exit "This script requires Bash 4 or newer (found: ${BASH_VERSION})."
fi

# Export Ollama host
export OLLAMA_HOST

# Check: fzf
if ! command -v fzf &> /dev/null; then
    error_exit "'fzf' is not installed.
  Install it with:
    Arch Linux:  ${CYAN}sudo pacman -S fzf${NC}
    Ubuntu:      ${CYAN}sudo apt install fzf${NC}"
fi

# Check: llmfit
if ! command -v llmfit &> /dev/null; then
    error_exit "'llmfit' is not installed.
  Install it with:
    ${CYAN}curl -fsSL https://llmfit.axjns.dev/install.sh | sh${NC}
    or via Cargo: ${CYAN}cargo install llmfit${NC}"
fi

# ------------------------------------------------------------------------------
# Start Ollama service (if needed)
# ------------------------------------------------------------------------------
# Wait until ollama responds to HTTP requests (max 15 seconds)
wait_for_ollama() {
    local retries=15
    local i
    for i in $(seq 1 "${retries}"); do
        if curl --silent --fail --max-time 2 "${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
            return 0
        fi
        if [[ "${i}" -lt "${retries}" ]]; then
            sleep 1
        fi
    done
    return 1
}

ensure_ollama_running() {
    # Check if ollama is already responding
    if wait_for_ollama; then
        return 0
    fi

    warn "Ollama service is not responding. Attempting to start it …"

    # Strategy 1: user systemd (without sudo)
    if command -v systemctl &> /dev/null; then
        # Try direct start of user service (fails fast if not present)
        systemctl --user start ollama.service 2>/dev/null || true
        if wait_for_ollama; then
            return 0
        fi

        # Strategy 2: systemd with sudo (non-interactive)
        if sudo -n systemctl start ollama 2>/dev/null; then
            if wait_for_ollama; then
                return 0
            fi
        fi

        # Strategy 3: sudo with password (interactive)
        warn "Attempting to start ollama with sudo (password may be required) …"
        sudo systemctl start ollama 2>&1 || true
        if wait_for_ollama; then
            return 0
        fi
    fi

    # Strategy 4: Direct start (if ollama binary is available)
    if command -v ollama &> /dev/null; then
        warn "Starting ollama directly (without systemd) …"
        ollama serve &> /dev/null &
        if wait_for_ollama; then
            return 0
        fi
    fi

    error_exit "Could not start ollama. Please start the service manually:
  ${CYAN}sudo systemctl start ollama${NC}
  or
  ${CYAN}ollama serve${NC}"
}

# ------------------------------------------------------------------------------
# Main program
# ------------------------------------------------------------------------------
clear
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BOLD}${CYAN}  LLMfitDownloadhelper ${NC}v${VERSION} | ${GREEN}Author: ZeroDot1${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Database update with extended model list
info "Updating llmfit database (extended model list) …"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
llmfit update --limit "${LLMFIT_LIMIT}"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo ""

# 2. Sorting selection menu
echo -e "${BOLD}${CYAN}Select your preferred sorting criteria:${NC}"
echo -e " [1] Newest models first (by release date)"
echo -e " [2] Largest text output first (by context window)"
echo -e " [3] Recommended best fit (by system score)"
echo -e " [4] Maximum speed (by tokens/second)"
echo -e " [5] Quit"
echo ""
echo -n "Choice [1-5]: "
read -r CHOICE

SORT_CRITERIA="score"
HEADER_MSG="Auto-Detected Hardware Fit"

case "${CHOICE}" in
    1)
        SORT_CRITERIA="date"
        HEADER_MSG="Sorted by date (newest first) | Full matrix"
        ;;
    2)
        SORT_CRITERIA="ctx"
        HEADER_MSG="Sorted by context window (largest first) | Full matrix"
        ;;
    3)
        SORT_CRITERIA="score"
        HEADER_MSG="Sorted by system score (best fit first) | Full matrix"
        ;;
    4)
        SORT_CRITERIA="tps"
        HEADER_MSG="Sorted by speed (tokens/s first) | Full matrix"
        ;;
    5|*)
        echo -e "\n${YELLOW}Exiting application.${NC}"
        exit 0
        ;;
esac

echo ""
info "Analyzing local hardware and generating matrix …"

# 3. llmfit query with hardware auto-detection and user sorting
MODEL_DATA="$(llmfit fit --sort "${SORT_CRITERIA}" --cli --limit "${LLMFIT_LIMIT}" 2>/dev/null || true)"

if [[ -z "${MODEL_DATA}" ]]; then
    warn "No optimal matrix found. Loading system fit list …"
    MODEL_DATA="$(llmfit list 2>/dev/null || true)"
fi

if [[ -z "${MODEL_DATA}" ]]; then
    error_exit "llmfit could not determine hardware metrics."
fi

# 4. Interactive TUI with fzf
success "Arrow keys to navigate, type to filter. [ENTER] to download & start:"
echo ""

SELECTED_LINE="$(echo "${MODEL_DATA}" | fzf \
    --ansi \
    --no-sort \
    --header="LLMfitDownloadhelper v${VERSION} | ${HEADER_MSG}" \
    --prompt="Search model > " \
    --border=rounded \
    --height=75% \
    --layout=reverse \
    --query="ollama")"

if [[ -z "${SELECTED_LINE}" ]]; then
    echo -e "\n${YELLOW}Selection canceled.${NC}"
    exit 0
fi

# 5. Extract model identifier from table row
MODEL_NAME="$(echo "${SELECTED_LINE}" | awk -F'│' '{print $2}' | xargs 2>/dev/null || true)"

if [[ -z "${MODEL_NAME}" || "${MODEL_NAME}" == "Name" ]]; then
    MODEL_NAME="$(echo "${SELECTED_LINE}" | awk '{print $1}' | sed 's/│//g' | xargs)"
fi

# Only allow alphanumeric characters, colons, dots, underscores, and hyphens
MODEL_NAME="$(echo "${MODEL_NAME}" | sed 's/[^a-zA-Z0-9:._-]//g' | awk '{print $1}')"

if [[ -z "${MODEL_NAME}" || "${MODEL_NAME}" == "Name" ]]; then
    error_exit "Could not extract a valid model identifier."
fi

# 6. Start ollama (if needed) and pull & run the model
ensure_ollama_running

clear
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BOLD}${GREEN}  Downloading & starting inference for: ${YELLOW}${MODEL_NAME}${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

exec ollama run "${MODEL_NAME}"
