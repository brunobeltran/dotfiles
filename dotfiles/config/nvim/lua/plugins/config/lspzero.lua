local lsp = require("lsp-zero").preset({
    manage_nvim_cmp = {
        set_sources = "recommended"
    }
})

lsp.on_attach(function(client, bufnr) -- NOQA
    lsp.default_keymaps({ buffer = bufnr })
end)

lsp.ensure_installed({
    "bashls",
    "bufls",
    -- "bzl",
    "clangd",
    "cssls",
    "dockerls",
    "html",
    "jsonls",
    "lua_ls",
    "marksman",
    "pyright",
    "rust_analyzer",
    "sqlls",
    "tailwindcss",
    "terraformls",
    "tflint",
    "texlab",
    "vimls",
    "volar",
    "yamlls",
})

lsp.format_on_save({
    format_opts = {
        async = false,
        timeout_ms = 10000,
    },
    servers = {
        ['lua_ls'] = { 'lua' },
        ['rust_analyzer'] = { 'rust' },
    }
})


-- (Optional) Configure lua language server for neovim
require("lspconfig").lua_ls.setup(lsp.nvim_lua_ls())

lsp.setup()

-- You need to setup `cmp` after lsp-zero
local cmp = require("cmp")
local cmp_action = require("lsp-zero").cmp_action()

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
    sources = {
        { name = "path" },
        { name = "nvim_lsp" },
        { name = "buffer",  keyword_length = 3 },
        { name = "luasnip", keyword_length = 2 },
        { name = "nvim_lua" },
    },
    mapping = {
        -- `Ctrl+Space` key to confirm completion. Enter is annoying.
        ["<C-Space>"] = cmp.mapping.confirm({ select = false }),

        -- Navigate between snippet placeholder
        ["<C-f>"] = cmp_action.luasnip_jump_forward(),
        ["<C-b>"] = cmp_action.luasnip_jump_backward(),
    },
    preselect = "item",
    completion = {
        completeopt = "menu,menuone,noinsert"
    },
})
