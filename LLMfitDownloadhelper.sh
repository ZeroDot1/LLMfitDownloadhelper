#!/usr/bin/env bash
# ==============================================================================
# Application:   LLMfitDownloadhelper
# Author:        ZeroDot1
# Version:       1.8
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
# Configuration (all overridable via environment variables)
# ------------------------------------------------------------------------------
VERSION="1.8"
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
LLMFIT_LIMIT="${LLMFIT_LIMIT:-10000}"
LLMFIT_PERFECT="${LLMFIT_PERFECT:-false}"
LLMFIT_TOOL_USE="${LLMFIT_TOOL_USE:-false}"
LLMFIT_NO_DASHBOARD="${LLMFIT_NO_DASHBOARD:-true}"
LLMFIT_MEMORY="${LLMFIT_MEMORY:-}"
LLMFIT_RAM="${LLMFIT_RAM:-}"
LLMFIT_CPU_CORES="${LLMFIT_CPU_CORES:-}"
LLMFIT_MAX_CONTEXT="${LLMFIT_MAX_CONTEXT:-}"

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
# Build extra CLI arguments from environment variables
# ------------------------------------------------------------------------------
# Arguments valid for ALL llmfit subcommands (update, fit, …)
build_global_args() {
    local args=()
    if [[ "${LLMFIT_NO_DASHBOARD}" == "true" ]]; then
        args+=(--no-dashboard)
    fi
    echo "${args[@]}"
}

# Arguments valid ONLY for `llmfit fit`
build_fit_args() {
    local args=()
    if [[ "${LLMFIT_PERFECT}" == "true" ]]; then
        args+=(--perfect)
    fi
    if [[ "${LLMFIT_TOOL_USE}" == "true" ]]; then
        args+=(--tool-use)
    fi
    if [[ -n "${LLMFIT_MEMORY}" ]]; then
        args+=(--memory "${LLMFIT_MEMORY}")
    fi
    if [[ -n "${LLMFIT_RAM}" ]]; then
        args+=(--ram "${LLMFIT_RAM}")
    fi
    if [[ -n "${LLMFIT_CPU_CORES}" ]]; then
        args+=(--cpu-cores "${LLMFIT_CPU_CORES}")
    fi
    if [[ -n "${LLMFIT_MAX_CONTEXT}" ]]; then
        args+=(--max-context "${LLMFIT_MAX_CONTEXT}")
    fi
    echo "${args[@]}"
}

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
# Manage installed models (list / delete)
# ------------------------------------------------------------------------------
manage_installed_models() {
    ensure_ollama_running
    while true; do
        clear
        echo -e "${BLUE}======================================================================${NC}"
        echo -e "${BOLD}${CYAN}  Manage Installed Models${NC}"
        echo -e "${BLUE}======================================================================${NC}"
        echo ""
        
        # Get models with header
        local list_output
        list_output=$(ollama list)
        
        # Check if empty (only header line)
        if [[ $(echo "${list_output}" | wc -l) -le 1 ]]; then
            info "No models are currently installed in Ollama."
            echo ""
            echo -e "${YELLOW}Press ENTER to return to main menu...${NC}"
            read -r _
            break
        fi
        
        echo -e "${BOLD}Installed Models:${NC}"
        echo "${list_output}"
        echo ""
        echo -e "${BOLD}${CYAN}Select an action:${NC}"
        echo -e " [1] Delete a specific model"
        echo -e " [2] Delete ALL models"
        echo -e " [3] Return to main menu"
        echo ""
        echo -n "Choice [1-3]: "
        read -r SUB_CHOICE
        
        case "${SUB_CHOICE}" in
            1)
                # Show list in fzf to select one to delete
                local selection
                selection=$(echo "${list_output}" | tail -n +2 | fzf \
                    --header="Select a model to DELETE (ESC to cancel)" \
                    --prompt="Select model > " \
                    --border=rounded \
                    --height=50% \
                    --layout=reverse)
                
                if [[ -n "${selection}" ]]; then
                    local model_to_delete
                    model_to_delete=$(echo "${selection}" | awk '{print $1}')
                    local confirm
                    confirm=$(echo -e "No, cancel deletion\nYes, delete model" | fzf \
                        --header="WARNING: Are you sure you want to delete ${model_to_delete}?" \
                        --prompt="Confirm deletion > " \
                        --border=rounded \
                        --height=15% \
                        --layout=reverse)
                    
                    if [[ "${confirm}" == "Yes, delete model" ]]; then
                        info "Deleting ${model_to_delete} ..."
                        ollama rm "${model_to_delete}"
                        success "Model deleted successfully."
                        sleep 1.5
                    else
                        info "Deletion cancelled."
                        sleep 1
                    fi
                fi
                ;;
            2)
                local confirm
                confirm=$(echo -e "No, keep all models\nYes, delete ALL models" | fzf \
                    --header="DANGER: Are you absolutely sure you want to delete ALL installed models?" \
                    --prompt="Confirm wipe > " \
                    --border=rounded \
                    --height=15% \
                    --layout=reverse)
                
                if [[ "${confirm}" == "Yes, delete ALL models" ]]; then
                    local model_name
                    echo "${list_output}" | tail -n +2 | awk '{print $1}' | while read -r model_name; do
                        if [[ -n "${model_name}" ]]; then
                            info "Deleting ${model_name} ..."
                            ollama rm "${model_name}"
                        fi
                    done
                    success "All models deleted."
                    sleep 2
                else
                    info "Deletion cancelled."
                    sleep 1
                fi
                ;;
            3|*)
                break
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Filter by tag (category) helper
# ------------------------------------------------------------------------------
LLMFIT_TAG_FILTER=""

select_tag_filter() {
    while true; do
        clear
        echo -e "${BLUE}======================================================================${NC}"
        echo -e "${BOLD}${CYAN}  Filter Models by Tag / Category${NC}"
        echo -e "${BLUE}======================================================================${NC}"
        echo ""
        local current_tag="${LLMFIT_TAG_FILTER:-None (Show all compatible models)}"
        echo -e "${BOLD}Current filter:${NC} ${YELLOW}${current_tag}${NC}"
        echo ""
        echo -e " [1] Coding          (Code generation, completion, etc.)"
        echo -e " [2] Vision          (Multimodal, Vision-Language models)"
        echo -e " [3] Reasoning       (Advanced reasoning, R1, step-by-step)"
        echo -e " [4] Audio / Speech  (Transcription, audio understanding)"
        echo -e " [5] General / Chat  (General purpose, instruct models)"
        echo -e " [6] Clear filter    (Show all compatible models)"
        echo -e " [7] Return to main menu"
        echo ""
        echo -n "Choice [1-7]: "
        read -r TAG_CHOICE
        
        case "${TAG_CHOICE}" in
            1) LLMFIT_TAG_FILTER="coding" ;;
            2) LLMFIT_TAG_FILTER="vision" ;;
            3) LLMFIT_TAG_FILTER="reasoning" ;;
            4) LLMFIT_TAG_FILTER="audio" ;;
            5) LLMFIT_TAG_FILTER="general" ;;
            6) LLMFIT_TAG_FILTER="" ;;
            7|*) break ;;
        esac
        success "Filter set to: ${LLMFIT_TAG_FILTER:-None}"
        sleep 1
        break
    done
}

# ------------------------------------------------------------------------------
# Self-update function
# ------------------------------------------------------------------------------
self_update() {
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    
    # If inside a git work tree, check and run git pull to update all repository files
    if git -C "${script_dir}" rev-parse --is-inside-work-tree &>/dev/null; then
        info "Checking for remote Git repository updates …"
        git -C "${script_dir}" fetch &>/dev/null || true
        
        local local_hash
        local_hash=$(git -C "${script_dir}" rev-parse HEAD)
        local upstream_hash
        upstream_hash=$(git -C "${script_dir}" rev-parse @{u} 2>/dev/null || echo "")
        
        if [[ -n "${upstream_hash}" && "${local_hash}" != "${upstream_hash}" ]]; then
            local choice
            choice=$(echo -e "Yes, update now (git pull)\nNo, cancel" | fzf \
                --header="A new repository update is available. Do you want to update?" \
                --prompt="Update choice > " \
                --border=rounded \
                --height=15% \
                --layout=reverse)
            if [[ "${choice}" == "Yes, update now (git pull)" ]]; then
                info "Updating all files via git pull …"
                if git -C "${script_dir}" pull; then
                    success "Successfully updated repository via git pull."
                    exit 0
                else
                    error_exit "Failed to run git pull."
                fi
            else
                info "Update cancelled."
                exit 0
            fi
        else
            success "Repository is already up-to-date."
            exit 0
        fi
    fi

    info "Non-git environment detected. Checking for updates on GitHub …"
    local remote_version
    remote_version=$(curl -fsSL "https://raw.githubusercontent.com/ZeroDot1/LLMfitDownloadhelper/main/LLMfitDownloadhelper.sh" 2>/dev/null | grep -E '^VERSION=' | head -n 1 | cut -d'"' -f2 || echo "")
    
    if [[ -z "${remote_version}" ]]; then
        error_exit "Could not retrieve remote version info. Check your connection."
    fi
    
    if [[ "${remote_version}" != "${VERSION}" ]]; then
        local choice
        choice=$(echo -e "Yes, update now\nNo, cancel" | fzf \
            --header="New version found: ${remote_version} (Local: ${VERSION}). Update now?" \
            --prompt="Update choice > " \
            --border=rounded \
            --height=15% \
            --layout=reverse)
        
        if [[ "${choice}" == "Yes, update now" ]]; then
            info "Updating LLMfitDownloadhelper.sh …"
            local script_path
            script_path=$(realpath "$0")
            
            # Download new script
            if ! curl -fsSL "https://raw.githubusercontent.com/ZeroDot1/LLMfitDownloadhelper/main/LLMfitDownloadhelper.sh" -o "${script_path}"; then
                error_exit "Failed to download update."
            fi
            
            # Download new helper script
            info "Updating filter_compatible.py …"
            if ! curl -fsSL "https://raw.githubusercontent.com/ZeroDot1/LLMfitDownloadhelper/main/filter_compatible.py" -o "${script_dir}/filter_compatible.py"; then
                warn "Failed to download filter_compatible.py update."
            else
                chmod +x "${script_dir}/filter_compatible.py"
            fi
            
            success "Successfully updated to version ${remote_version}."
            exit 0
        else
            info "Update cancelled."
            exit 0
        fi
    else
        success "LLMfitDownloadhelper is already up-to-date (Version ${VERSION})."
        exit 0
    fi
}

# ------------------------------------------------------------------------------
# Command Line Argument Parsing
# ------------------------------------------------------------------------------
PARSE_CLEAN=false
PARSE_UPDATE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean|--manage)
            PARSE_CLEAN=true
            shift
            ;;
        -t|--tag)
            if [[ -z "${2:-}" ]]; then
                error_exit "Option -t/--tag requires an argument (coding, vision, reasoning, audio, general)."
            fi
            LLMFIT_TAG_FILTER="$2"
            shift 2
            ;;
        --update)
            PARSE_UPDATE=true
            shift
            ;;
        -h|--help)
            echo "LLMfitDownloadhelper v${VERSION}"
            echo "Usage: ./LLMfitDownloadhelper.sh [options]"
            echo ""
            echo "Options:"
            echo "  -c, --clean, --manage   Directly open the installed models manager (Ollama-Aufräumer)"
            echo "  -t, --tag <tag>         Pre-filter TUI models by tag (coding, vision, reasoning, audio, general)"
            echo "  --update                Check for updates on GitHub and self-update"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1. Run with -h or --help for usage."
            ;;
    esac
done

if [[ "${PARSE_CLEAN}" == "true" ]]; then
    manage_installed_models
    exit 0
fi

if [[ "${PARSE_UPDATE}" == "true" ]]; then
    self_update
fi

# ------------------------------------------------------------------------------
# Database update helper (checks cache age or force updates all models)
# ------------------------------------------------------------------------------
update_database_if_old() {
    local force="${1:-false}"
    local cache_file="${HOME}/.llmfit/hf_models_cache.json"
    local now
    now=$(date +%s)
    local last_modified=0
    if [[ -f "${cache_file}" ]]; then
        last_modified=$(stat -c %Y "${cache_file}" 2>/dev/null || stat -f %m "${cache_file}" 2>/dev/null || echo 0)
    fi
    local diff=$(( now - last_modified ))
    
    if [[ "${force}" == "true" ]]; then
        local confirm
        confirm=$(echo -e "No, cancel\nYes, update database" | fzf \
            --header="WARNING: Fetching all models can take several minutes. Proceed?" \
            --prompt="Confirm force update > " \
            --border=rounded \
            --height=15% \
            --layout=reverse)
        
        if [[ "${confirm}" != "Yes, update database" ]]; then
            info "Database update cancelled."
            sleep 1.5
            return
        fi
        info "Force updating database with ALL models (up to 30,000) …"
        echo -e "${BLUE}----------------------------------------------------------------------${NC}"
        llmfit update --trending 30000 --downloads 30000 ${GLOBAL_ARGS}
        echo -e "${BLUE}----------------------------------------------------------------------${NC}"
        success "Database successfully updated."
        sleep 2
    elif [[ ${diff} -ge 7200 ]]; then
        info "Database cache is older than 2 hours. Updating (limit: ${LLMFIT_LIMIT}) …"
        echo -e "${BLUE}----------------------------------------------------------------------${NC}"
        llmfit update --trending "${LLMFIT_LIMIT}" ${GLOBAL_ARGS}
        echo -e "${BLUE}----------------------------------------------------------------------${NC}"
        success "Database cache updated."
        sleep 1.5
    else
        local remaining_mins=$(( (7200 - diff) / 60 ))
        info "Database cache is up-to-date (updated $(( diff / 60 ))m ago). Next auto-update in ${remaining_mins}m."
        sleep 1
    fi
}

# ------------------------------------------------------------------------------
# Main program
# ------------------------------------------------------------------------------
clear
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BOLD}${CYAN}  LLMfitDownloadhelper ${NC}v${VERSION} | ${GREEN}Author: ZeroDot1${NC}"
echo -e "${BLUE}======================================================================${NC}"

GLOBAL_ARGS="$(build_global_args)"

# 1. Database update with extended model list (once on launch, if old)
update_database_if_old false
echo ""

# ------------------------------------------------------------------------------
# Main menu loop: menu → fit → fzf → (run model | back | quit)
# ------------------------------------------------------------------------------
while true; do
    echo -e "${BOLD}${CYAN}Select your preferred sorting criteria:${NC}"
    echo -e " [1] Newest models first        (by release date)"
    echo -e " [2] Largest context window     (by context length)"
    echo -e " [3] Recommended best fit       (by composite score)"
    echo -e " [4] Maximum speed              (by tokens/second)"
    echo -e " [5] Most parameters            (by parameter count)"
    echo -e " [6] Lowest memory usage        (by memory utilization)"
    echo -e " [7] Grouped by use case"
    echo -e " [8] Grouped by model provider"
    echo -e " [9] Manage installed models"
    echo -e " [10] Filter by tag / category   (Current: ${LLMFIT_TAG_FILTER:-None})"
    echo -e " [11] Force update model database (all models)"
    echo -e " [12] Quit"
    echo ""
    echo -n "Choice [1-12]: "
    read -r CHOICE

    SORT_CRITERIA="score"
    HEADER_MSG="Auto-Detected Hardware Fit"

    case "${CHOICE}" in
        1)
            SORT_CRITERIA="date"
            HEADER_MSG="Sorted by date (newest first)"
            ;;
        2)
            SORT_CRITERIA="ctx"
            HEADER_MSG="Sorted by context window (largest first)"
            ;;
        3)
            SORT_CRITERIA="score"
            HEADER_MSG="Sorted by system score (best fit first)"
            ;;
        4)
            SORT_CRITERIA="tps"
            HEADER_MSG="Sorted by speed (tok/s first)"
            ;;
        5)
            SORT_CRITERIA="params"
            HEADER_MSG="Sorted by parameter count (largest first)"
            ;;
        6)
            SORT_CRITERIA="mem"
            HEADER_MSG="Sorted by memory utilization (lowest first)"
            ;;
        7)
            SORT_CRITERIA="use"
            HEADER_MSG="Grouped by use case"
            ;;
        8)
            SORT_CRITERIA="provider"
            HEADER_MSG="Grouped by model provider"
            ;;
        9)
            manage_installed_models
            continue
            ;;
        10)
            select_tag_filter
            continue
            ;;
        11)
            update_database_if_old true
            continue
            ;;
        12|*)
            echo -e "\n${YELLOW}Exiting application.${NC}"
            exit 0
            ;;
    esac

    echo ""
    info "Analyzing local hardware and generating matrix …"

    # 2. llmfit query with hardware auto-detection and user sorting
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    FIT_ARGS="$(build_fit_args)"
    FILTER_ARGS=()
    if [[ -n "${LLMFIT_TAG_FILTER}" ]]; then
        FILTER_ARGS+=(--tag "${LLMFIT_TAG_FILTER}")
    fi
    # shellcheck disable=SC2086
    MODEL_DATA="$(llmfit fit --sort "${SORT_CRITERIA}" --limit "${LLMFIT_LIMIT}" ${GLOBAL_ARGS} ${FIT_ARGS} 2>/dev/null | "${SCRIPT_DIR}/filter_compatible.py" "${FILTER_ARGS[@]}" || true)"

    if [[ -z "${MODEL_DATA}" ]]; then
        warn "No optimal matrix found. Loading system fit list …"
        MODEL_DATA="$(llmfit list 2>/dev/null | "${SCRIPT_DIR}/filter_compatible.py" "${FILTER_ARGS[@]}" || true)"
    fi

    if [[ -z "${MODEL_DATA}" ]]; then
        warn "llmfit could not determine hardware metrics."
        echo -e "${YELLOW}Press ENTER to try again or type 'q' to quit:${NC} "
        read -r RETRY
        [[ "${RETRY}" == "q" ]] && exit 0
        continue
    fi

    # 3. Interactive TUI with fzf — press [b] to go back
    echo ""
    success "Arrow keys to navigate, [ENTER] to download & start"
    echo -e "  ${BLUE}[b]${NC} back to menu  |  ${BLUE}[ESC]${NC} quit"
    echo ""

    RESULT="$(echo "${MODEL_DATA}" | fzf \
        --ansi \
        --no-sort \
        --expect=b \
        --header="LLMfitDownloadhelper v${VERSION} | ${HEADER_MSG}" \
        --prompt="Search model > " \
        --border=rounded \
        --height=75% \
        --layout=reverse \
        --query="ollama")"

    FZF_EXIT=$?

    # Esc / Ctrl-C — quit
    if [[ ${FZF_EXIT} -ne 0 ]]; then
        echo -e "\n${YELLOW}Exiting application.${NC}"
        exit 0
    fi

    # --expect prints the pressed key on line 1, the selected line on line 2
    EXPECTED_KEY="$(echo "${RESULT}" | head -1)"
    SELECTED_LINE="$(echo "${RESULT}" | tail -1)"

    # [b] pressed → back to menu
    if [[ "${EXPECTED_KEY}" == "b" ]] || [[ -z "${EXPECTED_KEY}" && -z "${SELECTED_LINE}" ]]; then
        echo ""
        continue
    fi

    # 4. Extract model identifier from table row (column 2 between │ chars)
    MODEL_NAME="$(echo "${SELECTED_LINE}" | grep -oP '(?<=\│)[^│]+(?=\│)' | sed -n '2p' | xargs 2>/dev/null || true)"

    # Only allow alphanumeric characters, colons, dots, slashes, underscores, and hyphens
    MODEL_NAME="$(echo "${MODEL_NAME}" | sed 's/[^a-zA-Z0-9:._/-]//g' | awk '{print $1}')"

    if [[ -z "${MODEL_NAME}" ]]; then
        warn "Could not extract a valid model identifier. Press ENTER to retry."
        read -r
        continue
    fi

    # Translate model name to GGUF source repository if mapped
    if [[ -f "/tmp/llmfit_model_mapping.json" ]]; then
        MAPPED_NAME="$(jq -r --arg name "${MODEL_NAME}" '.[$name] // empty' /tmp/llmfit_model_mapping.json 2>/dev/null || true)"
        if [[ -n "${MAPPED_NAME}" ]]; then
            MODEL_NAME="${MAPPED_NAME}"
        fi
    fi

    # If the model name has a slash (HuggingFace repo) and does not start with hf.co/, prepend hf.co/
    if [[ "${MODEL_NAME}" == */* ]] && [[ "${MODEL_NAME}" != hf.co/* ]]; then
        MODEL_NAME="hf.co/${MODEL_NAME}"
    fi

    # 5. Start ollama (if needed) and pull & run the model
    ensure_ollama_running

    clear
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${BOLD}${GREEN}  Downloading & starting inference for: ${YELLOW}${MODEL_NAME}${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo ""

    exec ollama run "${MODEL_NAME}"
done
