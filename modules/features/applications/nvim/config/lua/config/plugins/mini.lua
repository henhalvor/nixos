require("mini.surround").setup()

vim.g.skip_ts_context_commentstring_module = true
require("mini.comment").setup({
  options = {
    custom_commentstring = function()
      local ok, ts_context = pcall(require, "ts_context_commentstring.internal")
      if ok then
        return ts_context.calculate_commentstring() or vim.bo.commentstring
      end
      return vim.bo.commentstring
    end,
    ignore_blank_line = false,
    start_of_line = false,
    pad_comment_parts = true,
  },
  mappings = {
    comment = "gb",
    comment_line = "gbb",
    comment_visual = "gb",
    textobject = "gb",
  },
})

require("mini.ai").setup({ n_lines = 500 })
require("mini.pairs").setup()
require("mini.diff").setup({
  view = {
    style = "sign",
    signs = { add = "▒", change = "▒", delete = "▒" },
    priority = 199,
  },
})

local statusline = require("mini.statusline")
statusline.setup({ use_icons = vim.g.have_nerd_font })
statusline.section_location = function()
  return "%2l:%-2v"
end
statusline.section_filename = function()
  return "%f"
end
statusline.section_fileinfo = function()
  return ""
end
statusline.section_searchcount = function()
  return ""
end
statusline.section_git = function()
  return ""
end
statusline.section_diagnostics = function()
  return ""
end

local function statusline_highlights()
  vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#ebdbb2", bold = true })
  vim.api.nvim_set_hl(0, "MiniStatuslineDevinfo", { fg = "#ebdbb2" })
  vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE" })
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = statusline_highlights })
vim.defer_fn(statusline_highlights, 100)
