local M = {}

local state = {
	last_sent_ms = nil,
	last_failed_ms = nil,
	sending = false,
}

--- Called by diag.send() to update state.
--- @param status string "sending" | "sent" | "failed"
function M._update(status)
	if status == "sending" then
		state.sending = true
	elseif status == "sent" then
		state.sending = false
		state.last_sent_ms = vim.uv.now()
		state.last_failed_ms = nil
	elseif status == "failed" then
		state.sending = false
		state.last_failed_ms = vim.uv.now()
	end
end

--- Return a statusline string describing the last send.
--- Returns "" when nothing has been sent yet.
--- @return string
function M.component()
	if state.sending then
		return "cursed: sending…"
	end
	if state.last_failed_ms then
		local s = math.floor((vim.uv.now() - state.last_failed_ms) / 1000)
		return string.format("cursed: failed %ds ago", s)
	end
	if state.last_sent_ms then
		local s = math.floor((vim.uv.now() - state.last_sent_ms) / 1000)
		return string.format("cursed: sent %ds ago", s)
	end
	return ""
end

--- lualine component table.
--- Usage: require("lualine").setup({ sections = { lualine_x = { require("cursed.statusline").lualine } } })
local _cached = ""
M.lualine = {
	function()
		return _cached
	end,
	cond = function()
		_cached = M.component()
		return _cached ~= ""
	end,
}

return M
