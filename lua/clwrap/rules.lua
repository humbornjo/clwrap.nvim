local M = {}

local function starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

local function trim_prefix(text, prefix)
  if starts_with(text, prefix) then
    return text:sub(#prefix + 1)
  end
  return text
end

local function trim_left(text)
  return (text:gsub("^[ \t]+", ""))
end

local function words(text)
  local result = {}
  for word in text:gmatch("%S+") do
    result[#result + 1] = word
  end
  return result
end

local function area_lines(lines, marker)
  local marker_at = assert(lines[1]:find(marker, 1, true))
  local indent = lines[1]:sub(1, marker_at - 1)
  local result = {}
  for i, line in ipairs(lines) do
    local body = trim_prefix(trim_prefix(line, indent), marker)
    result[i] = trim_prefix(body, " ")
  end
  return indent, result
end

local function map_paragraphs(lines, fn)
  local result = {}
  local i = 1
  while i <= #lines do
    if lines[i] == "" then
      result[#result + 1] = ""
      i = i + 1
    else
      local paragraph = {}
      while i <= #lines and lines[i] ~= "" do
        paragraph[#paragraph + 1] = lines[i]
        i = i + 1
      end
      for _, line in ipairs(fn(paragraph)) do
        result[#result + 1] = line
      end
    end
  end
  return result
end

local function verbatim_lines(indent, marker, lines)
  local result = {}
  for i, line in ipairs(lines) do
    result[i] = line == "" and indent .. marker or indent .. marker .. " " .. line
  end
  return result
end

local function plain_prose(line, exempted_prefixes)
  for _, prefix in ipairs(exempted_prefixes) do
    if starts_with(line, prefix) then
      return false
    end
  end
  if line:match("^%d+[.)] ") then
    return false
  end
  if starts_with(line, "[") and line:find("]: ", 1, true) then
    return false
  end
  return true
end

local function bullet_item(line)
  local indent = line:match("^[ \t]*")
  local trimmed = line:sub(#indent + 1)
  for _, marker in ipairs({ "- ", "* ", "+ " }) do
    if starts_with(trimmed, marker) then
      return indent, marker, trimmed:sub(#marker + 1)
    end
  end
  local marker = trimmed:match("^(%d+[.)] )")
  if marker then
    return indent, marker, trimmed:sub(#marker + 1)
  end
end

local function reflow_list(lines, exempted_prefixes)
  local items = {}
  for _, line in ipairs(lines) do
    local indent, marker, body = bullet_item(line)
    if indent then
      items[#items + 1] = { indent = indent, marker = marker, words = words(body) }
    else
      local last = items[#items]
      if not last then
        return lines
      end
      local trimmed = trim_left(line)
      if #line - #trimmed <= #last.indent or not plain_prose(trimmed, exempted_prefixes) then
        return lines
      end
      for _, word in ipairs(words(trimmed)) do
        last.words[#last.words + 1] = word
      end
    end
  end

  local result = {}
  for i, item in ipairs(items) do
    result[i] = item.indent .. item.marker .. table.concat(item.words, " ")
  end
  return result
end

local function list_rewrite(lines, marker, exempted_prefixes)
  local indent, stripped = area_lines(lines, marker)
  stripped = map_paragraphs(stripped, function(paragraph)
    return reflow_list(paragraph, exempted_prefixes)
  end)
  return verbatim_lines(indent, marker, stripped)
end

local function display_width(text)
  return vim.fn.strdisplaywidth(text)
end

local function indent_columns(indent, tabstop)
  local width = 0
  for i = 1, #indent do
    local char = indent:sub(i, i)
    if char == "\t" then
      width = width + tabstop - width % tabstop
    else
      width = width + display_width(char)
    end
  end
  return width
end

local function tolerated(line_width, word_width, boundary, tolerance)
  return line_width + 1 < boundary and line_width + 1 + word_width <= boundary + tolerance
end

local function reflow_prose(lines, text_width, tolerance, exempted_prefixes)
  for _, line in ipairs(lines) do
    if not plain_prose(line, exempted_prefixes) then
      return lines
    end
  end

  local result = {}
  local current = ""
  local current_width = 0
  for _, word in ipairs(words(table.concat(lines, " "))) do
    local word_width = display_width(word)
    if current_width > 0 then
      local ending = current_width + 1 + word_width
      if ending > text_width and not tolerated(current_width, word_width, text_width, tolerance) then
        result[#result + 1] = current
        current = ""
        current_width = 0
      else
        current = current .. " "
        current_width = current_width + 1
      end
    end
    current = current .. word
    current_width = current_width + word_width
  end
  if current ~= "" then
    result[#result + 1] = current
  end
  return result
end

local function width_rewrite(lines, marker, class, opts)
  local boundary = class == "doc" and opts.doc_width or opts.comment_width
  local tolerance = class == "doc" and opts.tolerance or 0
  local indent, stripped = area_lines(lines, marker)
  local text_width = math.max(1, boundary - indent_columns(indent, opts.tabstop) - display_width(marker) - 1)
  stripped = map_paragraphs(stripped, function(paragraph)
    return reflow_prose(paragraph, text_width, tolerance, opts.exempted_prefixes)
  end)
  return verbatim_lines(indent, marker, stripped)
end

---@param lines string[] Full source lines occupied by one comment run.
---@param marker string The exact line-comment marker shared by the run.
---@param class "doc"|"comment"
---@param opts clwrap.ResolvedConfig
---@return string[]
function M.rewrite(lines, marker, class, opts)
  lines = list_rewrite(lines, marker, opts.exempted_prefixes)
  return width_rewrite(lines, marker, class, opts)
end

return M
