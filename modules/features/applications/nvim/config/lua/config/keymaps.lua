local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

map("n", "<leader>di", vim.diagnostic.open_float, { desc = "Show diagnostic Error messages" })
map("n", "<leader>q", _G.toggle_quickfix, { desc = "Toggle quickfix list" })
map("n", "]q", ":cnext<CR>", { desc = "Next quickfix item" })
map("n", "[q", ":cprev<CR>", { desc = "Prev quickfix item" })
map("n", "<leader>qc", function()
  vim.fn.setqflist({}, "f")
end, { desc = "[Q]uickfix [C]lear" })

map("n", "<A-k>", ":resize +5<CR>", { desc = "Increase window height" })
map("n", "<A-j>", ":resize -5<CR>", { desc = "Decrease window height" })
map("n", "<A-h>", ":vertical resize -5<CR>", { desc = "Decrease window width" })
map("n", "<A-l>", ":vertical resize +5<CR>", { desc = "Increase window width" })

map({ "n", "v", "x", "o" }, "<leader>f", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { silent = true, desc = "Format buffer" })

map("n", "<leader>dt", "<CMD>lua MiniDiff.toggle_overlay()<CR>", { silent = true, desc = "MINI [D]iff [T]oggle" })
map("n", "<leader>m", "<CMD>lua MiniMap.toggle()<CR>", { silent = true, desc = "Toggle minimap" })
