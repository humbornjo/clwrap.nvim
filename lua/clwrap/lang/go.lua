local shared = require("clwrap.lang.shared")

local root_declarations = {
  const_declaration = true,
  function_declaration = true,
  import_declaration = true,
  method_declaration = true,
  package_clause = true,
  type_declaration = true,
  var_declaration = true,
}

local spec_declarations = {
  const_spec = true,
  import_spec = true,
  type_spec = true,
  var_spec = true,
}

local spec_parents = {
  const_declaration = true,
  import_declaration = true,
  type_declaration = true,
  var_declaration = true,
}

local function classify(last, end_row)
  local parent = last:parent()
  if not parent then
    return "comment"
  end
  if parent:type() == "source_file" then
    return shared.immediately_followed_by(last, end_row, root_declarations) and "doc" or "comment"
  end
  if spec_parents[parent:type()] and parent:parent() and parent:parent():type() == "source_file" then
    return shared.immediately_followed_by(last, end_row, spec_declarations) and "doc" or "comment"
  end
  return "comment"
end

local function directive(text)
  local body = text:sub(3)
  return body ~= "" and not shared.starts_with(body, " ")
end

---@type clwrap.LanguageSpec
return {
  marker = shared.slash_marker,
  directive = directive,
  classify = classify,
}
