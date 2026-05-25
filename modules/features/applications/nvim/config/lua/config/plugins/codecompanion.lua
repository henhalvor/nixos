require("codecompanion").setup({
  adapters = {
    copilot = function()
      return require("codecompanion.adapters").extend("copilot", {
        schema = {
          model = {
            default = "gpt-5-mini",
            options = { "gpt-4", "gpt-4o", "gpt-5-mini" },
          },
        },
      })
    end,
  },
  prompt_library = {
    ["Code Review (Selection)"] = {
      strategy = "chat",
      description = "Review visually selected code",
      opts = {
        modes = { "v" },
        short_name = "cr_selection",
        adapter = "copilot",
        auto_submit = true,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "system",
          content = function(context)
            local selected_code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return string.format("You are an expert code reviewer for %s. Review the following code selection:\n\n```%s\n%s\n```", context.filetype, context.filetype, selected_code)
          end,
        },
        {
          role = "user",
          content = "Analyze code quality, logic, correctness, best practices, security, performance, error handling, dependencies, and testing. Provide specific actionable feedback with line references where applicable.",
          opts = { auto_submit = false },
        },
      },
    },
    ["Review Full Buffer"] = {
      strategy = "chat",
      description = "Review the entire current file",
      opts = {
        modes = { "n" },
        short_name = "cr_file",
        adapter = "copilot",
        auto_submit = true,
      },
      prompts = {
        {
          role = "system",
          content = function(context)
            local end_line = vim.api.nvim_buf_line_count(context.bufnr)
            local buffer_content = require("codecompanion.helpers.actions").get_code(1, end_line)
            return string.format("You are an expert code reviewer for %s. Review the following file content:\n\n```%s\n%s\n```", context.filetype, context.filetype, buffer_content)
          end,
        },
        {
          role = "user",
          content = "Analyze code quality, logic, correctness, best practices, security, performance, error handling, dependencies, and testing. Provide specific actionable feedback with line references where applicable.",
          opts = { auto_submit = false },
        },
      },
    },
    ["Meticulous Documentation"] = {
      strategy = "chat",
      description = "Generate meticulous documentation for the current file",
      opts = {
        modes = { "n" },
        short_name = "doc_file",
        adapter = "copilot",
        auto_submit = true,
      },
      prompts = {
        {
          role = "system",
          content = function(context)
            local end_line = vim.api.nvim_buf_line_count(context.bufnr)
            local buffer_content = require("codecompanion.helpers.actions").get_code(1, end_line)
            return string.format("You are an expert technical writer for %s. Generate documentation for this file:\n\n```%s\n%s\n```", context.filetype, context.filetype, buffer_content)
          end,
        },
        {
          role = "user",
          content = "Generate clear documentation covering purpose, functions, parameters, return values, side effects, usage examples, error handling, and dependencies. @{insert_edit_into_file} #{buffer}",
          opts = { auto_submit = false },
        },
      },
    },
  },
  display = {
    chat = {
      intro_message = "Welcome to CodeCompanion! Press ? for options",
      show_header_separator = true,
      auto_scroll = true,
      show_settings = true,
      show_token_count = true,
      show_references = true,
      token_count = function(tokens, adapter)
        return string.format(" %s (%d tokens)", adapter.formatted_name, tokens)
      end,
      separator = "-",
      window = {
        layout = "vertical",
        border = "rounded",
        height = 0.8,
        width = 0.45,
      },
    },
  },
  strategies = {
    chat = {
      adapter = "copilot",
      roles = {
        llm = function(adapter)
          return string.format("%s (%s)", adapter.formatted_name, adapter.schema.model.default)
        end,
        user = "Me",
      },
      keymaps = {
        close = { modes = { n = "q" }, index = 3, callback = "keymaps.close", description = "Close Chat" },
        stop = { modes = { n = "<C-c>" }, index = 4, callback = "keymaps.stop", description = "Stop Request" },
      },
    },
    inline = { adapter = "copilot" },
  },
})

vim.keymap.set({ "n", "v" }, "<leader>ac", "<cmd>CodeCompanionActions<CR>", { silent = true, desc = "CodeCompanion actions" })
vim.keymap.set({ "n", "v" }, "<leader>aa", "<cmd>CodeCompanionChat Toggle<CR>", { silent = true, desc = "CodeCompanion chat" })
vim.keymap.set("v", "<leader>ad", "<cmd>CodeCompanionChat Add<CR>", { silent = true, desc = "CodeCompanion add to chat" })
