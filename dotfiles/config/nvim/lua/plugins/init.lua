local plugins = {
    {
        name = "bazel",
        dev = true,
        dir = vim.fn.expand("$HOME/.config/nvim/lua/plugins/bazel"),
        config = function()
            require("plugins.config.bazel")
        end,
    },
    {
        -- Has to come even more first since it is used by lsp-zero.
        "williamboman/mason.nvim",
        build = ":MasonUpdate", -- :MasonUpdate updates registry contents
        config = function()
            require("plugins.config.mason")
        end,
        opts = {
            ensure_installed = {
                -- DAP
                "bash-debug-adapter",
                "cpptools",
                "debugpy",
                -- Linters/Formatters
                "black",
                "bzl",
                "isort",
                "ruff",
                "shellcheck",
                "shellharden",
                "shfmt",
            },
        },
    },
    {
        -- Has to come first, since it sets up several other plugins.
        "VonHeikemen/lsp-zero.nvim",
        branch = "v2.x",
        dependencies = {
            -- LSP Support
            { "neovim/nvim-lspconfig" }, -- Required
            -- -- We already use Mason, so this is handled below anyway.
            -- {                          -- Optional
            --     "williamboman/mason.nvim",
            --     build = function()
            --         pcall(vim.cmd, ":MasonUpdate")
            --     end,
            -- },
            { "williamboman/mason-lspconfig.nvim" }, -- Optional
            -- Autocompletion
            { "hrsh7th/nvim-cmp" },                  -- Required
            { "hrsh7th/cmp-nvim-lsp" },              -- Required
            { "L3MON4D3/LuaSnip" },                  -- Required
            { "hrsh7th/cmp-nvim-lua" },
            { "hrsh7th/cmp-path" },
            { "hrsh7th/cmp-buffer" },
            { "rafamadriz/friendly-snippets" },
            { "saadparwaiz1/cmp_luasnip" },
        },
        config = function()
            require("plugins.config.lspzero")
        end
    },
    {
        "jose-elias-alvarez/null-ls.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("plugins.config.null-ls")
        end
    },
    {
        "jay-babu/mason-null-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "jose-elias-alvarez/null-ls.nvim",
        },
        config = function()
            require("plugins.config.mason-null-ls")
        end,
    },
    {
        -- Progress bar plugin for when our LSPs are running.
        "j-hui/fidget.nvim",
        tag = "legacy",
        config = true,
    },
    {
        "neovim/nvim-lspconfig",
        config = function()
            require("plugins.config.lspconfig")
        end
    },
    {
        "nvim-telescope/telescope.nvim",
        config = function()
            require("plugins.config.telescope")
        end,
        dependencies = { "nvim-lua/plenary.nvim" },
        tag = "0.1.1",
    },
    {
        "sudormrfbin/cheatsheet.nvim",
        dependencies = {
            { 'nvim-telescope/telescope.nvim' },
            { 'nvim-lua/popup.nvim' },
            { 'nvim-lua/plenary.nvim' },
        },
        config = function()
            require("cheatsheet").setup({
                bundled_cheatsheets = {
                    disabled = { "nerd-fonts" },
                }
            })
        end
    },
    {
        "RRethy/nvim-base16",
        config = function()
            vim.cmd("colorscheme base16-solarized-light")
            -- vim.cmd("colorscheme base16-catppuccin")
        end
    },
    -- {
    --     "rose-pine/neovim",
    --     config = function()
    --         vim.cmd("colorscheme rose-pine")
    --     end
    -- },
    {
        "nvim-treesitter/nvim-treesitter",
        config = function()
            require("plugins.config.treesitter")
        end
    },
    { "nvim-treesitter/playground" },
    {
        -- Status bar. Replaces airline. Still want to try some others like
        -- feline.nvim.
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("plugins.config.lualine")
        end
    },
    {
        -- Visualize Vim's undo tree.
        "mbbill/undotree",
        config = function()
            vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
        end
    },
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        config = function()
            require("bufferline").setup({ options = { numbers = "buffer_id" } })
        end
    },
    { "adelarsq/vim-matchit" }, -- % operator for HTML, LaTeX, etc.
    -- Holdover from Vim.
    { "hashivim/vim-terraform" },
    { "AndrewRadev/linediff.vim" },
    { "AndrewRadev/tagalong.vim" }, -- change surrounding html tag
    { "ap/vim-css-color" },         -- see CSS colors in-line
    { "atweiden/vim-dragvisuals" }, -- move visual selections <Up>/.../<Right>
    {
        "nixon/vim-vmath",
        config = function()
            vim.cmd("vmap <expr> ++ VMATH_YankAndAnalyse()")
            -- vim.keymap.set("n", "++", vim.cmd("vip++"))
        end
    }, -- fork of "++" summarizer for numbers
    -- I like being able to distinguish these now.
    -- { "christoomey/vim-tmux-navigator" },     -- <A-hjkl> between vimdows and tpanes
    -- Replaced by a real LSP.
    -- { "davidhalter/jedi-vim" },   -- powerful python autcompletion/docs w/o YouCompleteMe
    -- We use ruff at work now.
    -- { "dense-analysis/ale" },       -- linter
    -- { "flazz/vim-colorschemes" },   -- lots of colorschemes
    -- I don't code in Haskell, so should probably re-set this up.
    -- { "eagletmt/ghcmod-vim" }, { "for": "haskell" }    -- stephendiehl.com/posts/vim_2016.html
    -- { "eagletmt/neco-ghc" }, {"for": "haskell" }    -- stephendiehl.com/posts/vim_2016.html
    -- { "Shougo/vimproc.vim" }, {"for": "haskell", "do": "make"}
    { "godlygeek/tabular" },  -- :Tabularize /<character to align by>
    { "honza/vim-snippets" }, -- various pre-made snippets for UltiSnips
    -- { "junegunn/fzf" }, { "do": { -> fzf#install() } } -- fast fuzzy file search
    -- { "kballard/vim-swift" }, { "for" : "swift" }    -- filetype, make commands, syntastic for Swift
    {
        "Lokaltog/vim-easymotion",
        config = function()
            require("plugins.config.easymotion")
        end
    },                        -- skip around, <leader><leader>*
    { "majutsushi/tagbar" },  -- browse C/C++ tag files in split
    { "mattn/emmet-vim" },    -- expanding html tags
    { "mhinz/vim-startify" }, -- TODO: setup after all components are in place for better landing screen
    { "mileszs/ack.vim" },    -- drop grep results into quickfix list
    -- Plug "python-rope/ropevim", { "do": "sudo python ./setup.py install" }    " advance refactoring library for python
    -- { "rust-lang/rust.vim" },     -- filetype, autoformatting, syntastic for rust
    --{ "SirVer/ultisnips" },   -- snippets manager
    -- { "tpope/vim-abolish" },      -- "semantic" substitution? :Subvert, :Abolish
    { "tpope/vim-commentary" }, -- "gc" verb to [un]comment lines
    { "tpope/vim-endwise" },    -- complete if...end blocks and similar
    { "tpope/vim-fugitive" },   -- git wrapper, <leader>g*
    -- { "tpope/vim-git" },          -- syntax/indent/etc files for git
    -- { "tpope/vim-obsession" },    -- save current open windows, folds, etc
    { "tpope/vim-repeat" },      -- make "." work as expected for plugin maps
    { "tpope/vim-speeddating" }, -- make <C-x> and <C-a> work on dates
    { "tpope/vim-surround" },    -- "s[urround]" direct object, e.g. ds, cs, ys
    { "tpope/vim-vinegar" },     -- make netrw not suck, "I" to toggle
    -- { "vim-scripts/indentpython.vim" },       -- PEP8-ier continued line indentation
    -- Using Git now: adelarsq/vim-matchit
    -- { "vim-scripts/matchit.zip" },
    -- My terminal should handle this..or :!open
    -- { "vim-scripts/utl.vim" },    -- Open links from Vim!
    -- { "altercation/vim-colors-solarized" }    {   "" }, color scheme
    -- { "morhetz/gruvbox" },    -- color scheme
    -- { "flazz/vim-colorschemes" }, -- lots of colorschemes
    -- { "NLKNguyen/papercolor-theme" },         -- another color theme
    -- { "tomasr/molokai" },         -- nice color scheme
}

return plugins
