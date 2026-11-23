-- Wait for LazyVim's declared Mason tools during headless bootstrap.
-- Mason installs asynchronously; immediately quitting Neovim aborts them.
require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-treesitter" } })

local registry = require("mason-registry")
local expected = LazyVim.opts("mason.nvim").ensure_installed or {}
local failed = {}

registry:on("package:install:failed", function(package)
  failed[package.name] = true
end)

local function missing()
  local result = {}
  for _, name in ipairs(expected) do
    local ok, package = pcall(registry.get_package, name)
    if not ok or not package:is_installed() then
      result[#result + 1] = name
    end
  end
  return result
end

local finished = vim.wait(600000, function()
  return next(failed) ~= nil or #missing() == 0
end, 200)

if not finished or next(failed) then
  local failed_names = vim.tbl_keys(failed)
  table.sort(failed_names)
  vim.api.nvim_err_writeln(
    "Mason tools failed or timed out. Failed: "
      .. table.concat(failed_names, ", ")
      .. "; not installed: "
      .. table.concat(missing(), ", ")
  )
  vim.cmd("cquit 1")
end
