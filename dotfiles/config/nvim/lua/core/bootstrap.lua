local M = {}

local echo = require("core.utils").echo

M.lazy = function(install_path)
  echo("Lazy.nvim not found, cloning...")
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    repo,
    "--branch=stable", -- latest stable release
    lazypath,
  })
  echo("Done cloning Lazy.nvim!")
end

return M
