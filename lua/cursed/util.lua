local M = {}

--- Resolve the pre_send command for a given feature.
--- Returns command, delay_ms if the feature should send a pre-command, or nil, nil if disabled.
--- @param feature string one of "send", "auto_send", "preview", "pick"
--- @return string|nil, number|nil
function M.resolve_pre_command(feature)
	local ps = ((require("cursed").config) or {}).pre_send or {}
	if not ps.command then
		return nil, nil
	end
	if ps[feature] == false then
		return nil, nil
	end
	return ps.command, ps.delay_ms or 300
end

return M
