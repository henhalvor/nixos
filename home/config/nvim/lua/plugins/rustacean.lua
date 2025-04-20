return {
  'mrcjkb/rustaceanvim',
  version = '^5',
  lazy = false,
  ft = { 'rust' },
  config = function()
    -- Set up an autocmd to configure buffer-local keymaps when a Rust buffer is opened
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'rust',
      callback = function(args)
        -- Buffer-local keymaps for Rust files
        local bufnr = args.buf

        -- Helper function to make mapping more concise
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
        end

        -- Migrate your existing keymaps to use rustaceanvim commands
        map('n', '<leader>ra', function()
          vim.cmd.RustLsp 'codeAction'
        end, 'Rust Code Action')

        map('n', 'K', function()
          vim.cmd.RustLsp { 'hover', 'actions' }
        end, 'Rust Hover Actions')

        map('n', '<leader>rd', function()
          vim.cmd.RustLsp 'debuggables'
        end, 'Rust Debuggables')

        map('n', '<leader>rr', function()
          vim.cmd.RustLsp 'runnables'
        end, 'Rust Runnables')

        map('n', '<leader>rm', function()
          vim.cmd.RustLsp 'expandMacro'
        end, 'Expand Rust Macro')

        -- -- Set up the auto-save functionality
        -- vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
        --   buffer = bufnr,
        --   callback = function()
        --     -- Only save if the buffer is modifiable to prevent errors
        --     if vim.bo[bufnr].modifiable then
        --       vim.cmd('write')
        --     end
        --   end,
        --   nested = true,
        -- })
      end,
    })

    -- Experimental config (didnt seem to have any effect therefore commented out, maybe needed for future use)
    -- vim.diagnostic.config {
    --   virtual_text = true,
    --   signs = true,
    --   update_in_insert = false,
    -- }

    vim.g.rustaceanvim = {
      -- Plugin configuration
      server = {
        default_settings = {
          ['rust-analyzer'] = {
            checkOnSave = {
              enable = true,
              command = 'clippy',
              extraArgs = { '--all-targets', '--all-features' },
            },
            diagnostics = {
              enable = true,
              enableExperimental = true,
            },
          },
        },
      },
      -- Tell rustaceanvim to use the system-provided tools
      tools = {
        autoSetHints = true,
        hover_actions = {
          auto_focus = false,
          border = {
            { '╭', 'FloatBorder' },
            { '─', 'FloatBorder' },
            { '╮', 'FloatBorder' },
            { '│', 'FloatBorder' },
            { '╯', 'FloatBorder' },
            { '─', 'FloatBorder' },
            { '╰', 'FloatBorder' },
            { '│', 'FloatBorder' },
          },
          max_width = 80,
          max_height = 20,
        },
      },
    }
  end,
}
