# Changelog

All notable changes to the **LLMfitDownloadhelper** project will be documented in this file.

## [2.2] - 2026-07-05
### Added
- Created 50 professional system prompt templates inside `system_prompts/` covering development, writing, tutoring, gaming, and business.
- Configured prompt templates using 2026 cognitive layout schemas featuring role definition, structured goals, 3-phase execution workflows (plan, process, self-verify), and formatting/safety constraints.
- Integrated built-in prompt template selection in the TUI (`[Built-in]` templates) alongside user prompts (`[User]` templates).
- Added new main menu option `[11]` to load and run already installed local Ollama models using any of the system prompt templates.

### Fixed
- Replaced double-quotes with triple-quotes (`"""`) in the Modelfile generator to ensure robust parsing of multi-line system prompts in Ollama.
- Removed illegal `local` variable declarations inside the main loop scope of `LLMfitDownloadhelper.sh` that were triggering Bash syntax warnings.
- Fixed an arithmetic expression syntax error (caused by residual HTML entities) during free space validation.

## [2.1] - 2026-07-05
### Added
- Implemented a dynamic custom system prompt compiler and Modelfile builder inside `LLMfitDownloadhelper.sh`.
- Added execution logs and analytics history tracking for model downloads (`PULLED`, `PULL_FAILED`) and run sessions (`RUN`, `RUN_FAILED`) with duration tracking.
- Added main menu option to inspect download & run history logs interactively using `fzf`.
- Added keybinding help hints (`Tab`, `Ctrl-S`, `Enter`, `b`, `ESC`) directly inside the `fzf` TUI header viewport.

## [2.0] - 2026-07-05
### Added
- Implemented Offline Mode (`-o`/`--offline`) to bypass online Git update checks and database cache aging verification.
- Added HuggingFace Hub authenticated download support by sourcing personal tokens (`HF_TOKEN`) from `.env` configurations.
- Created the Zsh/Bash Alt+L command quick-launcher widget (`--show-widget` and `--widget-mode`) to run selected fits directly from the shell buffer.
- Added proactive runtime dependency validation for `fzf`, `llmfit`, and `ollama`.
- Integrated free disk space safety check before model downloading.
- Captured Ollama error and exit codes cleanly to prevent crash loops.

## [1.9] - 2026-07-05
### Added
- Added multi-selection support with `[TAB]` for batch model downloads.
- Implemented dynamic preview panels displaying Hugging Face model description cards.
- Integrated sort criteria cycling via hotkeys (`[Ctrl-S]`) directly inside `fzf`.
- Created a side-by-side comparison pane when comparing two selected models.
- Adjusted TUI preview layouts to render at the bottom of the screen (`down:35%`) to prevent visual table squishing.

## [Older Releases]
- Self-updater CLI logic (`--update`) using Git checkouts.
- Tags filter logic (`-t`/`--tag`) for model categories.
- Direct model manager command shortcut (`-c`/`--clean`/`--manage`).
- Automated translation of Hugging Face base repository names to compatible GGUF versions before running.
- 2-hour aging local database cache limit.
