local M = {}

---@class clwrap.Edit
---@field start_row integer Zero-based inclusive start row.
---@field end_row integer Zero-based exclusive end row.
---@field lines string[] Replacement lines.

---Apply non-overlapping edits to a buffer from bottom to top.
---@param bufnr integer
---@param edits clwrap.Edit[]
function M.apply(bufnr, edits)
  for i = #edits, 1, -1 do
    local edit = edits[i]
    vim.api.nvim_buf_set_lines(bufnr, edit.start_row, edit.end_row, false, edit.lines)
  end
end

---Render non-overlapping edits against source lines without modifying a buffer.
---@param lines string[]
---@param edits clwrap.Edit[]
---@return string[]
function M.render(lines, edits)
  lines = vim.deepcopy(lines)
  for i = #edits, 1, -1 do
    local edit = edits[i]
    for _ = edit.start_row + 1, edit.end_row do
      table.remove(lines, edit.start_row + 1)
    end
    for j = #edit.lines, 1, -1 do
      table.insert(lines, edit.start_row + 1, edit.lines[j])
    end
  end
  return lines
end

return M
