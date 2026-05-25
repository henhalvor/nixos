local lazy = require("config.lazy")

vim.api.nvim_create_autocmd("LspAttach", {
  once = true,
  callback = function()
    lazy.packadd("garbage-day.nvim")
    require("garbage-day").setup({})
  end,
})
