if vim.fn.has("nvim-0.11.0") == 0 then
	vim.api.nvim_err_writeln("cursed.nvim requires Neovim 0.11.0 or later")
	return
end

if vim.g.loaded_cursed then
	return
end
vim.g.loaded_cursed = true
