local M = {}

M.defaults = {
	model = "qwen2.5-coder:7b",
	backend_url = "http://localhost:11434",
	max_tokens = 150,
	temperature = 0.2,
	debounce_ms = 400,
}

function M.get()
	return M.defaults
end

return M
