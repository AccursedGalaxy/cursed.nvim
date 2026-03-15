.PHONY: test lint fmt

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

lint:
	stylua --check .

fmt:
	stylua .
