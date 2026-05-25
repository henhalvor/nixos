require("catppuccin").setup({
  flavour = "macchiato",
  background = { light = "macchiato", dark = "macchiato" },
  transparent_background = true,
  integrations = {
    cmp = true,
    treesitter = true,
    noice = false,
    notify = true,
    which_key = false,
    fidget = true,
  },
})

require("rose-pine").setup({
  styles = { transparency = true },
  disable_background = true,
})

require("gruvbox").setup({
  transparent_mode = true,
})

vim.g.gruvbox_baby_transparent_mode = true
vim.g.gruvbox_material_transparent_background = 2
vim.g.nord_disable_background = true
vim.g.everforest_background = "hard"
vim.g.everforest_transparent_background = 2
vim.g.sonokai_style = "atlantis"
vim.g.sonokai_transparent_background = 2
vim.opt.background = "dark"

require("tokyonight").setup({
  style = "night",
  transparent = true,
  styles = { sidebars = "transparent", floats = "transparent" },
})
require("kanagawa").setup({ transparent = true, theme = "wave" })
require("nightfox").setup({ options = { transparent = true } })
require("onedark").setup({ style = "dark", transparent = true })
require("dracula").setup({ transparent_bg = true })
require("cyberdream").setup({ transparent = true, italic_comments = true })
require("vscode").setup({ transparent = true })
require("github-theme").setup({ options = { transparent = true } })

local colorschemes = {
  "catppuccin",
  "gruvbox",
  "gruvbox-baby",
  "gruvbox-material",
  "rose-pine",
  "tokyonight",
  "kanagawa",
  "nord",
  "nightfox",
  "dawnfox",
  "duskfox",
  "nordfox",
  "terafox",
  "carbonfox",
  "onedark",
  "dracula",
  "everforest",
  "sonokai",
  "oxocarbon",
  "melange",
  "cyberdream",
  "vscode",
  "github_dark",
  "github_dark_dimmed",
  "github_light",
}

local function save_colorscheme(name)
  local path = vim.fn.stdpath("data") .. "/colorscheme.tmp.lua"
  local file = io.open(path, "w")
  if file then
    file:write("vim.cmd([[colorscheme " .. name .. "]])\n")
    file:close()
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function(args)
    save_colorscheme(args.match)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      local saved = vim.fn.stdpath("data") .. "/colorscheme.tmp.lua"
      if vim.fn.filereadable(saved) == 1 then
        dofile(saved)
      else
        pcall(vim.cmd.colorscheme, "gruvbox")
      end
    end, 100)
  end,
})

vim.keymap.set("n", "<leader>cs", function()
  Snacks.picker.pick({
    prompt = "Select Colorscheme",
    format = "text",
    items = vim.tbl_map(function(name)
      return { text = name }
    end, colorschemes),
    preview = function(_, item)
      if item then
        pcall(vim.cmd.colorscheme, item.text)
      end
    end,
    actions = {
      confirm = function(picker, item)
        if item then
          vim.cmd.colorscheme(item.text)
          picker:close()
        end
      end,
    },
  })
end, { desc = "[S]earch [T]heme" })
