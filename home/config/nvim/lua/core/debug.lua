--[[
-- Configuration is cobbled together from LazyVim + nikolovlazar/dotfiles
-- https://www.youtube.com/watch?v=Ul_WPhS2bis
-- https://github.com/nikolovlazar/dotfiles/blob/92c91ed035348c74e387ccd85ca19a376ea2f35e/.config/nvim/lua/plugins/dap.lua
-- https://www.lazyvim.org/extras/dap/core
--]]

local js_based_languages = {
  'typescript',
  'javascript',
  'typescriptreact',
  'javascriptreact',
  'vue',
  'svelte',
}

return {
  'mfussenegger/nvim-dap',
  lazy = true,
  event = 'VeryLazy',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'theHamsta/nvim-dap-virtual-text',
    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    -- Install the vscode-js-debug adapter
    {
      'microsoft/vscode-js-debug',
      -- After install, build it and rename the dist directory to out
      build = 'npm install --legacy-peer-deps --no-save && npx gulp vsDebugServerBundle && rm -rf out && mv dist out',
      version = '1.*',
    },
    {
      'mxsdev/nvim-dap-vscode-js',
      config = function()
        ---@diagnostic disable-next-line: missing-fields
        require('dap-vscode-js').setup {
          -- Path of node executable. Defaults to $NODE_PATH, and then "node"
          -- node_path = "node",

          -- Path to vscode-js-debug installation.
          debugger_path = vim.fn.resolve(vim.fn.stdpath 'data' .. '/lazy/vscode-js-debug'),

          -- Command to use to launch the debug server. Takes precedence over "node_path" and "debugger_path"
          -- debugger_cmd = { "js-debug-adapter" },

          -- which adapters to register in nvim-dap
          adapters = {
            'chrome',
            'pwa-node',
            'pwa-chrome',
            'pwa-msedge',
            'pwa-extensionHost',
            'node-terminal',
          },

          -- Path for file logging
          -- log_file_path = "(stdpath cache)/dap_vscode_js.log",

          -- Logging level for output to file. Set to false to disable logging.
          -- log_file_level = false,

          -- Logging level for output to console. Set to false to disable console output.
          -- log_console_level = vim.log.levels.ERROR,
        }
      end,
    },
    {
      'Joakker/lua-json5',
      build = './install.sh',
    },
  },
  keys = {
    {
      '<leader><F5>',
      function()
        if vim.fn.filereadable '.vscode/launch.json' then
          local dap_vscode = require 'dap.ext.vscode'
          dap_vscode.load_launchjs(nil, {
            ['pwa-node'] = js_based_languages,
            ['chrome'] = js_based_languages,
            ['pwa-chrome'] = js_based_languages,
          })
        end
        require('dap').continue()
      end,
      desc = 'Run with Args',
    },
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    {
      '<F6>',
      function()
        require('dapui').toggle {}
      end,
      desc = 'Dap UI',
    },
    {
      '<F7>',
      function()
        require('dapui').eval()
      end,
      desc = 'Eval',
      mode = { 'n', 'v' },
    },
  },
  config = function()
    local dap = require 'dap'

    -- Auto install debuggers
    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        -- 'delve',
        'chrome-debug-adapter',
        'js-debug-adapter',
        'node-debug2-adapter',
      },
    }

    -- Boilerplate form lazyvim distro (Not using lazyvim)
    --[[ local Config = require 'lazyvim.config'

    vim.api.nvim_set_hl(0, 'DapStoppedLine', { default = true, link = 'Visual' })

    for name, sign in pairs(Config.icons.dap) do
      sign = type(sign) == 'table' and sign or { sign }
      vim.fn.sign_define('Dap' .. name, { text = sign[1], texthl = sign[2] or 'DiagnosticInfo', linehl = sign[3], numhl = sign[3] })
    end ]]

    for _, language in ipairs(js_based_languages) do
      dap.configurations[language] = {
        -- Debug single nodejs files
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'Launch file',
          program = '${file}',
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          skipFiles = { '<node_internals>/**', '${workspaceFolder}/node_modules/**' },
          pauseOnExceptions = true,
          pauseOnUncaughtExceptions = true,
          pauseOnCaughtExceptions = false,
        },
        -- Debug nodejs processes (make sure to add --inspect when you run the process)
        {
          type = 'pwa-node',
          request = 'attach',
          name = 'Attach',
          processId = require('dap.utils').pick_process,
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
        },
        -- Debug web applications (client side)
        {
          type = 'pwa-chrome',
          request = 'launch',
          name = 'Launch & Debug Chrome',
          url = function()
            local co = coroutine.running()
            return coroutine.create(function()
              vim.ui.input({
                prompt = 'Enter URL: ',
                default = 'http://localhost:3000',
              }, function(url)
                if url == nil or url == '' then
                  return
                else
                  coroutine.resume(co, url)
                end
              end)
            end)
          end,
          webRoot = vim.fn.getcwd(),
          protocol = 'inspector',
          sourceMaps = true,
          userDataDir = false,
        },
        {
          type = 'pwa-node',
          request = 'attach',
          name = 'Attach to SvelteKit',
          processId = require('dap.utils').pick_process,
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = 'inspector',
          skipFiles = { '<node_internals>/**' },
          resolveSourceMapLocations = {
            '${workspaceFolder}/**',
            '!**/node_modules/**',
          },
          pauseOnExceptions = true,
          pauseOnUncaughtExceptions = true,
          pauseOnCaughtExceptions = false,
        },
        -- Divider for the launch.json derived configs
        {
          name = '----- ↓ launch.json configs ↓ -----',
          type = '',
          request = 'launch',
        },
      }
    end

    -- Run DAP-UI
    local dapui = require 'dapui'
    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Run Setup
    dapui.setup()

    -- Configure virtual text
    require('nvim-dap-virtual-text').setup {
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      show_stop_reason = true,
      commented = false,
      -- Only show virtual text for the current line
      only_first_definition = true,
      all_references = false,
      -- Only show virtual text when debugger is stopped at a breakpoint
      all_frames = false,
      -- Show virtual text only for the current frame
      virt_text_pos = 'eol',
      -- Show virtual text at end of line

      -- Display mode for virtual text:
      -- show virtual text only for variables that are hovered
      display_callback = function(variable, buf, stackframe, node, options)
        if options.virt_text_pos == 'eol' then
          return ' = ' .. variable.value
        else
          return variable.value
        end
      end,
    }
    --
    -- Config taken from LazyVim distro
    --

    -- setup dap config by VsCode launch.json file
    local vscode = require 'dap.ext.vscode'
    local json = require 'plenary.json'
    vscode.json_decode = function(str)
      return vim.json.decode(json.json_strip_comments(str))
    end
  end,
}
