# Changelog

All notable changes to cursed.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-03-17

### Added

- **Diagnostics transport** — send LSP diagnostics from the current buffer, all open buffers, or the whole workspace to a Claude Code tmux pane with a single keymap or command
- **Visual selection send** — send any visual selection directly to the Claude Code pane via `CursedSendSelection` command / keymap
- **Auto-send** — optional background mode that debounces `DiagnosticChanged` events and sends diagnostics automatically; configurable debounce interval, scope, and minimum severity
- **Tmux transport** — robust tmux backend with configurable `pane_target`, `auto_submit` (paste + Enter vs paste-only), and `paste_delay_ms`
- **Preview window** — floating window to inspect the exact message that would be sent before committing
- **Config validation** — all options validated at `setup()` time with clear error messages; unknown keys are rejected
- **Keymap opt-out** — every keymap can be disabled by setting its value to `false` in `config.keymaps`
- **`M.send_command`** — public API to send arbitrary text to the tmux pane (useful for fixed commands like `/clear`)
