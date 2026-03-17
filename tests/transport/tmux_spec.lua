---@diagnostic disable: duplicate-set-field, undefined-field, need-check-nil
local tmux = require("cursed.transport.tmux")

-- Helper: check that a cmd list (table) contains all given strings.
local function cmd_contains(cmd_list, ...)
	local args = { ... }
	for _, v in ipairs(args) do
		local found = false
		for _, c in ipairs(cmd_list) do
			if c == v then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

describe("cursed.transport.tmux.send()", function()
	local orig_io_open, orig_system, orig_jobstart, orig_delete, orig_tempname
	local orig_defer_fn, orig_schedule, orig_notify, orig_vim_v

	local notifications, system_calls, jobstart_calls

	local default_opts = { pane_target = "test_pane", auto_submit = false }

	before_each(function()
		notifications, system_calls, jobstart_calls = {}, {}, {}

		orig_io_open  = io.open
		orig_system   = vim.fn.system
		orig_jobstart = vim.fn.jobstart
		orig_delete   = vim.fn.delete
		orig_tempname = vim.fn.tempname
		orig_defer_fn = vim.defer_fn
		orig_schedule = vim.schedule
		orig_notify   = vim.notify
		orig_vim_v    = vim.v

		-- Replace vim.v with a plain table so shell_error is writable in tests
		vim.v = setmetatable({ shell_error = 0 }, { __index = orig_vim_v })

		-- Default stubs (happy path)
		vim.fn.tempname = function() return "/tmp/cursed_test_tmp" end
		vim.fn.delete   = function() end
		vim.defer_fn    = function(fn, _) fn() end -- call immediately, no real timer
		vim.schedule    = function(fn) fn() end
		vim.notify      = function(msg, level)
			table.insert(notifications, { msg = msg, level = level })
		end

		-- io.open: fake file handle
		io.open = function(_, _)
			return { write = function() end, close = function() end }
		end

		-- vim.fn.system: capture calls, default to success (shell_error = 0)
		vim.fn.system = function(cmd)
			table.insert(system_calls, cmd)
			vim.v.shell_error = 0
			return ""
		end

		-- vim.fn.jobstart: capture calls, immediately fire on_exit with code=0
		vim.fn.jobstart = function(cmd, opts)
			table.insert(jobstart_calls, { cmd = cmd, opts = opts })
			if opts and opts.on_exit then
				opts.on_exit(1, 0)
			end
			return 1
		end
	end)

	after_each(function()
		io.open         = orig_io_open
		vim.fn.system   = orig_system
		vim.fn.jobstart = orig_jobstart
		vim.fn.delete   = orig_delete
		vim.fn.tempname = orig_tempname
		vim.defer_fn    = orig_defer_fn
		vim.schedule    = orig_schedule
		vim.notify      = orig_notify
		vim.v           = orig_vim_v
	end)

	-- 1. Temp file error
	it("returns false and notifies when io.open fails", function()
		io.open = function(_, _) return nil end
		local ok
		tmux.send("hello", default_opts, function(result) ok = result end)
		assert.is_false(ok)
		assert.equals(1, #notifications)
		assert.truthy(notifications[1].msg:find("temp file"))
	end)

	-- 2. Buffer load failure
	it("returns false and notifies when tmux load-buffer fails", function()
		vim.fn.system = function(cmd)
			table.insert(system_calls, cmd)
			vim.v.shell_error = 1
			return ""
		end
		local ok
		tmux.send("hello", default_opts, function(result) ok = result end)
		assert.is_false(ok)
		assert.equals(1, #notifications)
		assert.truthy(notifications[1].msg:find("load tmux buffer"))
	end)

	-- 3. Sync mode, no pre_command: paste-buffer succeeds
	it("calls paste-buffer via system and returns true", function()
		local ok
		tmux.send("hello", default_opts, function(result) ok = result end)
		assert.is_true(ok)
		-- At least one system call should be paste-buffer
		local found = false
		for _, call in ipairs(system_calls) do
			if cmd_contains(call, "paste-buffer") then
				found = true
				break
			end
		end
		assert.is_true(found, "expected a paste-buffer call in system_calls")
	end)

	-- 4. Sync mode, no pre_command: paste-buffer fails
	it("returns false and notifies when paste-buffer fails", function()
		local call_count = 0
		vim.fn.system = function(cmd)
			table.insert(system_calls, cmd)
			call_count = call_count + 1
			-- First call is load-buffer (success), second is paste-buffer (fail)
			vim.v.shell_error = (call_count >= 2) and 1 or 0
			return ""
		end
		local ok
		tmux.send("hello", default_opts, function(result) ok = result end)
		assert.is_false(ok)
		assert.equals(1, #notifications)
		assert.truthy(notifications[1].msg:find("failed to paste"))
	end)

	-- 5. Sync mode, with pre_command
	it("calls send-keys then deferred paste when pre_command is set", function()
		local opts = { pane_target = "test_pane", auto_submit = false, pre_command = "clear" }
		local ok
		tmux.send("hello", opts, function(result) ok = result end)
		assert.is_true(ok)
		-- system_calls[1] = load-buffer
		-- system_calls[2] = send-keys + "clear"
		-- system_calls[3] = paste-buffer (from deferred fn, fires immediately in test)
		assert.is_true(cmd_contains(system_calls[2], "send-keys", "clear"),
			"expected send-keys + clear in system_calls[2]")
		assert.is_true(cmd_contains(system_calls[3], "paste-buffer"),
			"expected paste-buffer in system_calls[3]")
	end)

	-- 6. Async mode, no pre_command: paste then Enter
	it("chains paste jobstart then deferred Enter jobstart", function()
		local opts = { pane_target = "test_pane", auto_submit = true }
		local ok
		tmux.send("hello", opts, function(result) ok = result end)
		assert.is_true(ok)
		assert.is_true(#jobstart_calls >= 2, "expected at least 2 jobstart calls")
		assert.is_true(cmd_contains(jobstart_calls[1].cmd, "paste-buffer"),
			"first jobstart should be paste-buffer")
		assert.is_true(cmd_contains(jobstart_calls[2].cmd, "Enter"),
			"second jobstart should send Enter")
	end)

	-- 7. Async mode, paste job exits non-zero
	it("notifies error when paste job exits non-zero", function()
		vim.fn.jobstart = function(cmd, opts)
			table.insert(jobstart_calls, { cmd = cmd, opts = opts })
			if opts and opts.on_exit then
				opts.on_exit(1, 1) -- non-zero exit
			end
			return 1
		end
		local opts = { pane_target = "test_pane", auto_submit = true }
		tmux.send("hello", opts)
		assert.equals(1, #notifications)
		assert.truthy(notifications[1].msg:find("failed to paste"))
	end)

	-- 8. Async mode, with pre_command: send-keys → paste → Enter
	it("sends pre_command via jobstart then chains paste then Enter", function()
		local opts = { pane_target = "test_pane", auto_submit = true, pre_command = "clear" }
		tmux.send("hello", opts)
		assert.is_true(#jobstart_calls >= 3, "expected at least 3 jobstart calls")
		assert.is_true(cmd_contains(jobstart_calls[1].cmd, "send-keys", "clear"),
			"first jobstart should be send-keys + pre_command")
		assert.is_true(cmd_contains(jobstart_calls[2].cmd, "paste-buffer"),
			"second jobstart should be paste-buffer")
		assert.is_true(cmd_contains(jobstart_calls[3].cmd, "Enter"),
			"third jobstart should send Enter")
	end)
end)
