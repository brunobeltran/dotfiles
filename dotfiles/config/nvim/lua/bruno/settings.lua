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
