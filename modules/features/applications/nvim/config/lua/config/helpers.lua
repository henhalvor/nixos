_G.toggle_quickfix = function()
  local is_open = false
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      is_open = true
      break
    end
  end

  if is_open then
    vim.cmd("cclose")
  else
    vim.cmd("copen")
  end
end

_G.ToggleDevTerminal = function()
  Snacks.terminal.toggle(nil, {
    win = {
      border = "rounded",
      relative = "editor",
      width = math.floor(vim.o.columns * 0.9),
      height = math.floor(vim.o.lines * 0.9),
      row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.9)) / 2),
      col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.9)) / 2),
      position = "float",
    },
    env = { TERM_ID = "9999" },
  })
end
