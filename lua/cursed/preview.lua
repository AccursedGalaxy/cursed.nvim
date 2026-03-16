local M = {}

--- Open a floating preview of the formatted diagnostics.
--- The user can edit the text before sending. Keymaps are controlled via
--- config.keymaps (preview_send, preview_close, preview_close_esc).
function M.open()
	local ok, text = pcall(require("cursed.diag").format_diagnostics, 0)
	if not ok then
		vim.notify(tostring(text), vim.log.levels.ERROR)
		return
	end
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
	local km = require("cursed.config").get().keymaps or {}
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
		require("cursed.util").send_to_transport(final_text, { feature = "preview" })
	end, "Send diagnostics to Claude Code")

	set_buf_km(km.preview_close, close, "Cancel preview")
	set_buf_km(km.preview_close_esc, close, "Cancel preview")
end

return M
