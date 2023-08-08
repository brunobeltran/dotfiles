-- Space is our leader 👑.
vim.g.mapleader = " "

-- Use the "go up one directory" mapping from netrw to also open netrw.
vim.keymap.set("n", "-", function() vim.cmd("Ex") end)
-- Paste without losing your copy buffer!
vim.keymap.set("x", "<leader>p", "\"_dP")


-- Move visually-selected lines up and down (fixing indenting dynamically).
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Preserve cursor location when using J.
vim.keymap.set("n", "J", "mzJ`z")

-- Preserve cursor in center when searching or navigating.
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Keep me from mistakenly throwing away edits done when changing vertical
-- blocks.
vim.keymap.set("i", "<C-c>", "<Esc>")

-- -- Typing the colon is such a slog.
vim.keymap.set("n", "<leader>cn", ":cnext<CR>")
vim.keymap.set("n", "<leader>cp", ":cprev<CR>")

-- Change into the directory of the current buffer.
vim.keymap.set("n", "<leader>cd", ":cd %:h<CR>")

vim.keymap.set("n", "<leader>bt", ":BazelSelectTarget<CR>")

-- Convenience for hard-to-do things.
vim.keymap.set("n", "<leader>ltl", ":set paste<CR>A  # NOQA: E501<ESC>:set nopaste<CR>")
