require("flash").setup()

vim.keymap.set({ "n", "x", "o" }, "<CR>", function()
  require("flash").jump()
end, { desc = "Flash" })

vim.keymap.set({ "n", "x", "o" }, "<leader><CR>", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })
