local M = {}

function M.check()
	local health = vim.health

	health.start("cursed.nvim")

	-- Neovim version
	if vim.fn.has("nvim-0.11.0") == 1 then
		health.ok("Neovim >= 0.11.0")
	else
		health.error("Neovim >= 0.11.0 required", "Upgrade Neovim")
	end

	-- Plugin loaded
	if vim.g.loaded_cursed then
		health.ok("plugin loaded")
	else
		health.warn("plugin not loaded — is cursed.nvim in your runtimepath?")
	end

	-- setup() called
	local setup_ok = pcall(require("cursed.config").get)
	if setup_ok then
		health.ok("setup() has been called")
	else
		health.warn("setup() has not been called — add require('cursed').setup() to your config")
	end

	-- tmux executable
	if vim.fn.executable("tmux") == 1 then
		health.ok("tmux is installed")
	else
		health.error("tmux not found in PATH", "Install tmux: https://github.com/tmux/tmux")
	end

	-- tmux server running
	vim.fn.system({ "tmux", "list-sessions" })
	if vim.v.shell_error == 0 then
		health.ok("tmux server is running")
	else
		health.warn("no tmux server running — start a tmux session before using cursed.nvim")
	end

	-- LSP clients
	local clients = vim.lsp.get_clients()
	if #clients > 0 then
		health.ok(string.format("%d LSP client(s) active", #clients))
	else
		health.info("no LSP clients active in the current session")
	end
end

return M
