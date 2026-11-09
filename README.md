# clwrap

`clwrap` is a Lua Neovim plugin that reflows standalone `//` comments in Go, TypeScript, TSX, Rust, and Zig, and `--` comments in Lua. It uses Neovim's installed Tree-sitter parsers directly: no Go runtime, CGo, external executable, or subprocess.

- Documentation attached to top-level named declarations wraps to `doc_width` (default 75).
- Other standalone comments wrap to `comment_width` (default 120).
- `tolerance` lets a doc-comment word that starts inside the boundary finish up to N columns beyond it.
- Rust and Zig preserve `///` and `//!`; Lua preserves `---`; Markdown list continuations join into one line per item.
- Indentation and words use display columns. Tabs use the buffer's `tabstop`, including `.editorconfig`'s `tab_width`.
- Generated Go files and buffers with syntax errors stay unchanged.

Trailing comments, block comments (including JSDoc and Lua long comments), four-slash comments, tooling directives, and structured paragraphs retain their layout. Directive lines split a comment group, and the prose on either side still reflows. LuaLS `---@...` annotations, Luau `--!...` controls, and StyLua, Selene, and Luacheck directives are preserved.

## Requirements

- Neovim 0.10 or newer.
- Tree-sitter parser libraries for `go`, `lua`, `typescript`, `tsx`, `rust`, and `zig`.
- Optional: [none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) for `vim.lsp.buf.format()` and format-on-save integration.
- Optional: [virt-column.nvim](https://github.com/lukas-reineke/virt-column.nvim) for width discovery.

Mason's `tree-sitter-cli` package is **not** used. Install parser libraries through `nvim-treesitter`:

```vim
:TSInstall go lua typescript tsx rust zig
```

Run `:checkhealth clwrap` to check the parsers Neovim can load.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "humbornjo/clwrap.nvim",
  opts = {},
}
```

`opts = {}` calls `require("clwrap").setup({})`; setup is only needed to change defaults. The `:Clwrap` command also works without calling setup.

## Usage

Run `:Clwrap` to reflow the current buffer. Run `:ClwrapAll` to format every supported file below Neovim's current working directory, or pass another root:

```vim
:Clwrap
:ClwrapAll
:ClwrapAll ~/Repository/another-project
```

The batch command skips dot/underscore directories, `vendor`, `node_modules`, and `testdata`. Modified buffers are skipped rather than saving unrelated edits. It reports formatted, unchanged, skipped, and failed counts; batch writes do not trigger save autocommands.

The same operations are available from Lua:

```lua
require("clwrap").format()
require("clwrap").format(0, { doc_width = 75, comment_width = 120, tolerance = 2 })

-- Defaults to getcwd() when root is omitted.
local report = require("clwrap").format_all()
-- report.formatted, report.unchanged, report.skipped, report.errors

-- Compute edits without changing the buffer.
local edits, err = require("clwrap").edits(0)
```

Formatting is idempotent. An unsupported filetype or syntax error returns an error and leaves the source untouched. A missing parser leaves the source unchanged and shows one warning per language with its `:TSInstall` command; later attempts skip silently. Installing the parser makes formatting available without restarting Neovim.

### Format on save

Enable clwrap's own `BufWritePre` hook during setup:

```lua
require("clwrap").setup({
  format_on_save = true,
})
```

It is disabled by default. Override the global setting for one buffer with:

```lua
vim.b.clwrap_format_on_save = false -- or true
```

Use either this hook or an external formatter's save integration for clwrap, not both; running both is idempotent but parses the buffer twice.

### none-ls integration

Add the supplied source to your existing `none-ls` configuration, preserving your other sources:

```lua
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    require("clwrap.none_ls"),
    -- Your other sources.
  },
})
```

The source runs in process and parses `none-ls`'s current formatter-chain text. `vim.lsp.buf.format()` and existing `none-ls` format-on-save integrations therefore work normally. Keep language formatting such as `gopls`, `rustfmt`, or Prettier enabled; clwrap only changes comments.

## Configuration

All settings are optional. The example below shows the complete setup configuration and its defaults; copy only the options you want to change.

```lua
require("clwrap").setup({
  -- Width for top-level declaration documentation. nil enables discovery; fallback: 75.
  doc_width = nil,

  -- Width for other standalone comments. nil enables discovery; fallback: 120.
  comment_width = nil,

  -- Let a doc-comment word finish this many columns beyond the wrap boundary.
  tolerance = 0,

  -- Preserve the layout of paragraphs beginning with these prefixes.
  exempted_prefixes = { " ", "\t", "- ", "* ", "+ " },

  -- Read max_line_length from Neovim's EditorConfig integration.
  editorconfig = true,

  -- Read wrapping columns from virt-column.nvim when available.
  virtcolumn = true,

  -- Format supported buffers from clwrap's BufWritePre hook.
  format_on_save = false,
})
```

For the rare case where the Tree-sitter language differs from the buffer's filetype, pass `lang` to an individual format call. Automatic detection is recommended for normal use:

```lua
require("clwrap").format(0, { lang = "typescript" })
```

Widths are resolved again for every format call:

1. Per-call options, `b:clwrap_doc_width`, `b:clwrap_comment_width`, then values explicitly passed to `setup()`.
2. `.editorconfig` `max_line_length` sets `comment_width`. Neovim's built-in EditorConfig support also applies `tab_width` to `tabstop`.
3. With two or more usable `virt-column` entries, the smallest sets `doc_width` and the largest sets `comment_width`. Relative entries such as `+1` resolve against `textwidth`, just as they do in virt-column.
4. A single usable virt-column entry sets `comment_width`; `doc_width` becomes `min(75, comment_width)`.
5. Otherwise, the defaults are 75 and 120. If only `comment_width` is known, doc width is capped at that value.

`virt-column`'s display can be enabled or disabled independently; its configured columns are still readable. Buffer-local explicit widths are useful for project or filetype overrides:

```lua
vim.b.clwrap_doc_width = 80
vim.b.clwrap_comment_width = 100
```

## Development

```sh
make test
```

The tests run headlessly against the Tree-sitter parsers available to Neovim. TSX tests are skipped when its parser is not installed.

The implementation is split by responsibility:

- `lua/clwrap/init.lua` — the small public Lua interface and idempotent setup.
- `lua/clwrap/formatter.lua` — buffer validation, option resolution, and formatting.
- `lua/clwrap/parser.lua` — string parsing, comment-run extraction, and edit computation.
- `lua/clwrap/edit.lua` — shared edit application and rendering.
- `lua/clwrap/lang/` — the language registry and one Tree-sitter policy adapter per grammar.
- `lua/clwrap/rules.lua` — language-neutral list and width rules.
- `lua/clwrap/config.lua` — EditorConfig, virt-column, and override resolution.
- `lua/clwrap/commands.lua` and `lifecycle.lua` — lazy command callbacks and buffer-loading/save lifecycle.
- `lua/clwrap/batch.lua` — recursive discovery, safe file writes, and batch reports.
- `lua/clwrap/none_ls.lua` — the optional in-process none-ls source.

Command callbacks load formatting modules only when invoked. Internal modules depend on concrete modules rather than calling back through `require("clwrap")`, so the public facade does not introduce dependency cycles. Calling `setup()` again replaces previous setup options and recreates the lifecycle hooks without duplicating them.
