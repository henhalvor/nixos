return {
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'github/copilot.vim',
    },
    enabled = true,
    opts = {
      adapters = {
        copilot = function()
          return require('codecompanion.adapters').extend('copilot', {
            schema = {
              model = {
                default = 'gemini-2.5-pro', -- Model list: https://codecompanion.olimorris.dev/usage/chat-buffer/agents#compatibility
              },
            },
          })
        end,
      },

      display = {
        chat = {
          intro_message = 'Welcome to CodeCompanion ✨! Press ? for options',
          show_header_separator = false, -- Show header separators in the chat buffer? Set this to false if you're using an external markdown formatting plugin
          auto_scroll = false,
        },
      },
      strategies = {
        chat = {
          adapter = 'copilot',
          roles = {
            llm = 'CodeCompanion',
            user = 'Me',
          },
          keymaps = {
            close = {
              modes = {
                n = 'q',
              },
              index = 3,
              callback = 'keymaps.close',
              description = 'Close Chat',
            },
            stop = {
              modes = {
                n = '<C-c',
              },
              index = 4,
              callback = 'keymaps.stop',
              description = 'Stop Request',
            },
          },
        },
      },
      inline = {
        adapter = 'copilot',
      },
      -- 🔥 Crucial: Register MCP Extension in `opts`
      extensions = {
        mcphub = {
          callback = 'mcphub.extensions.codecompanion',
          opts = {
            show_result_in_chat = true,
            make_vars = true,
            make_slash_commands = true, -- Enables `/` slash commands
          },
        },
      },
    },

    keys = {
      {
        '<leader>ac',
        '<cmd>CodeCompanionActions<cr>',
        mode = { 'n', 'v' },
        noremap = true,
        silent = true,
        desc = 'CodeCompanion actions',
      },
      {
        '<leader>aa',
        '<cmd>CodeCompanionChat Toggle<cr>',
        mode = { 'n', 'v' },
        noremap = true,
        silent = true,
        desc = 'CodeCompanion chat',
      },
      {
        '<leader>ad',
        '<cmd>CodeCompanionChat Add<cr>',
        mode = 'v',
        noremap = true,
        silent = true,
        desc = 'CodeCompanion add to chat',
      },
    },
    config = function()
      require('codecompanion').setup {
        extensions = {
          mcphub = {
            callback = 'mcphub.extensions.codecompanion',
            opts = {
              show_result_in_chat = true, -- Show mcp tool results in chat
              make_vars = true, -- Convert resources to #variables
              make_slash_commands = true, -- Add prompts as /slash commands
            },
          },
        },
      }
    end,
  },

  --
  -- Markdown rendering
  --
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown', 'codecompanion' },
  },

  --
  -- AutoComplete
  --
  {
    'saghen/blink.cmp',
    dependencies = { 'olimorris/codecompanion.nvim', 'saghen/blink.compat' },
    event = 'InsertEnter',
    opts = {
      enabled = function()
        return vim.bo.buftype ~= 'prompt' and vim.b.completion ~= false
      end,
      completion = {
        accept = {
          auto_brackets = {
            kind_resolution = {
              blocked_filetypes = { 'typescriptreact', 'javascriptreact', 'vue', 'codecompanion' },
            },
          },
        },
      },
      sources = {
        per_filetype = {
          codecompanion = { 'codecompanion' },
        },
      },
    },
  },

  --
  -- MCP Hub
  --
  {
    'ravitemer/mcphub.nvim',
    build = 'npm install -g mcp-hub@latest',
    config = function()
      require('mcphub').setup()
    end,
  },
}
