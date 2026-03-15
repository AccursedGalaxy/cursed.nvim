local M = {}

--- Return the transport module for the given backend name.
--- @param backend string e.g. "tmux"
--- @return table transport module with a send(text, opts) function
function M.get(backend)
	backend = backend or "tmux"
	local ok, transport = pcall(require, "cursed.transport." .. backend)
	if not ok then
		error("cursed: unknown backend '" .. backend .. "' — no module cursed.transport." .. backend)
	end
	return transport
end

return M
