local M = {}
local save_group

---@param opts clwrap.Config?
---@return clwrap
function M.setup(opts)
  require("clwrap.config").setup(opts)
  if save_group then
    vim.api.nvim_del_augroup_by_id(save_group)
  end
  save_group = vim.api.nvim_create_augroup("clwrap", {})
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = save_group,
    callback = function(event)
      local enabled = vim.b[event.buf].clwrap_format_on_save
      if enabled == nil then
        enabled = require("clwrap.config").options.format_on_save
      end
      if not enabled or not require("clwrap.languages").filetypes[vim.bo[event.buf].filetype] then
        return
      end
      local changed, err = M.format(event.buf)
      if not changed and err then
        vim.notify(err, vim.log.levels.ERROR, { title = "clwrap" })
      end
    end,
    desc = "Reflow comments before writing",
  })
  return M
end

local function buffer_number(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

---@param bufnr integer?
---@param opts clwrap.Config?
---@return clwrap.Edit[]? edits
---@return string? error
function M.edits(bufnr, opts)
  if type(bufnr) == "table" then
    opts = bufnr
    bufnr = nil
  end
  bufnr = buffer_number(bufnr)
  local resolved = require("clwrap.config").resolve(bufnr, opts)
  resolved.lang = resolved.lang or require("clwrap.languages").filetypes[vim.bo[bufnr].filetype]
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
  if type(bufnr) == "table" then
    opts = bufnr
    bufnr = nil
  end
  bufnr = buffer_number(bufnr)
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
    require("clwrap.parser").apply(bufnr, edits)
    if view then
      vim.fn.winrestview(view)
    end
  end
  return #edits > 0
end

---@param root string? Defaults to Neovim's current working directory.
---@param opts clwrap.Config?
---@return clwrap.BatchReport
function M.format_all(root, opts)
  return require("clwrap.batch").format_all(root, opts)
end

return M
