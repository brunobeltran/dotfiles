-- We opt for the simplest possible organization
--
-- Most of our Neovim "magic" comes from simply loading a nice set of plugins
-- from "plugins".
--
-- Literally everything else is organized into a "config" folder. We require all
-- "config.*" code from here, documenting what each require'd piece of code is
-- doing.

-- -- -- Bootstrap the environment
--
-- Setup our plugin manager.
require("config.lazy")
-- Some health checks vendored from `kickstart.nvim`.
require("config.kickstart.health").check()

-- -- -- Vim-side Settings
--
-- Load configuration settings that are shared with Vim before our plugins, to
-- allow them to be clobbered by new, neovim-specific code.
require("config.shared")

-- -- -- Load and configure all plugins.
--
-- We want to ensure our plugin config is loaded first, so that our later keymap
-- code can feel free to simply directly "require" in the appropriate plugins.
require("lazy").setup(require("plugins"))

-- -- -- General Settings: display, buffer strategies, undo, history, etc.
--
-- Load configuration settings that were either redefined since we switched to
-- neovim, or are neovim-specific.
require("config.settings")

-- -- -- KEYMAPS
--
-- Keymap-related settings are complex enough that they warrant their own file.
-- TODO: migrate all the magic settings from "plugins" into here.
require("config.keymaps")

-- -- -- Other small utilities and helpers.
--
-- Manually-set / hard-coded filetype determination code (e.g.,
require("config.filetypes")
-- Diagnostics-related settings, e.g., enable "hover window" for LSP diagnostics.
require("config.diagnostics")
