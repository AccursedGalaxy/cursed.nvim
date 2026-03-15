local cursed = require("cursed")

describe("cursed", function()
	before_each(function()
		cursed.setup()
	end)

	it("setup() merges config with defaults", function()
		cursed.setup({ custom_opt = true })
		assert.is_not_nil(cursed.config)
		assert.is_true(cursed.config.custom_opt)
	end)

	it("setup() works with no arguments", function()
		assert.has_no.errors(function()
			cursed.setup()
		end)
	end)

	it("hello() is a callable function", function()
		assert.is_function(cursed.hello)
	end)
end)
