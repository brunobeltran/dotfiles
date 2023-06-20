local M = {}

local echo = require("core.utils").echo

M.maybe_source = function(config_path) 
    if not vim.loop.fs_stat(config_path) then
        echo("Could not find shared vim config at: " .. config_path)
    else
        vim.cmd("source " .. config_path)
    end
end

return M
