# cursed.nvim

Send your buffer's LSP diagnostics to Claude Code in a tmux pane — one command, no copy-pasting.

## Requirements

- Neovim >= 0.11.0
- [tmux](https://github.com/tmux/tmux) with at least one active session
- [Claude Code](https://claude.ai/code) running inside a tmux pane

## Installation

**lazy.nvim**

```lua
{
  "AccursedGalaxy/cursed.nvim",
  config = function()
    require("cursed").setup({
      tmux = { pane_target = "{left}", auto_submit = true },
    })
  end,
}
```

**rocks.nvim** (rocks.toml)

```toml
[plugins]
"cursed.nvim" = "scm"
```

## Configuration

All options are optional. Defaults are shown below.

```lua
require("cursed").setup({
  -- Transport
  backend = "tmux",            -- only "tmux" is currently supported
  tmux = {
    pane_target = "{left}",    -- tmux target-pane: "{left}", "%3", "session:1.0", …
    auto_submit = true,        -- paste then send Enter (~300ms later, async) so Claude starts processing
  },

  -- What to collect
  scope        = "buffer",     -- "buffer" | "all_buffers" | "workspace"
  min_severity = vim.diagnostic.severity.HINT,  -- filter out below this level

  -- How to format
  format = "default",          -- "default" | "compact" | "with_source_lines" | function(d, bufnr) -> string|nil

  -- Prompt wrapping (use {diagnostics} as placeholder)
  templates = {
    fix     = "Please fix these diagnostics:\n\n{diagnostics}",
    explain = "Explain these diagnostics:\n\n{diagnostics}",
    test    = "Write tests that cover these diagnostics:\n\n{diagnostics}",
  },
  default_template = nil,      -- template key to apply automatically, or nil

  -- Auto-send on DiagnosticChanged
  auto_send = {
    enabled      = false,
    event        = "DiagnosticChanged",
    debounce_ms  = 500,        -- wait this long after the last event before sending
    min_severity = vim.diagnostic.severity.ERROR,
    scope        = "buffer",
  },

  -- Keymaps (set any value to false to disable)
  keymaps = {
    send              = nil,       -- global: e.g. "<leader>cd" → send_diagnostics()
    preview_send      = "<CR>",    -- confirm & send inside the preview window
    preview_close     = "q",       -- close preview window
    preview_close_esc = "<Esc>",   -- close preview window (Esc)
  },
})
```

### tmux pane target syntax

`pane_target` accepts any tmux [target-pane](https://man.openbsd.org/tmux#COMMANDS) value:

| Value | Meaning |
|-------|---------|
| `"{left}"` | The pane to the left of the current one (default) |
| `"{right}"` | The pane to the right |
| `"%3"` | Pane by ID |
| `"mysession:1.0"` | Explicit session:window.pane |

## Commands

| Command | Description |
|---------|-------------|
| `:Cursed` | Verify the plugin is loaded |
| `:CursedSendDiags [arg]` | Send diagnostics. Optional arg: scope (`buffer`, `all_buffers`, `workspace`) or template name (`fix`, `explain`, …) |
| `:CursedPreview` | Preview and edit the formatted text before sending (keymaps configurable via `keymaps.*`) |
| `:CursedPick` | Telescope picker to select individual diagnostics from all loaded buffers (ignores `scope`; requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)) |

## Usage

1. Open a file that has LSP diagnostics.
2. Run `:CursedSendDiags` (or your keymap).
3. Claude Code in the pane to your left receives the formatted diagnostics and — if `auto_submit = true` — Enter is sent automatically (~300 ms later) so Claude starts processing.

**Send only errors:**
```vim
:CursedSendDiags    " uses your configured min_severity
```

**Send workspace-wide diagnostics wrapped in the "fix" template:**
```vim
:CursedSendDiags workspace
" then manually pick a template, or set default_template = "fix"
```

**Preview before sending:**
```vim
:CursedPreview      " floating window — edit, then send with keymaps.preview_send (default <CR>)
```

## Statusline / lualine

```lua
-- lualine
require("lualine").setup({
  sections = {
    lualine_x = { require("cursed.statusline").lualine },
  },
})

-- or plain statusline
vim.o.statusline = "%{%v:lua.require('cursed.statusline').component()%}"
```

## Hooks / autocmd events

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "CursedPostSend",
  callback = function(ev)
    vim.notify(string.format("cursed: sent %d chars", #ev.data.text))
  end,
})
```

Events: `CursedPreSend`, `CursedPostSend`, `CursedSendFailed`. Each carries `data = { text, backend }`.

## Health check

```vim
:checkhealth cursed
```

Verifies Neovim version, plugin load, `setup()` call, tmux installation, tmux server status, and LSP client presence.

## Development

```bash
make test   # run tests (requires plenary.nvim)
make lint   # check formatting with StyLua
make fmt    # auto-format with StyLua
```

## License

MIT
