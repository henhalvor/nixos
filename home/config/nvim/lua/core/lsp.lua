return { -- LSP Configuration & Plugins
  'neovim/nvim-lspconfig',
  dependencies = {
    -- Automatically install LSPs and related tools to stdpath for Neovim
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- Useful status updates for LSP.
    -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
    { 'j-hui/fidget.nvim', opts = {} },

    -- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    { 'folke/neodev.nvim', opts = {} },
  },
  config = function()
    --  This function gets run when an LSP attaches to a particular buffer.
    --    That is to say, every time a new file is opened that is associated with
    --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
    --    function will be executed to configure the current buffer
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        -- NOTE: Remember that Lua is a real programming language, and as such it is possible
        -- to define small helper and utility functions so you don't have to repeat yourself.
        --
        -- In this case, we create a function that lets us more easily define mappings specific
        -- for LSP related items. It sets the mode, buffer and description for us each time.
        local map = function(keys, func, desc)
          vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Jump to the definition of the word under your cursor.
        --  This is where a variable was first declared, or where a function is defined, etc.
        --  To jump back, press <C-t>.
        map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

        -- Find references for the word under your cursor.
        map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

        -- Jump to the        --  Useful when your language has ways of declaring types without an actual implementation.
        map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

        -- Jump to the type of the        --  Useful when you're not sure what type a variable is and you want to see
        --  the definition of its *type*, not where it was *defined*.
        map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')

        -- Fuzzy find all the symbols in your current document.
        --  Symbols are things like variables, functions, types, etc.
        map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')

        -- Fuzzy find all the symbols in your current workspace.
        --  Similar to document symbols, except searches over your entire project.
        map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols') --  Most Language Servers support renaming across files, etc.
        map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

        -- Execute a code action, usually your cursor needs to be on top of an error
        -- or a suggestion from your LSP for this to activate.
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

        -- Opens a popup that displays documentation about the word under your cursor
        --  See `:help K` for why this keymap.
        map('K', vim.lsp.buf.hover, 'Hover Documentation')

        -- WARN: This is not Goto Definition, this is Goto Declaration.
        --  For example, in C this would take you to the header.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local function show_type_definition()
          local params = vim.lsp.util.make_position_params()
          vim.lsp.buf_request(0, 'textDocument/typeDefinition', params, function(err, result, ctx, config)
            if err then
              vim.api.nvim_err_writeln('Error getting type definition: ' .. err.message)
              return
            end
            if not result or vim.tbl_isempty(result) then
              vim.api.nvim_echo({ { 'No type definition found', 'WarningMsg' } }, true, {})
              return
            end
            if vim.tbl_isarray(result) and not vim.tbl_isempty(result) then
              local first_result = result[1]
              if first_result.targetUri then
                -- LSP 3.17 locationLink
                first_result = first_result.targetUri
                  and {
                    uri = first_result.targetUri,
                    range = first_result.targetRange,
                  }
              end
              local bufnr = vim.uri_to_bufnr(first_result.uri)
              if not vim.api.nvim_buf_is_loaded(bufnr) then
                vim.fn.bufload(bufnr)
              end
              local lines = vim.api.nvim_buf_get_lines(bufnr, first_result.range.start.line, first_result.range['end'].line + 1, false)

              local filetype = vim.bo[bufnr].filetype
              vim.lsp.util.open_floating_preview(lines, filetype, {
                border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
                focus = false,
              })
            end
          end)
        end

        -- Show type definition
        map('<leader>tp', show_type_definition, 'Show Type Definition')

        -- Toggle inlay hints
        map('<leader>th', function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = 0 }, { bufnr = 0 })
        end, '[T]oggle Inlay [H]ints')
        -- The following two autocommands are used to highlight references of the
        -- word under your cursor when your cursor rests there for a little while.
        --    See `:help CursorHold` for information about when this is executed
        --
        -- When you move your cursor, the highlights will be cleared (the second autocommand).
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.server_capabilities.documentHighlightProvider then
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end,
    })

    -- LSP servers and clients are able to communicate to each other what features they support.
    --  By default, Neovim doesn't support everything that is in the LSP specification.
    --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
    --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())
    capabilities.textDocument.publishDiagnostics = {
      refreshSupport = true,
    }

    local servers = {
      -- clangd = {},
      -- gopls = {},
      -- pyright = {},
      -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
      --
      -- Some languages (like typescript) have entire language plugins that can be useful:
      --    https://github.com/pmizio/typescript-tools.nvim
      --
      -- But for many setups, the LSP (`tsserver`) will work just fine
      ts_ls = {
        setting = {
          typescript = {
            updateImportsOnFileMove = { enabled = 'always' },
            suggest = {
              completeFunctionCalls = true,
            },
            inlayHints = {
              includeInlayParameterNameHints = 'all',
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
          javascript = {
            inlayHints = {
              includeInlayParameterNameHints = 'all',
              includeInlayParameterNameHintsWhenArgumentMatchesName = true,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
        },
      },
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
        -- cmd = {...},
        -- filetypes = { ...},
        -- capabilities = {},
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
            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
            -- diagnostics = { disable = { 'missing-fields' } },
          },
        },
      },
    }

    -- Ensure the servers and tools above are installed
    require('mason').setup()

    -- You can add other tools here that you want Mason to install
    -- for you, so that they are available from within Neovim.
    local ensure_installed_tools = { -- Tools for mason-tool-installer to ensure
      'stylua',
      'prettier',
      'eslint',
      'eslint_d',
    }
    require('mason-tool-installer').setup { ensure_installed = ensure_installed_tools }

    -- Borders
    -- First, define your border configuration (place this before the server setups)
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

    require('mason-lspconfig').setup {
      -- Explicitly list servers Mason should ensure, excluding rust_analyzer
      ensure_installed = {
        'ts_ls',
        'html',
        'cssls',
        'tailwindcss',
        'svelte',
        'lua_ls',
      },
      -- Remove automatic_installation = true and replace with this:
      automatic_installation = {
        exclude = { 'rust_analyzer' },
      },
      handlers = {
        function(server_name)
          local server = servers[server_name] or {}
          -- This handles overriding only values explicitly passed
          -- by the server configuration above. Useful when disabling
          -- certain features of an LSP (for example, turning off formatting for tsserver)
          server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
          server.handlers = handlers -- Add border around LSPs

          if server_name == 'rust_analyzer' then
            return
          end
          -- For all other servers, use mason-lspconfig's setup
          require('lspconfig')[server_name].setup(server)
        end,
      },
    }

    require('lspconfig').rust_analyzer.setup {
      capabilities = capabilities,
      handlers = handlers,
      settings = {
        ['rust-analyzer'] = {
          diagnostics = {
            enable = true,
            enableExperimental = true,
          },
          check = {
            command = 'clippy',
            extraArgs = {},
            features = 'all',
            invocationStrategy = 'immediate',
          },
          files = {
            watcher = 'client',
          },
          cargo = {
            allFeatures = true,
            buildScripts = {
              enable = true,
            },
          },
          procMacro = {
            enable = true,
          },
        },
      },
    }

    local function setup_lsp_diags()
      -- Configure diagnostics
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
          priority = 20, -- Single number for priority instead of a table
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
        border = 'rounded', -- Use the same border style here
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
