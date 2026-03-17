.PHONY: test lint fmt release

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

lint:
	stylua --check .

fmt:
	stylua .

release:
	@version=$$(grep 'M\.version' lua/cursed/init.lua | head -1 | sed 's/.*"\(.*\)".*/\1/'); \
	echo "Tagging v$$version"; \
	git tag -a "v$$version" -m "release: v$$version"; \
	echo "Done. Now run: git push origin main && git push origin v$$version"
