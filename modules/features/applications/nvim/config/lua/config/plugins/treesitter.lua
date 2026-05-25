require("nvim-treesitter.configs").setup({
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = { "ruby" },
  },
  indent = { enable = true, disable = { "ruby" } },
})

require("treesitter-context").setup({
  enable = false,
  max_lines = 3,
  multiline_threshold = 1,
  separator = nil,
  line_numbers = true,
})
