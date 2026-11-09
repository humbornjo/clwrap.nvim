local M = {}
M.did_setup = false

---@param opts clwrap.Config?
---@return clwrap
function M.setup(opts)
  require("clwrap.config").setup(opts)
  require("clwrap.save").setup()
  M.did_setup = true
  return M
end

---@param bufnr integer?
---@param opts clwrap.Config?
---@return clwrap.Edit[]? edits
---@return string? error
function M.edits(bufnr, opts)
  return require("clwrap.formatter").edits(bufnr, opts)
end

---@param bufnr integer?
---@param opts clwrap.Config?
---@return boolean? changed
---@return string? error
function M.format(bufnr, opts)
  return require("clwrap.formatter").format(bufnr, opts)
end

---@param root string? Defaults to Neovim's current working directory.
---@param opts clwrap.Config?
---@return clwrap.BatchReport
function M.format_all(root, opts)
  return require("clwrap.batch").format_all(root, opts)
end

return M
