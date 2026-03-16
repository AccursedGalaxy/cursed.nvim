local M = {}

M.defaults = {
	backend = "tmux",
	tmux = {
		pane_target = "{left}",
		auto_submit = true,
	},
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
		min_severity = vim.diagnostic.severity.ERROR,
		scope = "buffer",
	},
	keymaps = {
		send = nil,
		preview_send = "<CR>",
		preview_close = "q",
		preview_close_esc = "<Esc>",
	},
}

return M
