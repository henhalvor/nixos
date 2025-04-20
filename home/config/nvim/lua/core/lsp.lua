return {
  -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    { 'j-hui/fidget.nvim', opts = {} },

    -- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
    { 'folke/neodev.nvim', opts = {} },

    -- Autocompletion
    'saghen/blink.cmp',
  },
  config = function()
    -- Setup neodev before LSP servers
    require('neodev').setup()

    --  This function gets run when an LSP attaches to a particular buffer.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        map('<leader>th', function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = 0 }, { bufnr = 0 })
        end, '[T]oggle Inlay [H]ints')

        -- This function will call the hover function without showing a notification
        local function hover_without_notification()
          -- Save the current notify function
          local orig_notify = vim.notify

          -- Temporarily replace the notify function with one that ignores "No information available"
          vim.notify = function(msg, level, opts)
            if msg ~= 'No information available' then
              orig_notify(msg, level, opts)
            end
          end

          -- Call the hover function
          vim.lsp.buf.hover()

          -- Restore the original notify function after a short delay
          vim.defer_fn(function()
            vim.notify = orig_notify
          end, 1000)
        end

        map('K', hover_without_notification, 'Hover Documentation')
      end,
    })

    -- Define basic capabilities
    local base_capabilities = vim.lsp.protocol.make_client_capabilities()

    -- Add folding range capability
    local folding_capabilities = {
      textDocument = {
        foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true,
        },
      },
    }

    -- Configure borders for floats
    local border = {
      { '╭', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╮', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '╯', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╰', 'FloatBorder' },
      { '│', 'FloatBorder' },
    }

    -- Create handlers with borders
    local handlers = {
      ['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
      ['textDocument/signatureHelp'] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = border }),
    }

    -- Set up Mason
    require('mason').setup()

    -- Tools to install
    local ensure_installed_tools = {
      'stylua',
      'prettier',
      'eslint',
      'eslint_d',
    }
    require('mason-tool-installer').setup { ensure_installed = ensure_installed_tools }

    -- Define servers
    local servers = {
      -- vtsls = {}, -- js / ts alternative
      ts_ls = {},
      html = {},
      cssls = {},
      tailwindcss = {},
      svelte = {
        settings = {
          typescript = {
            inlayHints = {
              parameterNames = { enabled = 'all' },
              parameterTypes = { enabled = true },
              variableTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
          },
        },
      },
      lua_ls = {
        settings = {
          Lua = {
            completion = {
              callSnippet = 'Replace',
            },
            diagnostics = {
              globals = { 'vim' },
            },
            hint = {
              enable = true,
            },
          },
        },
      },
    }

    -- Set up mason-lspconfig
    require('mason-lspconfig').setup {
      ensure_installed = {
        'vtsls',
        'html',
        'cssls',
        'tailwindcss',
        'svelte',
        'lua_ls',
      },
      automatic_installation = {
        exclude = { 'rust_analyzer' },
      },
      handlers = {
        function(server_name)
          -- Skip rust_analyzer, will handle separately
          if server_name == 'rust_analyzer' then
            return
          end

          if server_name == 'ts_ls' then
            return
          end

          -- if server_name == 'vtsls' then
          --   return
          -- end

          -- Get server config or empty table if not defined
          local server_config = servers[server_name] or {}

          -- Add handlers with borders
          server_config.handlers = handlers

          -- Get the server's capabilities or use empty table if not defined
          local server_capabilities = server_config.capabilities or {}

          -- First combine the base capabilities with the server capabilities
          local combined_capabilities = vim.tbl_deep_extend('force', {}, base_capabilities, server_capabilities)

          -- Then get blink.cmp capabilities and merge them (not using false flag which seems problematic)
          server_config.capabilities = require('blink.cmp').get_lsp_capabilities(combined_capabilities)

          -- Finally add folding capabilities
          server_config.capabilities = vim.tbl_deep_extend('force', {}, server_config.capabilities, folding_capabilities)

          -- Set up the server
          require('lspconfig')[server_name].setup(server_config)
        end,
      },
    }

    -- -- Set up rust_analyzer separately
    -- require('lspconfig').rust_analyzer.setup {
    --   -- Start with base capabilities
    --   -- capabilities = vim.tbl_deep_extend('force', {}, base_capabilities, folding_capabilities),
    --   -- Then add blink.cmp capabilities
    --   capabilities = require('blink.cmp').get_lsp_capabilities(vim.tbl_deep_extend('force', {}, base_capabilities, folding_capabilities)),
    --   handlers = handlers,
    --   settings = {
    --     ['rust-analyzer'] = {
    --       diagnostics = {
    --         enable = true,
    --         enableExperimental = true,
    --       },
    --       check = {
    --         command = 'clippy',
    --         extraArgs = {},
    --         features = 'all',
    --         invocationStrategy = 'immediate',
    --       },
    --       files = {
    --         watcher = 'client',
    --       },
    --       cargo = {
    --         allFeatures = true,
    --         buildScripts = {
    --           enable = true,
    --         },
    --       },
    --       procMacro = {
    --         enable = true,
    --       },
    --     },
    --   },
    -- }

    -- Set up diagnostics
    local function setup_lsp_diags()
      vim.diagnostic.config {
        virtual_text = {
          source = 'if_many',
          spacing = 4,
          prefix = '●',
        },
        float = {
          source = 'always',
          border = 'rounded',
          header = '',
          prefix = '',
        },
        signs = {
          active = true,
          priority = 20,
          text = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.HINT] = '󰌵 ',
            [vim.diagnostic.severity.INFO] = ' ',
          },
        },
        underline = {
          severity = {
            min = vim.diagnostic.severity.ERROR,
          },
        },
        severity_sort = true,
        update_in_insert = true,
      }
    end

    -- Add highlight configurations
    vim.cmd [[
  highlight DiagnosticUnderlineError gui=undercurl guisp=#db4b4b
  highlight DiagnosticUnderlineWarn gui=undercurl guisp=#e0af68
  highlight DiagnosticUnderlineInfo gui=undercurl guisp=#0db9d7
  highlight DiagnosticUnderlineHint gui=undercurl guisp=#1abc9c
  
  highlight DiagnosticError guifg=#db4b4b
  highlight DiagnosticWarn guifg=#e0af68
  highlight DiagnosticInfo guifg=#0db9d7
  highlight DiagnosticHint guifg=#1abc9c

  highlight DiagnosticSignError guifg=#db4b4b guibg=NONE
  highlight DiagnosticSignWarn guifg=#e0af68 guibg=NONE
  highlight DiagnosticSignInfo guifg=#0db9d7 guibg=NONE
  highlight DiagnosticSignHint guifg=#1abc9c guibg=NONE
    ]]

    -- Configure hover display
    vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, {
      border = 'rounded',
      max_width = 80,
      max_height = 20,
    })

    setup_lsp_diags()

    -- Function to check if a floating dialog exists and if not
    -- then check for diagnostics under the cursor
    function OpenDiagnosticIfNoFloat()
      for _, winid in pairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(winid).zindex then
          return
        end
      end
      -- THIS IS FOR BUILTIN LSP
      vim.diagnostic.open_float {
        border = 'rounded',
        scope = 'cursor',
        focusable = false,
        close_events = {
          'CursorMoved',
          'CursorMovedI',
          'BufHidden',
          'InsertCharPre',
          'WinLeave',
        },
      }
    end

    -- Show diagnostics under the cursor when holding position
    vim.api.nvim_create_augroup('lsp_diagnostics_hold', { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorHold' }, {
      pattern = '*',
      command = 'lua OpenDiagnosticIfNoFloat()',
      group = 'lsp_diagnostics_hold',
    })
  end,
}
