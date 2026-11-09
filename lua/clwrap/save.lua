local M = {}

---Install the save hook. Repeated calls replace the previous hook atomically.
function M.setup()
  local group = vim.api.nvim_create_augroup("clwrap", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function(event)
      local enabled = vim.b[event.buf].clwrap_format_on_save
      if enabled == nil then
        enabled = require("clwrap.config").options.format_on_save
      end
      if not enabled or not require("clwrap.lang").filetypes[vim.bo[event.buf].filetype] then
        return
      end
      local changed, err = require("clwrap.formatter").format(event.buf)
      if not changed and err then
        vim.notify(err, vim.log.levels.ERROR, { title = "clwrap" })
      end
    end,
    desc = "Reflow comments before writing",
  })
end

return M
