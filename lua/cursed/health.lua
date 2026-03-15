local M = {}

function M.check()
	local health = vim.health

	health.start("cursed.nvim")

	if vim.fn.has("nvim-0.11.0") == 1 then
		health.ok("Neovim >= 0.11.0")
	else
		health.error("Neovim >= 0.11.0 required", "Upgrade Neovim")
	end

	if vim.g.loaded_cursed then
		health.ok("plugin loaded")
	else
		health.warn("plugin not loaded — is cursed.nvim in your runtimepath?")
	end
end

return M
