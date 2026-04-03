local M = {}

-- ── highlight group → default link target ─────────────────────────────────────

local links = {
	-- Preview float
	CursedFloat = "NormalFloat",
	CursedBorder = "FloatBorder",
	CursedTitle = "FloatTitle",
	-- Statusline states
	CursedStatusSending = "DiagnosticWarn",
	CursedStatusSent = "DiagnosticInfo",
	CursedStatusFailed = "DiagnosticError",
}

local function apply()
	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { default = true, link = target })
	end
end

--- Define all plugin highlight groups and register a ColorScheme autocmd so
--- they are re-applied whenever the user switches colorschemes.
--- Groups are created with `default = true`, so explicit user overrides win.
function M.setup()
	apply()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("CursedHighlights", { clear = true }),
		callback = apply,
	})
end

return M
