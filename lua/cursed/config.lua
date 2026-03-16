local M = {}

local _active = nil

--- Store the merged, validated config. Called once from setup().
function M._set(cfg)
	_active = cfg
end

--- Return the active config. Errors if setup() has not been called.
function M.get()
	if _active == nil then
		error("cursed.nvim: config.get() called before setup(). Call require('cursed').setup() first.", 2)
	end
	return _active
end

-- ── Config-precedence contract ────────────────────────────────────────────────
--
-- scope / min_severity — two independent resolution paths:
--   • Manual sends (:CursedSendDiags, keymaps, send_command):
--       use top-level `scope` and `min_severity`.
--   • auto_send (DiagnosticChanged autocmd):
--       always use `auto_send.scope` and `auto_send.min_severity`.
--       These do NOT fall back to the top-level values; set them explicitly.
--
-- pre_send — three-step resolution per feature (send / auto_send / preview / pick):
--   1. pre_send.command = nil  → feature is globally off; nothing else matters.
--   2. pre_send.<feature> = false → disabled for that specific feature only.
--   3. pre_send.<feature> = nil  → inherits the global command + delay_ms.
--
-- See util.resolve_pre_command for the implementation.
-- ─────────────────────────────────────────────────────────────────────────────

M.defaults = {
	backend = "tmux",
	tmux = {
		pane_target = "{left}",
		auto_submit = true,
		paste_delay_ms = 300, -- ms between paste and Enter; increase on slow machines
	},
	-- Used by manual sends only. auto_send has its own scope/min_severity below.
	scope = "buffer",
	min_severity = vim.diagnostic.severity.HINT,
	format = "default",
	templates = {
		fix = "Please fix these diagnostics:\n\n{diagnostics}",
		explain = "Explain these diagnostics:\n\n{diagnostics}",
		test = "Write tests that cover these diagnostics:\n\n{diagnostics}",
	},
	default_template = nil,
	auto_send = {
		enabled = false,
		event = "DiagnosticChanged",
		debounce_ms = 500,
		-- These override the top-level scope/min_severity for auto-send triggers.
		-- Passed as explicit opts to send_diagnostics; never fall back to the globals.
		min_severity = vim.diagnostic.severity.ERROR,
		scope = "buffer",
	},
	keymaps = {
		send = nil,
		preview_send = "<CR>",
		preview_close = "q",
		preview_close_esc = "<Esc>",
	},
	pre_send = {
		command  = nil,   -- string|nil: command to send before diagnostics (e.g. "/clear")
		delay_ms = 300,   -- ms to wait after the command before pasting diagnostics
		-- per-feature overrides: nil = follow global, false = disable for this feature
		send      = nil,
		auto_send = nil,
		preview   = nil,
		pick      = nil,
	},
}

return M
