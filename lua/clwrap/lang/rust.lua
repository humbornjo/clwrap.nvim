local shared = require("clwrap.lang.shared")

local declarations = {
  const_item = true,
  enum_item = true,
  extern_crate_declaration = true,
  function_item = true,
  function_signature_item = true,
  macro_definition = true,
  mod_item = true,
  static_item = true,
  struct_item = true,
  trait_item = true,
  type_item = true,
  union_item = true,
}

local function classify(last, end_row)
  local parent = last:parent()
  if not parent or parent:type() ~= "source_file" then
    return "comment"
  end
  local row = end_row
  local next = last:next_named_sibling()
  while next and next:type() == "attribute_item" do
    local start_row, _, final_row = next:range()
    if start_row ~= row + 1 then
      return "comment"
    end
    row = final_row
    next = next:next_named_sibling()
  end
  if not next or not declarations[next:type()] then
    return "comment"
  end
  local start_row = next:range()
  return start_row == row + 1 and "doc" or "comment"
end

local function directive(text)
  return shared.doc_marker(text) == "//" and shared.starts_with(vim.trim(text:sub(3)), "rustfmt::")
end

---@type clwrap.LanguageSpec
return {
  marker = shared.doc_marker,
  directive = directive,
  classify = classify,
}
