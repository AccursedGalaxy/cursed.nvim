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

local function fire(event, data)
	vim.api.nvim_exec_autocmds("User", { pattern = event, data = data })
end

--- Centralized send orchestration.
--- Handles: pre-command, transport, autocmds, statusline updates.
--- All send paths (diag.send, preview, picker) should call this.
--- @param text string The text to send
--- @param opts table { feature: string, pane_target: string, auto_submit: boolean, backend: string }
--- @return boolean ok
function M.send_to_transport(text, opts)
	opts = opts or {}
	local cfg = require("cursed").config or {}
	local tmux_cfg = cfg.tmux or {}

	local backend_name = opts.backend or cfg.backend
	local pane_target = opts.pane_target or tmux_cfg.pane_target
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = tmux_cfg.auto_submit
	end

	local statusline = require("cursed.statusline")
	fire("CursedPreSend", { text = text, backend = backend_name })
	statusline._update("sending")

	local pre_cmd, pre_delay = M.resolve_pre_command(opts.feature or "send")
	local transport = require("cursed.transport").get(backend_name)
	local ok = transport.send(text, {
		pane_target = pane_target,
		auto_submit = auto_submit,
		pre_command = pre_cmd,
		pre_command_delay_ms = pre_delay,
	})

	if ok then
		fire("CursedPostSend", { text = text, backend = backend_name })
		statusline._update("sent")
	else
		fire("CursedSendFailed", { text = text, backend = backend_name })
		statusline._update("failed")
	end

	return ok
end

return M
