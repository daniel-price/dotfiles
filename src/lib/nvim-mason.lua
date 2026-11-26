-- Wait for LazyVim's Mason installations during headless bootstrap.
-- Mason installs asynchronously; quitting before they settle aborts other packages.
require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-treesitter" } })

local registry = require("mason-registry")
local expected = LazyVim.opts("mason.nvim").ensure_installed or {}
local failed = {}
local all_packages
local registry_error

registry:on("package:install:failed", function(package, err)
  failed[package.name] = tostring(err or "installation failed")
end)

-- LazyVim refreshes the registry asynchronously before scheduling installations.
-- Wait for the registry as well, so a fresh machine cannot appear idle too early.
registry.refresh(function()
  local ok, result = pcall(registry.get_all_packages)
  if ok then
    all_packages = result
  else
    registry_error = tostring(result)
  end
end)

local function pending()
  local names = {}
  for _, name in ipairs(expected) do
    local ok, package = pcall(registry.get_package, name)
    if not ok then
      failed[name] = "package not found in Mason registry"
    elseif not package:is_installed() and not failed[name] then
      names[#names + 1] = name
    end
  end
  return names
end

local idle_since
local last_progress = vim.uv.now()
local finished = vim.wait(600000, function()
  if registry_error or not all_packages then
    return registry_error ~= nil
  end

  local remaining = pending()
  if vim.uv.now() - last_progress >= 10000 then
    io.stderr:write("[nvim] Mason waiting for: " .. (#remaining > 0 and table.concat(remaining, ", ") or "active installations") .. "\n")
    io.stderr:flush()
    last_progress = vim.uv.now()
  end

  -- A failed package is settled, not a reason to cancel the remaining installs.
  if #remaining > 0 then
    idle_since = nil
    return false
  end

  -- Other LazyVim plugins may trigger Mason installs beyond ensure_installed
  -- (e.g. tree-sitter-cli). Do not terminate those jobs either.
  for _, package in ipairs(all_packages) do
    if package:is_installing() then
      idle_since = nil
      return false
    end
  end

  -- Let deferred install callbacks run before declaring the session idle.
  idle_since = idle_since or vim.uv.now()
  return vim.uv.now() - idle_since >= 1000
end, 200)

local missing = {}
if all_packages then
  for _, name in ipairs(expected) do
    local ok, package = pcall(registry.get_package, name)
    if not ok or not package:is_installed() then
      missing[#missing + 1] = name
    end
  end
end

if not finished or registry_error or next(failed) or #missing > 0 then
  local failures = {}
  for name, reason in pairs(failed) do
    failures[#failures + 1] = name .. " (" .. reason .. ")"
  end
  table.sort(failures)
  table.sort(missing)
  vim.api.nvim_err_writeln(
    "Mason installations did not complete."
      .. (registry_error and (" Registry: " .. registry_error .. ".") or "")
      .. (#failures > 0 and (" Failed: " .. table.concat(failures, ", ") .. ".") or "")
      .. (#missing > 0 and (" Missing: " .. table.concat(missing, ", ") .. ".") or "")
      .. (not finished and " Timed out." or "")
      .. " See :MasonLog for installer errors."
  )
  vim.cmd("cquit 1")
end
