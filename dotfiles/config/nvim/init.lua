-- We mirror the configuration structure of github.com/NvChad/NvChad:
--
-- 1. First require any core (Lua) helper utilities (currently none).
-- 2. Bootstrap Lazy.nvim (plugin manager) and other things using a dedicated
--    "bootstrap" module.
-- 3. Load in "simple" config (shared with vim) if it exists.
-- 4. Require our nvim-specific configuration, which is allowed to depend on
--    stuff that was bootstrapped in.

require("core")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    require("core.bootstrap").lazy(lazypath)
end
vim.opt.rtp:prepend(lazypath)

require("bruno")
local shared_vim_config = os.getenv("HOME") .. "/.vim/shared.vim"
require("core.shared").maybe_source(shared_vim_config)


require("lazy").setup(require("plugins"))
