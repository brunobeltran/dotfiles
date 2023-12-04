local cmp = require("cmp")
local cmp_action = require("lsp-zero").cmp_action()

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
    sources = {
        { name = "path" },
        { name = "nvim_lsp" },
        { name = "buffer",  keyword_length = 5 },
        { name = "luasnip", keyword_length = 2 },
        { name = "nvim_lua" },
    },
    mapping = {
        -- `Ctrl+Space` key to confirm completion. Enter is annoying.
        ["<C-Space>"] = cmp.mapping.confirm({
            select = true,
            behavior = cmp.ConfirmBehavior.Replace,
        }),

        -- Navigate between snippet placeholder
        ["<C-j>"] = cmp_action.luasnip_jump_forward(),
        ["<C-k>"] = cmp_action.luasnip_jump_backward(),
    },
    preselect = "item",
    performance = {
        debounce = 200,
        -- fetching_timeout = 200,
        max_view_entries = 10,
        -- throttle = 60,
    },
    completion = {
        completeopt = "menu,menuone,insert"
    },
})
