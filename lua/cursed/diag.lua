local M = {}

local severity_labels = {
	[vim.diagnostic.severity.ERROR] = "ERROR",
	[vim.diagnostic.severity.WARN] = "WARN",
	[vim.diagnostic.severity.INFO] = "INFO",
	[vim.diagnostic.severity.HINT] = "HINT",
}

local function format_diagnostics(bufnr)
	local diags = vim.diagnostic.get(bufnr)
	if #diags == 0 then
		return nil
	end

	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local lines = { "Diagnostics for " .. path .. ":" }

	table.sort(diags, function(a, b)
		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		return a.col < b.col
	end)

	for _, d in ipairs(diags) do
		local label = severity_labels[d.severity] or "INFO"
		local source = d.source and ("  (" .. d.source .. ")") or ""
		local msg = d.message:gsub("\n", " ")
		lines[#lines + 1] = string.format(
			"[%-5s] %d:%d  %s%s",
			label,
			d.lnum + 1,
			d.col + 1,
			msg,
			source
		)
	end

	return table.concat(lines, "\n")
end

function M.send(opts)
	opts = opts or {}
	local cursed = require("cursed")
	local tmux_cfg = (cursed.config and cursed.config.tmux) or {}
	local pane_target = opts.pane_target or tmux_cfg.pane_target or "{left}"
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = tmux_cfg.auto_submit
	end
	if auto_submit == nil then
		auto_submit = true
	end

	local text = format_diagnostics(0)
	if not text then
		vim.notify("No diagnostics for current buffer", vim.log.levels.INFO)
		return
	end

	local tmp = vim.fn.tempname()
	vim.fn.writefile(vim.split(text, "\n"), tmp)
	vim.fn.system({ "tmux", "load-buffer", "-b", "cursed_diag", tmp })
	vim.fn.delete(tmp)
	vim.fn.system({ "tmux", "select-pane", "-t", pane_target })
	vim.fn.system({ "tmux", "paste-buffer", "-b", "cursed_diag", "-t", pane_target })
	if auto_submit then
		vim.uv.sleep(50)
		vim.fn.system({ "tmux", "send-keys", "-t", pane_target, "", "Enter" })
	end
end

return M
