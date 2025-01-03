return {
  'monkoose/neocodeium',
  --[[   event = 'VeryLazy', ]]
  config = function()
    local neocodeium = require 'neocodeium'
    neocodeium.setup {
      manual = false,
    }
    vim.keymap.set('i', '<A-y>', function()
      require('neocodeium').accept()
    end)
    vim.keymap.set('i', '<A-w>', function()
      require('neocodeium').accept_word()
    end)
    vim.keymap.set('i', '<A-a>', function()
      require('neocodeium').accept_line()
    end)
    vim.keymap.set('i', '<A-n>', function()
      require('neocodeium').cycle_or_complete()
    end)
    vim.keymap.set('i', '<A-p>', function()
      require('neocodeium').cycle_or_complete(-1)
    end)
    vim.keymap.set('i', '<A-c>', function()
      require('neocodeium').clear()
    end)
  end,
}