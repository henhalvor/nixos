local lazy = require("config.lazy")
local configured = false

local function persistence()
  lazy.packadd("persistence.nvim")
  if not configured then
    require("persistence").setup({})
    configured = true
  end
  return require("persistence")
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("restore_session", { clear = true }),
  callback = function()
    local should_load = false
    if vim.fn.argc() == 0 then
      should_load = true
    elseif vim.fn.argc() == 1 then
      local arg = vim.fn.argv(0)
      should_load = arg == "." or arg == vim.fn.getcwd()
    end

    if should_load and vim.fn.getcwd() ~= vim.env.HOME then
      persistence().load()
    end
  end,
  nested = true,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "PersistenceLoadPost",
  callback = function()
    vim.defer_fn(function()
      local visible = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        visible[vim.api.nvim_win_get_buf(win)] = true
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf)
          and vim.fn.buflisted(buf) == 1
          and not visible[buf]
          and vim.bo[buf].modified == false
          and vim.bo[buf].buftype == "" then
          pcall(vim.api.nvim_buf_delete, buf, {})
        end
      end
    end, 100)
  end,
})

vim.keymap.set("n", "<leader>qs", function() persistence().load() end, { desc = "Persistence load session for current directory" })
vim.keymap.set("n", "<leader>qS", function() persistence().select() end, { desc = "Persistence [S]elect" })
vim.keymap.set("n", "<leader>ql", function() persistence().load({ last = true }) end, { desc = "Persistence [L]oad last session" })
vim.keymap.set("n", "<leader>qd", function() persistence().stop() end, { desc = "Persistence Stop" })
