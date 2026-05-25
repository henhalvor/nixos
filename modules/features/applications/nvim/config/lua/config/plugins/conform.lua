require("conform").setup({
  notify_on_error = false,
  format_on_save = function(bufnr)
    local disable_filetypes = { c = true, cpp = true }
    return {
      timeout_ms = 2000,
      lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
    }
  end,
  formatters = {
    prettier = {
      command = "prettierd",
      timeout_ms = 3000,
      ignore_errors = true,
    },
    eslint_d = {
      command = "eslint_d",
      args = { "--fix", "--stdin", "--stdin-filename", "$FILENAME" },
      stdin = true,
    },
  },
  formatters_by_ft = {
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    svelte = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    graphql = { "prettier" },
    lua = { "stylua" },
    python = { "black" },
    rust = { "rustfmt" },
    nix = { "nixfmt" },
  },
})
