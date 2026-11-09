local shared = require("clwrap.lang.shared")

local declarations = {
  function_declaration = true,
  test_declaration = true,
  variable_declaration = true,
}

local function classify(last, end_row)
  local parent = last:parent()
  if not parent or parent:type() ~= "source_file" then
    return "comment"
  end
  return shared.immediately_followed_by(last, end_row, declarations) and "doc" or "comment"
end

local function directive(text)
  return shared.doc_marker(text) == "//" and shared.starts_with(vim.trim(text:sub(3)), "zig fmt:")
end

---@type clwrap.LanguageSpec
return {
  marker = shared.doc_marker,
  directive = directive,
  classify = classify,
}
