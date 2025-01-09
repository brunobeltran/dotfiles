local M = {}

---@return vim.treesitter.Query
function M.sql_in_python_query()
  return vim.treesitter.query.parse(
    'python',
    [[
(call
  function: (attribute 
    object: (identifier) @object (#eq? @object "conn")
    attribute: (identifier) @attr (#eq? @attr "execute")) 
  arguments: (argument_list
    (string
      (string_content) @sql)))
  ]]
  )
end

function M.get_python_threesitter_root(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, 'python', {})
  if parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  return tree:root()
end

function M.format_sql_in_python_string(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'python' then
    vim.notify(
      'Tried to format embedded SQL strings in a file, but this only works in Python and the provided buf '
        .. tostring(bufnr)
        .. ' is not a Python buffer, its `filetype` is set to '
        .. tostring(vim.bo[bufnr].filetype)
    )
    return
  end
  local root = M.get_python_threesitter_root(bufnr)
  if root == nil then
    vim.notify('Parsing failure in buffer #' .. tostring(bufnr) .. ', will not format SQL strings')
    return
  end
  local query = M.sql_in_python_query()
  local changes = {}
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    if name == 'sql' then
      ---@type integer[]
      --- start row, start col, end row, end col
      local range = { node:range() }
      -- Spaces equal to start col of string_content node.
      local indentation = string.rep(' ', range[2])
    end
  end
  return changes
end

return M
