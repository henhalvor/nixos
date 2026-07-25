require("nvim-treesitter").setup({})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("treesitter-highlight", { clear = true }),
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
})

require("treesitter-context").setup({
  enable = false,
  max_lines = 3,
  multiline_threshold = 1,
  separator = nil,
  line_numbers = true,
})
