local source = {}

function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts or {}
	self._req_id = 0        -- generation counter for cancellation
	self._timer = nil       -- debounce timer handle
	self._cancel_tcp = nil  -- cancel function for the in-flight TCP request
	return self
end

function source:get_completions(ctx, callback)
	local inference = require("cursed.inference")
	local context   = require("cursed.context")
	local cfg       = require("cursed.config").get()

	self._req_id = self._req_id + 1
	local my_id = self._req_id

	-- cancel any pending debounce timer or in-flight TCP request
	if self._timer then
		self._timer:stop()
		self._timer:close()
		self._timer = nil
	end
	if self._cancel_tcp then
		self._cancel_tcp()
		self._cancel_tcp = nil
	end

	-- capture prompt and keyword now (cursor position correct here, before the delay)
	local prompt = context.get_context()
	-- keyword = the text the user has typed in the current word (e.g. "T" when typing " -- T")
	-- used as filterText so blink's fuzzy filter always considers the item a match
	local keyword = ctx.line:sub(ctx.bounds.start_col, ctx.bounds.start_col + ctx.bounds.length - 1)

	-- debounce: wait for the user to stop typing before hitting Ollama
	self._timer = vim.uv.new_timer()
	self._timer:start(cfg.debounce_ms, 0, vim.schedule_wrap(function()
		self._timer:stop()
		self._timer:close()
		self._timer = nil

		if my_id ~= self._req_id then return end  -- cancelled while waiting

		self._cancel_tcp = inference.complete(prompt, function(result, err)
			if my_id ~= self._req_id then return end  -- cancelled during inference
			if err or not result or result == "" then
				callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
				return
			end

			-- Trim leading/trailing whitespace; take first line for label
			result = result:match("^%s*(.-)%s*$")
			local label = result:match("^[^\n]*") or result

			-- cursor: nvim returns {row (1-indexed), col (0-indexed)}; LSP range needs 0-indexed line
			local line = ctx.cursor[1] - 1
			local col  = ctx.cursor[2]

			callback({
				items = {
					{
						label        = label,
						insertText   = result,
						filterText   = keyword, -- typed keyword at trigger time; ensures blink's fuzzy filter always matches
						sortText     = "\001",  -- float to top
						score_offset = 100,
						kind         = vim.lsp.protocol.CompletionItemKind.Text,
						-- textEdit range: insert at cursor (not replacing word)
						textEdit = {
							newText = result,
							range = {
								start   = { line = line, character = col },
								["end"] = { line = line, character = col },
							},
						},
					},
				},
				is_incomplete_backward = false,
				is_incomplete_forward  = false,
			})
		end)
	end))

	-- cancel: bump id, stop timer, and close the TCP socket so Ollama stops generating
	return function()
		self._req_id = self._req_id + 1
		if self._timer then
			self._timer:stop()
			self._timer:close()
			self._timer = nil
		end
		if self._cancel_tcp then
			self._cancel_tcp()
			self._cancel_tcp = nil
		end
	end
end

return source
