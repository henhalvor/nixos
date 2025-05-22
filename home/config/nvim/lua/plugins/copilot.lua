return {
  'github/copilot.vim',
  cmd = 'Copilot',
  event = 'InsertEnter',
  config = function()
    -- Set up Copilot
    -- require('copilot').setup {}

    -- Disable default tab mapping
    vim.g.copilot_no_tab_map = true
    vim.g.copilot_assume_mapped = true

    -- Custom keymaps
    vim.keymap.set('i', '<A-y>', 'copilot#Accept("<CR>")', {
      expr = true,
      replace_keycodes = false,
    })
    vim.keymap.set('i', '<A-n>', '<Plug>(copilot-next)')
    vim.keymap.set('i', '<A-p>', '<Plug>(copilot-previous)')
    vim.keymap.set('i', '<A-c>', '<Plug>(copilot-suggest)')
  end,
}
