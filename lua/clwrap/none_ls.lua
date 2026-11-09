local languages = require("clwrap.languages")
local parser = require("clwrap.parser")

return {
  name = "clwrap",
  method = "NULL_LS_FORMATTING",
  filetypes = vim.tbl_keys(languages.filetypes),
  generator = {
    fn = function(params)
      local config = require("clwrap.config").resolve(params.bufnr)
      config.lang = languages.filetypes[vim.bo[params.bufnr].filetype]
      local edits, err = parser.edits(params.content, config)
      if not edits then
        error(err, 0)
      end
      if #edits == 0 then
        return {}
      end
      return { { text = table.concat(parser.render(params.content, edits), "\n") } }
    end,
  },
}
