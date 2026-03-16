local M = {}

--- Send text to a tmux pane.
--- @param text string The text to paste
--- @param opts table Options: pane_target (string), auto_submit (boolean),
---                            pre_command (string|nil), pre_command_delay_ms (number|nil)
--- @return boolean ok true on success
function M.send(text, opts)
	opts = opts or {}
	local pane_target = opts.pane_target or "{left}"
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = true
	end
	local pre_command = opts.pre_command
	local pre_delay = opts.pre_command_delay_ms or 300

	local tmp = vim.fn.tempname()
	local file = io.open(tmp, "w")
	if not file then
		vim.notify("cursed: failed to create temp file", vim.log.levels.ERROR)
		return false
	end
	file:write(text)
	file:close()

	vim.fn.system({ "tmux", "load-buffer", "-b", "cursed_diag", tmp })
	vim.fn.delete(tmp)
	if vim.v.shell_error ~= 0 then
		vim.notify("cursed: failed to load tmux buffer (is tmux running?)", vim.log.levels.ERROR)
		return false
	end

	if auto_submit then
		-- Run (optional pre-command →) paste → sleep → Enter as a single async
		-- shell job so Neovim is never blocked. The shell sleep gives Claude Code
		-- enough time to finish processing the bracketed paste before Enter
		-- arrives; 300ms is generous and imperceptible.
		local t = vim.fn.shellescape(pane_target)
		local pre = ""
		if pre_command then
			local delay_s = string.format("%.3f", pre_delay / 1000)
			pre = "tmux send-keys -t " .. t .. " " .. vim.fn.shellescape(pre_command) .. " Enter && sleep " .. delay_s .. " && "
		end
		vim.fn.jobstart({
			"sh", "-c",
			pre .. "tmux paste-buffer -b cursed_diag -t " .. t .. " && sleep 0.3 && tmux send-keys -t " .. t .. " Enter",
		})
	else
		if pre_command then
			vim.fn.system({ "tmux", "send-keys", "-t", pane_target, pre_command, "Enter" })
			vim.fn.system({ "sleep", string.format("%.3f", pre_delay / 1000) })
		end
		vim.fn.system({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target })
		if vim.v.shell_error ~= 0 then
			vim.notify("cursed: failed to paste to tmux pane '" .. pane_target .. "'", vim.log.levels.ERROR)
			return false
		end
	end

	return true
end

return M
