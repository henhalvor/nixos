local M = {}
local loaded = {}

function M.packadd(name)
  if not loaded[name] then
    vim.cmd.packadd(name)
    loaded[name] = true
  end
end

function M.packadd_many(names)
  for _, name in ipairs(names) do
    M.packadd(name)
  end
end

return M
