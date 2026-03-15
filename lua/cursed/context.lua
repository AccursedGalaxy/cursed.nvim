local M = {}
local config = require("cursed.config")

--- Build a prompt string from the current buffer state.
--- @return string prompt
function M.get_context()
  local cfg = config.get()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]  -- 1-based
  local col = cursor[2]  -- 0-based byte offset
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ft = vim.bo.filetype

  local above_start = math.max(1, row - cfg.lines_above)
  local above = vim.list_slice(lines, above_start, row - 1)

  -- Text on the current line before the cursor (e.g. "-- This is a")
  -- Without this the model has no idea what the user is mid-typing.
  local prefix = lines[row] and lines[row]:sub(1, col) or ""

  local header = "-- filetype: " .. (ft ~= "" and ft or "unknown")
  return table.concat(vim.list_extend({ header }, above), "\n") .. "\n" .. prefix .. "<CURSOR>"
end

return M
