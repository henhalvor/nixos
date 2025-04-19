-- Sync buffers automatically
vim.opt.autoread = true
vim.opt.termguicolors = true
vim.opt_global.formatoptions:append '2'
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.g.mapleader = ' '
vim.g.have_nerd_font = true
-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true
-- Show mode
vim.opt.showmode = true
-- System clipboard
vim.opt.clipboard = 'unnamedplus'
-- Line wrapping
vim.opt.wrap = true -- Enable line wrapping
vim.opt.linebreak = true -- Break lines at word boundaries
vim.opt.breakindent = true -- Preserve indentation in wrapped text
-- Optional but recommended with linebreak
vim.opt.showbreak = '↪ ' -- Show a symbol at the beginning of wrapped lines
vim.opt.breakat = ' ^!@*-+;:,./?' -- Characters that might cause a word break
-- Save undo history
vim.opt.undofile = true
-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true
-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'
-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true
-- Indenting indication
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
-- Show which line your cursor is on
vim.opt.cursorline = true
-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10
-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
-- Move lines
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Diagnostic keymaps
-- vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
-- vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>di', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
--
--  Use CTRL+<hjkl> to switch between windows
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

--
-- QuickFix list
--

-- Toggle quickfix list with <leader>q
vim.keymap.set('n', '<leader>q', function()
  local is_open = false
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      is_open = true
      break
    end
  end
  if is_open then
    vim.cmd 'cclose'
  else
    vim.cmd 'copen'
  end
end, { desc = 'Toggle quickfix list' })

-- Navigate quickfix list
vim.keymap.set('n', ']q', ':cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '[q', ':cprev<CR>', { desc = 'Prev quickfix item' })
vim.keymap.set('n', '<leader>qc', ":lua vim.fn.setqflist({}, 'f')<CR>", { desc = '[Q]uickfix [C]lear' })

--
--
--

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  pattern = '*',
  command = 'silent! checktime',
})

-- [[ Install `lazy.nvim` plugin manager ]]
-- Define base directories at the start of init.lua
vim.g.package_home = vim.fn.expand '~/.local/share/nvim'
vim.g.mason_home = vim.fn.expand '~/.local/share/nvim/mason'
vim.g.lazy_home = vim.fn.expand '~/.local/share/nvim/lazy'

-- Update lazy.nvim path
local lazypath = vim.g.lazy_home .. '/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
require('lazy').setup {
  root = vim.g.lazy_home,
  lockfile = vim.fn.expand '~/.local/state/nvim/lazy-lock.json', -- Store lock file in state directory

  -- importing core plugins from "./lua/core""
  { import = 'core' },

  -- importing regular plugins from "./lua/plugins""
  { import = 'plugins' },
}
