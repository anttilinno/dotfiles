require "nvchad.options"

-- undo
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.updatetime = 200 -- Save swap file and trigger CursorHold

-- skip startup screen
vim.opt.shortmess:append "I"

-- line numbers
vim.opt.number = true
vim.opt.relativenumber = false

-- set tab and indents defaults (can be overridden by per-language configs)
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- incremental search
vim.opt.incsearch = true
vim.opt.hlsearch = true

-- ignore case when searching
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- 24-bit color
vim.opt.termguicolors = true

-- sync with system clipboard (also see autocmds for text yank config)
vim.opt.clipboard = "unnamedplus"
