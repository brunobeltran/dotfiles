require("mason-null-ls").setup({
    ensure_installed = {
        "black",
        "isort",
        "ruff",
        "shfmt",
        "terraform_fmt",
        "yamlfmt",
    },
    automatic_installation = true,
})
