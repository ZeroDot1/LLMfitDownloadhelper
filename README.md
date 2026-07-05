# LLMfitDownloadhelper

[![License: AGPLv3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Shell Script](https://img.shields.io/badge/Language-Bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)]()

A smart, lightweight, and interactive **Terminal User Interface (TUI)** to seamlessly discover,
sort, and download the best-fitting Local Large Language Models (LLMs) for your specific hardware.

Developed by **ZeroDot1** and distributed under the **GNU AGPLv3 License**.

---

## Table of Contents

- [Why this tool was created](#why-this-tool-was-created)
- [Features](#features)
- [Quick Start](#quick-start)
- [Supported Operating Systems](#supported-operating-systems)
- [Prerequisites / Dependencies](#prerequisites--dependencies)
  - [Arch Linux](#1-arch-linux)
  - [Ubuntu / Debian](#2-ubuntu--debian)
  - [Via Rust / Cargo](#alternative-installation-via-rust-cargo)
- [Installation & Usage](#installation--usage)
- [How it Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Environment Variables](#environment-variables)
- [License](#license)

---

## Why this tool was created

The **LLMfitDownloadhelper** bridges the gap between model evaluation and instant deployment.
While `llmfit` provides detailed hardware metrics and `ollama` offers a powerful engine for local
models, combining them manually requires jumping between terminal commands, configurations, and
sorting parameters.

This shell script **radically simplifies this workflow**. By wrapping both tools into a single
interactive interface, you can instantly see which models fit your system and pull them into
Ollama with a single keystroke.

---

## Features

| Feature                         | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| **Universal Hardware Profiling** | Detects CPU, RAM, and GPU (NVIDIA CUDA, AMD ROCm, Apple Silicon) anywhere.  |
| **Flexible Sorting**            | Sort by newest release, context window size, best fit score, or speed.      |
| **Deep Cache Updates**          | Fetches **500+ trending models** from HuggingFace on every launch.          |
| **fzf-Powered Interface**       | Blazing-fast fuzzy search with responsive keyboard navigation.              |
| **Ollama Integration**          | Extracts clean model identifiers and runs `ollama run` automatically.       |

---

## Quick Start

```bash
git clone https://github.com/ZeroDot1/LLMfitDownloadhelper.git
cd LLMfitDownloadhelper
chmod +x LLMfitDownloadhelper.sh
./LLMfitDownloadhelper.sh
```

Make sure you have the [required dependencies](#prerequisites--dependencies) installed first.

---

## Supported Operating Systems

- **Arch Linux** (primary target)
- **Ubuntu** (and derivatives: Linux Mint, Pop!_OS, etc.)
- Any Linux distribution with Bash 4+, `fzf`, `llmfit`, and `ollama`.

---

## Prerequisites / Dependencies

Before launching the helper, all core dependencies must be installed and globally accessible
via your system's `PATH`. Follow the steps for your distribution:

### 1. Arch Linux

```bash
# Install ollama and fzf from official repositories
sudo pacman -S ollama fzf

# Start and enable the ollama background service
sudo systemctl enable --now ollama

# Install llmfit via the official standalone script
curl -fsSL https://llmfit.axjns.dev/install.sh | sh
```

### 2. Ubuntu / Debian

```bash
# Update package repositories and install dependencies
sudo apt update
sudo apt install fzf git curl build-essential -y

# Download and install ollama officially
curl -fsSL https://ollama.com | sh

# Install llmfit via the official standalone script
curl -fsSL https://llmfit.axjns.dev/install.sh | sh
```

### Alternative: Installation via Rust / Cargo

If you prefer to build `llmfit` from source:

```bash
cargo install llmfit
```

> **Note:** If you installed via the curl installer without root, make sure
> `~/.local/bin` is in your `$PATH`.

---

## Installation & Usage

1. **Clone or download** the script into a directory of your choice.
2. **Make it executable**:
   ```bash
   chmod +x LLMfitDownloadhelper.sh
   ```
3. **Run it**:
   ```bash
   ./LLMfitDownloadhelper.sh
   ```

The script will:
1. Update the `llmfit` model cache (500+ models).
2. Present a sorting menu (newest, context size, best fit, speed).
3. Analyze your hardware and build a compatibility matrix.
4. Launch an interactive `fzf` search window pre-filtered for Ollama models.
5. On selection, start the Ollama daemon automatically (if needed).
6. Pull and run the chosen model with `ollama run`.

---

## How it Works

1. **Cache Update**  
   On startup, the script connects to HuggingFace and updates your local `llmfit` cache with
   **500+ trending models**.

2. **Sorting Choice**  
   You pick how models are sorted: newest release, largest context window, best fit score, or
   fastest speed.

3. **Matrix Calculation**  
   Based on your choice, `llmfit` builds a hardware compatibility matrix covering VRAM footprint,
   token speed, and context window size.

4. **Interactive Search**  
   The TUI populates a list pre-filtered for `ollama`. Type any keyword (e.g., `llama3`, `qwen`,
   `mistral`) to narrow down the selection while keeping full visibility of compatibility data.

5. **Automatic Ollama Start**  
   Once a model is selected, the script checks if the Ollama service is running and starts it
   if needed (user systemd → sudo systemd → direct start).

6. **Instant Inference**  
   `ollama run` pulls the model (if not cached) and starts an interactive chat session in your
   terminal.

---

## Troubleshooting

### "fzf is not installed"

```bash
# Arch Linux
sudo pacman -S fzf

# Ubuntu / Debian
sudo apt install fzf
```

### "llmfit is not installed"

```bash
curl -fsSL https://llmfit.axjns.dev/install.sh | sh
```

### "Ollama service is inactive" / cannot start ollama

The script tries several strategies automatically:
1. `systemctl --user start ollama` (user service, no root)
2. `sudo systemctl start ollama` (system service)
3. `ollama serve &` (direct binary start)

If all fail, start ollama manually:

```bash
sudo systemctl start ollama
# or
ollama serve
```

### "Failed to parse a valid model identifier"

This can happen if the `llmfit` table output format changes. Try running:

```bash
llmfit fit --sort score --cli --limit 10
```

to verify that model names appear in the expected format. If the output looks different, please
[open an issue](https://github.com/ZeroDot1/LLMfitDownloadhelper/issues).

### The fzf window looks garbled

Make sure your terminal supports ANSI escape codes and Unicode. Most modern terminal emulators
(gnome-terminal, kitty, alacritty, Windows Terminal) work out of the box.

---

## Environment Variables

The following variables can be set to customize behavior:

| Variable         | Default                 | Description                            |
|------------------|-------------------------|----------------------------------------|
| `OLLAMA_HOST`    | `http://127.0.0.1:11434`| Ollama API endpoint                    |
| `LLMFIT_LIMIT`   | `500`                   | Trending models to fetch / max fit results |

Example:

```bash
OLLAMA_HOST="http://10.0.0.5:11434" LLMFIT_LIMIT=1000 ./LLMfitDownloadhelper.sh
```

---

## License

This project is open-source software licensed under the **GNU Affero General Public License v3
(AGPLv3)**. See the [LICENSE](./LICENSE) file for the full license text.

---

*Maintained and curated by **ZeroDot1**.*
