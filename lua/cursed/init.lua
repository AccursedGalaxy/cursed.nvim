local M = {}

local config = require("cursed.config")
local validate = require("cursed.validate")

local auto_send_timer = nil

function M.setup(opts)
	local merged = vim.tbl_deep_extend("force", config.defaults, opts or {})

	local errors = validate.validate(merged)
	if #errors > 0 then
		for _, err in ipairs(errors) do
			vim.notify(err, vim.log.levels.ERROR)
		end
		return
	end

	M.config = merged

	local km = M.config.keymaps
	if km.send then
		vim.keymap.set("n", km.send, M.send_diagnostics, {
			desc = "Send diagnostics to Claude Code tmux pane",
		})
	end

	local as = M.config.auto_send
	if as and as.enabled then
		local group = vim.api.nvim_create_augroup("CursedAutoSend", { clear = true })
		local debounce_ms = as.debounce_ms or 500
		local scope = as.scope or "buffer"
		local min_sev = as.min_severity or vim.diagnostic.severity.ERROR

		vim.api.nvim_create_autocmd(as.event or "DiagnosticChanged", {
			group = group,
			callback = function()
				if auto_send_timer then
					auto_send_timer:stop()
					auto_send_timer:close()
					auto_send_timer = nil
				end
				auto_send_timer = vim.uv.new_timer()
				auto_send_timer:start(
					debounce_ms,
					0,
					vim.schedule_wrap(function()
						if auto_send_timer then
							auto_send_timer:close()
							auto_send_timer = nil
						end
						M.send_diagnostics({ scope = scope, min_severity = min_sev, from_auto_send = true })
					end)
				)
			end,
		})
	end
end

function M.send_diagnostics(opts)
	require("cursed.diag").send(opts)
end

--- Send an arbitrary string to the configured tmux pane.
--- Useful for keymaps that send fixed commands (e.g. "/clear", "/help").
--- Respects tmux.pane_target and tmux.auto_submit from config.
--- @param text string The text to send
--- @param opts table|nil Optional overrides: pane_target (string), auto_submit (boolean)
function M.send_command(text, opts)
	opts = opts or {}
	local cfg = M.config or {}
	local tmux_cfg = cfg.tmux or {}
	local transport = require("cursed.transport").get(cfg.backend or "tmux")
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = tmux_cfg.auto_submit
	end
	transport.send(text, {
		pane_target = opts.pane_target or tmux_cfg.pane_target or "{left}",
		auto_submit = auto_submit,
	})
end

--- Open a floating preview of the formatted diagnostics.
--- Keymaps are controlled via config.keymaps (preview_send, preview_close, preview_close_esc).
function M.preview()
	local text = require("cursed.diag").format_diagnostics(0)
	if not text then
		vim.notify("No diagnostics for current buffer", vim.log.levels.INFO)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))
	vim.bo[buf].filetype = "text"
	vim.bo[buf].modifiable = true

	local width = math.min(100, vim.o.columns - 4)
	local height = math.min(30, vim.o.lines - 4)
	local km = M.config.keymaps
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = string.format(
			" cursed.nvim — preview (%s send · %s cancel) ",
			km.preview_send or "?",
			km.preview_close or "?"
		),
		title_pos = "center",
	})

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	local function set_buf_km(lhs, rhs, desc)
		if lhs then
			vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
		end
	end

	set_buf_km(km.preview_send, function()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local final_text = table.concat(lines, "\n")
		close()
		local cfg = M.config or {}
		local tmux_cfg = cfg.tmux or {}
		local backend_name = cfg.backend or "tmux"
		local statusline = require("cursed.statusline")
		vim.api.nvim_exec_autocmds(
			"User",
			{ pattern = "CursedPreSend", data = { text = final_text, backend = backend_name } }
		)
		statusline._update("sending")
		local pre_cmd, pre_delay = require("cursed.util").resolve_pre_command("preview")
		local transport = require("cursed.transport").get(backend_name)
		local ok = transport.send(final_text, {
			pane_target = tmux_cfg.pane_target or "{left}",
			auto_submit = tmux_cfg.auto_submit,
			pre_command = pre_cmd,
			pre_command_delay_ms = pre_delay,
		})
		if ok then
			vim.api.nvim_exec_autocmds(
				"User",
				{ pattern = "CursedPostSend", data = { text = final_text, backend = backend_name } }
			)
			statusline._update("sent")
		else
			vim.api.nvim_exec_autocmds(
				"User",
				{ pattern = "CursedSendFailed", data = { text = final_text, backend = backend_name } }
			)
			statusline._update("failed")
		end
	end, "Send diagnostics to Claude Code")

	set_buf_km(km.preview_close, close, "Cancel preview")
	set_buf_km(km.preview_close_esc, close, "Cancel preview")
end

function M.hello()
	vim.notify("cursed.nvim is alive!", vim.log.levels.INFO)
end

return M
