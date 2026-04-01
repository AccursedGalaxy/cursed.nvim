if vim.fn.has("nvim-0.11.0") == 0 then
	vim.notify("cursed.nvim requires Neovim 0.11.0 or later", vim.log.levels.ERROR)
	return
end

if vim.g.loaded_cursed then
	return
end
vim.g.loaded_cursed = true

vim.api.nvim_create_user_command("CursedSendDiags", function(cmd_opts)
	local arg = vim.trim(cmd_opts.args or "")
	local opts = {}
	if arg ~= "" then
		local scopes = { buffer = true, all_buffers = true, workspace = true }
		if scopes[arg] then
			opts.scope = arg
		else
			opts.template = arg
		end
	end
	require("cursed").send_diagnostics(opts)
end, {
	desc = "Send LSP diagnostics to Claude Code tmux pane",
	nargs = "?",
})

vim.api.nvim_create_user_command("CursedPreview", function()
	require("cursed").preview()
end, { desc = "Preview diagnostics before sending to Claude Code" })

vim.api.nvim_create_user_command("CursedSendCommand", function(cmd_opts)
	local text = vim.trim(cmd_opts.args or "")
	if text == "" then
		vim.notify("cursed: CursedSendCommand requires a argument, e.g. :CursedSendCommand /clear", vim.log.levels.WARN)
		return
	end
	require("cursed").send_command(text)
end, {
	desc = "Send an arbitrary command to the Claude Code tmux pane",
	nargs = "+",
})

vim.api.nvim_create_user_command("CursedPick", function()
	require("cursed.pickers.telescope").pick()
end, { desc = "Pick diagnostics to send using Telescope" })

vim.api.nvim_create_user_command("CursedSendSelection", function(cmd_opts)
	local arg = vim.trim(cmd_opts.args or "")
	local opts = arg ~= "" and { template = arg } or {}
	opts.line1 = cmd_opts.line1
	opts.line2 = cmd_opts.line2
	require("cursed").send_selection(opts)
end, {
	desc = "Send visual selection to Claude Code tmux pane",
	nargs = "?",
	range = true,
})
