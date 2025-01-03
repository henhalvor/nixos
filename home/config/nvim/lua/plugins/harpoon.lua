return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'

    -- REQUIRED
    harpoon:setup()
    -- OPTIONAL: Configure Harpoon options here
    -- harpoon:setup({
    --   settings = {
    --     save_on_toggle = true,
    --     sync_on_ui_close = true,
    --   }
    -- })

    -- Set up keymaps
    vim.keymap.set('n', '<leader>a', function()
      harpoon:list():add()
    end, { desc = 'Harpoon [A]ppend' })
    vim.keymap.set('n', '<leader>e', function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = 'Harpoon [E]xplore' })

    -- Set up keymaps for selecting items
    for i = 1, 8 do
      vim.keymap.set('n', string.format('<leader>%s', i), function()
        harpoon:list():select(i)
      end)
    end
  end,
}
