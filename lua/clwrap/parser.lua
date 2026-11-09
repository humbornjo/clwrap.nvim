local languages = require("clwrap.lang")
local rules = require("clwrap.rules")

local M = {}

-- Every supported grammar uses one of these three node names.
local comment_types = { comment = true, line_comment = true, block_comment = true }

local function comment_nodes(root)
  local result = {}
  local stack = { root }
  while #stack > 0 do
    local node = table.remove(stack)
    if comment_types[node:type()] then
      result[#result + 1] = node
    end
    for i = node:child_count() - 1, 0, -1 do
      stack[#stack + 1] = node:child(i)
    end
  end
  return result
end

local function standalone_comment(source, lines, node, spec)
  local text = vim.treesitter.get_node_text(node, source)
  local marker = spec.marker(text)
  if not marker then
    return
  end

  local start_row, start_col, end_row, end_col = node:range()
  local prefix = lines[start_row + 1]:sub(1, start_col)
  if not prefix:match("^%s*$") then
    return
  end
  if end_row > start_row and end_col == 0 then
    end_row = end_row - 1
  end
  return {
    node = node,
    text = text,
    marker = marker,
    start_row = start_row,
    end_row = end_row,
  }
end

local function extract_regions(source, lines, root, spec)
  local nodes = comment_nodes(root)
  local comments = {}
  for _, node in ipairs(nodes) do
    comments[#comments + 1] = standalone_comment(source, lines, node, spec) or false
  end

  local regions = {}
  local i = 1
  while i <= #comments do
    if not comments[i] then
      i = i + 1
    else
      local group = { comments[i] }
      local j = i + 1
      while comments[j] and comments[j].start_row == group[#group].end_row + 1 do
        group[#group + 1] = comments[j]
        j = j + 1
      end

      local last = group[#group]
      local class = spec.classify(last.node, last.end_row)
      local from, finish, run_marker
      local function flush()
        if from then
          regions[#regions + 1] = {
            start_row = from.start_row,
            end_row = finish.end_row + 1,
            class = class,
            marker = run_marker,
          }
          from = nil
        end
      end

      for _, comment in ipairs(group) do
        if spec.directive and spec.directive(comment.text) then
          flush()
        else
          if from and comment.marker ~= run_marker then
            flush()
          end
          if not from then
            from = comment
            run_marker = comment.marker
          end
          finish = comment
        end
      end
      flush()
      i = j
    end
  end
  return regions
end

local function generated_go(lines)
  local bytes = 0
  for _, line in ipairs(lines) do
    bytes = bytes + #line + 1
    if bytes > 4096 then
      return false
    end
    if line:match("^// Code generated .* DO NOT EDIT%.$") then
      return true
    end
  end
  return false
end

local function slice(lines, first, last)
  local result = {}
  for i = first, last do
    result[#result + 1] = lines[i]
  end
  return result
end

local function equal_lines(left, right)
  if #left ~= #right then
    return false
  end
  for i = 1, #left do
    if left[i] ~= right[i] then
      return false
    end
  end
  return true
end

---Compute comment-only edits for source lines without modifying a buffer.
---@param lines string[]
---@param opts clwrap.ResolvedConfig|{lang?: string}
---@return clwrap.Edit[]? edits
---@return string? error
function M.edits(lines, opts)
  local lang = opts.lang
  local spec = languages.specs[lang]
  if not spec then
    return nil, ("clwrap: unsupported language %q"):format(tostring(lang))
  end

  local source = table.concat(lines, "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
  if not ok or not parser then
    return nil, ("clwrap: %s parser: %s"):format(lang, parser or "not installed")
  end
  local parsed, trees = pcall(parser.parse, parser)
  if not parsed then
    return nil, ("clwrap: parse %s: %s"):format(lang, trees)
  end
  local root = trees[1]:root()
  if root:has_error() then
    return nil, ("clwrap: source contains %s syntax errors"):format(lang)
  end

  local regions = lang == "go" and generated_go(lines) and {} or extract_regions(source, lines, root, spec)
  local edits = {}
  for _, region in ipairs(regions) do
    local original = slice(lines, region.start_row + 1, region.end_row)
    local replacement = rules.rewrite(original, region.marker, region.class, opts)
    if not equal_lines(original, replacement) then
      edits[#edits + 1] = {
        start_row = region.start_row,
        end_row = region.end_row,
        lines = replacement,
      }
    end
  end
  return edits
end

return M
