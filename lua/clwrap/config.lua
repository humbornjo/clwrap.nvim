local M = {}

---@class clwrap.Config
---@field doc_width? integer Width for top-level declaration documentation.
---@field comment_width? integer Width for other standalone comments.
---@field tolerance? integer Extra columns allowed for a straddling doc-comment word.
---@field exempted_prefixes? string[] Prefixes whose paragraphs retain their layout.
---@field editorconfig? boolean Read max_line_length from b:editorconfig.
---@field virtcolumn? boolean Read virt-column's configured columns.
---@field format_on_save? boolean Format supported buffers from BufWritePre.
---@field lang? string Override the Tree-sitter language for one call.

---@class clwrap.ResolvedConfig: clwrap.Config
---@field doc_width integer
---@field comment_width integer
---@field tolerance integer
---@field exempted_prefixes string[]
---@field tabstop integer

M.defaults = {
  doc_width = 75,
  comment_width = 120,
  tolerance = 0,
  exempted_prefixes = { " ", "\t", "- ", "* ", "+ " },
  editorconfig = true,
  virtcolumn = true,
  format_on_save = false,
}

local function copy(value)
  return vim.deepcopy(value)
end

M.options = copy(M.defaults)
M.options.doc_width = nil
M.options.comment_width = nil

---@param opts clwrap.Config?
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", copy(M.options), opts)
  if opts.exempted_prefixes then
    M.options.exempted_prefixes = copy(opts.exempted_prefixes)
  end
end

local function positive_integer(value)
  value = tonumber(value)
  if value and value > 0 then
    return math.floor(value)
  end
end

local function editorconfig_width(bufnr)
  local properties = vim.b[bufnr].editorconfig
  if type(properties) == "table" then
    return positive_integer(properties.max_line_length)
  end
end

local function virtcolumn_widths(bufnr)
  local ok, virtcolumn = pcall(require, "virt-column.config")
  if not ok or type(virtcolumn.get_config) ~= "function" then
    return {}
  end
  local configured
  ok, configured = pcall(virtcolumn.get_config, bufnr)
  if not ok or type(configured) ~= "table" then
    return {}
  end

  local textwidth = vim.bo[bufnr].textwidth
  local unique = {}
  for entry in tostring(configured.virtcolumn or ""):gmatch("[^,]+") do
    entry = vim.trim(entry)
    local sign = entry:sub(1, 1)
    local column
    if (sign == "+" or sign == "-") and textwidth > 0 then
      local offset = tonumber(entry:sub(2))
      if offset then
        column = sign == "+" and textwidth + offset or textwidth - offset
      end
    else
      column = tonumber(entry)
    end
    column = positive_integer(column)
    if column then
      unique[column] = true
    end
  end

  local columns = vim.tbl_keys(unique)
  table.sort(columns)
  return columns
end

---Resolve widths afresh for every format so buffer-local changes take effect.
---@param bufnr integer
---@param overrides clwrap.Config?
---@return clwrap.ResolvedConfig
function M.resolve(bufnr, overrides)
  overrides = overrides or {}
  local resolved = vim.tbl_deep_extend("force", copy(M.defaults), M.options, overrides)
  local prefixes = overrides.exempted_prefixes or M.options.exempted_prefixes or M.defaults.exempted_prefixes
  resolved.exempted_prefixes = copy(prefixes)

  local columns = resolved.virtcolumn and virtcolumn_widths(bufnr) or {}
  local editorconfig = resolved.editorconfig and editorconfig_width(bufnr) or nil
  local comment_width = positive_integer(overrides.comment_width)
    or positive_integer(vim.b[bufnr].clwrap_comment_width)
    or positive_integer(M.options.comment_width)
    or editorconfig
    or columns[#columns]
    or M.defaults.comment_width

  local doc_width = positive_integer(overrides.doc_width)
    or positive_integer(vim.b[bufnr].clwrap_doc_width)
    or positive_integer(M.options.doc_width)
    or (#columns >= 2 and columns[1] or nil)
    or math.min(M.defaults.doc_width, comment_width)

  resolved.doc_width = doc_width
  resolved.comment_width = comment_width
  resolved.tolerance = math.max(0, tonumber(resolved.tolerance) or 0)
  resolved.tabstop = vim.bo[bufnr].tabstop
  return resolved
end

return M
