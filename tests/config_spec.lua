---@diagnostic disable: undefined-field, need-check-nil
local validate = require("cursed.validate")

describe("cursed.validate", function()
	it("accepts a fully valid config", function()
		local errors = validate.validate({
			backend = "tmux",
			tmux = { pane_target = "{left}", auto_submit = true },
			scope = "buffer",
			min_severity = vim.diagnostic.severity.HINT,
			format = "default",
			keymap = "<leader>cd",
			templates = { fix = "Fix: {diagnostics}" },
			default_template = "fix",
			auto_send = {
				enabled = false,
				event = "DiagnosticChanged",
				debounce_ms = 500,
				min_severity = vim.diagnostic.severity.ERROR,
				scope = "buffer",
			},
		})
		assert.are.equal(0, #errors)
	end)

	it("accepts an empty config (all defaults apply)", function()
		local errors = validate.validate({})
		assert.are.equal(0, #errors)
	end)

	it("allows nil keymap", function()
		local errors = validate.validate({ keymap = nil })
		assert.are.equal(0, #errors)
	end)

	it("errors when keymap is not a string", function()
		local errors = validate.validate({ keymap = true })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("keymap"))
	end)

	it("errors when tmux.auto_submit is a string instead of boolean", function()
		local errors = validate.validate({ tmux = { auto_submit = "yes" } })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("auto_submit"))
		assert.truthy(errors[1]:find("boolean"))
		assert.truthy(errors[1]:find("string"))
	end)

	it("errors when tmux.pane_target is not a string", function()
		local errors = validate.validate({ tmux = { pane_target = 42 } })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("pane_target"))
	end)

	it("errors when backend is an invalid value", function()
		local errors = validate.validate({ backend = "wezterm" })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("backend"))
	end)

	it("errors when backend is not a string", function()
		local errors = validate.validate({ backend = 99 })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("backend"))
	end)

	it("errors on invalid scope value", function()
		local errors = validate.validate({ scope = "all" })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("scope"))
	end)

	it("accepts all valid scope values", function()
		for _, s in ipairs({ "buffer", "all_buffers", "workspace" }) do
			local errors = validate.validate({ scope = s })
			assert.are.equal(0, #errors, "scope '" .. s .. "' should be valid")
		end
	end)

	it("errors when format is an invalid string", function()
		local errors = validate.validate({ format = "fancy" })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("format"))
	end)

	it("accepts a function as format", function()
		local errors = validate.validate({ format = function() end })
		assert.are.equal(0, #errors)
	end)

	it("accepts all valid format string values", function()
		for _, f in ipairs({ "default", "compact", "with_source_lines" }) do
			local errors = validate.validate({ format = f })
			assert.are.equal(0, #errors, "format '" .. f .. "' should be valid")
		end
	end)

	it("errors on multiple invalid fields and reports all of them", function()
		local errors = validate.validate({
			auto_send = {
				enabled = "yes", -- should be boolean
				debounce_ms = "500", -- should be number
			},
		})
		assert.are.equal(2, #errors)
	end)

	it("errors when auto_send.scope is invalid", function()
		local errors = validate.validate({ auto_send = { scope = "global" } })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("auto_send.scope"))
	end)

	it("errors when min_severity is not a number", function()
		local errors = validate.validate({ min_severity = "ERROR" })
		assert.are.equal(1, #errors)
		assert.truthy(errors[1]:find("min_severity"))
	end)
end)
