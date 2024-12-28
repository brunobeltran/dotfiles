local shared_vim_config = os.getenv("HOME") .. "/.vim/shared.vim"
if not vim.loop.fs_stat(shared_vim_config) then
    echo("Could not find shared vim config at: " .. shared_vim_config)
else
    vim.cmd("source " .. shared_vim_config)
end
