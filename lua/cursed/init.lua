local M = {}

local config = require("cursed.config")

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", config.defaults, opts or {})
	if M.config.keymap then
		vim.keymap.set("n", M.config.keymap, M.send_diagnostics, {
			desc = "Send diagnostics to Claude Code tmux pane",
		})
	end
end

function M.send_diagnostics(opts)
	require("cursed.diag").send(opts)
end

function M.hello()
	vim.notify("cursed.nvim is alive!", vim.log.levels.INFO)
end

return M
