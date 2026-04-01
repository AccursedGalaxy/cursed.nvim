local M = {}

--- Send text to a tmux pane.
--- @param text string The text to paste
--- @param opts table Options: pane_target (string), auto_submit (boolean),
---                            pre_command (string|nil), pre_command_delay_ms (number|nil),
---                            paste_delay_ms (number|nil)
--- @param on_done function|nil Callback: on_done(ok) called when the operation completes
function M.send(text, opts, on_done)
	opts = opts or {}
	local pane_target = opts.pane_target
	local auto_submit = opts.auto_submit
	local pre_command = opts.pre_command
	local pre_delay = opts.pre_command_delay_ms or 300

	local tmp = vim.fn.tempname()
	local file = io.open(tmp, "w")
	if not file then
		vim.notify("cursed: failed to create temp file", vim.log.levels.ERROR)
		if on_done then
			on_done(false)
		end
		return
	end
	-- Wrap in bracketed paste sequences so embedded newlines are not interpreted
	-- as Enter keypresses by the receiving application (e.g. Claude Code / xterm.js).
	file:write("\027[200~" .. text .. "\027[201~")
	file:close()

	vim.fn.system({ "tmux", "load-buffer", "-b", "cursed_diag", tmp })
	vim.fn.delete(tmp)
	if vim.v.shell_error ~= 0 then
		vim.notify("cursed: failed to load tmux buffer (is tmux running?)", vim.log.levels.ERROR)
		if on_done then
			on_done(false)
		end
		return
	end

	if auto_submit then
		-- Chain steps as async jobs so Neovim is never blocked:
		-- (optional pre-command → pre_delay) → paste → paste_delay_ms → Enter
		-- Each tmux call is a proper argv list — no shell interpolation.
		local paste_delay_ms = opts.paste_delay_ms or 300

		local function do_enter()
			vim.defer_fn(function()
				vim.fn.jobstart({ "tmux", "send-keys", "-t", pane_target, "Enter" }, {
					on_exit = function(_, code)
						vim.schedule(function()
							if on_done then
								on_done(code == 0)
							end
						end)
					end,
				})
			end, paste_delay_ms)
		end

		local function do_paste()
			vim.fn.jobstart({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target }, {
				on_exit = function(_, code)
					if code == 0 then
						do_enter()
					else
						vim.schedule(function()
							vim.notify("cursed: failed to paste to tmux pane '" .. pane_target .. "'", vim.log.levels.ERROR)
							if on_done then
								on_done(false)
							end
						end)
					end
				end,
			})
		end

		if pre_command then
			vim.fn.jobstart({ "tmux", "send-keys", "-t", pane_target, pre_command, "Enter" }, {
				on_exit = function(_, code)
					if code ~= 0 then
						vim.schedule(function()
							vim.notify("cursed: pre-command failed (exit " .. code .. ")", vim.log.levels.ERROR)
							if on_done then
								on_done(false)
							end
						end)
					else
						vim.defer_fn(do_paste, pre_delay)
					end
				end,
			})
		else
			do_paste()
		end
	else
		if pre_command then
			-- send-keys succeeds as soon as keystrokes are delivered to the pane;
			-- it does not wait for the command to execute, so shell_error is not reliable here.
			vim.fn.system({ "tmux", "send-keys", "-t", pane_target, pre_command, "Enter" })
			-- Defer the paste so we don't block Neovim's main thread while
			-- waiting for the pre-command to be processed.
			vim.defer_fn(function()
				vim.fn.system({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target })
				if vim.v.shell_error ~= 0 then
					vim.notify("cursed: failed to paste to tmux pane '" .. pane_target .. "'", vim.log.levels.ERROR)
					if on_done then
						on_done(false)
					end
				else
					if on_done then
						on_done(true)
					end
				end
			end, pre_delay)
		else
			vim.fn.system({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target })
			if vim.v.shell_error ~= 0 then
				vim.notify("cursed: failed to paste to tmux pane '" .. pane_target .. "'", vim.log.levels.ERROR)
				if on_done then
					on_done(false)
				end
				return
			end
			if on_done then
				on_done(true)
			end
		end
	end
end

return M
