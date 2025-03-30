return {
  'saghen/blink.cmp',
  dependencies = { 'rafamadriz/friendly-snippets', 'Kaiser-Yang/blink-cmp-avante' },
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
      default = { 'avante', 'lsp', 'path', 'snippets', 'buffer' },
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
}
