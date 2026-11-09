local languages = require("clwrap.languages")

local M = {}

function M.check()
  vim.health.start("clwrap")
  for filetype, lang in vim.spairs(languages.filetypes) do
    local ok, installed, err = pcall(vim.treesitter.language.add, lang)
    if ok and installed then
      vim.health.ok(("%s: %s parser installed"):format(filetype, lang))
    else
      vim.health.warn(("%s: %s parser unavailable"):format(filetype, lang), err or installed)
    end
  end
  if pcall(require, "virt-column.config") then
    vim.health.ok("virt-column.nvim found; configured columns are available")
  else
    vim.health.info("virt-column.nvim not found; using editorconfig and defaults")
  end
end

return M
