---@diagnostic disable: undefined-field
local highlights = require("cursed.highlights")

local expected_groups = {
	CursedFloat = "NormalFloat",
	CursedBorder = "FloatBorder",
	CursedTitle = "FloatTitle",
	CursedStatusSending = "DiagnosticWarn",
	CursedStatusSent = "DiagnosticInfo",
	CursedStatusFailed = "DiagnosticError",
}

describe("cursed.highlights", function()
	before_each(function()
		-- Clear any previous definitions so each test starts clean.
		for group, _ in pairs(expected_groups) do
			vim.api.nvim_set_hl(0, group, {})
		end
		highlights.setup()
	end)

	it("defines all plugin highlight groups as links", function()
		for group, target in pairs(expected_groups) do
			local hl = vim.api.nvim_get_hl(0, { name = group })
			assert.is_not_nil(hl.link, group .. " should be a link")
			assert.are.equal(target, hl.link, group .. " should link to " .. target)
		end
	end)

	it("re-applies groups after ColorScheme event", function()
		-- :hi clear is what colorschemes call; it truly removes custom groups,
		-- allowing our default=true definitions to take effect again.
		vim.cmd("highlight clear")

		vim.api.nvim_exec_autocmds("ColorScheme", { group = "CursedHighlights" })

		for group, target in pairs(expected_groups) do
			local hl = vim.api.nvim_get_hl(0, { name = group })
			assert.is_not_nil(hl.link, group .. " should be restored after ColorScheme")
			assert.are.equal(target, hl.link)
		end
	end)

	it("registers the CursedHighlights augroup", function()
		local id = vim.api.nvim_create_augroup("CursedHighlights", { clear = false })
		assert.is_truthy(id)
		local cmds = vim.api.nvim_get_autocmds({ group = "CursedHighlights", event = "ColorScheme" })
		assert.are.equal(1, #cmds)
	end)
end)
