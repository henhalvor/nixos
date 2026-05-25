local lazy = require("config.lazy")

vim.keymap.set("n", "-", function()
  lazy.packadd("yazi.nvim")
  require("yazi").yazi()
end, { desc = "Open yazi at current file" })

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    lazy.packadd("yazi.nvim")
    require("yazi").setup({ open_for_directories = true })
  end,
})
