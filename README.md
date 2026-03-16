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
  -- ── Transport ──────────────────────────────────────────────────────────────
  backend = "tmux",            -- only "tmux" is currently supported
  tmux = {
    pane_target = "{left}",    -- tmux target-pane: "{left}", "{right}", "%3", "session:1.0", …
    auto_submit = true,        -- true  → paste + Enter so Claude starts immediately
                               -- false → paste only; go to pane, edit, press Enter yourself
    paste_delay_ms = 300,      -- ms between paste and Enter; increase on slow machines or large diagnostics
  },

  -- ── What to collect ────────────────────────────────────────────────────────
  scope        = "buffer",     -- "buffer" | "all_buffers" | "workspace"
  min_severity = vim.diagnostic.severity.HINT,  -- HINT=4 INFO=3 WARN=2 ERROR=1

  -- ── How to format ──────────────────────────────────────────────────────────
  format = "default",          -- "default" | "compact" | "with_source_lines"
                               -- or function(diag, bufnr) -> string|nil

  -- ── Prompt templates ───────────────────────────────────────────────────────
  -- Use {content} as the placeholder — it is replaced by the formatted
  -- diagnostics or selected code depending on how the template is invoked.
  -- {diagnostics} still works as a legacy alias.
  -- Pass the key as an arg to :CursedSendDiags or :CursedSendSelection,
  -- e.g. :CursedSendDiags explain  or  :CursedSendSelection fix_selection
  templates = {
    -- diagnostics templates
    fix     = "Please fix these diagnostics:\n\n{diagnostics}",
    explain = "Explain these diagnostics:\n\n{diagnostics}",
    test    = "Write tests that cover these diagnostics:\n\n{diagnostics}",
    -- selection templates
    fix_selection     = "Please fix the following code:\n\n{content}",
    explain_selection = "Explain the following code:\n\n{content}",
    review            = "Review the following code and suggest improvements:\n\n{content}",
  },
  default_template = nil,      -- apply a template automatically on every send, or nil

  -- ── Auto-send on DiagnosticChanged ─────────────────────────────────────────
  auto_send = {
    enabled      = false,
    event        = "DiagnosticChanged",
    debounce_ms  = 500,        -- wait this long after the last event before sending
    min_severity = vim.diagnostic.severity.ERROR,
    scope        = "buffer",
  },

  -- ── Keymaps ────────────────────────────────────────────────────────────────
  -- Set any value to false to disable, or a string to remap.
  keymaps = {
    send              = nil,       -- global normal-mode: e.g. "<leader>cd" → send_diagnostics()
    send_selection    = nil,       -- visual-mode: e.g. "<leader>cs" → send selected code
    preview_send      = "<CR>",    -- inside :CursedPreview: confirm & send
    preview_close     = "q",       -- inside :CursedPreview: close without sending
    preview_close_esc = "<Esc>",   -- inside :CursedPreview: close without sending (Esc)
  },

  -- ── Pre-send command ───────────────────────────────────────────────────────
  -- Sends a command to the pane *before* pasting diagnostics.
  -- Typical use: "/clear" resets Claude's context so history doesn't accumulate.
  -- command = nil disables the feature entirely.
  -- Per-feature keys: nil = follow global, false = suppress for that feature only.
  pre_send = {
    command   = nil,       -- string|nil: e.g. "/clear"; nil = feature off
    delay_ms  = 300,       -- ms to wait after the command before pasting diagnostics
    send      = nil,       -- nil: follows global  (manual :CursedSendDiags / keymap)
    auto_send = nil,       -- nil: follows global  (consider false to reduce noise)
    preview   = nil,       -- nil: follows global  (:CursedPreview send action)
    pick      = nil,       -- nil: follows global  (:CursedPick send action)
    selection = nil,       -- nil: follows global  (:CursedSendSelection / visual keymap)
  },
})
```

### Config precedence

**`scope` and `min_severity`** have two independent resolution paths:

| Send path | `scope` used | `min_severity` used |
|-----------|-------------|---------------------|
| Manual (`:CursedSendDiags`, keymap, `send_command`) | top-level `scope` | top-level `min_severity` |
| Auto-send (`DiagnosticChanged` autocmd) | `auto_send.scope` | `auto_send.min_severity` |

`auto_send` values are passed as explicit opts and **never fall back to the top-level globals**. If you set `min_severity = ERROR` at the top level expecting auto-send to follow, it will not — set `auto_send.min_severity` explicitly.

**`pre_send`** resolves in three steps for each feature (`send`, `auto_send`, `preview`, `pick`, `selection`):

1. `pre_send.command = nil` → entire feature off; per-feature keys are ignored.
2. `pre_send.<feature> = false` → disabled for that feature only.
3. `pre_send.<feature> = nil` → inherits `pre_send.command` + `pre_send.delay_ms`.

### Sending arbitrary commands

`send_command(text, opts?)` sends any raw string to the configured pane. Use it for keymaps that trigger Claude Code slash commands without leaving Neovim.

```lua
local cursed = require("cursed")

-- Fixed command
vim.keymap.set("n", "<leader>cC", function()
  cursed.send_command("/clear")
end, { desc = "Clear Claude Code context" })

-- Interactive prompt
vim.keymap.set("n", "<leader>c:", function()
  vim.ui.input({ prompt = "Claude> " }, function(input)
    if input and input ~= "" then cursed.send_command(input) end
  end)
end, { desc = "Send arbitrary command to Claude Code" })
```

Or from the command line: `:CursedSendCommand /clear`

`opts` accepts `pane_target` and `auto_submit` to override config defaults for that call.

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
| `:CursedSendSelection [template]` | Send the current visual selection. Optional arg: template name (`fix_selection`, `explain_selection`, `review`, …). Without a template, prompts for an instruction. |
| `:CursedPreview` | Preview and edit the formatted text before sending (keymaps configurable via `keymaps.*`) |
| `:CursedPick` | Telescope picker to select individual diagnostics from all loaded buffers (ignores `scope`; requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)) |
| `:CursedSendCommand {text}` | Send any raw string to the pane (e.g. `:CursedSendCommand /clear`) |

## Usage

1. Open a file that has LSP diagnostics.
2. Run `:CursedSendDiags` (or your keymap).
3. Claude Code in the pane to your left receives the formatted diagnostics and — if `auto_submit = true` — Enter is sent automatically (after `tmux.paste_delay_ms`) so Claude starts processing.

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

**Send a visual selection:**

Select code in visual mode, then:
```vim
:'<,'>CursedSendSelection              " prompts for an instruction, then sends selection
:'<,'>CursedSendSelection fix_selection " applies the fix_selection template immediately
:'<,'>CursedSendSelection review        " asks Claude to review the selected code
```

Or bind the `send_selection` keymap and use it directly from visual mode:
```lua
keymaps = { send_selection = "<leader>cs" }
-- In visual mode: select code, press <leader>cs, type your instruction
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
