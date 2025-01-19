-- Get current buffer number
local bufnr = vim.api.nvim_get_current_buf()

-- Rust-specific keymaps
vim.keymap.set('n', '<leader>ra', function()
  vim.cmd.RustLsp 'codeAction'
end, { silent = true, buffer = bufnr, desc = 'Rust Code Action' })

vim.keymap.set('n', 'K', function()
  vim.cmd.RustLsp { 'hover', 'actions' }
end, { silent = true, buffer = bufnr, desc = 'Rust Hover Actions' })

-- Additional Rust-specific keymaps
vim.keymap.set('n', '<leader>rd', function()
  vim.cmd.RustLsp 'debuggables'
end, { silent = true, buffer = bufnr, desc = 'Rust Debuggables' })

vim.keymap.set('n', '<leader>rr', function()
  vim.cmd.RustLsp 'runnables'
end, { silent = true, buffer = bufnr, desc = 'Rust Runnables' })

vim.keymap.set('n', '<leader>rm', function()
  vim.cmd.RustLsp 'expandMacro'
end, { silent = true, buffer = bufnr, desc = 'Expand Rust Macro' })
