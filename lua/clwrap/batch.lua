local languages = require("clwrap.lang")

local M = {}
local uv = vim.uv or vim.loop

local ignored_directories = {
  node_modules = true,
  testdata = true,
  vendor = true,
}

---@param root string
---@return string[]? paths
---@return string? error
local function find_sources(root)
  local paths = {}
  local directories = { root }
  while #directories > 0 do
    local directory = table.remove(directories)
    local scanner, err = uv.fs_scandir(directory)
    if not scanner then
      return nil, ("clwrap: scan %s: %s"):format(directory, err)
    end
    while true do
      local name, kind = uv.fs_scandir_next(scanner)
      if not name then
        break
      end
      local path = vim.fs.joinpath(directory, name)
      if kind == "directory" then
        if not ignored_directories[name] and not name:match("^[._]") then
          directories[#directories + 1] = path
        end
      elseif kind == "file" and languages.for_path(path) then
        paths[#paths + 1] = path
      end
    end
  end
  table.sort(paths)
  return paths
end

local function format_file(path, opts)
  local bufnr = vim.fn.bufnr(path)
  local was_loaded = bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr)
  if was_loaded and vim.bo[bufnr].modified then
    return "skipped"
  end
  if bufnr < 0 then
    bufnr = vim.fn.bufadd(path)
  end

  local function cleanup()
    if not was_loaded and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  local loaded, load_err = pcall(vim.fn.bufload, bufnr)
  if not loaded then
    cleanup()
    return nil, load_err
  end
  if vim.b[bufnr].editorconfig == nil and vim.g.editorconfig ~= false then
    require("editorconfig").config(bufnr)
  end

  local changed, err = require("clwrap.formatter").format(bufnr, opts)
  if changed == nil then
    cleanup()
    return nil, err
  end
  if changed then
    local written, write_err = pcall(vim.api.nvim_buf_call, bufnr, function()
      vim.cmd("silent noautocmd write")
    end)
    if not written then
      cleanup()
      return nil, write_err
    end
  end
  cleanup()
  return changed and "formatted" or "unchanged"
end

---@class clwrap.BatchReport
---@field formatted string[]
---@field unchanged string[]
---@field skipped string[] Modified buffers that were not written.
---@field errors {path:string,error:string}[]

---Format every supported file below root, defaulting to Neovim's cwd.
---@param root string?
---@param opts clwrap.Config?
---@return clwrap.BatchReport
function M.format_all(root, opts)
  if type(root) == "table" then
    opts = root
    root = nil
  end
  root = vim.fs.normalize(vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p"))
  local report = { formatted = {}, unchanged = {}, skipped = {}, errors = {} }
  local paths, err = find_sources(root)
  if not paths then
    report.errors[1] = { path = root, error = err }
    return report
  end

  for _, path in ipairs(paths) do
    local file_opts = vim.tbl_extend("force", {}, opts or {}, { lang = languages.for_path(path) })
    local status, format_err = format_file(path, file_opts)
    if status then
      table.insert(report[status], path)
    else
      table.insert(report.errors, { path = path, error = format_err })
    end
  end
  return report
end

return M
