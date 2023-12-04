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
    "taplo",
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

require("lspconfig").lua_ls.setup(lsp.nvim_lua_ls())

lsp.setup()

require("plugins.config.cmp")
