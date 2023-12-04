local lspconfig = require("lspconfig")
-- Configure `ruff-lsp`.
local configs = require("lspconfig.configs")
if not configs.ruff_lsp then
    configs.ruff_lsp = {
        default_config = {
            cmd = { 'ruff-lsp' },
            filetypes = { 'python' },
            root_dir = require('lspconfig').util.find_git_ancestor,
            init_options = {
                settings = {
                    args = {}
                }
            }
        }
    }
end
lspconfig.ruff_lsp.setup({})
lspconfig.pyright.setup({
    settings = {
        pyright = {
            disableOrganizeImports = true,
            openFilesOnly = true,
            useLibraryCodeForTypes = true,
        },
        python = {
            analysis = {
                autoImportCompletions = true,
                autoSearchPaths = true,
                diagnosticMode = 'openFilesOnly',
                typeCheckingMode = "basic",
            },
        },
    },
})
lspconfig.taplo.setup({})
