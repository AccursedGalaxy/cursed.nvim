if vim.fn.has("nvim-0.11.0") == 0 then
	vim.notify("cursed.nvim requires Neovim 0.11.0 or later", vim.log.levels.ERROR)
	return
end

if vim.g.loaded_cursed then
	return
end
vim.g.loaded_cursed = true

vim.api.nvim_create_user_command("Cursed", function()
	require("cursed").hello()
end, { desc = "Test that cursed.nvim is working" })

vim.api.nvim_create_user_command("CursedSendDiags", function()
	require("cursed").send_diagnostics()
end, { desc = "Send LSP diagnostics to Claude Code tmux pane" })
