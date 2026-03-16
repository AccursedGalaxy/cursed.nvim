local M = {}

local function type_err(key, expected, got)
	return string.format("cursed: config.%s must be %s, got %s", key, expected, got)
end

local valid_scopes = { buffer = true, all_buffers = true, workspace = true }
local valid_formats = { default = true, compact = true, with_source_lines = true }
local valid_backends = { tmux = true }

function M.validate(config)
	local errors = {}

	if config.backend ~= nil then
		if type(config.backend) ~= "string" then
			table.insert(errors, type_err("backend", "string", type(config.backend)))
		elseif not valid_backends[config.backend] then
			table.insert(errors, 'cursed: config.backend must be one of: "tmux"')
		end
	end

	if config.tmux ~= nil then
		if type(config.tmux) ~= "table" then
			table.insert(errors, type_err("tmux", "table", type(config.tmux)))
		else
			if config.tmux.pane_target ~= nil and type(config.tmux.pane_target) ~= "string" then
				table.insert(errors, type_err("tmux.pane_target", "string", type(config.tmux.pane_target)))
			end
			if config.tmux.auto_submit ~= nil and type(config.tmux.auto_submit) ~= "boolean" then
				table.insert(errors, type_err("tmux.auto_submit", "boolean", type(config.tmux.auto_submit)))
			end
		end
	end

	if config.scope ~= nil then
		if type(config.scope) ~= "string" then
			table.insert(errors, type_err("scope", "string", type(config.scope)))
		elseif not valid_scopes[config.scope] then
			table.insert(errors, 'cursed: config.scope must be one of: "buffer", "all_buffers", "workspace"')
		end
	end

	if config.min_severity ~= nil and type(config.min_severity) ~= "number" then
		table.insert(errors, type_err("min_severity", "number (vim.diagnostic.severity.*)", type(config.min_severity)))
	end

	if config.format ~= nil then
		local t = type(config.format)
		if t ~= "string" and t ~= "function" then
			table.insert(errors, type_err("format", "string or function", t))
		elseif t == "string" and not valid_formats[config.format] then
			table.insert(
				errors,
				'cursed: config.format must be one of: "default", "compact", "with_source_lines", or a function'
			)
		end
	end

	if config.keymaps ~= nil then
		if type(config.keymaps) ~= "table" then
			table.insert(errors, type_err("keymaps", "table", type(config.keymaps)))
		else
			for k, v in pairs(config.keymaps) do
				if v ~= false and type(v) ~= "string" then
					table.insert(errors, type_err("keymaps." .. k, "string or false", type(v)))
				end
			end
		end
	end

	if config.templates ~= nil and type(config.templates) ~= "table" then
		table.insert(errors, type_err("templates", "table", type(config.templates)))
	end

	if config.default_template ~= nil and type(config.default_template) ~= "string" then
		table.insert(errors, type_err("default_template", "string", type(config.default_template)))
	end

	if config.auto_send ~= nil then
		if type(config.auto_send) ~= "table" then
			table.insert(errors, type_err("auto_send", "table", type(config.auto_send)))
		else
			local as = config.auto_send
			if as.enabled ~= nil and type(as.enabled) ~= "boolean" then
				table.insert(errors, type_err("auto_send.enabled", "boolean", type(as.enabled)))
			end
			if as.event ~= nil and type(as.event) ~= "string" then
				table.insert(errors, type_err("auto_send.event", "string", type(as.event)))
			end
			if as.debounce_ms ~= nil and type(as.debounce_ms) ~= "number" then
				table.insert(errors, type_err("auto_send.debounce_ms", "number", type(as.debounce_ms)))
			end
			if as.min_severity ~= nil and type(as.min_severity) ~= "number" then
				table.insert(
					errors,
					type_err("auto_send.min_severity", "number (vim.diagnostic.severity.*)", type(as.min_severity))
				)
			end
			if as.scope ~= nil then
				if type(as.scope) ~= "string" then
					table.insert(errors, type_err("auto_send.scope", "string", type(as.scope)))
				elseif not valid_scopes[as.scope] then
					table.insert(
						errors,
						'cursed: config.auto_send.scope must be one of: "buffer", "all_buffers", "workspace"'
					)
				end
			end
		end
	end

	return errors
end

return M
