local M = {}

local config = require("cursed.config")
local validate = require("cursed.validate")

local auto_send_timer = nil

local function teardown_auto_send()
	if auto_send_timer then
		auto_send_timer:stop()
		auto_send_timer:close()
		auto_send_timer = nil
	end
	-- Clear the augroup so any previously-registered autocmd stops firing.
	vim.api.nvim_create_augroup("CursedAutoSend", { clear = true })
end

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
	config._set(merged)

	teardown_auto_send()

	local km = M.config.keymaps
	if km.send then
		vim.keymap.set("n", km.send, M.send_diagnostics, {
			desc = "Send diagnostics to Claude Code tmux pane",
		})
	end
	if km.send_selection then
		vim.keymap.set("x", km.send_selection, ":CursedSendSelection<CR>", {
			silent = true,
			desc = "Send visual selection to Claude Code tmux pane",
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

function M.send_selection(opts)
	require("cursed.selection").send(opts)
end

--- Send an arbitrary string to the configured tmux pane.
--- Useful for keymaps that send fixed commands (e.g. "/clear", "/help").
--- Respects tmux.pane_target and tmux.auto_submit from config.
--- @param text string The text to send
--- @param opts table|nil Optional overrides: pane_target (string), auto_submit (boolean)
function M.send_command(text, opts)
	opts = opts or {}
	require("cursed.util").send_to_transport(text, {
		feature = "send",
		pane_target = opts.pane_target,
		auto_submit = opts.auto_submit,
	})
end

function M.preview()
	require("cursed.preview").open()
end

function M.hello()
	vim.notify("cursed.nvim is alive!", vim.log.levels.INFO)
end

return M
