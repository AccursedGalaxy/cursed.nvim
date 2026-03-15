local M = {}

local severity_labels = {
	[vim.diagnostic.severity.ERROR] = "ERROR",
	[vim.diagnostic.severity.WARN] = "WARN",
	[vim.diagnostic.severity.INFO] = "INFO",
	[vim.diagnostic.severity.HINT] = "HINT",
}

-- ── helpers ──────────────────────────────────────────────────────────────────

local function get_source_line(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
	return lines[1]
end

local function collect_diags(scope, bufnr, min_severity)
	local diags = {}

	if scope == "all_buffers" then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				vim.list_extend(diags, vim.diagnostic.get(buf))
			end
		end
	elseif scope == "workspace" then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) and #vim.lsp.get_clients({ bufnr = buf }) > 0 then
				vim.list_extend(diags, vim.diagnostic.get(buf))
			end
		end
	else
		diags = vim.diagnostic.get(bufnr)
	end

	if min_severity ~= nil then
		diags = vim.tbl_filter(function(d)
			return d.severity <= min_severity
		end, diags)
	end

	return diags
end

-- ── formatters ───────────────────────────────────────────────────────────────

local function fmt_default(diags, bufnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local lines = { "Diagnostics for " .. path .. ":" }
	for _, d in ipairs(diags) do
		local label = severity_labels[d.severity] or "INFO"
		local source = d.source and ("  (" .. d.source .. ")") or ""
		local msg = d.message:gsub("\n", " ")
		lines[#lines + 1] = string.format("[%-5s] %d:%d  %s%s", label, d.lnum + 1, d.col + 1, msg, source)
	end
	return table.concat(lines, "\n")
end

local function fmt_compact(diags, bufnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local lines = {}
	for _, d in ipairs(diags) do
		local label = severity_labels[d.severity] or "INFO"
		local msg = d.message:gsub("\n", " ")
		lines[#lines + 1] = string.format("%s:%d:%d: %s: %s", path, d.lnum + 1, d.col + 1, label, msg)
	end
	return table.concat(lines, "\n")
end

local function fmt_with_source_lines(diags, bufnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local lines = { "Diagnostics for " .. path .. ":" }
	for _, d in ipairs(diags) do
		local label = severity_labels[d.severity] or "INFO"
		local source = d.source and ("  (" .. d.source .. ")") or ""
		local msg = d.message:gsub("\n", " ")
		lines[#lines + 1] = string.format("[%-5s] %d:%d  %s%s", label, d.lnum + 1, d.col + 1, msg, source)
		local src_buf = d.bufnr or bufnr
		local src_line = get_source_line(src_buf, d.lnum)
		if src_line then
			lines[#lines + 1] = "  > " .. src_line
		end
	end
	return table.concat(lines, "\n")
end

local function fmt_custom(diags, bufnr, fn)
	local lines = {}
	for _, d in ipairs(diags) do
		local result = fn(d, bufnr)
		if result then
			lines[#lines + 1] = result
		end
	end
	return table.concat(lines, "\n")
end

local function format_buf(diags, bufnr, fmt)
	if fmt == "compact" then
		return fmt_compact(diags, bufnr)
	elseif fmt == "with_source_lines" then
		return fmt_with_source_lines(diags, bufnr)
	elseif type(fmt) == "function" then
		return fmt_custom(diags, bufnr, fmt)
	else
		return fmt_default(diags, bufnr)
	end
end

local function format_multi_buf(diags, fmt)
	local by_buf = {}
	local buf_order = {}
	for _, d in ipairs(diags) do
		local bn = d.bufnr or 0
		if not by_buf[bn] then
			by_buf[bn] = {}
			table.insert(buf_order, bn)
		end
		table.insert(by_buf[bn], d)
	end

	local sections = {}
	for _, bn in ipairs(buf_order) do
		local buf_diags = by_buf[bn]
		table.sort(buf_diags, function(a, b)
			if a.lnum ~= b.lnum then
				return a.lnum < b.lnum
			end
			return a.col < b.col
		end)
		table.insert(sections, format_buf(buf_diags, bn, fmt))
	end
	return table.concat(sections, "\n\n")
end

-- ── public API ───────────────────────────────────────────────────────────────

--- Format diagnostics for the given buffer and options.
--- Exported so tests can call it directly.
--- @param bufnr number Buffer number (0 = current)
--- @param opts table Optional overrides: scope, min_severity, format
--- @return string|nil Formatted text, or nil if no diagnostics match
function M.format_diagnostics(bufnr, opts)
	opts = opts or {}
	local cfg = (require("cursed").config) or {}
	bufnr = bufnr or 0

	local scope = opts.scope or cfg.scope or "buffer"
	local min_severity = opts.min_severity
	if min_severity == nil then
		min_severity = cfg.min_severity
	end
	local fmt = opts.format or cfg.format or "default"

	local diags = collect_diags(scope, bufnr, min_severity)
	if #diags == 0 then
		return nil
	end

	if scope == "buffer" then
		table.sort(diags, function(a, b)
			if a.lnum ~= b.lnum then
				return a.lnum < b.lnum
			end
			return a.col < b.col
		end)
		return format_buf(diags, bufnr, fmt)
	else
		return format_multi_buf(diags, fmt)
	end
end

local function apply_template(text, template_name)
	local cfg = (require("cursed").config) or {}
	local templates = cfg.templates or {}
	local tpl = templates[template_name]
	if not tpl then
		return text
	end
	-- Use a function replacement so % in the diagnostics text is never
	-- interpreted as a gsub capture reference (e.g. %1 in error messages).
	return (tpl:gsub("{diagnostics}", function() return text end))
end

local function fire(event, data)
	vim.api.nvim_exec_autocmds("User", { pattern = event, data = data })
end

--- Send diagnostics to the configured backend.
--- @param opts table Optional overrides: scope, min_severity, format, template, pane_target, auto_submit, backend
function M.send(opts)
	opts = opts or {}
	local cursed = require("cursed")
	local cfg = cursed.config or {}
	local tmux_cfg = cfg.tmux or {}

	local backend_name = opts.backend or cfg.backend or "tmux"
	local pane_target = opts.pane_target or tmux_cfg.pane_target or "{left}"
	local auto_submit = opts.auto_submit
	if auto_submit == nil then
		auto_submit = tmux_cfg.auto_submit
	end
	if auto_submit == nil then
		auto_submit = true
	end

	local text = M.format_diagnostics(0, opts)
	if not text then
		vim.notify("No diagnostics for current buffer", vim.log.levels.INFO)
		return
	end

	local template_name = opts.template or cfg.default_template
	if template_name then
		text = apply_template(text, template_name)
	end

	fire("CursedPreSend", { text = text, backend = backend_name })

	local transport = require("cursed.transport").get(backend_name)
	local ok = transport.send(text, { pane_target = pane_target, auto_submit = auto_submit })

	if ok then
		fire("CursedPostSend", { text = text, backend = backend_name })
		require("cursed.statusline")._update("sent")
	else
		fire("CursedSendFailed", { text = text, backend = backend_name })
		require("cursed.statusline")._update("failed")
	end
end

return M
