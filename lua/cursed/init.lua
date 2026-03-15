local M = {}

local config = require("cursed.config")
local inference = require("cursed.inference")
local context = require("cursed.context")

function M.setup(opts)
	opts = opts or {}
	config.defaults = vim.tbl_deep_extend("force", config.defaults, opts)
	vim.notify("[cursed] setup complete: model=" .. config.defaults.model, vim.log.levels.INFO)
end

function M.complete_at_cursor(callback)
	local prompt = context.get_context()
	inference.complete(prompt, callback or function(res, err)
		if err then
			vim.notify("cursed: " .. err, vim.log.levels.WARN)
		else
			vim.notify("cursed: " .. (res or "(empty)"), vim.log.levels.INFO)
		end
	end)
end

return M
