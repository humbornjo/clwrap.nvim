local M = {}

function M.starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

function M.slash_marker(text)
  return M.starts_with(text, "//") and "//" or nil
end

function M.doc_marker(text)
  if M.starts_with(text, "////") then
    return nil
  elseif M.starts_with(text, "///") then
    return "///"
  elseif M.starts_with(text, "//!") then
    return "//!"
  elseif M.starts_with(text, "//") then
    return "//"
  end
end

function M.immediately_followed_by(last, end_row, declarations)
  local next = last:next_named_sibling()
  if not next then
    return false
  end
  local start_row = next:range()
  return start_row == end_row + 1 and declarations[next:type()] == true
end

return M
