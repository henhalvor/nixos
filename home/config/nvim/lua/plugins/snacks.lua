return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
    scroll = { enabled = false },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    styles = {},
    terminal = {
      enabled = true,
    },
  },
  keys = {
    {
      '<leader>z',
      function()
        Snacks.zen()
      end,
      desc = 'Toggle Zen Mode',
    },
    {
      '<leader>Z',
      function()
        Snacks.zen.zoom()
      end,
      desc = 'Toggle Zoom',
    },
    {
      '<leader>.',
      function()
        Snacks.scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>S',
      function()
        Snacks.scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },
    {
      '<leader>n',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>bd',
      function()
        Snacks.bufdelete()
      end,
      desc = 'Delete Buffer',
    },
    {
      '<leader>cR',
      function()
        Snacks.rename.rename_file()
      end,
      desc = 'Rename File',
    },
    {
      '<leader>gB',
      function()
        Snacks.gitbrowse()
      end,
      desc = 'Git Browse',
      mode = { 'n', 'v' },
    },
    {
      '<leader>gg',
      function()
        Snacks.lazygit()
      end,
      desc = 'Lazygit',
    },
    {
      '<leader>gl',
      function()
        Snacks.lazygit.log()
      end,
      desc = 'Lazygit Log (cwd)',
    },
    {
      '<leader>un',
      function()
        Snacks.notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },

    -- Floating Terminal
    {
      '<leader>tt',
      function()
        -- Calculate window dimensions and position
        local width = vim.o.columns
        local height = vim.o.lines
        local win_height = math.floor(height * 0.9)
        local win_width = math.floor(width * 0.9)
        local row = math.floor((height - win_height) / 2)
        local col = math.floor((width - win_width) / 2)

        Snacks.terminal.toggle(nil, {
          win = {
            border = 'rounded',
            relative = 'editor',
            width = win_width,
            height = win_height,
            row = row,
            col = col,
            position = 'float',
          },
          env = { TERM_ID = '9999' },
        })
      end,
      desc = 'Toggle Dev Server Terminal',
    },

    -- Terminal 1
    {
      '<leader>ai',
      function()
        -- Calculate window dimensions and position
        local width = vim.o.columns
        local height = vim.o.lines
        local win_height = math.floor(height * 0.9)
        local win_width = math.floor(width * 0.9)
        local row = math.floor((height - win_height) / 2)
        local col = math.floor((width - win_width) / 2)

        -- Snacks.terminal.toggle('aider --no-auto-commits --read CONVENTIONS.md --dark-mode --model gemini-2.0-flash-thinking-exp', {
        Snacks.terminal.toggle('aider --no-auto-commits --read CONVENTIONS.md --dark-mode --architect --yes-always', {
          win = {
            border = 'rounded',
            relative = 'editor',
            width = win_width,
            height = win_height,
            row = row,
            col = col,
            position = 'float',
          },
          env = { TERM_ID = '1' },
        })
      end,
      desc = 'Toggle Aider Ai',
    },
    -- Terminal 2
    {
      '<leader>t2',
      function()
        Snacks.terminal.toggle(nil, {
          env = { TERM_ID = '2' },
          win = {
            border = 'rounded',
            relative = 'editor',
            height = 0.15,
          },
        })
      end,
      desc = 'Toggle Terminal 2',
    },
    -- Terminal 3
    {
      '<leader>t3',
      function()
        Snacks.terminal.toggle(nil, {
          env = { TERM_ID = '3' },
          win = {
            border = 'rounded',
            relative = 'editor',
            height = 0.15,
          },
        })
      end,
      desc = 'Toggle Terminal 3',
    },
    -- {
    --   '<leader>tt',
    --   function()
    --     Snacks.terminal()
    --   end,
    --   desc = 'Toggle Terminal',
    -- },
    {
      ']]',
      function()
        Snacks.words.jump(vim.v.count1)
      end,
      desc = 'Next Reference',
      mode = { 'n', 't' },
    },
    {
      '[[',
      function()
        Snacks.words.jump(-vim.v.count1)
      end,
      desc = 'Prev Reference',
      mode = { 'n', 't' },
    },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command
        -- Create some toggle mappings
        Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
        Snacks.toggle.option('relativenumber', { name = 'Relative Number' }):map '<leader>uL'
        Snacks.toggle.diagnostics():map '<leader>ud'
        Snacks.toggle.line_number():map '<leader>ul'
        Snacks.toggle.option('conceallevel', { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map '<leader>uc'
        Snacks.toggle.treesitter():map '<leader>uT'
        Snacks.toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }):map '<leader>ub'
        Snacks.toggle.inlay_hints():map '<leader>uh'
        Snacks.toggle.indent():map '<leader>ug'
        Snacks.toggle.dim():map '<leader>uD'
      end,
    })
  end,
}
