# clwrap

`clwrap` is a Lua Neovim plugin that reflows standalone `//` comments in Go, TypeScript, TSX, Rust, and Zig. It uses Neovim's installed Tree-sitter parsers directly: no Go runtime, CGo, external executable, or subprocess.

- Documentation attached to top-level named declarations wraps to `doc_width` (default 75).
- Other standalone comments wrap to `comment_width` (default 120).
- `tolerance` lets a doc-comment word that starts inside the boundary finish up to N columns beyond it.
- Rust and Zig preserve `///` and `//!`; Markdown list continuations join into one line per item.
- Indentation and words use display columns. Tabs use the buffer's `tabstop`, including `.editorconfig`'s `tab_width`.
- Generated Go files and buffers with syntax errors stay unchanged.

Trailing comments, block comments (including JSDoc), four-slash comments, tooling directives, and structured paragraphs retain their layout. Directive lines split a comment group, and the prose on either side still reflows.

## Requirements

- Neovim 0.10 or newer.
- Tree-sitter parser libraries for `go`, `typescript`, `tsx`, `rust`, and `zig`.
- Optional: [none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) for `vim.lsp.buf.format()` and format-on-save integration.
- Optional: [virt-column.nvim](https://github.com/lukas-reineke/virt-column.nvim) for width discovery.

Mason's `tree-sitter-cli` package is **not** used. Install parser libraries through `nvim-treesitter`, for example in AstroNvim:

```lua
return {
  "AstroNvim/astrocore",
  opts = {
    treesitter = {
      ensure_installed = { "go", "typescript", "tsx", "rust", "zig" },
    },
  },
}
```

Run `:checkhealth clwrap` to check the parsers Neovim can load.

## Installation

With `lazy.nvim`, using this local checkout:

```lua
return {
  {
    dir = "~/Repository/clwrap",
    opts = {},
  },
}
```

Replace `dir` with the plugin's repository URL if installing from Git. `opts = {}` calls `require("clwrap").setup({})`; setup is only needed to change defaults. The `:Clwrap` command also works without calling setup.

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

Formatting is idempotent. A missing parser, unsupported filetype, or syntax error returns an error and leaves the source untouched.

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

Add the supplied source to your existing `none-ls` configuration. In AstroNvim, merge it into `opts.sources` rather than replacing other formatters:

```lua
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      require("clwrap.none_ls"),
    })
  end,
}
```

For a plain `none-ls` setup:

```lua
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    require("clwrap.none_ls"),
    -- Your other sources.
  },
})
```

The source runs in process and parses `none-ls`'s current formatter-chain text. `vim.lsp.buf.format()` therefore works normally, as does AstroLSP's `format_on_save`. Keep language formatting such as `gopls`, `rustfmt`, or Prettier enabled; clwrap only changes comments.

If your checked-in `lua/plugins/none-ls.lua` starts with an early `return {}` that disables the file, remove that line before adding the source.

## Configuration

Defaults:

```lua
require("clwrap").setup({
  doc_width = nil, -- nil enables automatic discovery; fallback 75
  comment_width = nil, -- nil enables automatic discovery; fallback 120
  tolerance = 0,
  exempted_prefixes = { " ", "\t", "- ", "* ", "+ " },
  editorconfig = true,
  virtcolumn = true,
  format_on_save = false,
})
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

- `lua/clwrap/parser.lua` — string parsing, comment-run extraction, and line edits.
- `lua/clwrap/languages.lua` — grammar-specific markers, directives, and declaration classification.
- `lua/clwrap/rules.lua` — language-neutral list and width rules.
- `lua/clwrap/config.lua` — EditorConfig, virt-column, and override resolution.
- `lua/clwrap/batch.lua` — recursive discovery, safe file writes, and batch reports.
- `lua/clwrap/none_ls.lua` — the optional in-process none-ls source.
