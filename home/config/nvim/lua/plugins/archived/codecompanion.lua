return {}
-- return {
--   'olimorris/codecompanion.nvim',
--   dependencies = {
--     'nvim-lua/plenary.nvim',
--     'nvim-treesitter/nvim-treesitter',
--     'github/copilot.vim',
--   },
--   opts = {
--     strategies = {
--       -- Change the default chat adapter
--       chat = {
--         adapter = 'anthropic', -- or anthropic
--       },
--       inline = {
--         adapter = 'copilot',
--       },
--       agent = {
--         adapter = 'anthropic',
--       },
--     },
--     opts = {
--       -- Set debug logging
--       log_level = 'DEBUG',
--     },
--   },
--   config = function()
--     require('codecompanion').setup {}
--     vim.keymap.set({ 'n', 'v' }, '<leader>cc', '<cmd>CodeCompanionActions<cr>', { noremap = true, silent = true })
--     vim.keymap.set({ 'n', 'v' }, '<leader>aa', '<cmd>CodeCompanionChat Toggle<cr>', { noremap = true, silent = true })
--     vim.keymap.set('v', '<leader>a+', '<cmd>CodeCompanionChat Add<cr>', { noremap = true, silent = true })
--
--     -- Expand 'cc' into 'CodeCompanion' in the command line
--     vim.cmd [[cab cc CodeCompanion]]
--   end,
-- }
