local M = {}

M.filetypes = {
  go = "go",
  typescript = "typescript",
  typescriptreact = "tsx",
  rust = "rust",
  zig = "zig",
}

M.extensions = {
  cts = "typescript",
  go = "go",
  mts = "typescript",
  rs = "rust",
  ts = "typescript",
  tsx = "tsx",
  zig = "zig",
}

---@param path string
---@return string?
function M.for_path(path)
  local extension = path:match("%.([^%.]+)$")
  return extension and M.extensions[extension:lower()] or nil
end

local function starts_with(text, prefix)
  return text:sub(1, #prefix) == prefix
end

local function contains(set, value)
  return set[value] == true
end

local function slash_marker(text)
  return starts_with(text, "//") and "//" or nil
end

local function doc_marker(text)
  if starts_with(text, "////") then
    return nil
  elseif starts_with(text, "///") then
    return "///"
  elseif starts_with(text, "//!") then
    return "//!"
  elseif starts_with(text, "//") then
    return "//"
  end
end

local function immediately_followed_by(last, end_row, declarations)
  local next = last:next_named_sibling()
  if not next then
    return false
  end
  local start_row = next:range()
  return start_row == end_row + 1 and contains(declarations, next:type())
end

local go_root_declarations = {
  const_declaration = true,
  function_declaration = true,
  import_declaration = true,
  method_declaration = true,
  package_clause = true,
  type_declaration = true,
  var_declaration = true,
}

local go_spec_declarations = {
  const_spec = true,
  import_spec = true,
  type_spec = true,
  var_spec = true,
}

local go_spec_parents = {
  const_declaration = true,
  import_declaration = true,
  type_declaration = true,
  var_declaration = true,
}

local function go_classify(last, end_row)
  local parent = last:parent()
  if not parent then
    return "comment"
  end
  if parent:type() == "source_file" then
    return immediately_followed_by(last, end_row, go_root_declarations) and "doc" or "comment"
  end
  if go_spec_parents[parent:type()] and parent:parent() and parent:parent():type() == "source_file" then
    return immediately_followed_by(last, end_row, go_spec_declarations) and "doc" or "comment"
  end
  return "comment"
end

local function go_directive(text)
  local body = text:sub(3)
  return body ~= "" and not starts_with(body, " ")
end

local typescript_declarations = {
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

local function typescript_classify(last, end_row)
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
  return start_row == end_row + 1 and typescript_declarations[next:type()] and "doc" or "comment"
end

local function typescript_directive(text)
  if starts_with(text, "///") then
    return true
  end
  local body = vim.trim(text:sub(3))
  return starts_with(body, "@ts-")
    or body == "eslint"
    or starts_with(body, "eslint-")
    or starts_with(body, "eslint ")
    or starts_with(body, "tslint:")
    or starts_with(body, "prettier-ignore")
    or starts_with(body, "biome-ignore")
    or starts_with(body, "istanbul ignore")
    or starts_with(body, "c8 ignore")
end

local rust_declarations = {
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

local function rust_classify(last, end_row)
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
  if not next or not rust_declarations[next:type()] then
    return "comment"
  end
  local start_row = next:range()
  return start_row == row + 1 and "doc" or "comment"
end

local function rust_directive(text)
  return doc_marker(text) == "//" and starts_with(vim.trim(text:sub(3)), "rustfmt::")
end

local zig_declarations = {
  function_declaration = true,
  test_declaration = true,
  variable_declaration = true,
}

local function zig_classify(last, end_row)
  local parent = last:parent()
  if not parent or parent:type() ~= "source_file" then
    return "comment"
  end
  return immediately_followed_by(last, end_row, zig_declarations) and "doc" or "comment"
end

local function zig_directive(text)
  return doc_marker(text) == "//" and starts_with(vim.trim(text:sub(3)), "zig fmt:")
end

M.specs = {
  go = {
    comment_types = { comment = true },
    marker = slash_marker,
    directive = go_directive,
    classify = go_classify,
  },
  typescript = {
    comment_types = { comment = true },
    marker = slash_marker,
    directive = typescript_directive,
    classify = typescript_classify,
  },
  tsx = {
    comment_types = { comment = true },
    marker = slash_marker,
    directive = typescript_directive,
    classify = typescript_classify,
  },
  rust = {
    comment_types = { line_comment = true, block_comment = true },
    marker = doc_marker,
    directive = rust_directive,
    classify = rust_classify,
  },
  zig = {
    comment_types = { comment = true },
    marker = doc_marker,
    directive = zig_directive,
    classify = zig_classify,
  },
}

return M
