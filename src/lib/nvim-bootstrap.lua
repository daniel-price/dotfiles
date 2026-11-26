-- Run before the user's init.lua in a dedicated headless bootstrap session.
-- Keep all plugin and language-tool work in this process.
local function guarded(fn)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
  end
end

local function progress(message)
  io.stderr:write("[nvim] " .. message .. "\n")
  io.stderr:flush()
end

local function git(args)
  local result = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
  assert(result.code == 0, "Git failed: " .. table.concat(args, " ") .. "\n" .. (result.stderr or ""))
  return vim.trim(result.stdout or "")
end

local function read_lock(path)
  return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end

local original = read_lock(vim.env.DOTFILES_NVIM_ORIGINAL)
local parser_languages
local update_parsers = false

local function pin(name, remote, clone)
  local entry = assert(original[name], "Missing lock entry: " .. name)
  local commit = entry.commit
  assert(type(commit) == "string" and #commit == 40 and commit:match("^%x+$"), "Invalid pin: " .. name)
  local path = vim.fn.stdpath("data") .. "/lazy/" .. name
  if not vim.uv.fs_stat(path) then
    if not clone then
      return
    end
    progress("Cloning " .. name .. " at its locked revision")
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    git({ "clone", "--filter=blob:none", "--no-checkout", remote, path })
    git({ "-C", path, "checkout", "--detach", commit })
    return
  end
  assert(vim.uv.fs_lstat(path).type == "directory", "Unexpected plugin path: " .. path)
  local origin = git({ "-C", path, "remote", "get-url", "origin" })
  assert(origin:gsub("%.git$", "") == remote:gsub("%.git$", ""), "Unexpected plugin origin: " .. name)
  if git({ "-C", path, "rev-parse", "HEAD" }) == commit then
    return
  end
  assert(git({ "-C", path, "status", "--porcelain", "--untracked-files=no" }) == "", "Modified plugin: " .. name)
  progress("Restoring " .. name .. " to its locked revision")
  git({ "-C", path, "fetch", "origin", commit })
  git({ "-C", path, "checkout", "--detach", commit })
end

local function mismatches()
  local plugins = require("lazy.core.config").plugins
  local changed = {}
  for name, plugin in pairs(plugins) do
    if not (plugin._ and plugin._.is_local) then
      local entry = assert(original[name], "Plugin missing from original lockfile: " .. name)
      assert(vim.fn.isdirectory(plugin.dir) == 1, "Plugin not installed: " .. name)
      if git({ "-C", plugin.dir, "rev-parse", "HEAD" }) ~= entry.commit then
        changed[#changed + 1] = name
      end
    end
  end
  table.sort(changed)
  return changed
end

local function verify()
  local changed = mismatches()
  assert(#changed == 0, "Plugins do not match original lockfile: " .. table.concat(changed, ", "))
end

guarded(function()
  assert(vim.uv.fs_realpath(vim.fn.stdpath("config")) == vim.uv.fs_realpath(vim.env.DOTFILES_NVIM_CONFIG),
    "Neovim is loading an unexpected configuration directory")
  -- These two repositories determine the loader and imported plugin specs.
  -- They must be pinned before either is loaded.
  pin("lazy.nvim", "https://github.com/folke/lazy.nvim.git", true)
  pin("LazyVim", "https://github.com/LazyVim/LazyVim.git", false)
  vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/lazy.nvim")

  local lazy = require("lazy")
  local setup = lazy.setup
  lazy.setup = function(opts)
    assert(type(opts) == "table" and type(opts.spec) == "table", "Unexpected LazyVim setup format")
    opts.lockfile = vim.env.DOTFILES_NVIM_LOCK
    opts.checker = { enabled = false }
    opts.change_detection = { enabled = false }
    -- lazy.nvim may update its lockfile after an install or clean, even while
    -- installing locked plugins. Keep the snapshot fixed for subsequent
    -- imports, restores and verification. This override is session-local.
    require("lazy.manage.lock").update = function() end

    local ts_path = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"
    if vim.uv.fs_stat(ts_path) and original["nvim-treesitter"] then
      update_parsers = git({ "-C", ts_path, "rev-parse", "HEAD" }) ~= original["nvim-treesitter"].commit
    end
    -- Suppress LazyVim's automatic parser installation and build-time update
    -- only in bootstrap; run them once, explicitly, after Mason has settled.
    table.insert(opts.spec, {
      "nvim-treesitter/nvim-treesitter",
      build = false,
      opts = function(_, ts_opts)
        parser_languages = vim.deepcopy(ts_opts.ensure_installed or {})
        ts_opts.ensure_installed = {}
      end,
    })

    local loader = require("lazy.core.loader")
    local startup = loader.startup
    loader.startup = function(...)
      local changed = mismatches()
      if #changed > 0 then
        progress("Restoring " .. #changed .. " existing plugin(s) before loading")
        require("lazy.manage").restore({ plugins = changed, wait = true, show = false })
      end
      verify()
      return startup(...)
    end

    progress("Installing missing plugins from the original lockfile")
    return setup(opts)
  end
end)

local function parsers()
  local ts = require("nvim-treesitter")
  assert(type(parser_languages) == "table", "Tree-sitter configuration was not loaded")
  assert(type(ts.install) == "function" and type(ts.get_installed) == "function",
    "Unsupported Tree-sitter installation API")
  local installed = {}
  for _, lang in ipairs(ts.get_installed()) do
    installed[lang] = true
  end
  local missing = vim.tbl_filter(function(lang)
    return not installed[lang]
  end, parser_languages)
  if #missing > 0 then
    progress("Installing Tree-sitter parsers: " .. table.concat(missing, ", "))
    ts.install(missing, { summary = true }):wait(300000)
  end
  if update_parsers then
    progress("Updating parsers for the restored Tree-sitter revision")
    ts.update(nil, { summary = true }):wait(300000)
  end
  -- A completed installer is not evidence that all parsers succeeded.
  for _, lang in ipairs(parser_languages) do
    local ok, loaded, reason = pcall(vim.treesitter.language.add, lang)
    assert(ok and loaded, "Tree-sitter parser unavailable: " .. lang .. " (" .. tostring(reason or loaded) .. ")")
  end
  progress("Verified required Tree-sitter parsers")
end

function _G.DotfilesNvimFinish()
  guarded(function()
    verify()
    vim.cmd("Lazy! clean")
    progress("Waiting for Mason language tools")
    dofile(vim.env.DOTFILES_NVIM_MASON_SCRIPT)
    parsers()
    verify()
    assert(vim.fn.writefile({ "ok" }, vim.env.DOTFILES_NVIM_SUCCESS) == 0, "Could not record verification")
  end)
end
