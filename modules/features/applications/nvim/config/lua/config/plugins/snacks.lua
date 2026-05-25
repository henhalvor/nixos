require("snacks").setup({
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
      { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
      { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
      {
        pane = 2,
        icon = " ",
        title = "Git Status",
        section = "terminal",
        enabled = function()
          return Snacks.git.get_root() ~= nil
        end,
        cmd = "git status --short --branch --renames",
        height = 5,
        padding = 1,
        ttl = 300,
        indent = 3,
      },
      { section = "startup" },
    },
  },
  indent = { enabled = false },
  input = { enabled = true },
  notifier = { enabled = true, timeout = 3000 },
  quickfile = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = true },
  words = { enabled = true },
  styles = {},
  terminal = { enabled = true },
  picker = {
    enabled = true,
    layout = "custom",
    layouts = {
      custom = {
        layout = {
          box = "vertical",
          backdrop = false,
          row = -1,
          width = 0,
          height = 0.4,
          border = "none",
          title = " {title} {live} {flags}",
          title_pos = "left",
          {
            box = "horizontal",
            { win = "list", border = "rounded" },
            { win = "preview", title = "{preview}", width = 0.6, border = "rounded" },
          },
          { win = "input", height = 1, border = "none" },
        },
      },
    },
  },
  explorer = { enabled = false },
})

local map = vim.keymap.set

map("n", "<leader>sh", function() Snacks.picker.help() end, { silent = true, desc = "[S]earch [H]elp" })
map("n", "<leader>sk", function() Snacks.picker.keymaps() end, { silent = true, desc = "[S]earch [K]eymaps" })
map("n", "<leader>sc", function() Snacks.picker.files() end, { silent = true, desc = "[S]earch [Current] Files" })
map("n", "<leader>ss", function() Snacks.picker.pickers() end, { silent = true, desc = "[S]earch [S]elect Picker" })
map("n", "<leader>sw", function() Snacks.picker.grep_word() end, { silent = true, desc = "[S]earch current [W]ord" })
map("n", "<leader>sg", function() Snacks.picker.grep() end, { silent = true, desc = "[S]earch by [G]rep" })
map("n", "<leader>sd", function() Snacks.picker.diagnostics() end, { silent = true, desc = "[S]earch [D]iagnostics" })
map("n", "<leader><leader>", function() Snacks.picker.buffers() end, { silent = true, desc = "Find existing buffers" })
map("n", "<leader>/", function() Snacks.picker.lines() end, { desc = "[/] Fuzzily search in current buffer" })
map("n", "<leader>s/", function() Snacks.picker.grep_buffers() end, { desc = "[S]earch [/] in Open Files" })
map("n", "<leader>s.", function()
  Snacks.picker.files({ cwd = vim.fn.expand("~/.dotfiles/"), hidden = true })
end, { desc = "[S]earch [.]dotfiles" })

map("n", "<leader>z", function() Snacks.zen() end, { silent = true, desc = "Toggle Zen Mode" })
map("n", "<leader>Z", function() Snacks.zen.zoom() end, { silent = true, desc = "Toggle Zoom" })
map({ "n", "v" }, "<leader>.", function() Snacks.scratch() end, { silent = true, desc = "Toggle Scratch Buffer" })
map({ "n", "v" }, "<leader>S", function() Snacks.scratch.select() end, { silent = true, desc = "Select Scratch Buffer" })
map({ "n", "v" }, "<leader>n", function() Snacks.notifier.show_history() end, { silent = true, desc = "Notification History" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { silent = true, desc = "Delete Buffer" })
map({ "n", "v" }, "<leader>cR", function() Snacks.rename.rename_file() end, { silent = true, desc = "Rename File" })
map({ "n", "v" }, "<leader>gB", function() Snacks.gitbrowse() end, { silent = true, desc = "Git Browse" })
map({ "n", "v" }, "<leader>gg", function() Snacks.lazygit() end, { silent = true, desc = "Lazygit" })
map({ "n", "v" }, "<leader>gl", function() Snacks.lazygit.log() end, { silent = true, desc = "Lazygit Log (cwd)" })
map({ "n", "v" }, "<leader>un", function() Snacks.notifier.hide() end, { silent = true, desc = "Dismiss All Notifications" })
map({ "n", "v" }, "<leader>tt", _G.ToggleDevTerminal, { silent = true, desc = "Toggle Dev Server Terminal" })
map({ "n", "t" }, "]]", function() Snacks.words.jump(vim.v.count1) end, { silent = true, desc = "Next Reference" })
map({ "n", "t" }, "[[", function() Snacks.words.jump(-vim.v.count1) end, { silent = true, desc = "Prev Reference" })

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    _G.dd = function(...)
      Snacks.debug.inspect(...)
    end
    _G.bt = function()
      Snacks.debug.backtrace()
    end
    vim.print = _G.dd
    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
    Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
    Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
    Snacks.toggle.inlay_hints():map("<leader>uh")
    Snacks.toggle.indent():map("<leader>ug")
  end,
})

map("n", "<leader>rf", function()
  vim.ui.input({ prompt = "Folder to rename: " }, function(old_dir)
    if not old_dir or old_dir == "" then
      return
    end
    vim.ui.input({ prompt = "New folder name: ", default = old_dir }, function(new_dir)
      if not new_dir or new_dir == "" or new_dir == old_dir then
        return
      end
      vim.cmd("wa")
      vim.loop.fs_rename(old_dir, new_dir)
      Snacks.rename.on_rename_file(old_dir, new_dir)
    end)
  end)
end, { desc = "Rename folder (LSP-safe)" })
