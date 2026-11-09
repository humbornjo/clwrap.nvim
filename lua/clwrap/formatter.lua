local M = {}

local function buffer_number(bufnr, opts)
  if type(bufnr) == "table" then
    return vim.api.nvim_get_current_buf(), bufnr
  end
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf(), opts
  end
  return bufnr, opts
end

---@param bufnr integer?
---@param opts clwrap.Config?
---@return clwrap.Edit[]? edits
---@return string? error
function M.edits(bufnr, opts)
  bufnr, opts = buffer_number(bufnr, opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "clwrap: invalid buffer"
  end

  local resolved = require("clwrap.config").resolve(bufnr, opts)
  resolved.lang = resolved.lang or require("clwrap.lang").filetypes[vim.bo[bufnr].filetype]
  if not resolved.lang then
    return nil, ("clwrap: unsupported filetype %q"):format(vim.bo[bufnr].filetype)
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return require("clwrap.parser").edits(lines, resolved)
end

---Reflow standalone comments in one buffer.
---@param bufnr integer?
---@param opts clwrap.Config?
---@return boolean? changed
---@return string? error
function M.format(bufnr, opts)
  bufnr, opts = buffer_number(bufnr, opts)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "clwrap: invalid buffer"
  end
  if not vim.bo[bufnr].modifiable then
    return nil, "clwrap: buffer is not modifiable"
  end

  local edits, err = M.edits(bufnr, opts)
  if not edits then
    return nil, err
  end
  if #edits > 0 then
    local view = bufnr == vim.api.nvim_get_current_buf() and vim.fn.winsaveview() or nil
    require("clwrap.edit").apply(bufnr, edits)
    if view then
      vim.fn.winrestview(view)
    end
  end
  return #edits > 0
end

return M
