-- Remap semicolon to colon
vim.keymap.set("n", ";", ":", { desc = "CMD enter command mode" })
-- Save with Ctrl+s
vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
-- Open terminal
vim.keymap.set({ "n" }, "<C-Space>", "<cmd>ToggleTerm direction=float<cr>", { desc = "Floating terminal" })
