local lspconfig = require("lspconfig")
local bazel = require("bazel.api")
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
