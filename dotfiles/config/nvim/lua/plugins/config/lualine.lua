local _MAX_SECTION_LENGTH = 16
local _truncate = function(str)
    if #str > _MAX_SECTION_LENGTH then
        return str:sub(1, _MAX_SECTION_LENGTH - 3) .. "..."
    else
        return str
    end
end

require("lualine").setup {
    sections = {
        -- +-----------------------------------+
        -- | A | B | C               X | Y | Z |
        -- +-----------------------------------+
        lualine_b = {
            { 'branch', fmt = _truncate } },
        lualine_x = { 'encoding', 'filetype' },
    },
}
