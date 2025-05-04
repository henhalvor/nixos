return {
  'zeioth/garbage-day.nvim',
  dependencies = 'neovim/nvim-lspconfig',
  event = 'VeryLazy',
  opts = {
    -- your options here
    grace_period = 60 * 20, -- 20 minutes
  },
}
