local M = {}

local config = require("cursed.config")

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", config.defaults, opts or {})
end

function M.hello()
	vim.notify("cursed.nvim is alive!", vim.log.levels.INFO)
end

return M
