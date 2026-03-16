local M = {}

--- Get the current visual selection: raw lines + metadata.
--- Prefers an explicit line range (from a command's range) over marks, because
--- <Cmd> mappings do not exit visual mode and therefore do not commit '< / '>.
--- @param line1 number|nil First line of selection (1-based, from cmd range)
--- @param line2 number|nil Last line of selection (1-based, from cmd range)
--- @return table|nil { lines: string[], path: string, start_line: number, end_line: number }
function M.get(line1, line2)
	local bufnr = vim.api.nvim_get_current_buf()

	local start_line, end_line

	if line1 and line2 then
		start_line = math.min(line1, line2)
		end_line = math.max(line1, line2)
	else
		-- Fallback: read committed marks (only reliable when visual mode has fully exited)
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		if start_pos[2] == 0 and end_pos[2] == 0 then
			return nil
		end
		start_line = math.min(start_pos[2], end_pos[2])
		end_line = math.max(start_pos[2], end_pos[2])
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	if not lines or #lines == 0 then
		return nil
	end

	return {
		lines = lines,
		path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":."),
		start_line = start_line,
		end_line = end_line,
	}
end

local function dispatch(text, opts)
	require("cursed.util").send_to_transport(text, {
		feature = "selection",
		backend = opts.backend,
		pane_target = opts.pane_target,
		auto_submit = opts.auto_submit,
	})
end

--- Build the final message: optional user prompt, file context, raw code.
--- @param sel table Result of M.get()
--- @param prompt string|nil User's instruction (may be empty string)
--- @return string
local function build_message(sel, prompt)
	local context = string.format("File: %s, lines %d-%d:", sel.path, sel.start_line, sel.end_line)
	local code = table.concat(sel.lines, "\n")
	if prompt and prompt ~= "" then
		return prompt .. "\n\n" .. context .. "\n" .. code
	end
	return context .. "\n" .. code
end

--- Send the current visual selection to the configured backend.
--- If opts.template is set, applies that template immediately (no prompt).
--- Otherwise opens vim.ui.input so the user can type an instruction;
--- the instruction is prepended before the file context and code.
--- @param opts table|nil Optional overrides: template, pane_target, auto_submit, backend
function M.send(opts)
	opts = opts or {}

	local sel = M.get(opts.line1, opts.line2)
	if not sel then
		vim.notify("cursed: no visual selection found", vim.log.levels.INFO)
		return
	end

	-- Template path: used by :CursedSendSelection <template>
	if opts.template then
		local code = table.concat(sel.lines, "\n")
		local text = require("cursed.diag").apply_template(code, opts.template)
		dispatch(text, opts)
		return
	end

	-- Interactive path: prompt for an instruction, then send
	vim.ui.input({ prompt = "Claude: " }, function(input)
		if input == nil then
			return -- user cancelled
		end
		dispatch(build_message(sel, input), opts)
	end)
end

return M
