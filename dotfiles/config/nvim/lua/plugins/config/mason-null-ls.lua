require("mason-null-ls").setup({
    ensure_installed = {
        "black",
        "isort",
        "prettierd",
        "ruff",
        "shfmt",
        "yamlfmt",
    },
    automatic_installation = true,
})
