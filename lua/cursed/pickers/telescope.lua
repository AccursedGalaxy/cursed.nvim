local M = {}

--- Open a Telescope picker to select individual diagnostics to send.
--- Only call this if telescope.nvim is installed.
function M.pick()
	local ok_tel, _ = pcall(require, "telescope")
	if not ok_tel then
		vim.notify("cursed: telescope.nvim is required for :CursedPick", vim.log.levels.ERROR)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local sev_names = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}

	local entries = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			for _, d in ipairs(vim.diagnostic.get(buf)) do
				local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
				local label = sev_names[d.severity] or "INFO"
				local msg = d.message:gsub("\n", " ")
				table.insert(entries, {
					display = string.format("[%s] %s:%d:%d  %s", label, path, d.lnum + 1, d.col + 1, msg),
					bufnr = buf,
					path = path,
					diag = d,
					label = label,
				})
			end
		end
	end

	if #entries == 0 then
		vim.notify("cursed: no diagnostics found", vim.log.levels.INFO)
		return
	end

	pickers
		.new({}, {
			prompt_title = "Select Diagnostic to Send",
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return { value = entry, display = entry.display, ordinal = entry.display }
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local sel = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not sel then
						return
					end
					local e = sel.value
					local d = e.diag
					local text = string.format(
						"Diagnostics for %s:\n[%-5s] %d:%d  %s",
						e.path,
						e.label,
						d.lnum + 1,
						d.col + 1,
						d.message:gsub("\n", " ")
					)
					local cursed = require("cursed")
					local cfg = cursed.config or {}
					local tmux_cfg = cfg.tmux or {}
					local transport = require("cursed.transport").get(cfg.backend or "tmux")
					transport.send(text, {
						pane_target = tmux_cfg.pane_target or "{left}",
						auto_submit = tmux_cfg.auto_submit,
					})
				end)
				return true
			end,
		})
		:find()
end

return M
