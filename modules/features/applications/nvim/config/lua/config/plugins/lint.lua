local lint = require("lint")

lint.linters_by_ft = {
  typescript = { "eslint" },
  typescriptreact = { "eslint" },
  javascript = { "eslint" },
  javascriptreact = { "eslint" },
}

lint.linters.eslint = vim.tbl_deep_extend("force", lint.linters.eslint or {}, {
  condition = function(ctx)
    return vim.fs.find({
      "eslint.config.js",
      "eslint.config.mjs",
      "eslint.config.cjs",
      ".eslintrc.js",
      ".eslintrc.cjs",
      ".eslintrc.yaml",
      ".eslintrc.yml",
      ".eslintrc.json",
      ".eslintrc",
    }, { path = ctx.filename, upward = true })[1] ~= nil
  end,
})

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    require("lint").try_lint()
  end,
})
