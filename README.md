# cursed.nvim

A Neovim plugin. _What does it do? That's the fun part._

## Requirements

- Neovim >= 0.11.0

## Installation

**lazy.nvim**

```lua
{
  "yourusername/cursed.nvim",
  config = function()
    require("cursed").setup({
      -- options
    })
  end,
}
```

**rocks.nvim**

```toml
[plugins]
"cursed.nvim" = "scm"
```

## Configuration

```lua
require("cursed").setup({
  -- all options are optional
})
```

## Usage

`:Cursed` — verify the plugin is loaded and working.

`:checkhealth cursed` — run the health check.

## Development

```bash
# run tests
make test
```

## License

MIT
