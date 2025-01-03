return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  opts = {
    flavour = 'macchiato',
    background = {
      light = 'macchiato',
      dark = 'macchiato',
    },
    transparent_background = true,
    integrations = {
      cmp = true,
      treesitter = true,
      telescope = true,
      mason = true,
      noice = true,
      notify = true,
      which_key = true,
      fidget = true,
    },
  },
  config = function(_, opts)
    require('catppuccin').setup(opts)
    vim.cmd.colorscheme 'catppuccin'
  end,
}
