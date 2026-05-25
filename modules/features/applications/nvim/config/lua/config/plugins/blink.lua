require("luasnip.loaders.from_vscode").lazy_load()

require("blink.cmp").setup({
  enabled = function()
    return vim.bo.buftype ~= "prompt" and vim.b.completion ~= false
  end,
  keymap = {
    preset = "default",
    ["<C-y>"] = { "select_and_accept" },
    ["<C-n>"] = { "select_next", "fallback" },
    ["<C-p>"] = { "select_prev", "fallback" },
    ["<C-d>"] = { "scroll_documentation_down", "fallback" },
    ["<C-u>"] = { "scroll_documentation_up", "fallback" },
  },
  appearance = {
    nerd_font_variant = "mono",
  },
  completion = {
    accept = {
      auto_brackets = {
        kind_resolution = {
          blocked_filetypes = { "typescriptreact", "javascriptreact", "vue", "codecompanion" },
        },
      },
    },
    menu = { border = "rounded" },
    documentation = {
      auto_show = true,
      window = { border = "rounded" },
    },
  },
  sources = {
    default = { "lsp", "buffer", "path", "snippets" },
    per_filetype = {
      codecompanion = { "codecompanion", "buffer" },
    },
  },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})
