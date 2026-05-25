local lazy = require("config.lazy")
local configured = false

local js_based_languages = {
  "typescript",
  "javascript",
  "typescriptreact",
  "javascriptreact",
  "vue",
  "svelte",
}

local function setup()
  if configured then
    return require("dap")
  end

  lazy.packadd_many({
    "nvim-nio",
    "nvim-dap",
    "nvim-dap-ui",
    "nvim-dap-virtual-text",
    "nvim-dap-vscode-js",
  })

  local nix_info = require(vim.g.nix_info_plugin_name)
  local dap = require("dap")

  require("dap-vscode-js").setup({
    debugger_path = nix_info(nil, "info", "dap", "vscodeJsDebug"),
    adapters = {
      "chrome",
      "pwa-node",
      "pwa-chrome",
      "pwa-msedge",
      "pwa-extensionHost",
      "node-terminal",
    },
  })

  for _, language in ipairs(js_based_languages) do
    dap.configurations[language] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        skipFiles = { "<node_internals>/**", "${workspaceFolder}/node_modules/**" },
        pauseOnExceptions = true,
        pauseOnUncaughtExceptions = true,
        pauseOnCaughtExceptions = false,
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("dap.utils").pick_process,
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
      },
      {
        type = "pwa-chrome",
        request = "launch",
        name = "Launch & Debug Chrome",
        url = function()
          local co = coroutine.running()
          return coroutine.create(function()
            vim.ui.input({ prompt = "Enter URL: ", default = "http://localhost:3000" }, function(url)
              if url and url ~= "" then
                coroutine.resume(co, url)
              end
            end)
          end)
        end,
        webRoot = vim.fn.getcwd(),
        protocol = "inspector",
        sourceMaps = true,
        userDataDir = false,
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach to SvelteKit",
        processId = require("dap.utils").pick_process,
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        skipFiles = { "<node_internals>/**" },
        resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
        pauseOnExceptions = true,
        pauseOnUncaughtExceptions = true,
        pauseOnCaughtExceptions = false,
      },
      { name = "----- down launch.json configs down -----", type = "", request = "launch" },
    }
  end

  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = nix_info("lldb-dap", "info", "dap", "codelldb"),
      args = { "--port", "${port}" },
    },
  }
  dap.configurations.rust = {
    {
      name = "Launch Rust executable",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
      runInTerminal = false,
    },
  }

  vim.keymap.set("n", "<leader>dr", function()
    vim.cmd.RustLsp("debuggables")
  end, { desc = "[D]ebug [R]ust: Pick Debuggable" })

  local dapui = require("dapui")
  dap.listeners.after.event_initialized["dapui_config"] = dapui.open
  dap.listeners.before.event_terminated["dapui_config"] = dapui.close
  dap.listeners.before.event_exited["dapui_config"] = dapui.close
  dapui.setup()

  require("nvim-dap-virtual-text").setup({
    enabled = true,
    enabled_commands = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = false,
    show_stop_reason = true,
    commented = false,
    only_first_definition = true,
    all_references = false,
    all_frames = false,
    virt_text_pos = "eol",
    display_callback = function(variable, _, _, _, options)
      if options.virt_text_pos == "eol" then
        return " = " .. variable.value
      end
      return variable.value
    end,
  })

  local vscode = require("dap.ext.vscode")
  local json = require("plenary.json")
  vscode.json_decode = function(str)
    return vim.json.decode(json.json_strip_comments(str))
  end

  configured = true
  return dap
end

local function dap()
  return setup()
end

vim.keymap.set("n", "<leader><F5>", function()
  local d = dap()
  if vim.fn.filereadable(".vscode/launch.json") == 1 then
    require("dap.ext.vscode").load_launchjs(nil, {
      ["pwa-node"] = js_based_languages,
      chrome = js_based_languages,
      ["pwa-chrome"] = js_based_languages,
    })
  end
  d.continue()
end, { desc = "Run with Args" })
vim.keymap.set("n", "<F5>", function() dap().continue() end, { desc = "Debug: Start/Continue" })
vim.keymap.set("n", "<F1>", function() dap().step_into() end, { desc = "Debug: Step Into" })
vim.keymap.set("n", "<F2>", function() dap().step_over() end, { desc = "Debug: Step Over" })
vim.keymap.set("n", "<F3>", function() dap().step_out() end, { desc = "Debug: Step Out" })
vim.keymap.set("n", "<leader>b", function() dap().toggle_breakpoint() end, { desc = "Debug: Toggle Breakpoint" })
vim.keymap.set("n", "<leader>B", function() dap().set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, { desc = "Debug: Set Breakpoint" })
vim.keymap.set("n", "<F6>", function() setup(); require("dapui").toggle({}) end, { desc = "Dap UI" })
vim.keymap.set({ "n", "v" }, "<F7>", function() setup(); require("dapui").eval() end, { desc = "Eval" })
