local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(source, ":p")))
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.fs.joinpath(vim.fn.stdpath("data"), "site"))
vim.o.swapfile = false
