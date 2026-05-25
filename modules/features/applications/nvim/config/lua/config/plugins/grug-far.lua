local lazy = require("config.lazy")

vim.keymap.set("n", "<leader>sr", function()
  lazy.packadd("grug-far.nvim")
  require("grug-far").setup({})
  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  require("grug-far").open({
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
    },
  })
end, { desc = "Grug Far Search and Replace" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "grug-far",
  callback = function()
    vim.keymap.set("n", "<Esc>", "<Cmd>stopinsert | bd!<CR>", { buffer = true })
  end,
})
