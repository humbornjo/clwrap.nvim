local M = {}

function M.check()
  vim.health.start("clwrap")
  vim.health.ok("Neovim " .. tostring(vim.version()))

  vim.health.start("Tree-sitter parsers")
  local languages = require("clwrap.lang")
  for filetype, lang in vim.spairs(languages.filetypes) do
    local ok, installed, err = pcall(vim.treesitter.language.add, lang)
    if ok and installed then
      vim.health.ok(("%s: %s parser installed"):format(filetype, lang))
    else
      vim.health.warn(("%s: %s parser unavailable"):format(filetype, lang), err or installed)
    end
  end

  vim.health.start("Optional integrations")
  if pcall(require, "virt-column.config") then
    vim.health.ok("virt-column.nvim found; configured columns are available")
  else
    vim.health.info("virt-column.nvim not found; using editorconfig and defaults")
  end
  if pcall(require, "null-ls") then
    vim.health.info("none-ls found; add require('clwrap.none_ls') to its sources to enable formatting")
  else
    vim.health.info("none-ls not found; native commands and format-on-save remain available")
  end
end

return M
