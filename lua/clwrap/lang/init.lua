local M = {}

M.filetypes = {
  go = "go",
  lua = "lua",
  typescript = "typescript",
  typescriptreact = "tsx",
  rust = "rust",
  zig = "zig",
}

M.extensions = {
  cts = "typescript",
  go = "go",
  lua = "lua",
  mts = "typescript",
  rs = "rust",
  ts = "typescript",
  tsx = "tsx",
  zig = "zig",
}

---@class clwrap.LanguageSpec
---@field marker fun(text: string): string?
---@field directive? fun(text: string): boolean
---@field classify fun(last: TSNode, end_row: integer): "doc"|"comment"

---@type table<string, clwrap.LanguageSpec>
M.specs = {
  go = require("clwrap.lang.go"),
  lua = require("clwrap.lang.lua"),
  typescript = require("clwrap.lang.typescript"),
  rust = require("clwrap.lang.rust"),
  zig = require("clwrap.lang.zig"),
}
M.specs.tsx = M.specs.typescript

---@param path string
---@return string?
function M.for_path(path)
  local extension = path:match("%.([^%.]+)$")
  return extension and M.extensions[extension:lower()] or nil
end

return M
