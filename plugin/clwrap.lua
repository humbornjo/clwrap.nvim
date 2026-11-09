if vim.g.loaded_clwrap then
  return
end
vim.g.loaded_clwrap = true

vim.api.nvim_create_user_command("Clwrap", function()
  local changed, err = require("clwrap").format(0)
  if not changed and err then
    vim.notify(err, vim.log.levels.ERROR, { title = "clwrap" })
  end
end, { desc = "Reflow standalone comments in the current buffer" })

vim.api.nvim_create_user_command("ClwrapAll", function(args)
  local report = require("clwrap").format_all(args.args ~= "" and args.args or nil)
  local messages = {
    ("clwrap: %d formatted, %d unchanged, %d modified buffers skipped, %d failed"):format(
      #report.formatted,
      #report.unchanged,
      #report.skipped,
      #report.errors
    ),
  }
  for i = 1, math.min(#report.errors, 5) do
    messages[#messages + 1] = ("%s: %s"):format(report.errors[i].path, report.errors[i].error)
  end
  if #report.errors > 5 then
    messages[#messages + 1] = ("... and %d more errors"):format(#report.errors - 5)
  end
  vim.notify(table.concat(messages, "\n"), #report.errors > 0 and vim.log.levels.WARN or vim.log.levels.INFO, {
    title = "clwrap",
  })
end, {
  nargs = "?",
  complete = "dir",
  desc = "Reflow supported files below Neovim's cwd or the given directory",
})
