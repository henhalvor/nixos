-- ./lua/plugins/lazydocker.lua

return {
  'nvim-lua/plenary.nvim', -- dependency for terminal management
  config = function()
    local function open_lazydocker()
      -- Get dimensions of current window
      local width = vim.o.columns
      local height = vim.o.lines

      -- Calculate floating window size (80% of screen)
      local win_height = math.floor(height * 0.9)
      local win_width = math.floor(width * 0.9)

      -- Calculate starting position
      local row = math.floor((height - win_height) / 2)
      local col = math.floor((width - win_width) / 2)

      -- Create buffer for terminal
      local buf = vim.api.nvim_create_buf(false, true)

      -- Set up floating window options
      local win_opts = {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'none',
      }

      -- Create the floating window
      local win = vim.api.nvim_open_win(buf, true, win_opts)

      -- Set window options
      vim.wo[win].winblend = 0
      vim.wo[win].winhighlight = 'Normal:Normal'

      -- Open terminal with lazydocker
      vim.fn.termopen('lazydocker', {
        on_exit = function()
          vim.api.nvim_win_close(win, true)
        end,
      })

      -- Enter terminal mode automatically
      vim.cmd 'startinsert'

      -- Add keybinding to close the floating window
      vim.api.nvim_buf_set_keymap(buf, 't', 'q', [[<C-\><C-n>:q<CR>]], { noremap = true, silent = true })
    end

    -- Set up the keymap
    vim.keymap.set('n', '<leader>lzd', open_lazydocker, { noremap = true, silent = true })
  end,
}