local M = {}

M.defaults = {
	model = "qwen2.5-coder:7b",
	backend_url = "http://localhost:11434",
	max_tokens = 150,
	temperature = 0.2,
	debounce_ms = 400,
	lines_above = 20,
	lines_below = 5,

	-- System prompt sent on every request. Ollama caches the KV state for a
	-- fixed system prompt, so keeping it identical across requests is important
	-- for performance. Override in setup() only if you know what you're doing.
	system_prompt = [[You are a code completion engine embedded in a text editor.

The user's file is shown with a <CURSOR> marker where their cursor is. Your job is to predict what code belongs immediately after the cursor.

Rules — follow them exactly:
- Output ONLY the raw code to insert. Nothing else.
- No markdown. No code fences. No backticks. No language tags.
- No explanations, comments, or prose.
- Do not repeat any code that appears before <CURSOR>.
- Match the indentation, naming style, and patterns of the surrounding code.
- Stop as soon as the immediate logical unit is complete (one expression, one statement, one short block).
- If nothing meaningful can be inferred, output a single newline.

BAD output (never do this):
```lua
M.setup = function() ... end
```
Here is the completion: M.setup = function() ...

GOOD output (exactly like this):
M.setup = function()
  config.init()
end]],
}

function M.get()
	return M.defaults
end

return M
