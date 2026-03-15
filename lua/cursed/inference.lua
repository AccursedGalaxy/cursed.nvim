local M = {}

local config = require("cursed.config")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function parse_url(url)
	-- Accepts: "http://host:port", "host:port", or bare "host" (port → 11434)
	local host, port = url:match("^https?://([^:]+):(%d+)")
	if not host then
		host, port = url:match("^([^:]+):(%d+)")
	end
	if not host then
		host = url:gsub("^https?://", "")
		port = "11434"
	end
	return host, tonumber(port)
end

local function build_http_request(host, port, json_body)
	return table.concat({
		"POST /api/generate HTTP/1.1",
		"Host: " .. host .. ":" .. port,
		"Content-Type: application/json",
		"Content-Length: " .. #json_body,
		"Connection: close",
		"",
		json_body,
	}, "\r\n")
end

local function dechunk(body)
	-- Strip HTTP chunked transfer encoding: hex-size\r\ndata\r\n...0\r\n\r\n
	local out = {}
	local pos = 1
	while pos <= #body do
		local nl = body:find("\r\n", pos, true)
		if not nl then
			break
		end
		local size = tonumber(body:sub(pos, nl - 1), 16)
		if not size or size == 0 then
			break
		end
		out[#out + 1] = body:sub(nl + 2, nl + 1 + size)
		pos = nl + 2 + size + 2 -- skip data + trailing \r\n
	end
	return #out > 0 and table.concat(out) or body
end

local function parse_response(raw)
	-- HTTP response: headers and body are separated by \r\n\r\n
	local header_end, body_start = raw:find("\r\n\r\n", 1, true)
	local json_body = body_start and raw:sub(body_start + 1) or raw

	-- Dechunk if server used Transfer-Encoding: chunked
	local headers = header_end and raw:sub(1, header_end) or ""
	if headers:lower():find("transfer%-encoding:%s*chunked") then
		json_body = dechunk(json_body)
	end

	local ok, decoded = pcall(vim.json.decode, json_body)
	if not ok or type(decoded) ~= "table" then
		return nil, "failed to decode response"
	end
	if decoded.error then
		return nil, "model error: " .. tostring(decoded.error)
	end
	return decoded.response, nil
end

-- ── TCP callbacks (named so the flow in M.complete reads linearly) ────────────

local function on_read(tcp, chunks, callback)
	return function(err, data)
		if err then
			tcp:close()
			vim.schedule(function()
				vim.notify("cursed: read error (" .. err .. ")", vim.log.levels.WARN)
				callback(nil, err)
			end)
			return
		end

		if data then
			chunks[#chunks + 1] = data
		else
			-- EOF — full response received, parse and return
			tcp:close()
			local response, parse_err = parse_response(table.concat(chunks))
			vim.schedule(function()
				callback(response, parse_err)
			end)
		end
	end
end

local function on_write(tcp, callback)
	return function(err)
		if err then
			tcp:close()
			vim.schedule(function()
				vim.notify("cursed: write error (" .. err .. ")", vim.log.levels.WARN)
				callback(nil, err)
			end)
		end
	end
end

local function on_connect(tcp, request, chunks, callback)
	return function(err)
		if err then
			tcp:close()
			vim.schedule(function()
				vim.notify("cursed: backend unreachable (" .. err .. ")", vim.log.levels.WARN)
				callback(nil, err)
			end)
			return
		end

		tcp:read_start(on_read(tcp, chunks, callback))
		tcp:write(request, on_write(tcp, callback))
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--
--- Send a completion request to Ollama.
--- @param prompt   string
--- @param callback fun(response: string|nil, err: string|nil)
--- @return fun() cancel  Call to abort the in-flight request and close the TCP socket.
function M.complete(prompt, callback)
	local cfg = config.get()
	local host, port = parse_url(cfg.backend_url)

	local json_body = vim.json.encode({
		model = cfg.model,
		prompt = prompt,
		system = cfg.system_prompt,
		stream = false,
		temperature = cfg.temperature,
		num_predict = cfg.max_tokens,
	})

	-- shared state so cancel() can reach the tcp handle even if created after cancel is called
	local state = { tcp = nil, cancelled = false }

	local function cancel()
		state.cancelled = true
		if state.tcp and not state.tcp:is_closing() then
			state.tcp:close()
		end
	end

	-- vim.uv TCP connect requires a resolved IP, not a hostname
	vim.uv.getaddrinfo(host, nil, nil, function(err, res)
		if state.cancelled then return end
		if err or not res or not res[1] then
			vim.schedule(function()
				vim.notify("cursed: DNS resolution failed for " .. host, vim.log.levels.WARN)
				callback(nil, err or "no address resolved")
			end)
			return
		end

		-- prefer IPv4 — Ollama binds on 127.0.0.1, not ::1
		local entry = res[1]
		for _, r in ipairs(res) do
			if r.family == "inet" then
				entry = r
				break
			end
		end
		local ip = entry.addr
		local tcp = vim.uv.new_tcp()
		if not tcp then
			vim.schedule(function()
				callback(nil, "cursed: failed to create TCP handle")
			end)
			return
		end

		state.tcp = tcp
		if state.cancelled then
			tcp:close()
			return
		end

		local chunks = {}
		tcp:connect(ip, port, on_connect(tcp, build_http_request(host, port, json_body), chunks, callback))
	end)

	return cancel
end

return M
