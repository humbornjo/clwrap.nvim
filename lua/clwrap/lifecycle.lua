local M = {}

local function check_filetype(bufnr)
  local lang = require("clwrap.lang").filetypes[vim.bo[bufnr].filetype]
  if lang then
    require("clwrap.parser").available(lang)
  end
end

---Install buffer-loading and save hooks. Repeated calls replace them atomically.
function M.setup()
  local group = vim.api.nvim_create_augroup("clwrap", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(event)
      check_filetype(event.buf)
    end,
    desc = "Warn once when a supported comment parser is unavailable",
  })
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
  check_filetype(vim.api.nvim_get_current_buf())
end

return M
