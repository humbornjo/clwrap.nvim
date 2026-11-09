if vim.g.loaded_clwrap then
  return
end
vim.g.loaded_clwrap = true

require("clwrap.commands").setup()
