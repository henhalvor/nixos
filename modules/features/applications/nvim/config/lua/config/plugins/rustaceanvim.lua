vim.g.rustaceanvim = {
  server = {
    capabilities = require("blink.cmp").get_lsp_capabilities(),
  },
}
