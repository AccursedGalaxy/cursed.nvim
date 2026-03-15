local M = {}

--- Send text to a tmux pane.
--- @param text string The text to paste
--- @param opts table Options: pane_target (string), auto_submit (boolean)
--- @return boolean ok true on success
function M.send(text, opts)
	opts = opts or {}
	local pane_target = opts.pane_target or "{left}"
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = true
	end

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
		-- Run paste → sleep → Enter as a single async shell job so Neovim is
		-- never blocked. The shell sleep gives Claude Code enough time to finish
		-- processing the bracketed paste before Enter arrives. A synchronous
		-- send-keys immediately after paste-buffer races with Claude Code's
		-- input handler and loses; 300ms is generous and imperceptible.
		local t = vim.fn.shellescape(pane_target)
		vim.fn.jobstart({
			"sh", "-c",
			"tmux paste-buffer -b cursed_diag -t " .. t .. " && sleep 0.3 && tmux send-keys -t " .. t .. " Enter",
		})
	else
		vim.fn.system({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target })
		if vim.v.shell_error ~= 0 then
			vim.notify("cursed: failed to paste to tmux pane '" .. pane_target .. "'", vim.log.levels.ERROR)
			return false
		end
	end

	return true
end

return M
