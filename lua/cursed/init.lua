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

	if M.config.keymap then
		vim.keymap.set("n", M.config.keymap, M.send_diagnostics, {
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
						M.send_diagnostics({ scope = scope, min_severity = min_sev })
					end)
				)
			end,
		})
	end
end

function M.send_diagnostics(opts)
	require("cursed.diag").send(opts)
end

--- Open a floating preview of the formatted diagnostics.
--- Press <CR> to send, q/<Esc> to cancel.
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
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = " cursed.nvim — preview (<CR> send · q cancel) ",
		title_pos = "center",
	})

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	vim.keymap.set("n", "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local final_text = table.concat(lines, "\n")
		close()
		local cfg = M.config or {}
		local tmux_cfg = cfg.tmux or {}
		local transport = require("cursed.transport").get(cfg.backend or "tmux")
		transport.send(final_text, {
			pane_target = tmux_cfg.pane_target or "{left}",
			auto_submit = tmux_cfg.auto_submit,
		})
	end, { buffer = buf, desc = "Send diagnostics to Claude Code" })

	vim.keymap.set("n", "q", close, { buffer = buf, desc = "Cancel preview" })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Cancel preview" })
end

function M.hello()
	vim.notify("cursed.nvim is alive!", vim.log.levels.INFO)
end

return M
