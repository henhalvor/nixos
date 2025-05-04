return {
  {
    'echasnovski/mini.nvim',
    version = false, -- Use '*' for stable version
    dependencies = {
      'JoosepAlviste/nvim-ts-context-commentstring',
    },
    config = function()
      -- Files
      require('mini.files').setup {
        vim.keymap.set('n', '-', '<CMD>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', { desc = 'Open parent directory' }),

        vim.keymap.set('n', '<Esc>', '<CMD>lua MiniFiles.close()<CR>', { desc = 'Close MiniFiles' }),

        content = {
          -- Predicate for which file system entries to show
          filter = nil,
          -- What prefix to show to the left of file system entry
          prefix = nil,
          -- In which order to show file system entries
          sort = nil,
        },
        -- Module mappings created only inside explorer
        mappings = {
          close = 'q',
          go_in = 'l',
          go_in_plus = 'L',
          go_out = 'h',
          go_out_plus = 'H',
          mark_goto = "'",
          mark_set = 'm',
          reset = '<BS>',
          reveal_cwd = '@',
          show_help = 'g?',
          synchronize = '=',
          trim_left = '<',
          trim_right = '>',
        },
        -- General options
        options = {
          -- Whether to delete permanently or move into module-specific trash
          permanent_delete = true,
          -- Whether to use for editing directories
          use_as_default_explorer = true,
        },
        -- Customization of explorer windows
        windows = {
          -- Maximum number of windows to show side by side
          max_number = 4,
          -- Whether to show preview of file/directory under cursor
          preview = false,
          -- Width of focused window
          width_focus = 50,
          -- Width of non-focused window
          width_nofocus = 15,
          -- Width of preview window
          width_preview = 25,
        },
      }

      require('mini.surround').setup {
        -- Add custom surroundings to be used on top of builtin ones. For more
        -- information with examples, see `:h MiniSurround.config`.
        custom_surroundings = nil,

        -- Module mappings. Use `''` (empty string) to disable one.
        -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
        -- - sd'   - [S]urround [D]elete [']quotes
        -- - sr)'  - [S]urround [R]eplace [)] [']

        mappings = {
          add = 'sa', -- Add surrounding in Normal and Visual modes
          delete = 'sd', -- Delete surrounding
          find = 'sf', -- Find surrounding (to the right)
          find_left = 'sF', -- Find surrounding (to the left)
          highlight = 'sh', -- Highlight surrounding
          replace = 'sr', -- Replace surrounding
          update_n_lines = 'sn', -- Update `n_lines`

          suffix_last = 'l', -- Suffix to search with "prev" method
          suffix_next = 'n', -- Suffix to search with "next" method
        },
      }

      -- Comment setup "ts-context-commentstring" is needed for jsx comments
      vim.g.skip_ts_context_commentstring_module = true
      require('ts_context_commentstring').setup {
        enable_autocmd = false,
      }
      require('mini.comment').setup {
        options = {
          custom_commentstring = function()
            return require('ts_context_commentstring.internal').calculate_commentstring() or vim.bo.commentstring
          end,
          ignore_blank_line = false,
          start_of_line = false,
          pad_comment_parts = true,
        },
        mappings = {
          comment = 'gb',
          comment_line = 'gbb',
          comment_visual = 'gb',
          textobject = 'gb',
        },
      }

      require('mini.map').setup {
        symbols = {
          encode = require('mini.map').gen_encode_symbols.dot '4x2',
        },
        integrations = {
          require('mini.map').gen_integration.builtin_search(),
          require('mini.map').gen_integration.diagnostic(),
          require('mini.map').gen_integration.gitsigns(),
        },
        window = {
          side = 'right', -- or 'left'
          width = 20,
          show_integration_count = false,
        },

        vim.keymap.set('n', '<leader>m', '<CMD>lua MiniMap.toggle()<CR>', { desc = 'Toggle minimap' }),
      }

      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Simple and easy statusline.
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }
      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      require('mini.pairs').setup()
      require('mini.diff').setup {

        vim.keymap.set('n', '<leader>dt', '<CMD>lua MiniDiff.toggle_overlay()<CR>', { desc = 'MINI [D]iff [T]oggle' }),
        view = {
          -- Visualization style. Possible values are 'sign' and 'number'.
          -- Default: 'number' if line numbers are enabled, 'sign' otherwise.
          style = 'sign',

          -- Signs used for hunks with 'sign' view
          signs = { add = '▒', change = '▒', delete = '▒' },

          -- Priority of used visualization extmarks
          priority = 199,
        },
      }
      -- -- Add any other mini modules you want to use
    end,
  },
}
