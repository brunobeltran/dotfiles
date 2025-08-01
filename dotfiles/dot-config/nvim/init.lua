-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function _bazel_workspace_root(path)
  return vim.fs.root(path, '.bazelversion')
end

local function _close_window_matching(pattern)
  local window_was_closed = false
  for _, wnr in ipairs(vim.api.nvim_list_wins()) do
    local buffer = vim.api.nvim_win_get_buf(wnr)
    local buffer_name = vim.api.nvim_buf_get_name(buffer)
    if buffer_name:match(pattern) then
      vim.api.nvim_win_close(wnr, true)
      window_was_closed = true
    end
  end
  return window_was_closed
end

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: For more options, you can see `:help option-list`

-- Set most basic Vim options in a 'shared.vim' file that can also be using by
-- (non-neo) Vim.
local shared_vim_config = os.getenv 'HOME' .. '/.vim/shared.vim'
if not vim.loop.fs_stat(shared_vim_config) then
  print('Could not find shared vim config at: ' .. shared_vim_config)
else
  vim.cmd('source ' .. shared_vim_config)
end

-- Don't show the mode, since it's already in the status line
-- Not in shared.vim because Vim might not have as good of a status line.
vim.opt.showmode = false

-- Save undo history, not in shared.vim because we use the default
-- nvim-specific folder here.
vim.opt.swapfile = true
vim.opt.backupdir = os.getenv 'HOME' .. '/.vim/temp_dirs/nvim-backups'
vim.opt.backup = true
vim.opt.undodir = os.getenv 'HOME' .. '/.vim/temp_dirs/nvim-undodir'
vim.opt.undofile = true

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner, but not appropriate for Vim, which doesn't
-- have which-key.
vim.opt.timeoutlen = 300

-- Preview substitutions live, as you type!
-- Not available in base vim.
vim.opt.inccommand = 'split'

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Remove highlights from search' })
local function _delete_trailing_whitespace()
  local save = vim.fn.winsaveview()
  local function _remove_line_trailing()
    return vim.cmd [[silent %s/\s+$//e]]
  end
  local function _remove_file_trailing()
    return vim.cmd [[silent %s#($\n\s*)+%$##]]
  end
  pcall(_remove_line_trailing)
  pcall(_remove_file_trailing)
  vim.fn.winrestview(save)
end
local function _cleanup_save_and_clear()
  _delete_trailing_whitespace()
  vim.cmd [[nohlsearch]]
  vim.cmd [[redraw!]]
  vim.cmd [[w]]
end
vim.keymap.set('n', '<leader><CR>', _cleanup_save_and_clear, { desc = 'Cleanup whitespace, save, clear highlighting' })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', function()
  return vim.diagnostic.jump { count = -1, float = true }
end, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', function()
  return vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>te', vim.diagnostic.open_float, { desc = '[T]oggle diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>tq', vim.diagnostic.setloclist, { desc = "[T]oggle [Q]uickfix 'location list'" })

-- Git
vim.keymap.set('n', '<leader>Ga', vim.cmd.Gwrite, { desc = '[G]it [A]dd current file' })
vim.keymap.set('n', '<leader>Gs', vim.cmd.Gstatus, { desc = '[G]it [S]tatus' })
vim.keymap.set('n', '<leader>Gc', function()
  vim.cmd [[ Gcommit -v -q ]]
end, { desc = '[G]it [C]ommit' })
vim.keymap.set('n', '<leader>GD', vim.cmd.Gdiff, { desc = '[G]it [D]iff with Fugitive' })
vim.keymap.set('n', '<leader>Gd', vim.cmd.Gvdiffsplit, { desc = '[G]it [d]iffsplit current file' })
vim.keymap.set('n', '<leader>Gr', vim.cmd.Gread, { desc = '[G]it [R]ead/Checkout/Reset current file' })
vim.keymap.set('n', '<leader>Gl', function()
  vim.cmd [[Git! lg ]]
end, { desc = '[G]it [l]g preview' })
vim.keymap.set('n', '<leader>GL', vim.cmd.Glog, { desc = '[G]it [L]og' })
vim.keymap.set('n', '<leader>Gps', function()
  vim.cmd [[Dispatch! git push]]
end, { desc = '[G]it [P]u[s]h' })
vim.keymap.set('n', '<leader>Gpl', function()
  vim.cmd [[Dispatch! git pull]]
end, { desc = '[G]it [P]u[l]l' })

-- Keybinds to make split navigation easier.  # NOQA: E501
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- [[ Personal Keymaps ]]
--
-- Use the "go up one directory" mapping from netrw to also open netrw.
vim.keymap.set('n', '-', function()
  vim.cmd 'Ex'
end, { desc = "Open current file's directory in NetRW (i.e., view folder contents)." })
vim.keymap.set('x', '<leader>p', '"_dP', { desc = 'Paste without losing your copy buffer' })

-- Move visually-selected lines up and down (fixing indenting dynamically).
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Shift current line downward' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Shift current line upward' })

-- Preserve cursor location when using J.
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Shift current line downward' })

-- Preserve cursor in center when searching or navigating.
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- Keep me from mistakenly throwing away edits done when changing vertical
-- blocks.
vim.keymap.set('i', '<C-c>', '<Esc>', { desc = 'Send <Esc> with <C-c>' })

-- -- Typing the colon is such a slog.
vim.keymap.set('n', ']q', ':cnext<CR>', { desc = 'Jump to next (global) quickfix list entry' })
vim.keymap.set('n', '[q', ':cprev<CR>', { desc = 'Jump to previous (global) quickfix list entry' })

-- Change into the directory of the current buffer.
vim.keymap.set('n', '<leader>gcd', ':cd %:h<CR>', { desc = "[g]oto [c]urrent file's [d]irectory" })

vim.keymap.set('n', '<leader>st', ':BazelSelectTarget<CR>', { desc = '[S]earch Bazel [t]argets that dep on current file' })

-- Undotree interface
vim.keymap.set('n', '<leader>tu', vim.cmd.UndotreeToggle, { desc = '[T]oggle [U]ndotree viewer' })

-- Treesitter
-- I find it hard to remember the :InspectTree and :EditQuery commands, so we
-- add some shortcuts to make them more discoverable.
local function _toggle_ts_tree()
  if not _close_window_matching '.*Syntax tree for .*' then
    vim.cmd.InspectTree()
  end
end
vim.keymap.set('n', '<leader>tts', _toggle_ts_tree, { desc = '[T]oggle [t]reesitter [s]plit' })
local function _toggle_ts_query()
  if not _close_window_matching 'query_editor.scm$' then
    vim.cmd.EditQuery()
  end
end
vim.keymap.set('n', '<leader>ttq', _toggle_ts_query, { desc = '[T]oggle [t]reesitter [q]uery preview' })

-- Convenience for hard-to-do things.
vim.keymap.set('n', '<leader>fll', ':set paste<CR>A  # NOQA: E501<ESC>:set nopaste<CR>', {
  desc = '[F]ix [L]ine [L]ength error',
})

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- To get full diagnostic from LSP, simply hold the cursor.
-- updatetime set in `shared.vim`.
vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
  group = vim.api.nvim_create_augroup('float_diagnostic', { clear = true }),
  callback = function()
    vim.diagnostic.open_float(nil, { focus = false })
  end,
})

-- [[ Custom Filetype Patterns ]]
vim.filetype.add {
  filename = {
    ['dot-bash_aliases'] = 'sh',
    ['.bash_aliases'] = 'sh',
    ['dot-set_path'] = 'sh',
    ['.set_path'] = 'sh',
    ['dot-bash_completion'] = 'sh',
    ['.bash_completion'] = 'sh',
    ['.sqlfluff'] = 'dosini',
  },
}

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  'tpope/vim-surround', -- Expand the known set of delimiters.
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  'tpope/vim-fugitive', -- Git integration, old school
  'mbbill/undotree', -- Visualize Vim's "Undotree"

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.
  --
  { 'akinsho/bufferline.nvim', version = '*', dependencies = 'nvim-tree/nvim-web-devicons' },

  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`. This is equivalent to the following Lua:
  --    require('gitsigns').setup({ ... })
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']h', function()
          if vim.wo.diff then
            vim.cmd.normal { ']h', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to next [h]unk / git change' })

        map('n', '[h', function()
          if vim.wo.diff then
            vim.cmd.normal { '[h', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to previous [h]unk / git change' })

        -- Actions
        -- visual mode
        map('v', '<leader>Ga', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[G]it [A]dd hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[G]it [R]eset hunk' })
        -- normal mode
        map('n', '<leader>Gha', gitsigns.stage_hunk, { desc = '[G]it [h]unk [s]tage' })
        map('n', '<leader>Ghr', gitsigns.reset_hunk, { desc = '[G]it [h]unk [r]eset' })
        map('n', '<leader>Ghu', gitsigns.undo_stage_hunk, { desc = '[G]it [h]unk [u]ndo stage' })
        map('n', '<leader>Gp', gitsigns.preview_hunk, { desc = '[G]it [p]review hunk' })
        map('n', '<leader>Gb', gitsigns.blame_line, { desc = '[G]it [b]lame line' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
        map('n', '<leader>tD', gitsigns.toggle_deleted, { desc = '[T]oggle git show [D]eleted' })
      end,
    },
  },
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    opts = {
      indent = {
        char = '▏',
      },
      scope = {
        show_start = false,
        show_end = false,
      },
    },
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>G', group = '[G]it' },
        { '<leader>b', group = '[b]uffer' },
        { '<leader>f', group = '[f]ix' },
        { '<leader>fl', group = '[f]ix [l]ine error via NOQA' },
        -- "[G]oto" sometimes directly goes, but often pops up a search window
        -- with options. For regular "goto definition", <C-]> is still fine.
        { '<leader>g', group = '[g]oto' },
        { '<leader>o', group = '[o]pen' },
        { '<leader>r', group = '[r]ename' },
        { '<leader>s', group = '[s]earch' },
        { '<leader>sp', group = '[s]earch [p]lugins' },
        { '<leader>t', group = '[t]oggle' },
        { '<leader>tt', group = '[t]oggle [t]reesitter' },
        -- Maybe re-instate once I start using build-related commands?
        -- { '<leader>w', group = '[W]orkspace' },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          path_display = { 'absolute', 'smart' },
        },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sm', builtin.builtin, { desc = '[S]earch Categories ([M]eta-Search)"' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sb', builtin.buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>spf', function()
        -- stdpath returns a single string for 'data', list for 'data_dir'.
        local data_dir = vim.fn.stdpath 'data' --[[@as string]]
        require('telescope.builtin').find_files {
          cwd = vim.fs.joinpath(data_dir, 'lazy'),
        }
      end, { desc = '[S]each [P]lugin [F]iles' })
      vim.keymap.set('n', '<leader>spg', function()
        -- stdpath returns a single string for 'data', list for 'data_dir'.
        local data_dir = vim.fn.stdpath 'data' --[[@as string]]
        require('telescope.builtin').live_grep {
          search_dirs = { vim.fs.joinpath(data_dir, 'lazy') },
        }
      end, { desc = '[S]each [P]lugin [G]rep' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by nvim-cmp
      'hrsh7th/cmp-nvim-lsp',
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end
          map('<leader>gd', require('telescope.builtin').lsp_definitions, '[G]oto [d]efinition')
          map('<leader>gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('<leader>gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('<leader>gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>gT', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
          map('<leader>ss', require('telescope.builtin').lsp_document_symbols, '[S]earch LSP [S]ymbols')
          map('<leader>sw', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[S]earch [W]orkspace')
          map('<leader>ri', vim.lsp.buf.rename, '[R]ename [I]dentifier')
          map('<leader>fx', vim.lsp.buf.code_action, '[F]i[x]/Code Action', { 'n', 'x' })

          -- Make inlay hints (e.g., visually make `f(5)` into `f(x=5)`)
          -- toggle-able. We usually don't want them,
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Change diagnostic symbols in the sign column (gutter)
      if vim.g.have_nerd_font then
        local signs = { ERROR = '', WARN = '', INFO = '', HINT = '' }
        local diagnostic_signs = {}
        for type, icon in pairs(signs) do
          diagnostic_signs[vim.diagnostic.severity[type]] = icon
        end
        vim.diagnostic.config { signs = { text = diagnostic_signs } }
      end

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},
        --
        --
        pyright = {
          cmd = { 'pyright-langserver', '--stdio' }, -- Same as default, copied here for reference.
          root_dir = function(filename, bufnr)
            local bazel_root = _bazel_workspace_root(filename)
            if bazel_root ~= nil then
              return bazel_root
            end
            local python_root = vim.fs.root(filename, { 'pyproject.toml', 'setup.py' })
            if python_root ~= nil then
              return python_root
            end
            local cwd = vim.fn.getcwd()
            bazel_root = _bazel_workspace_root(cwd)
            if bazel_root ~= nil then
              return bazel_root
            end
            return nil
          end,
          on_new_config = function(new_config, new_root_dir)
            local python_path = nil
            local bazel_python_bin = vim.fs.joinpath(new_root_dir, '.pyright_python_executable')
            if vim.fn.filereadable(bazel_python_bin) then
              python_path = bazel_python_bin
            end
            if python_path == nil then
              python_path = vim.fn.exepath 'python'
            end
            if python_path == nil then
              vim.notify(
                "Unable to find Python on Neovim's exepath or a .pyright_python_executable file, Pyright will default to its built-in Python executable!",
                vim.log.levels.WARN
              )
            else
              new_config.cmd[#new_config.cmd + 1] = '--pythonpath'
              new_config.cmd[#new_config.cmd + 1] = python_path
            end
          end,
          settings = {
            -- python = {
            --   pythonPath = vim.fn.exepath 'python',
            -- },
          },
        },
        lua_ls = {
          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
        starpls = {},
      }

      -- Ensure the servers and tools above are installed
      --  To check the current status of installed tools and/or manually install
      --  other tools, you can run
      --    :Mason
      --
      --  You can press `g?` for help in this menu.
      require('mason').setup()

      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    dependencies = {
      { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>F',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    config = function()
      local formatters_by_ft = {
        cpp = { 'clang_format' },
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        python = { 'isort', 'black', 'ruff' },
        sql = { 'sqlfluff' },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      }
      local ensure_installed = {}
      for _, formatters in pairs(formatters_by_ft) do
        for _, formatter in ipairs(formatters) do
          table.insert(ensure_installed, formatter)
        end
      end
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }
      require('conform').setup {
        notify_on_error = true,
        format_on_save = function(bufnr)
          -- Disable "format_on_save lsp_fallback" for languages that don't
          -- have a well standardized coding style. You can add additional
          -- languages here or re-enable it for the disabled ones.
          local disable_filetypes = { c = true, cpp = true, python = true }
          local lsp_format_opt
          if disable_filetypes[vim.bo[bufnr].filetype] then
            lsp_format_opt = 'never'
          else
            lsp_format_opt = 'fallback'
          end
          return {
            timeout_ms = 500,
            lsp_format = lsp_format_opt,
          }
        end,
        formatters_by_ft = formatters_by_ft,
        log_level = vim.log.levels.INFO,
        formatters = {
          black = {
            prepend_args = { '--fast' },
          },
          buildifier = {},
          --   -- Don't need SQLfluff config because I switched to using per-project
          --   -- files.
          --   sqlfluff = {
          --     -- Can't use `prepend_args` since default is `fix -`, and --dialect
          --     -- has to come _after_ the `fix`.
          --     args = { 'fix', '--dialect', 'duckdb', '-' },
          --   },
        },
      }
    end,
  },

  { -- Autocompletion
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
      },
      'saadparwaiz1/cmp_luasnip',

      -- Adds other completion capabilities.
      --  nvim-cmp does not ship with all sources by default. They are split
      --  into multiple repos for maintenance purposes.
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
    },
    config = function()
      -- See `:help cmp`
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noinsert' },

        -- For an understanding of why these mappings were
        -- chosen, you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert {
          -- Select the [n]ext item
          ['<C-n>'] = cmp.mapping.select_next_item(),
          -- Select the [p]revious item
          ['<C-p>'] = cmp.mapping.select_prev_item(),

          -- Scroll the documentation window [b]ack / [f]orward
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),

          -- Accept ([y]es) the completion.
          --  This will auto-import if your LSP supports it.
          --  This will expand snippets if the LSP sent a snippet.
          ['<C-y>'] = cmp.mapping.confirm { select = true },

          -- If you prefer more traditional completion keymaps,
          -- you can uncomment the following lines
          --['<CR>'] = cmp.mapping.confirm { select = true },
          --['<Tab>'] = cmp.mapping.select_next_item(),
          --['<S-Tab>'] = cmp.mapping.select_prev_item(),

          -- Manually trigger a completion from nvim-cmp.
          --  Generally you don't need this, because nvim-cmp will display
          --  completions whenever it has completion options available.
          ['<C-Space>'] = cmp.mapping.complete {},

          -- Think of <c-l> as moving to the right of your snippet expansion.
          --  So if you have a snippet that's like:
          --  function $name($args)
          --    $body
          --  end
          --
          -- <c-l> will move you to the right of each of the expansion locations.
          -- <c-h> is similar, except moving you backwards.
          ['<C-l>'] = cmp.mapping(function()
            if luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            end
          end, { 'i', 's' }),
          ['<C-h>'] = cmp.mapping(function()
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            end
          end, { 'i', 's' }),

          -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
          --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
        },
        sources = {
          {
            name = 'lazydev',
            -- set group index to 0 to skip loading LuaLS completions as lazydev recommends it
            group_index = 0,
          },
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
        },
      }
    end,
  },

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      { 'williamboman/mason.nvim', config = true }, -- NOTE: Must be loaded before dependants
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        dockerfile = { 'hadolint' },
        markdown = { 'vale' },
        -- Not needed since redundant relative to the LSP.
        -- python = { 'ruff' },
        rst = { 'vale' },
        sql = { 'sqlfluff' },
        text = { 'vale' },
        -- Not needed since we have `terraformls`.
        -- terraform = { 'tflint' },
      }
      local ensure_installed = {}
      for _, linters in pairs(lint.linters_by_ft) do
        for _, linter in ipairs(linters) do
          table.insert(ensure_installed, linter)
        end
      end
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify in order to
          -- avoid superfluous noise, notably within the handy LSP pop-ups that
          -- describe the hovered symbol using Markdown.
          if vim.opt_local.modifiable:get() then
            lint.try_lint()
          end
        end,
      })
    end,
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    opts = {},
    init = function()
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight'.
      --
      -- We choose this one to slightly mis-match catppuccin, so that (Neo)vim
      -- panes are distinguishable easily from terminal panes in tmux.
      vim.cmd.colorscheme 'tokyonight-day'

      -- You can configure highlights by doing something like:
      vim.cmd.hi 'Comment gui=none'
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = { flavour = 'latte' },
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'dockerfile',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'regex',
        'query',
        'python',
        'sql',
        'vim',
        'vimdoc',
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
  { -- Debugging
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'theHamsta/nvim-dap-virtual-text',
      'nvim-neotest/nvim-nio',
      'williamboman/mason.nvim',
    },
    config = function()
      dap = require 'dap'
      local ui = require 'dapui'
      ui.setup()
      require('nvim-dap-virtual-text').setup()

      vim.keymap.set('n', '<leader>d?', function()
        ui.eval(nil, { enter = true })
      end, { desc = '[D]ebug [?] value under cursor' })

      dap.listeners.before.attach.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        ui.open()
      end
    end,
  },
  --
  -- TODO: Incorporate equivalents to kickstart's debug/lint configs.
  -- require 'kickstart.plugins.lint',
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
