# clwrap

`clwrap` reflows standalone line comments with Neovim's installed Tree-sitter parsers. It supports `//` comments in Go, TypeScript, TSX, Rust, and Zig, plus `--` comments in Lua. Parsing and formatting run inside Neovim.

- Documentation attached to top-level named declarations wraps to `doc_width`, which defaults to 75.
- Other standalone comments wrap to `comment_width`, which defaults to 120.
- `tolerance` lets a doc-comment word that starts inside the boundary finish up to N columns beyond it.
- Rust and Zig preserve `///` and `//!`. Lua preserves `---`. Markdown list continuations join into one line per item.
- Indentation and words use display columns. Tabs use the buffer's `tabstop`, including `.editorconfig`'s `tab_width`.
- Generated Go files and buffers with syntax errors stay unchanged.

Trailing comments, block comments, four-slash comments, tooling directives, and structured paragraphs retain their layout. This includes JSDoc and Lua long comments. Directive lines split a comment group, and the prose on either side still reflows. clwrap also preserves LuaLS `---@...` annotations, Luau `--!...` controls, and StyLua, Selene, and Luacheck directives.

## Requirements

- Neovim 0.10 or newer.
- Tree-sitter parser libraries for `go`, `lua`, `typescript`, `tsx`, `rust`, and `zig`.
- Optional [none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) for `vim.lsp.buf.format()` and format-on-save integration.
- Optional [virt-column.nvim](https://github.com/lukas-reineke/virt-column.nvim) for width discovery.

Install parser libraries through `nvim-treesitter`:

```vim
:TSInstall go lua typescript tsx rust zig
```

Run `:checkhealth clwrap` to list the parsers Neovim can load.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "humbornjo/clwrap.nvim",
  opts = {},
}
```

`opts = {}` calls `require("clwrap").setup({})`. Add setup when you want to change defaults. Plugin loading registers `:Clwrap` and `:ClwrapAll`.

## Usage

Run `:Clwrap` to reflow the current buffer. Run `:ClwrapAll` to format every supported file below Neovim's current working directory, or pass another root:

```vim
:Clwrap
:ClwrapAll
:ClwrapAll ~/Repository/another-project
```

The batch command skips directories whose names start with `.` or `_`, plus `vendor`, `node_modules`, and `testdata`. It leaves modified buffers untouched to avoid saving unrelated edits. It reports formatted, unchanged, skipped, and failed counts. Batch writes use `noautocmd`.

The Lua interface provides the same operations:

```lua
require("clwrap").format()
require("clwrap").format(0, { doc_width = 75, comment_width = 120, tolerance = 2 })

-- Defaults to getcwd() when root is omitted.
local report = require("clwrap").format_all()
-- report.formatted, report.unchanged, report.skipped, report.errors

-- Compute edits and keep the buffer unchanged.
local edits, err = require("clwrap").edits(0)
```

Formatting is idempotent. clwrap reports unsupported filetypes and syntax errors as errors. For a missing parser, it warns once per language and shows the relevant `:TSInstall` command. These cases preserve the source. Later missing-parser attempts run silently and preserve the source. A newly installed parser takes effect in the current Neovim session.

### Format on save

Enable clwrap's `BufWritePre` hook during setup:

```lua
require("clwrap").setup({
  format_on_save = true,
})
```

`format_on_save` is false by default. Override the global setting for one buffer with:

```lua
vim.b.clwrap_format_on_save = false -- or true
```

Choose one save integration for clwrap, either this hook or an external formatter's integration. Combining them is idempotent, and each integration parses the buffer.

### none-ls integration

Add the supplied source to your existing `none-ls` configuration and keep your other sources in the list:

```lua
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    require("clwrap.none_ls"),
    -- Your other sources.
  },
})
```

The source runs in process and parses text produced by earlier formatters in the `none-ls` chain. You can call it through `vim.lsp.buf.format()` and existing `none-ls` save hooks. Keep language formatting such as `gopls`, `rustfmt`, or Prettier enabled. clwrap formats comments and preserves the surrounding source.

## Configuration

All settings are optional. This example shows every setup option and its default. Copy the options you want to change.

```lua
require("clwrap").setup({
  -- Width for top-level declaration documentation. nil enables discovery with a fallback of 75.
  doc_width = nil,

  -- Width for other standalone comments. nil enables discovery with a fallback of 120.
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

If the Tree-sitter language differs from the buffer's filetype, pass `lang` to an individual format call. Otherwise, let clwrap detect the language:

```lua
require("clwrap").format(0, { lang = "typescript" })
```

clwrap resolves widths for every format call:

1. Per-call options have highest priority, followed by `b:clwrap_doc_width`, `b:clwrap_comment_width`, and values passed to `setup()`.
2. `.editorconfig` `max_line_length` sets `comment_width`. Neovim's EditorConfig integration also applies `tab_width` to `tabstop`.
3. With two or more usable `virt-column` entries, the smallest sets `doc_width` and the largest sets `comment_width`. Relative entries such as `+1` resolve against `textwidth`, just as they do in virt-column.
4. A single usable virt-column entry sets `comment_width`. The doc width becomes `min(75, comment_width)`.
5. Otherwise, clwrap uses 75 and 120. A known `comment_width` also caps the doc width.

clwrap reads virt-column's configured columns even when its guides are hidden. Set buffer-local widths for project or filetype overrides:

```lua
vim.b.clwrap_doc_width = 80
vim.b.clwrap_comment_width = 100
```

## Development

```sh
make test
```

The tests run headlessly against the Tree-sitter parsers available to Neovim. The test runner skips the TSX test when its parser is unavailable.

The modules have the following responsibilities:

- `lua/clwrap/init.lua` exposes the public Lua functions and runs setup.
- `lua/clwrap/formatter.lua` validates buffers, resolves options, and formats comments.
- `lua/clwrap/parser.lua` parses source text, extracts comment runs, and computes edits.
- `lua/clwrap/edit.lua` applies edits to buffers and renders edited source text.
- `lua/clwrap/lang/` registers languages and holds one Tree-sitter policy adapter per grammar.
- `lua/clwrap/rules.lua` implements the language-neutral list and width rules.
- `lua/clwrap/config.lua` resolves EditorConfig, virt-column, and explicit overrides.
- `lua/clwrap/commands.lua` registers commands with lazy callbacks.
- `lua/clwrap/lifecycle.lua` manages buffer-loading and save hooks.
- `lua/clwrap/batch.lua` finds files, writes changes, and reports batch results.
- `lua/clwrap/none_ls.lua` provides the optional in-process none-ls source.

Command callbacks load formatting modules when invoked. Internal modules depend on concrete modules directly, which prevents `require` cycles. Calling `setup()` again replaces earlier options and keeps one copy of each lifecycle hook.
