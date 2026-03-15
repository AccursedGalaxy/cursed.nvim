local M = {}
local config = require("cursed.config")

--- Build a prompt string from the current buffer state.
--- @return string prompt
function M.get_context()
  local cfg = config.get()
  local row = vim.api.nvim_win_get_cursor(0)[1]  -- 1-based
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ft = vim.bo.filetype

  local above_start = math.max(1, row - cfg.lines_above)
  local above = vim.list_slice(lines, above_start, row - 1)

  local header = "-- filetype: " .. (ft ~= "" and ft or "unknown")
  return table.concat(vim.list_extend({ header }, above), "\n") .. "\n<CURSOR>"
end

return M
