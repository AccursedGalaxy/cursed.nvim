local M = {}

M.severity_labels = {
	[vim.diagnostic.severity.ERROR] = "ERROR",
	[vim.diagnostic.severity.WARN] = "WARN",
	[vim.diagnostic.severity.INFO] = "INFO",
	[vim.diagnostic.severity.HINT] = "HINT",
}

--- Resolve the pre_send command for a given feature.
--- Returns command, delay_ms if the feature should send a pre-command, or nil, nil if disabled.
--- @param feature string one of "send", "auto_send", "preview", "pick"
--- @return string|nil, number|nil
function M.resolve_pre_command(feature)
	local ps = require("cursed.config").get().pre_send or {}
	if not ps.command then
		return nil, nil
	end
	if ps[feature] == false then
		return nil, nil
	end
	return ps.command, ps.delay_ms or 300
end

--- Apply a named template to the given text.
--- {content} and {diagnostics} are both accepted as placeholder names.
--- @param text string The text to embed
--- @param template_name string Key into config.templates
--- @return string
function M.apply_template(text, template_name)
	local cfg = require("cursed.config").get()
	local templates = cfg.templates or {}
	local tpl = templates[template_name]
	if not tpl then
		return text
	end
	-- Use a function replacement so % in the text is never interpreted as a
	-- gsub capture reference (e.g. %1 in error messages).
	-- {content} is the canonical placeholder; {diagnostics} is a legacy alias.
	local result = tpl:gsub("{content}", function()
		return text
	end)
	return (result:gsub("{diagnostics}", function()
		return text
	end))
end

local function fire(event, data)
	vim.api.nvim_exec_autocmds("User", { pattern = event, data = data })
end

--- Centralized send orchestration.
--- Handles: pre-command, transport, autocmds, statusline updates.
--- All send paths (diag.send, preview, picker) should call this.
--- @param text string The text to send
--- @param opts table { feature: string, pane_target: string, auto_submit: boolean, backend: string }
function M.send_to_transport(text, opts)
	opts = opts or {}
	local cfg = require("cursed.config").get()
	local tmux_cfg = cfg.tmux or {}

	local backend_name = opts.backend or cfg.backend
	local pane_target = opts.pane_target or tmux_cfg.pane_target
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = tmux_cfg.auto_submit
	end
	local paste_delay_ms = tmux_cfg.paste_delay_ms or 300

	local statusline = require("cursed.statusline")
	fire("CursedPreSend", { text = text, backend = backend_name })
	statusline._update("sending")

	local pre_cmd, pre_delay = M.resolve_pre_command(opts.feature or "send")
	local transport = require("cursed.transport").get(backend_name)
	transport.send(text, {
		pane_target = pane_target,
		auto_submit = auto_submit,
		pre_command = pre_cmd,
		pre_command_delay_ms = pre_delay,
		paste_delay_ms = paste_delay_ms,
	}, function(ok)
		if ok then
			fire("CursedPostSend", { text = text, backend = backend_name })
			statusline._update("sent")
		else
			fire("CursedSendFailed", { text = text, backend = backend_name })
			statusline._update("failed")
		end
	end)
end

return M
