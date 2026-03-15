local M = {}

local config = require("cursed.config")

function M.setup(opts)
  opts = opts or {}
  config.defaults = vim.tbl_deep_extend("force", config.defaults, opts)
  vim.notify("[cursed] setup complete: model=" .. config.defaults.model, vim.log.levels.INFO)
end

return M
