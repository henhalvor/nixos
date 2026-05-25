local lazy = require("config.lazy")

local function setup()
  lazy.packadd("harpoon")
  local harpoon = require("harpoon")

  harpoon:setup({
    settings = {
      save_on_toggle = false,
      sync_on_ui_close = false,
    },
    default = {},
    auto = {
      select_with_nil = false,
      BufLeave = function(evt, list)
        local filename = vim.api.nvim_buf_get_name(evt.buf)
        if filename == "" or vim.fn.filereadable(filename) ~= 1 then
          return
        end
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = evt.buf })
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = evt.buf })
        if vim.tbl_contains({ "help", "terminal", "quickfix", "nofile", "prompt" }, buftype) then
          return
        end
        if vim.tbl_contains({ "help", "qf", "man", "telescope", "harpoon", "NvimTree", "neo-tree" }, filetype) then
          return
        end
        for _, item in ipairs(list.items) do
          if item.value == filename then
            return
          end
        end
        if #list.items >= 6 then
          table.remove(list.items, 1)
        end
        list:add()
      end,
    },
  })

  return harpoon
end

local harpoon_loaded
local function harpoon()
  harpoon_loaded = harpoon_loaded or setup()
  return harpoon_loaded
end

vim.keymap.set("n", "<leader>a", function() harpoon():list():add() end, { desc = "Harpoon: Add to pinned list" })
vim.keymap.set("n", "<leader>e", function() harpoon().ui:toggle_quick_menu(harpoon():list()) end, { desc = "Harpoon: Show pinned list" })
for i = 1, 6 do
  vim.keymap.set("n", string.format("<leader>%s", i), function() harpoon():list():select(i) end, { desc = "Harpoon: Jump to pinned #" .. i })
  vim.keymap.set("n", string.format("<M-%s>", i), function() harpoon():list("auto"):select(i) end, { desc = "Harpoon: Jump to auto #" .. i })
end
vim.keymap.set("n", "<M-a>", function() harpoon():list("auto"):add() end, { desc = "Harpoon: Add to auto list" })
vim.keymap.set("n", "<M-e>", function() harpoon().ui:toggle_quick_menu(harpoon():list("auto")) end, { desc = "Harpoon: Show auto list" })
