local shared = require("clwrap.lang.shared")

local declarations = {
  function_declaration = true,
  variable_declaration = true,
}

local function marker(text)
  if text:match("^%-%-%[=*%[") or shared.starts_with(text, "----") then
    return nil
  elseif shared.starts_with(text, "---") then
    return "---"
  elseif shared.starts_with(text, "--") then
    return "--"
  end
end

local function classify(last, end_row)
  local parent = last:parent()
  if not parent or parent:type() ~= "chunk" then
    return "comment"
  end
  return shared.immediately_followed_by(last, end_row, declarations) and "doc" or "comment"
end

local function directive(text)
  if shared.starts_with(text, "---@") then
    return true
  end
  if marker(text) ~= "--" then
    return false
  end
  local body = vim.trim(text:sub(3))
  return shared.starts_with(body, "!")
    or shared.starts_with(body, "stylua:")
    or shared.starts_with(body, "selene:")
    or shared.starts_with(body, "luacheck:")
end

---@type clwrap.LanguageSpec
return {
  marker = marker,
  directive = directive,
  classify = classify,
}
