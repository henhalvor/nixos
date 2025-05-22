return {
  'saghen/blink.cmp',
  dependencies = {
    'Kaiser-Yang/blink-cmp-avante',
    {
      'L3MON4D3/LuaSnip',
      build = (function()
        -- Build Step is needed for regex support in snippets.
        -- This step is not supported in many windows environments.
        -- Remove the below condition to re-enable on windows.
        if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
          return
        end
        return 'make install_jsregexp'
      end)(),
      dependencies = {
        -- `friendly-snippets` contains a variety of premade snippets.
        --    See the README about individual language/framework/plugin snippets:
        --    https://github.com/rafamadriz/friendly-snippets
        {
          'rafamadriz/friendly-snippets',
          config = function()
            require('luasnip.loaders.from_vscode').lazy_load()
          end,
        },
      },
    },
  },
  version = '*',

  opts = {
    keymap = { preset = 'default' },

    appearance = {
      nerd_font_variant = 'mono',
    },

    -- Add rounded border to the completion menu
    completion = {
      -- Make completion trigger faster
      trigger = {
        -- Enable showing on keywords for immediate triggering
        show_on_keyword = true,
        -- Prefetch completions when entering insert mode
        prefetch_on_insert = true,
      },

      -- Configure menu appearance
      menu = {
        -- Set rounded border
        border = 'rounded',
        -- Ensure menu appears immediately
        auto_show = true,
      },

      -- Configure documentation window
      documentation = {
        auto_show = true,
        window = {
          border = 'rounded',
        },
      },
    },

    sources = {
      -- Lower the minimum keyword length to trigger sources
      min_keyword_length = 1,
      default = { 'avante', 'lsp', 'path', 'snippets', 'buffer', 'codecompanion' },
      providers = {
        avante = {
          module = 'blink-cmp-avante',
          name = 'Avante',
          opts = {
            -- options for blink-cmp-avante
          },
        },
      },
    },

    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
  opts_extend = { 'sources.default' },
  -- config = function()
  --   -- Setup luasnip
  --   local luasnip = require 'luasnip'
  --   luasnip.config.setup {}
  -- end,
}
