---@diagnostic disable: duplicate-set-field, undefined-field, need-check-nil
local diag = require("cursed.diag")
local config = require("cursed.config")

-- Bootstrap a minimal config so config.get() doesn't error in tests.
config._set(vim.tbl_deep_extend("force", config.defaults, {}))

describe("cursed.diag.format_diagnostics()", function()
	local orig_get, orig_name, orig_get_lines

	before_each(function()
		orig_get = vim.diagnostic.get
		orig_name = vim.api.nvim_buf_get_name
		orig_get_lines = vim.api.nvim_buf_get_lines
	end)

	after_each(function()
		vim.diagnostic.get = orig_get
		vim.api.nvim_buf_get_name = orig_name
		vim.api.nvim_buf_get_lines = orig_get_lines
	end)

	it("returns nil when there are no diagnostics", function()
		vim.diagnostic.get = function()
			return {}
		end
		local result = diag.format_diagnostics(0, { scope = "buffer" })
		assert.is_nil(result)
	end)

	it("returns nil when all diagnostics are filtered by min_severity", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.HINT, message = "hint only", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, {
			scope = "buffer",
			min_severity = vim.diagnostic.severity.ERROR,
		})
		assert.is_nil(result)
	end)

	it("sorts diagnostics by line then column", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 5, col = 3, severity = vim.diagnostic.severity.ERROR, message = "third", bufnr = 0 },
				{ lnum = 2, col = 1, severity = vim.diagnostic.severity.ERROR, message = "first", bufnr = 0 },
				{ lnum = 2, col = 5, severity = vim.diagnostic.severity.ERROR, message = "second", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, { scope = "buffer" })
		assert.is_not_nil(result)
		local lines = vim.split(result, "\n")
		-- Line 0 is the header; lines 1-3 are the diagnostics (1-indexed in output)
		assert.truthy(lines[2]:find("first"), "first diag should be second line")
		assert.truthy(lines[3]:find("second"), "second diag should be third line")
		assert.truthy(lines[4]:find("third"), "third diag should be fourth line")
	end)

	it("outputs 1-indexed line and column numbers", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "at origin", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, { scope = "buffer" })
		-- 0-indexed lnum=0, col=0 → 1-indexed 1:1
		assert.truthy(result:find("1:1"), "expected 1:1 in output, got: " .. tostring(result))
	end)

	it("filters diagnostics by min_severity", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "an error", bufnr = 0 },
				{ lnum = 1, col = 0, severity = vim.diagnostic.severity.HINT, message = "just a hint", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, {
			scope = "buffer",
			min_severity = vim.diagnostic.severity.ERROR,
		})
		assert.is_not_nil(result)
		assert.truthy(result:find("an error"))
		assert.falsy(result:find("just a hint"))
	end)

	it("embeds source lines in with_source_lines format", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "nil value", bufnr = 0 },
			}
		end
		vim.api.nvim_buf_get_lines = function(_, _, _, _)
			return { "local x = nil" }
		end
		local result = diag.format_diagnostics(0, { scope = "buffer", format = "with_source_lines" })
		assert.is_not_nil(result)
		assert.truthy(result:find("local x = nil"), "expected source line in output")
		assert.truthy(result:find("> "), "expected '> ' prefix for source line")
	end)

	it("compact format omits the header line", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.WARN, message = "warn msg", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, { scope = "buffer", format = "compact" })
		assert.is_not_nil(result)
		assert.falsy(result:find("^Diagnostics for"), "compact format should not have header")
		assert.truthy(result:find("WARN"))
		assert.truthy(result:find("warn msg"))
	end)

	it("accepts a custom format function", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 3, col = 7, severity = vim.diagnostic.severity.ERROR, message = "custom", bufnr = 0 },
			}
		end
		local result = diag.format_diagnostics(0, {
			scope = "buffer",
			format = function(d, _)
				return "custom:" .. d.message
			end,
		})
		assert.is_not_nil(result)
		assert.are.equal("custom:custom", result)
	end)

	it("raises a clear cursed error when format function returns a non-string", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "oops", bufnr = 0 },
			}
		end
		local ok, err = pcall(diag.format_diagnostics, 0, {
			scope = "buffer",
			format = function(_, _)
				return { "not", "a", "string" }
			end,
		})
		assert.is_false(ok)
		assert.truthy(err:find("cursed:"), "error should start with cursed:")
		assert.truthy(err:find("format function"), "error should mention format function")
		assert.truthy(err:find("table"), "error should mention the bad return type")
	end)

	it("raises a clear cursed error when format function itself errors", function()
		vim.api.nvim_buf_get_name = function()
			return "/test/file.lua"
		end
		vim.diagnostic.get = function()
			return {
				{ lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "oops", bufnr = 0 },
			}
		end
		local ok, err = pcall(diag.format_diagnostics, 0, {
			scope = "buffer",
			format = function(_, _)
				error("boom from user fn")
			end,
		})
		assert.is_false(ok)
		assert.truthy(err:find("cursed:"), "error should start with cursed:")
		assert.truthy(err:find("format function"), "error should mention format function")
		assert.truthy(err:find("boom from user fn"), "error should include original message")
	end)
end)
