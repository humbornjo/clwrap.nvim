local shared = require("clwrap.lang.shared")

local declarations = {
  abstract_class_declaration = true,
  ambient_declaration = true,
  class_declaration = true,
  enum_declaration = true,
  function_declaration = true,
  function_signature = true,
  generator_function_declaration = true,
  import_alias = true,
  interface_declaration = true,
  internal_module = true,
  lexical_declaration = true,
  module = true,
  type_alias_declaration = true,
  variable_declaration = true,
}

local function classify(last, end_row)
  local parent = last:parent()
  if not parent or parent:type() ~= "program" then
    return "comment"
  end
  local next = last:next_named_sibling()
  if not next then
    return "comment"
  end
  local kind = next:type()
  if kind == "export_statement" then
    next = next:field("declaration")[1]
  elseif kind == "expression_statement" then
    next = next:named_child(0)
  end
  if not next then
    return "comment"
  end
  local start_row = next:range()
  return start_row == end_row + 1 and declarations[next:type()] and "doc" or "comment"
end

local function directive(text)
  if shared.starts_with(text, "///") then
    return true
  end
  local body = vim.trim(text:sub(3))
  return shared.starts_with(body, "@ts-")
    or body == "eslint"
    or shared.starts_with(body, "eslint-")
    or shared.starts_with(body, "eslint ")
    or shared.starts_with(body, "tslint:")
    or shared.starts_with(body, "prettier-ignore")
    or shared.starts_with(body, "biome-ignore")
    or shared.starts_with(body, "istanbul ignore")
    or shared.starts_with(body, "c8 ignore")
end

---@type clwrap.LanguageSpec
return {
  marker = shared.slash_marker,
  directive = directive,
  classify = classify,
}
