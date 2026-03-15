-- Bootstrap plenary.nvim for running tests
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

if not vim.uv.fs_stat(plenary_path) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/nvim-lua/plenary.nvim",
		plenary_path,
	})
end

vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(plenary_path)

vim.cmd("runtime plugin/plenary.vim")
