vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.colorcolumn = "80"

vim.opt.swapfile = true
vim.opt.backupdir = os.getenv("HOME") .. "/.vim/temp_dirs/nvim-backups"
vim.opt.backup = true
vim.opt.undodir = os.getenv("HOME") .. "/.vim/temp_dirs/nvim-undodir"
vim.opt.undofile = true

vim.g.python3_host_prog = os.getenv("HOME") .. "/.miniconda/envs/neovim/bin/python"
vim.cmd [[
let g:python_indent = {'disable_parentheses_indenting': v:false, 'closed_paren_align_last_line': v:false, 'searchpair_time out': 150, 'continue': 'shiftwidth() * 2', 'open_paren': 'shiftwidth()', 'nested_paren': 'shiftwidth()'}
]]
