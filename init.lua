-- vim: foldmethod=marker foldlevel=99 foldmarker={{{,}}}
-- ============================================================================
-- nvim-cpp: A SMART NEOVIM C++ DEVELOPMENT CONFIGURATION
-- A minimal, fast, and powerful Neovim configuration optimized for C++/CMake development using Neovim 0.12's native package manager and LSP.
-- Author: Michael Mattsson <michael@mattsson.net>
-- ============================================================================

-- First run: Checks if LSPs are installed
-- LSPs missing: Shows dialog with 3 options:ap('n', '<leader>lm', ':Mason<C
-- 
-- Run install_lsp.sh (recommended)
-- Enable Mason (creates marker file)
-- Skip (just marks as complete)
-- 
-- Subsequent runs:
-- 
-- If Mason was enabled → loads Mason plugins
-- If script was run → no Mason overhead
-- 
-- Reset: Delete ~/.local/share/nvim/init_completed to trigger first-run again



-- ============================================================================
-- LEADER KEY {{{
-- ============================================================================

vim.g.mapleader = " "

-- }}}



-- ============================================================================
-- LANGUAGE CONFIGURATION {{{
-- ============================================================================
-- Add new languages here - this is the ONLY place you need to edit!
-- Each entry configures LSP, Treesitter, and file associations automatically.

_G.supported_languages = {
    {
        name = "C/C++",
        lsp = {
            name = "clangd",
            cmd = {"clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu", "--completion-style=detailed", "--function-arg-placeholders", "--pch-storage=memory"},
            filetypes = {"c", "cpp", "objc", "objcpp"},
        },
        treesitter = {"c", "cpp"},
        format_tool = ".clang-format",  -- Optional
    },
    {
        name = "Rust",
        lsp = {
            name = "rust_analyzer",
            cmd = {"rust-analyzer"},
            filetypes = {"rs"},
        },
        treesitter = {"rust"},
    },    
    {
        name = "Lua",
        lsp = {
            name = "lua_ls",
            cmd = {"lua-language-server"},
            filetypes = {"lua"},
        },
        treesitter = {"lua"},
    },
    {
        name = "Bash",
        lsp = {
            name = "bashls",
            cmd = {"bash-language-server", "start"},
            filetypes = {"sh", "bash"},
        },
        treesitter = {"bash"},
    },
    {
        name = "JavaScript/TypeScript",
        lsp = {
            name = "ts_ls",
            cmd = {"typescript-language-server", "--stdio"},
            filetypes = {"javascript", "typescript", "javascriptreact", "typescriptreact"},
        },
        treesitter = {"javascript", "typescript"},
    },
    {
        name = "HTML",
        lsp = {
            name = "html",
            cmd = {"vscode-html-language-server", "--stdio"},
            filetypes = {"html"},
        },
        treesitter = {"html"},
    },
    {
        name = "CSS",
        lsp = {
            name = "cssls",
            cmd = {"vscode-css-language-server", "--stdio"},
            filetypes = {"css", "scss", "less"},
        },
        treesitter = {"css"},
    },
    {
        name = "CMake",
        lsp = {
            name = "cmake",
            cmd = {"cmake-language-server"},
            filetypes = {"cmake"},
        },
        treesitter = {"cmake"},
    },
    
    -- ============================================================
    -- ADD NEW LANGUAGES HERE - Example for Rust:
    -- ============================================================
    -- {
    --     name = "Rust",
    --     lsp = {
    --         name = "rust_analyzer",
    --         cmd = {"rust-analyzer"},
    --         filetypes = {"rust"},
    --     },
    --     treesitter = {"rust"},
    -- },
    -- ============================================================
}

-- }}}





-- ============================================================================
-- FIRST RUN SETUP {{{
-- ============================================================================

local data_dir = vim.fn.stdpath('data')
local first_run_marker = data_dir .. '/init_completed'

-- Check if this is the first run
if vim.fn.filereadable(first_run_marker) == 0 then
    -- First run detected
    vim.notify("First run detected - checking LSP installation...", vim.log.levels.INFO)
    
    -- Check if LSPs are installed
    local lsps_to_check = {}
    for _, lang in ipairs(_G.supported_languages) do
        if lang.lsp then
            table.insert(lsps_to_check, {
                name = lang.lsp.name,
                cmd = lang.lsp.cmd[1]
            })
        end
    end
    
    local missing = {}
    for _, lsp in ipairs(lsps_to_check) do
        if vim.fn.executable(lsp.cmd) == 0 then
            table.insert(missing, lsp.name)
        end
    end
    
    if #missing > 0 then
        -- LSPs are missing - ask about Mason
        vim.defer_fn(function()
            local response = vim.fn.confirm(
                "LSP servers not found!\n\n" ..
                "Missing: " .. table.concat(missing, ", ") .. "\n\n" ..
                "Options:\n" ..
                "1. Run install_lsp.sh (recommended)\n" ..
                "2. Enable Mason for automatic installation\n" ..
                "3. Skip (install manually later)",
                "&Run Script\n&Enable Mason\n&Skip",
                1
            )
            
            if response == 1 then
                -- Option 1: Show instructions for running script
                vim.notify(
                    "Please exit Neovim and run:\n" ..
                    "  cd ~/.config/nvim\n" ..
                    "  ./install_lsp.sh\n\n" ..
                    "Then restart Neovim.",
                    vim.log.levels.WARN,
                    {timeout = 10000}
                )
            elseif response == 2 then
                -- Option 2: Enable Mason
                local mason_config = data_dir .. '/mason_enabled'
                vim.fn.writefile({''}, mason_config)
                vim.notify(
                    "Mason enabled! Restart Neovim and run :Mason to install LSPs",
                    vim.log.levels.INFO
                )
                
                -- Mark as completed so we don't ask again
                vim.fn.writefile({''}, first_run_marker)
            else
                -- Option 3: Skip
                vim.notify("Skipped LSP installation. Run :Mason later to install.", vim.log.levels.WARN)
                vim.fn.writefile({''}, first_run_marker)
            end
        end, 500)
    else
        -- LSPs found - mark as complete
        vim.notify("LSP servers found! Setup complete.", vim.log.levels.INFO)
        vim.fn.writefile({''}, first_run_marker)
    end
end

-- Check if Mason should be loaded
_G.mason_enabled = vim.fn.filereadable(data_dir .. '/mason_enabled') == 1

-- }}}



-- ============================================================================
-- PROJECT ROOT DETECTION {{{
-- ============================================================================

function _G.find_project_root()
    local current_dir = vim.fn.expand('%:p:h')
    if current_dir == '' then
        current_dir = vim.fn.getcwd()
    end
    
    local root_markers = {
        {'.git', 'directory'},
        {'build', 'directory'},
        {'.gitignore', 'file'},
        {'compile_commands.json', 'file'},
    }
    
    local path = current_dir
    local root_found = nil
    local cmake_found = nil
    
    while path ~= '/' do
        for _, marker in ipairs(root_markers) do
            local marker_path = path .. '/' .. marker[1]
            local exists = marker[2] == 'directory' 
                and vim.fn.isdirectory(marker_path) == 1
                or vim.fn.filereadable(marker_path) == 1
            
            if exists and not root_found then
                root_found = path
            end
        end
        
        local cmake_path = path .. '/CMakeLists.txt'
        if vim.fn.filereadable(cmake_path) == 1 then
            cmake_found = path
        end
        
        if root_found and cmake_found then
            return root_found
        end
        
        path = vim.fn.fnamemodify(path, ':h')
    end
    
    return cmake_found or vim.fn.getcwd()
end

function _G.get_build_dir()
    return find_project_root() .. '/build'
end

function _G.ensure_build_dir()
    local build_dir = get_build_dir()
    if vim.fn.isdirectory(build_dir) == 0 then
        vim.fn.mkdir(build_dir, 'p')
        vim.notify("Created build/ directory at: " .. build_dir, vim.log.levels.INFO)
    end
    return build_dir
end

function _G.cd_to_project_root()
    local project_root = find_project_root()
    local current_dir = vim.fn.getcwd()
    
    if project_root ~= current_dir then
        vim.cmd('cd ' .. vim.fn.fnameescape(project_root))
        vim.notify("Changed to project root: " .. project_root, vim.log.levels.INFO)
    end
    
    return project_root
end

-- }}}



-- ============================================================================
-- AI CODING COMPANION CONFIGURATION {{{
-- ============================================================================

-- Default AI provider setting
_G.ai_companion = {
    enabled = true,
    provider = "claude",  -- Options: "claude", "openai", "copilot", "gemini", "ollama"
    auto_suggestions = true,
    dual_boost = false,
    use_avante = true,  -- Set to false to skip avante.nvim entirely
    api_keys = {
        anthropic = "",
        openai = "",
        gemini = "",
    },
    ollama = {
        enabled = false,
        endpoint = "http://127.0.0.1:11434",
        model = "codellama",  -- Default model
    },
    copilot = {
        enabled = false,
        authenticated = false,
    },
}

-- Load AI companion settings from file if exists
function _G.load_ai_companion_settings()
    local config_path = vim.fn.stdpath('data') .. '/ai_companion_settings.json'
    if vim.fn.filereadable(config_path) == 1 then
        local file = io.open(config_path, 'r')
        if file then
            local content = file:read('*all')
            file:close()
            local ok, settings = pcall(vim.json.decode, content)
            if ok and settings then
                _G.ai_companion = vim.tbl_deep_extend('force', _G.ai_companion, settings)
            end
        end
    end
end

-- Save AI companion settings to file
function _G.save_ai_companion_settings()
    local config_path = vim.fn.stdpath('data') .. '/ai_companion_settings.json'
    local file = io.open(config_path, 'w')
    if file then
        file:write(vim.json.encode(_G.ai_companion))
        file:close()
    end
end

-- Apply API keys to environment variables
function _G.apply_api_keys()
    if _G.ai_companion.api_keys.anthropic ~= "" then
        vim.env.ANTHROPIC_API_KEY = _G.ai_companion.api_keys.anthropic
    end
    if _G.ai_companion.api_keys.openai ~= "" then
        vim.env.OPENAI_API_KEY = _G.ai_companion.api_keys.openai
    end
    if _G.ai_companion.api_keys.gemini ~= "" then
        vim.env.GEMINI_API_KEY = _G.ai_companion.api_keys.gemini
    end
end

-- Function to set API key for a provider
function _G.set_api_key(provider)
    local key_map = {
        claude = "anthropic",
        openai = "openai",
        gemini = "gemini",
    }
    
    local key_name = key_map[provider]
    if not key_name then
        vim.notify("Copilot uses GitHub CLI authentication (gh auth login)", vim.log.levels.INFO)
        return
    end
    
    local current_key = _G.ai_companion.api_keys[key_name]
    local display_key = current_key ~= "" and (current_key:sub(1, 10) .. "..." .. current_key:sub(-4)) or "not set"
    
    vim.ui.input({
        prompt = provider:upper() .. " API Key (current: " .. display_key .. ", empty to clear): ",
        default = "",
    }, function(input)
        if input ~= nil then  -- User didn't cancel
            _G.ai_companion.api_keys[key_name] = input  -- Empty string clears it
            save_ai_companion_settings()
            apply_api_keys()
            if input == "" then
                vim.notify("API key cleared for " .. provider, vim.log.levels.INFO)
            else
                vim.notify("API key saved for " .. provider, vim.log.levels.INFO)
            end
        end
    end)
end

-- Function to clear API key for a provider
function _G.clear_api_key(provider)
    local key_map = {
        claude = "anthropic",
        openai = "openai",
        gemini = "gemini",
    }
    
    local key_name = key_map[provider]
    if not key_name then
        return
    end
    
    _G.ai_companion.api_keys[key_name] = ""
    save_ai_companion_settings()
    apply_api_keys()
    vim.notify("API key cleared for " .. provider, vim.log.levels.INFO)
end

-- Function to configure Ollama endpoint
function _G.configure_ollama_endpoint()
    local current = _G.ai_companion.ollama.endpoint
    vim.ui.input({
        prompt = "Ollama endpoint (current: " .. current .. "): ",
        default = current,
    }, function(input)
        if input and input ~= "" then
            _G.ai_companion.ollama.endpoint = input
            save_ai_companion_settings()
            vim.notify("Ollama endpoint set to: " .. input, vim.log.levels.INFO)
        end
    end)
end

-- Function to set Ollama model
function _G.set_ollama_model()
    local current = _G.ai_companion.ollama.model
    local common_models = {
        "codellama",
        "llama2",
        "mistral",
        "deepseek-coder",
        "phi",
        "qwen",
        "custom"
    }
    
    vim.ui.select(common_models, {
        prompt = "Select Ollama model (current: " .. current .. "): ",
    }, function(choice)
        if choice then
            if choice == "custom" then
                vim.ui.input({
                    prompt = "Enter custom model name: ",
                    default = current,
                }, function(input)
                    if input and input ~= "" then
                        _G.ai_companion.ollama.model = input
                        save_ai_companion_settings()
                        vim.notify("Ollama model set to: " .. input, vim.log.levels.INFO)
                    end
                end)
            else
                _G.ai_companion.ollama.model = choice
                save_ai_companion_settings()
                vim.notify("Ollama model set to: " .. choice, vim.log.levels.INFO)
            end
        end
    end)
end

-- Function to toggle Ollama
function _G.toggle_ollama()
    _G.ai_companion.ollama.enabled = not _G.ai_companion.ollama.enabled
    save_ai_companion_settings()
    
    if _G.ai_companion.ollama.enabled then
        vim.notify("Ollama enabled", vim.log.levels.INFO)
    else
        vim.notify("Ollama disabled", vim.log.levels.WARN)
    end
end

-- Function to test Ollama connection
function _G.test_ollama_connection()
    local endpoint = _G.ai_companion.ollama.endpoint
    vim.notify("Testing connection to " .. endpoint .. "...", vim.log.levels.INFO)
    
    local cmd = string.format('curl -s -o /dev/null -w "%%{http_code}" %s/api/tags', endpoint)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result:match("200") then
        vim.notify("✓ Ollama is running and accessible!", vim.log.levels.INFO)
    else
        vim.notify("✗ Cannot connect to Ollama. Is it running?", vim.log.levels.ERROR)
        vim.notify("Start with: ollama serve", vim.log.levels.INFO)
    end
end

-- Function to setup Copilot authentication
function _G.setup_copilot()
    vim.notify("Setting up GitHub Copilot...", vim.log.levels.INFO)
    vim.notify("Run: gh auth login", vim.log.levels.INFO)
    vim.cmd("Copilot setup")
end

-- Function to check Copilot status
function _G.check_copilot_status()
    local has_copilot, copilot = pcall(require, 'copilot')
    if has_copilot then
        vim.notify("Copilot plugin loaded", vim.log.levels.INFO)
        vim.cmd("Copilot status")
    else
        vim.notify("Copilot plugin not found", vim.log.levels.WARN)
    end
end

-- Load settings on startup and apply API keys
load_ai_companion_settings()
apply_api_keys()

-- }}



-- ============================================================================
-- UNIFIED KEYMAP SYSTEM {{{
-- ============================================================================

_G.whichkey_specs = {}
_G.temp_keymap_specs = {}

function _G.map(mode, key, action, description, opts)
    opts = opts or {}
    local group = opts.group
    opts.group = nil
    
    local keymap_opts = vim.tbl_extend('force', {desc = description}, opts)
    vim.keymap.set(mode, key, action, keymap_opts)
    
    if type(mode) == 'table' then
        for _, m in ipairs(mode) do
            table.insert(_G.whichkey_specs, {key, desc = description, mode = m, group = group})
        end
    else
        table.insert(_G.whichkey_specs, {key, desc = description, mode = mode, group = group})
    end
end

function _G.temp_map(mode, key, action, description, opts)
    opts = opts or {}
    local group = opts.group
    opts.group = nil
    
    -- Force buffer-local for temporary keymaps
    local keymap_opts = vim.tbl_extend('force', {desc = description, buffer = true, silent = true}, opts)
    vim.keymap.set(mode, key, action, keymap_opts)
    
    local spec = {key, desc = description, mode = mode, group = group}
    
    if type(mode) == 'table' then
        for _, m in ipairs(mode) do
            local mode_spec = {key, desc = description, mode = m, group = group}
            table.insert(_G.temp_keymap_specs, mode_spec)
        end
    else
        table.insert(_G.temp_keymap_specs, spec)
    end
    
    require('which-key').add({spec})
end

function _G.temp_unmap(mode, key)
    if type(mode) == 'table' then
        for _, m in ipairs(mode) do
            pcall(vim.keymap.del, m, key, {buffer = true})
        end
    else
        pcall(vim.keymap.del, mode, key, {buffer = true})
    end
end

function _G.clear_all_temp_maps()
    for _, spec in ipairs(_G.temp_keymap_specs) do
        local mode = spec.mode or 'n'
        local key = spec[1]
        temp_unmap(mode, key)
    end
    _G.temp_keymap_specs = {}
end

function _G.map_group(key, group_name, mode)
    mode = mode or 'n'
    table.insert(_G.whichkey_specs, {key, group = group_name, mode = mode})
end

function _G.register_whichkey()
    require('which-key').setup({preset = "modern", delay = 300})
    require('which-key').add(_G.whichkey_specs)
end

-- }}}

-- ============================================================================
-- GENERAL SETTINGS {{{
-- ============================================================================

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.wrap = false
vim.o.winborder = "rounded"
vim.o.laststatus = 3

vim.o.foldcolumn = '1'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.cindent = true

vim.o.incsearch = true
vim.o.hlsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.swapfile = false
vim.o.undofile = true

vim.o.scrolloff = 8
vim.o.sidescrolloff = 8

vim.o.splitright = true
vim.o.splitbelow = true

vim.opt.diffopt:append('vertical')
vim.opt.diffopt:append('algorithm:histogram')

vim.o.mouse = 'a'
vim.o.clipboard = 'unnamedplus'

vim.cmd("set completeopt+=noselect")

-- Bufferline visibility state
local bufferline_state = vim.fn.stdpath('data') .. '/bufferline_visible'
if vim.fn.filereadable(bufferline_state) == 1 then
    _G.bufferline_visible = vim.fn.readfile(bufferline_state)[1] == '1'
else
    _G.bufferline_visible = true  -- Default: visible
end


-- Satellite scrollbar state
local satellite_state = vim.fn.stdpath('data') .. '/satellite_enabled'
if vim.fn.filereadable(satellite_state) == 1 then
    _G.satellite_enabled = vim.fn.readfile(satellite_state)[1] == '1'
else
    _G.satellite_enabled = true  -- Default: enabled
end

-- Neoscroll state
local neoscroll_state = vim.fn.stdpath('data') .. '/neoscroll_enabled'
if vim.fn.filereadable(neoscroll_state) == 1 then
    _G.neoscroll_enabled = vim.fn.readfile(neoscroll_state)[1] == '1'
else
    _G.neoscroll_enabled = true  -- Default: enabled
end

local neoscroll_duration_file = vim.fn.stdpath('data') .. '/neoscroll_duration'
if vim.fn.filereadable(neoscroll_duration_file) == 1 then
    _G.neoscroll_duration = tonumber(vim.fn.readfile(neoscroll_duration_file)[1]) or 300
else
    _G.neoscroll_duration = 300  -- Default: 300ms
end


-- }}}

-- ============================================================================
-- PLUGINS {{{
-- ============================================================================

vim.pack.add({
    { src = 'https://github.com/vague2k/vague.nvim' },
    { src = 'https://github.com/folke/tokyonight.nvim' },
    { src = 'https://github.com/askfiy/visual_studio_code' },
    { src = 'https://github.com/navarasu/onedark.nvim' },
    { src = 'https://github.com/projekt0n/github-nvim-theme' },
    { src = 'https://github.com/stevearc/oil.nvim' },
    -- { src = 'https://github.com/echasnovski/mini.pick' },
    { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim' },
    { src = 'https://github.com/mikavilpas/yazi.nvim' },
    { src = 'https://github.com/rmagatti/auto-session' },
    { src = 'https://github.com/echasnovski/mini.statusline' },
    { src = 'https://github.com/lewis6991/gitsigns.nvim' },
    { src = 'https://github.com/folke/which-key.nvim' },
    { src = 'https://github.com/nvim-tree/nvim-web-devicons' },
    { src = 'https://github.com/MunifTanjim/nui.nvim' },
    { src = 'https://github.com/kevinhwang91/nvim-ufo' },
    { src = 'https://github.com/kevinhwang91/promise-async' },
    { src = 'https://github.com/numToStr/Comment.nvim' },
    { src = 'https://github.com/windwp/nvim-autopairs' },
    { src = 'https://github.com/mbbill/undotree' },
    { src = 'https://github.com/nvim-treesitter/nvim-treesitter' },
    { src = 'https://github.com/nvim-telescope/telescope.nvim' },
    { src = 'https://github.com/nvim-lua/plenary.nvim' },
    { src = 'https://github.com/ThePrimeagen/harpoon', version = 'harpoon2' },
    { src = 'https://github.com/Civitasv/cmake-tools.nvim' },
    { src = 'https://github.com/mfussenegger/nvim-dap' },
    { src = 'https://github.com/rcarriga/nvim-dap-ui' },
    { src = 'https://github.com/ldelossa/nvim-dap-projects' },
    { src = 'https://github.com/nvim-neotest/nvim-nio' },
    { src = 'https://github.com/chomosuke/typst-preview.nvim' },
    { src = 'https://github.com/akinsho/bufferline.nvim' },
    { src = 'https://github.com/karb94/neoscroll.nvim' },
    { src = 'https://github.com/lewis6991/satellite.nvim' },
    
    -- AI Coding Companion
    { src = 'https://github.com/yetone/avante.nvim' },
    { src = 'https://github.com/stevearc/dressing.nvim' },
    { src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim' },
    
    -- Conditionally load Mason
    _G.mason_enabled and { src = 'https://github.com/williamboman/mason.nvim'} or nil,
    _G.mason_enabled and { src = 'https://github.com/williamboman/mason-lspconfig.nvim'} or nil,
    
})

-- }}}


-- Workaround: Force harpoon to harpoon2 branch (vim.pack version parameter is broken)
do
    local harpoon_path = vim.fn.stdpath('data') .. '/site/pack/core/opt/harpoon'
    if vim.fn.isdirectory(harpoon_path) == 1 then
        local result = vim.fn.system('cd ' .. harpoon_path .. ' && git symbolic-ref -q HEAD')
        -- If in detached HEAD or wrong branch
        if vim.v.shell_error ~= 0 or not result:match('harpoon2') then
            vim.fn.system('cd ' .. harpoon_path .. ' && git checkout harpoon2 2>&1')
            if vim.v.shell_error == 0 then
                print("Harpoon: switched to harpoon2 branch")
            end
        end
    end
end

-- Workaround: Download avante.nvim pre-built binaries if not already installed
do
    -- Check if user wants avante (can be disabled if they don't want to download binaries)
    if _G.ai_companion.use_avante then
        local avante_path = vim.fn.stdpath('data') .. '/site/pack/core/opt/avante.nvim'
        local build_dir = avante_path .. '/build'
        
        -- Check for either .so (Linux) or .dylib (macOS) files in build directory
        local function has_library_files()
            if vim.fn.isdirectory(build_dir) == 0 then
                return false
            end
            
            -- Check for shared library files
            local so_files = vim.fn.glob(build_dir .. '/*.so', false, true)
            local dylib_files = vim.fn.glob(build_dir .. '/*.dylib', false, true)
            
            return #so_files > 0 or #dylib_files > 0
        end
        
        -- Check if avante is installed but not built
        if vim.fn.isdirectory(avante_path) == 1 and not has_library_files() then
            vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.INFO)
            vim.notify("📦 Downloading avante.nvim pre-built binaries...", vim.log.levels.INFO)
            vim.notify("This is a one-time setup (takes ~30 seconds)", vim.log.levels.INFO)
            vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.INFO)
            
            -- Detect system architecture
            local system = vim.loop.os_uname().sysname
            local machine = vim.loop.os_uname().machine
            
            -- Map to GitHub release asset names (v0.0.27+ format)
            local platform_map = {
                ["Linux-x86_64"] = "avante_lib-linux-x86_64-lua51.tar.gz",
                ["Linux-aarch64"] = "avante_lib-linux-aarch64-lua51.tar.gz",
                ["Darwin-x86_64"] = "avante_lib-darwin-x86_64-lua51.tar.gz",
                ["Darwin-arm64"] = "avante_lib-darwin-aarch64-lua51.tar.gz",
            }
            
            local platform_key = system .. "-" .. machine
            local asset_name = platform_map[platform_key]
            
            if not asset_name then
                vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.WARN)
                vim.notify("⚠️  No pre-built binary for: " .. platform_key, vim.log.levels.WARN)
                vim.notify("", vim.log.levels.WARN)
                vim.notify("Supported platforms:", vim.log.levels.INFO)
                vim.notify("  • Linux x86_64", vim.log.levels.INFO)
                vim.notify("  • Linux ARM64", vim.log.levels.INFO)
                vim.notify("  • macOS x86_64 (Intel)", vim.log.levels.INFO)
                vim.notify("  • macOS ARM64 (Apple Silicon)", vim.log.levels.INFO)
                vim.notify("", vim.log.levels.INFO)
                vim.notify("Option 1: Build from source with Rust", vim.log.levels.INFO)
                vim.notify("  See RUST_INSTALL_GUIDE.md", vim.log.levels.INFO)
                vim.notify("", vim.log.levels.INFO)
                vim.notify("Option 2: Disable avante.nvim", vim.log.levels.INFO)
                vim.notify("  <Space>s → AI Companion → Use Avante.nvim [✗]", vim.log.levels.INFO)
                vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.WARN)
            else
                -- Download and extract pre-built binary
                local download_url = "https://github.com/yetone/avante.nvim/releases/download/v0.0.27/" .. asset_name
                local temp_file = vim.fn.tempname() .. ".tar.gz"
                
                -- Create build directory
                vim.fn.mkdir(build_dir, "p")
                
                -- Download binary
                vim.notify("Downloading: " .. asset_name, vim.log.levels.INFO)
                local download_cmd = string.format('curl -L -o "%s" "%s" 2>&1', temp_file, download_url)
                local download_result = vim.fn.system(download_cmd)
                
                if vim.v.shell_error ~= 0 then
                    vim.notify("❌ Download failed. Check your internet connection.", vim.log.levels.ERROR)
                    vim.notify("Details: " .. download_result, vim.log.levels.ERROR)
                    vim.notify("Manual install: See AVANTE_BINARY_INSTALL.md", vim.log.levels.INFO)
                else
                    -- Extract binary
                    vim.notify("Extracting binaries...", vim.log.levels.INFO)
                    local extract_cmd = string.format('tar -xzf "%s" -C "%s" 2>&1', temp_file, build_dir)
                    local extract_result = vim.fn.system(extract_cmd)
                    
                    if vim.v.shell_error ~= 0 then
                        vim.notify("❌ Extraction failed.", vim.log.levels.ERROR)
                        vim.notify("Details: " .. extract_result, vim.log.levels.ERROR)
                    else
                        -- Clean up temp file
                        vim.fn.delete(temp_file)
                        
                        -- Verify installation by checking for library files
                        if has_library_files() then
                            vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.INFO)
                            vim.notify("✅ Avante.nvim installed successfully!", vim.log.levels.INFO)
                            vim.notify("Restart Neovim to activate AI features", vim.log.levels.INFO)
                            vim.notify("", vim.log.levels.INFO)
                            vim.notify("Quick start:", vim.log.levels.INFO)
                            vim.notify("  <Space>at  → Toggle AI panel", vim.log.levels.INFO)
                            vim.notify("  <Space>aa  → Ask AI question", vim.log.levels.INFO)
                            vim.notify("  <Space>ac  → AI chat", vim.log.levels.INFO)
                            vim.notify("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", vim.log.levels.INFO)
                        else
                            vim.notify("❌ Installation verification failed.", vim.log.levels.ERROR)
                            vim.notify("Build directory does not contain expected library files.", vim.log.levels.ERROR)
                            vim.notify("Expected: .so or .dylib files in " .. build_dir, vim.log.levels.ERROR)
                            vim.notify("", vim.log.levels.INFO)
                            vim.notify("Debug: Check what was extracted:", vim.log.levels.INFO)
                            vim.notify("  ls -la " .. build_dir, vim.log.levels.INFO)
                        end
                    end
                end
            end
        end
    end
end


-- ============================================================================
-- CMAKE & BUILD UTILITIES {{{
-- ============================================================================

_G.last_cmake_target = nil

local function find_cmake_executables()
    local build_dir = get_build_dir()
    local executables = {}
    local find_cmd = string.format(
        'find %s -maxdepth 3 -type f -executable ! -name "*.so*" ! -name "*.a" 2>/dev/null',
        vim.fn.shellescape(build_dir)
    )
    local result = vim.fn.system(find_cmd)
    
    for line in result:gmatch('[^\r\n]+') do
        local name = vim.fn.fnamemodify(line, ':t')
        if name ~= '' 
           and not name:match('^lib') 
           and not name:match('^cmake') 
           and not name:match('^CMake')
           and not name:match('^_') 
           and not line:match('CMakeFiles')
        then
            table.insert(executables, {name = name, path = line})
        end
    end
    return executables
end

-- Terminal runners (shared between run and debug)
local terminal_runners = {
    {
        name = "Split Terminal",
        desc = "Run in vertical split terminal",
        func = function(path, is_debug)
            vim.cmd('vsplit')
            -- Set width to 40% of screen
            vim.cmd('vertical resize ' .. math.floor(vim.o.columns * 0.4))
            vim.cmd('enew')
            local cmd = is_debug and ('gdb ' .. vim.fn.shellescape(path)) or path
            vim.fn.termopen(cmd, {
                on_exit = function(job_id, exit_code, event_type)
                    vim.schedule(function()
                        if not is_debug then
                            print(exit_code == 0 and "Program exited successfully." or ("Program exited with code " .. exit_code))
                        else
                            print("Debug session ended.")
                        end
                        print("Press any key to close.")
                        vim.fn.getchar()
                        vim.cmd('close')
                    end)
                end
            })
            vim.cmd('startinsert')
        end
    },
    {
        name = "Fullscreen Tab",
        desc = "Run in fullscreen terminal tab",
        func = function(path, is_debug)
            vim.cmd('tabnew')
            local cmd = is_debug and ('gdb ' .. vim.fn.shellescape(path)) or path
            vim.fn.termopen(cmd, {
                on_exit = function(job_id, exit_code, event_type)
                    vim.schedule(function()
                        if not is_debug then
                            print(exit_code == 0 and "Program exited successfully." or ("Program exited with code " .. exit_code))
                        else
                            print("Debug session ended.")
                        end
                        print("Press any key to close.")
                        vim.fn.getchar()
                        vim.cmd('tabclose')
                    end)
                end
            })
            vim.cmd('startinsert')
        end
    },
    {
        name = "Floating Terminal",
        desc = "Run in floating window",
        func = function(path, is_debug)
            local buf = vim.api.nvim_create_buf(false, true)
            -- Adjust these percentages to change floating window size
            local width = math.floor(vim.o.columns * 0.9)
            local height = math.floor(vim.o.lines * 0.9)
            local row = math.floor((vim.o.lines - height) / 2)
            local col = math.floor((vim.o.columns - width) / 2)
            
            local win = vim.api.nvim_open_win(buf, true, {
                relative = 'editor',
                width = width,
                height = height,
                row = row,
                col = col,
                style = 'minimal',
                border = 'rounded',
            })
            
            local cmd = is_debug and ('gdb ' .. vim.fn.shellescape(path)) or path
            vim.fn.termopen(cmd, {
                on_exit = function(job_id, exit_code, event_type)
                    vim.schedule(function()
                        if not is_debug then
                            print(exit_code == 0 and "Program exited successfully." or ("Program exited with code " .. exit_code))
                        else
                            print("Debug session ended.")
                        end
                        print("Press any key to close.")
                        vim.fn.getchar()
                        if vim.api.nvim_win_is_valid(win) then
                            vim.api.nvim_win_close(win, true)
                        end
                    end)
                end,
            })
            vim.cmd('startinsert')
        end
    },
    {
        name = "External Terminal",
        desc = "Run in external terminal window",
        func = function(path, is_debug)
            local cmd = is_debug and ('gdb ' .. vim.fn.shellescape(path)) or path
            if vim.fn.executable("kitty") == 1 then
                vim.cmd("silent !kitty --hold sh -c '" .. cmd .. "' &")
            elseif vim.fn.executable("alacritty") == 1 then
                vim.cmd("silent !alacritty --hold -e sh -c '" .. cmd .. "' &")
            elseif vim.fn.executable("gnome-terminal") == 1 then
                vim.cmd("silent !gnome-terminal -- sh -c '" .. cmd .. "; read' &")
            elseif vim.fn.executable("konsole") == 1 then
                vim.cmd("silent !konsole --hold -e sh -c '" .. cmd .. "' &")
            elseif vim.fn.executable("xterm") == 1 then
                vim.cmd("silent !xterm -hold -e sh -c '" .. cmd .. "' &")
            else
                vim.notify("No supported external terminal found", vim.log.levels.ERROR)
            end
        end
    },
    {
        name = "Tmux Split",
        desc = "Run in tmux split",
        func = function(path, is_debug)
            if vim.fn.executable("tmux") == 1 and os.getenv("TMUX") then
                local cmd = is_debug and ('gdb ' .. vim.fn.shellescape(path)) or path
                vim.cmd('silent !tmux split-window -v "' .. cmd .. '; read"')
            else
                vim.notify("Not in a tmux session or tmux not installed", vim.log.levels.WARN)
            end
        end
    },
}

-- Generic executable selector
local function select_executable(executables, callback, prompt)
    local wk = require("which-key")
    
    for i = 1, 9 do
        pcall(vim.keymap.del, 'n', '<leader>E' .. tostring(i))
    end
    
    local specs = {{ "<leader>E", group = prompt or "Select Executable" }}
    
    for i, exe in ipairs(executables) do
        table.insert(specs, {
            "<leader>E" .. tostring(i),
            function() callback(exe) end,
            desc = exe.name
        })
    end
    
    wk.add(specs)
    vim.schedule(function()
        wk.show({ keys = "<leader>E", mode = "n" })
    end)
end

-- Generic terminal selector
local function select_terminal(target, is_debug)
    local wk = require("which-key")
    
    for i = 1, 9 do
        pcall(vim.keymap.del, 'n', '<leader>T' .. tostring(i))
    end
    
    local specs = {{ "<leader>T", group = is_debug and "Debug Terminal" or "Terminal Type" }}
    
    for i, runner in ipairs(terminal_runners) do
        table.insert(specs, {
            "<leader>T" .. tostring(i),
            function() runner.func(target.path, is_debug) end,
            desc = runner.desc
        })
    end
    
    wk.add(specs)
    vim.schedule(function()
        wk.show({ keys = "<leader>T", mode = "n" })
    end)
end

-- Build and run
function _G.cmake_run_with_picker()
    cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    local cmake_cache = build_dir .. '/CMakeCache.txt'
    if vim.fn.filereadable(cmake_cache) == 0 then
        vim.notify("Build not configured. Run <leader>bc first.", vim.log.levels.WARN)
        return
    end
    
    local result = vim.fn.system('cmake --build ' .. vim.fn.shellescape(build_dir))
    if vim.v.shell_error ~= 0 then
        vim.notify("Build failed!", vim.log.levels.ERROR)
        return
    end
    
    local executables = find_cmake_executables()
    
    if #executables == 0 then
        vim.notify("No executables found in " .. build_dir, vim.log.levels.WARN)
        return
    end
    
    local function run_target(target)
        _G.last_cmake_target = target
        select_terminal(target, false)
    end
    
    if _G.last_cmake_target then
        for _, exe in ipairs(executables) do
            if exe.path == _G.last_cmake_target.path then
                run_target(exe)
                return
            end
        end
    end
    
    if #executables == 1 then
        run_target(executables[1])
    else
        select_executable(executables, run_target, "Select Executable")
    end
end

-- Debug with GDB
function _G.debug_in_terminal()
    cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    local result = vim.fn.system('cmake --build ' .. vim.fn.shellescape(build_dir))
    if vim.v.shell_error ~= 0 then
        vim.notify("Build failed!", vim.log.levels.ERROR)
        return
    end
    
    local executables = find_cmake_executables()
    
    if #executables == 0 then
        vim.notify("No executables found in " .. build_dir, vim.log.levels.WARN)
        return
    end
    
    local function run_in_terminal(target)
        _G.last_cmake_target = target
        select_terminal(target, true)
        
        vim.notify("GDB commands: run | break main | n (next) | s (step) | c (continue) | p var | bt | q", vim.log.levels.INFO)
    end
    
    if _G.last_cmake_target then
        for _, exe in ipairs(executables) do
            if exe.path == _G.last_cmake_target.path then
                run_in_terminal(exe)
                return
            end
        end
    end
    
    if #executables == 1 then
        run_in_terminal(executables[1])
    else
        select_executable(executables, run_in_terminal, "Select Executable to Debug")
    end
end

-- }}}

-- ============================================================================
-- DAP UTILITIES {{{
-- ============================================================================

local function create_io_terminal(runner)
    local tty_file = vim.fn.tempname()
    local tty_cmd = 'tty > ' .. vim.fn.shellescape(tty_file) .. ' && echo "=== Program Output ===" && cat'
    
    if runner.name == "Split Terminal" then
        vim.cmd('vsplit')
        -- Make it take full height and set width
        vim.cmd('wincmd L')  -- Move to far right
        vim.cmd('vertical resize ' .. math.floor(vim.o.columns * 0.4))
        vim.cmd('enew')
        vim.fn.termopen(tty_cmd, {on_exit = function() vim.fn.delete(tty_file) end})
    elseif runner.name == "Fullscreen Tab" then
        vim.cmd('tabnew')
        vim.fn.termopen(tty_cmd, {on_exit = function() vim.fn.delete(tty_file) end})
    elseif runner.name == "Floating Terminal" then
        local buf = vim.api.nvim_create_buf(false, true)
        local width = math.floor(vim.o.columns * 0.9)
        local height = math.floor(vim.o.lines * 0.9)
        
        vim.api.nvim_open_win(buf, false, {
            relative = 'editor',
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = 'minimal',
            border = 'rounded',
        })
        
        vim.fn.termopen(tty_cmd, {on_exit = function() vim.fn.delete(tty_file) end})
    elseif runner.name == "External Terminal" then
        if vim.fn.executable("kitty") == 1 then
            vim.cmd("silent !kitty sh -c 'tty > " .. tty_file .. " && echo \"=== Program Output ===\" && cat' &")
        elseif vim.fn.executable("alacritty") == 1 then
            vim.cmd("silent !alacritty -e sh -c 'tty > " .. tty_file .. " && echo \"=== Program Output ===\" && cat' &")
        elseif vim.fn.executable("gnome-terminal") == 1 then
            vim.cmd("silent !gnome-terminal -- sh -c 'tty > " .. tty_file .. " && echo \"=== Program Output ===\" && cat' &")
        else
            vim.notify("No supported external terminal found", vim.log.levels.ERROR)
            return nil
        end
    elseif runner.name == "Tmux Split" then
        if vim.fn.executable("tmux") == 1 and os.getenv("TMUX") then
            vim.cmd('silent !tmux split-window -v "tty > ' .. tty_file .. ' && echo \\"=== Program Output ===" && cat"')
        else
            vim.notify("Not in tmux session", vim.log.levels.WARN)
            return nil
        end
    end
    
    vim.wait(2000, function() return vim.fn.filereadable(tty_file) == 1 end, 100)
    
    if vim.fn.filereadable(tty_file) == 1 then
        local tty = vim.fn.readfile(tty_file)[1]
        if tty and tty ~= '' then
            return tty
        end
    end
    
    return nil
end

function _G.debug_with_io_terminal()
    cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    local result = vim.fn.system('cmake --build ' .. vim.fn.shellescape(build_dir))
    if vim.v.shell_error ~= 0 then
        vim.notify("Build failed!", vim.log.levels.ERROR)
        return
    end
    
    local executables = find_cmake_executables()
    
    if #executables == 0 then
        vim.notify("No executables found in " .. build_dir, vim.log.levels.WARN)
        return
    end
    
    local function start_debug(target, runner)
        _G.last_cmake_target = target
        local tty = create_io_terminal(runner)

        if tty then
            _G.debug_terminal_tty = tty
            vim.notify("Terminal ready. Starting debugger...", vim.log.levels.INFO)
            vim.cmd('wincmd p')
            vim.defer_fn(function() require('dap').continue() end, 100)
        else
            vim.notify("Failed to create terminal", vim.log.levels.ERROR)
        end
    end

    local function select_term(target)
        local wk = require("which-key")
        
        for i = 1, 9 do
            pcall(vim.keymap.del, 'n', '<leader>T' .. tostring(i))
        end
        
        local specs = {{ "<leader>T", group = "I/O Terminal" }}
        
        for i, runner in ipairs(terminal_runners) do
            table.insert(specs, {
                "<leader>T" .. tostring(i),
                function() start_debug(target, runner) end,
                desc = runner.desc
            })
        end
        
        wk.add(specs)
        vim.schedule(function() wk.show({ keys = "<leader>T", mode = "n" }) end)
    end
    
    if _G.last_cmake_target then
        for _, exe in ipairs(executables) do
            if exe.path == _G.last_cmake_target.path then
                select_term(exe)
                return
            end
        end
    end
    
    if #executables == 1 then
        select_term(executables[1])
    else
        select_executable(executables, select_term, "Select Executable to Debug")
    end
end

-- }}}


-- ============================================================================
-- AUTOCOMMANDS {{{
-- ============================================================================

-- Neovin Focus {{{
vim.api.nvim_create_autocmd('FocusGained', {
    callback = function()
        -- If DAP session is active and we're not in a code buffer, switch to one
        if require('dap').session() then
            local current_buf = vim.api.nvim_get_current_buf()
            if vim.bo[current_buf].buftype ~= '' then
                -- We're in a special buffer, find a code buffer
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].buftype == '' then
                        vim.api.nvim_set_current_win(win)
                        break
                    end
                end
            end
        end
    end,
})
-- }}}

-- Terminal {{{
vim.api.nvim_create_autocmd({'BufEnter', 'WinEnter'}, {
    pattern = '*',
    callback = function()
        if vim.bo.buftype == 'terminal' then
            -- Auto-enter insert mode when focusing terminal
            vim.defer_fn(function()
                if vim.api.nvim_get_mode().mode ~= 't' then
                    vim.cmd('startinsert')
                end
            end, 10)
        end
    end,
})

vim.api.nvim_create_autocmd({'BufLeave', 'WinLeave'}, {
    pattern = '*',
    callback = function()
        if vim.bo.buftype == 'terminal' then
            -- Exit insert mode when leaving terminal
            vim.cmd('stopinsert')
        end
    end,
})

vim.api.nvim_create_autocmd('TermOpen', {
    callback = function()
        -- Click to focus and enter insert mode
        vim.keymap.set('n', '<LeftMouse>', '<LeftMouse>i', { buffer = true })
        
        -- Disable line numbers in terminal
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end,
})
-- }}}


-- Project root {{{
vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
        local root = find_project_root()
        local cwd = vim.fn.getcwd()
        
        if root ~= cwd then
            vim.cmd('cd ' .. vim.fn.fnameescape(root))
            vim.notify("Changed to: " .. root, vim.log.levels.INFO)
        end
    end,
})
-- }}}

-- Highlight yank {{{
vim.api.nvim_create_autocmd('TextYankPost', {
    callback = function()
        vim.highlight.on_yank({higroup = 'IncSearch', timeout = 200})
    end,
})
-- }}}

-- Dim inactive {{{
vim.api.nvim_create_autocmd('WinEnter', {
    callback = function() vim.wo.winhl = '' end,
})

vim.api.nvim_create_autocmd('WinLeave', {
    callback = function() vim.wo.winhl = 'Normal:NormalNC' end,
})

vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function()
        local bg = vim.api.nvim_get_hl(0, {name = 'Normal'}).bg or 0
        vim.api.nvim_set_hl(0, 'NormalNC', { bg = bg - 0x0a0a0a })
        
        vim.api.nvim_set_hl(0, 'DapStoppedLine', { reverse = true })
        vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#ff0000' })
        vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = '#61afef' })
        vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#ff0000' })
    end,
})
-- }}}

-- Auto-format {{{
local clang_fmt_warned = false

vim.api.nvim_create_autocmd('BufWritePre', {
    pattern = {'*.cpp', '*.c', '*.h', '*.hpp'},
    callback = function()
        if not _G.autoformat_enabled then return end
        
        local fmt = find_project_root() .. '/.clang-format'
        
        if vim.fn.filereadable(fmt) == 1 then
            vim.lsp.buf.format()
        elseif not clang_fmt_warned then
            vim.notify("No .clang-format found", vim.log.levels.WARN)
            clang_fmt_warned = true
        end
    end,
})
-- }}}

-- C++ settings {{{
vim.api.nvim_create_autocmd('FileType', {
    pattern = {'cpp', 'c'},
    callback = function()
        vim.opt_local.cindent = true
        vim.opt_local.cinoptions = 'g0,:0,N-s,(0'
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
        vim.opt_local.expandtab = true
        vim.opt_local.spell = true
        vim.opt_local.spelllang = 'en_us'
    end,
})
-- }}}

-- LSP attach {{{
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client:supports_method('textDocument/completion') then
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
        end
        print("LSP: " .. client.name)
    end,
})
-- }}}

-- }}}



-- ============================================================================
-- LSP CONFIGURATION {{{
-- ============================================================================

-- ============================================================================
-- LSP CONFIGURATION {{{
-- ============================================================================

-- Build LSP servers list from language config
local lsp_servers = {}
for _, lang in ipairs(_G.supported_languages) do
    if lang.lsp then
        table.insert(lsp_servers, {
            name = lang.lsp.name,
            cmd = lang.lsp.cmd,
            ft = lang.lsp.filetypes,
        })
    end
end

-- Load LSP enabled state
local state_file = vim.fn.stdpath('data') .. '/lsp_enabled.json'
local enabled_lsps = {}

if vim.fn.filereadable(state_file) == 1 then
    local ok, data = pcall(vim.fn.json_decode, vim.fn.readfile(state_file)[1])
    if ok then
        enabled_lsps = data
    end
end

-- Enable LSPs that are toggled on (default all on if no state file)
local lsps_to_enable = {}
for _, srv in ipairs(lsp_servers) do
    if enabled_lsps[srv.name] == nil or enabled_lsps[srv.name] == true then
        table.insert(lsps_to_enable, srv.name)
    end
end

if #lsps_to_enable > 0 then
    vim.lsp.enable(lsps_to_enable)
end

-- Only configure LSPs that are enabled
for _, srv in ipairs(lsp_servers) do
    if enabled_lsps[srv.name] == nil or enabled_lsps[srv.name] == true then
        vim.api.nvim_create_autocmd('FileType', {
            pattern = srv.ft,
            callback = function()
                vim.lsp.start({name = srv.name, cmd = srv.cmd})
            end,
        })
    end
end

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

local signs = { Error = "✘", Warn = "▲", Hint = "⚑", Info = "»" }
for type, icon in pairs(signs) do
    vim.fn.sign_define("DiagnosticSign" .. type, { text = icon, texthl = "DiagnosticSign" .. type, numhl = "DiagnosticSign" .. type })
end

-- }}}


-- ============================================================================
-- COLORSCHEME {{{
-- ============================================================================

local cs_file = vim.fn.stdpath('data') .. '/current_colorscheme.txt'

local function load_cs()
    local f = io.open(cs_file, 'r')
    if f then
        local s = f:read('*all')
        f:close()
        return s:gsub('%s+', '')
    end
    return 'visual_studio_code'
end

local saved = load_cs()
local ok = pcall(function() vim.cmd('colorscheme ' .. saved) end)

if not ok then
    vim.cmd('colorscheme visual_studio_code')
    local f = io.open(cs_file, 'w')
    if f then f:write('visual_studio_code'); f:close() end
end

vim.cmd("hi statusline guibg=NONE")

-- }}}


-- ============================================================================
-- AI CODING COMPANION - AVANTE.NVIM {{{
-- ============================================================================

-- Only setup avante if enabled and Rust is available
if _G.ai_companion.use_avante then
    -- Defer avante setup to avoid startup prompts
    vim.defer_fn(function()
    pcall(function()
        require('render-markdown').setup({
            file_types = { "markdown", "Avante" },
        })
        
        require('avante').setup({
            provider = _G.ai_companion.provider,
            auto_suggestions_provider = _G.ai_companion.provider,
            providers = {
            claude = {
                endpoint = "https://api.anthropic.com",
                model = "claude-sonnet-4-5-20250929",
                extra_request_body = {
                    temperature = 0,
                    max_tokens = 8000,
                },
            },
            openai = {
                endpoint = "https://api.openai.com/v1",
                model = "gpt-4o",
                extra_request_body = {
                    temperature = 0,
                    max_tokens = 4096,
                },
            },
            copilot = {
                endpoint = "https://api.githubcopilot.com",
                model = "gpt-4",
                extra_request_body = {
                    temperature = 0,
                    max_tokens = 4096,
                },
            },
            gemini = {
                endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
                model = "gemini-2.0-flash-exp",
                extra_request_body = {
                    temperature = 0,
                    max_tokens = 8000,
                },
            },
            ollama = {
                endpoint = _G.ai_companion.ollama.endpoint .. "/v1",
                model = _G.ai_companion.ollama.model,
                parse_curl_args = function(opts, code_opts)
                    return {
                        url = opts.endpoint .. "/chat/completions",
                        headers = {
                            ["Content-Type"] = "application/json",
                        },
                        body = {
                            model = opts.model,
                            messages = opts.messages,
                            max_tokens = 4096,
                            stream = true,
                        },
                    }
                end,
            },
        },
        dual_boost = {
            enabled = _G.ai_companion.dual_boost,
            first_provider = "openai",
            second_provider = "claude",
            prompt = "Based on the two reference outputs below, generate a response that incorporates elements from both but reflects your own judgment and unique perspective.",
            timeout = 60000,
        },
        behaviour = {
            auto_suggestions = _G.ai_companion.auto_suggestions,
            auto_set_highlight_group = true,
            auto_set_keymaps = true,
            auto_apply_diff_after_generation = false,
            support_paste_from_clipboard = true,
            suppress_missing_provider_warnings = true,
        },
        mappings = {
            diff = {
                ours = "co",
                theirs = "ct",
                all_theirs = "ca",
                both = "cb",
                cursor = "cc",
                next = "]x",
                prev = "[x",
            },
            suggestion = {
                accept = "<M-l>",
                next = "<M-]>",
                prev = "<M-[>",
                dismiss = "<C-]>",
            },
            jump = {
                next = "]]",
                prev = "[[",
            },
            submit = {
                normal = "<CR>",
                insert = "<C-s>",
            },
            sidebar = {
                apply_all = "A",
                apply_cursor = "a",
                switch_windows = "<Tab>",
                reverse_switch_windows = "<S-Tab>",
            },
        },
        hints = { enabled = true },
        windows = {
            position = "right",
            wrap = true,
            width = 30,
            sidebar_header = {
                align = "center",
                rounded = true,
            },
        },
        highlights = {
            diff = {
                current = "DiffText",
                incoming = "DiffAdd",
            },
        },
        diff = {
            autojump = true,
            list_opener = "copen",
        },
    })
    
    -- Setup completion sources for avante
    local cmp = require('cmp')
    cmp.setup.filetype('AvanteInput', {
        sources = cmp.config.sources({
            { name = 'avante_commands' },
            { name = 'avante_mentions' },
            { name = 'avante_files' },
        }, {
            { name = 'buffer' },
        }),
    })
end)
end, 100)  -- Defer by 100ms to avoid startup prompts
else
    vim.notify("Avante.nvim disabled. Set use_avante=true in settings or install Rust to enable.", vim.log.levels.INFO)
end

-- Function to toggle AI companion
function _G.toggle_ai_companion()
    _G.ai_companion.enabled = not _G.ai_companion.enabled
    save_ai_companion_settings()
    
    if _G.ai_companion.enabled then
        vim.notify("AI Companion enabled", vim.log.levels.INFO)
    else
        vim.notify("AI Companion disabled", vim.log.levels.WARN)
        vim.cmd("AvanteToggle")
    end
end

-- Function to switch AI provider
function _G.switch_ai_provider(provider)
    local valid_providers = {"claude", "openai", "copilot", "gemini", "ollama"}
    if not vim.tbl_contains(valid_providers, provider) then
        vim.notify("Invalid provider: " .. provider, vim.log.levels.ERROR)
        return
    end
    
    _G.ai_companion.provider = provider
    save_ai_companion_settings()
    
    -- Update avante configuration
    pcall(function()
        require('avante.config').override({
            provider = provider,
            auto_suggestions_provider = provider,
        })
    end)
    
    vim.notify("AI provider switched to: " .. provider:upper(), vim.log.levels.INFO)
end

-- Function to toggle auto suggestions
function _G.toggle_auto_suggestions()
    _G.ai_companion.auto_suggestions = not _G.ai_companion.auto_suggestions
    save_ai_companion_settings()
    
    pcall(function()
        require('avante.config').override({
            behaviour = {
                auto_suggestions = _G.ai_companion.auto_suggestions,
            },
        })
    end)
    
    if _G.ai_companion.auto_suggestions then
        vim.notify("Auto suggestions enabled", vim.log.levels.INFO)
    else
        vim.notify("Auto suggestions disabled", vim.log.levels.WARN)
    end
end

-- Function to toggle dual boost
function _G.toggle_dual_boost()
    _G.ai_companion.dual_boost = not _G.ai_companion.dual_boost
    save_ai_companion_settings()
    
    pcall(function()
        require('avante.config').override({
            dual_boost = {
                enabled = _G.ai_companion.dual_boost,
            },
        })
    end)
    
    if _G.ai_companion.dual_boost then
        vim.notify("Dual boost enabled (uses 2 providers)", vim.log.levels.INFO)
    else
        vim.notify("Dual boost disabled", vim.log.levels.WARN)
    end
end

-- }}}


-- ============================================================================
-- NEO-TREE AND AVANTE INTEGRATION {{{
-- ============================================================================

-- Configure Neo-tree with Avante file selection support
pcall(function()
    require('neo-tree').setup({
        close_if_last_window = false,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        filesystem = {
            commands = {
                -- Add files to Avante context from Neo-tree
                avante_add_files = function(state)
                    local node = state.tree:get_node()
                    local filepath = node:get_id()
                    
                    -- Get relative path
                    local relative_path = vim.fn.fnamemodify(filepath, ':.')
                    
                    -- Try to use avante's utility if available
                    pcall(function()
                        relative_path = require('avante.utils').relative_path(filepath)
                    end)
                    
                    -- Get or create avante sidebar
                    local has_avante, avante = pcall(require, 'avante')
                    if not has_avante then
                        vim.notify("Avante not available. Enable use_avante in settings.", vim.log.levels.WARN)
                        return
                    end
                    
                    local sidebar = avante.get()
                    local was_open = sidebar and sidebar:is_open()
                    
                    -- Open avante if not already open
                    if not was_open then
                        local api_ok, api = pcall(require, 'avante.api')
                        if api_ok then
                            api.ask()
                            sidebar = avante.get()
                        else
                            vim.notify("Could not open Avante sidebar", vim.log.levels.ERROR)
                            return
                        end
                    end
                    
                    -- Add file to selector
                    if sidebar and sidebar.file_selector then
                        sidebar.file_selector:add_selected_file(relative_path)
                        vim.notify("Added to Avante: " .. relative_path, vim.log.levels.INFO)
                        
                        -- Clean up neo-tree buffer from selector if we just opened avante
                        if not was_open then
                            pcall(function()
                                sidebar.file_selector:remove_selected_file('neo-tree filesystem [1]')
                            end)
                        end
                    end
                end,
            },
            window = {
                position = "left",
                width = 30,
                mappings = {
                    ['oa'] = 'avante_add_files',  -- Press 'oa' in Neo-tree to add file to Avante
                    ['<space>'] = 'toggle_node',
                    ['<cr>'] = 'open',
                    ['<esc>'] = 'cancel',
                    ['P'] = { 'toggle_preview', config = { use_float = true } },
                    ['l'] = 'focus_preview',
                    ['S'] = 'open_split',
                    ['s'] = 'open_vsplit',
                    ['t'] = 'open_tabnew',
                    ['C'] = 'close_node',
                    ['z'] = 'close_all_nodes',
                    ['a'] = {
                        'add',
                        config = {
                            show_path = 'none',
                        },
                    },
                    ['A'] = 'add_directory',
                    ['d'] = 'delete',
                    ['r'] = 'rename',
                    ['y'] = 'copy_to_clipboard',
                    ['x'] = 'cut_to_clipboard',
                    ['p'] = 'paste_from_clipboard',
                    ['c'] = 'copy',
                    ['m'] = 'move',
                    ['q'] = 'close_window',
                    ['R'] = 'refresh',
                    ['?'] = 'show_help',
                    ['<'] = 'prev_source',
                    ['>'] = 'next_source',
                    ['i'] = 'show_file_details',
                },
            },
            filtered_items = {
                visible = false,
                hide_dotfiles = false,
                hide_gitignored = false,
            },
            follow_current_file = {
                enabled = true,
            },
            use_libuv_file_watcher = true,
        },
        buffers = {
            follow_current_file = {
                enabled = true,
            },
        },
        git_status = {
            window = {
                position = "float",
            },
        },
    })
end)

-- }}}


-- ============================================================================
-- SETTINGS WINDOW {{{
-- ============================================================================

function _G.show_settings_window()
    -- Create buffer and window
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].modifiable = false

    -- State
    local state = {
        view = "main",
        selection = 1,
        original_cs = vim.g.colors_name or 'visual_studio_code',
        saved_cs = vim.g.colors_name or 'visual_studio_code',
        lsp_configs = {},
        enabled_lsps = {},
        lsp_state_file = vim.fn.stdpath('data') .. '/lsp_enabled.json',
    }

    -- Load LSP configs and state
    for _, lang in ipairs(_G.supported_languages) do
        if lang.lsp then
            table.insert(state.lsp_configs, {
                name = lang.lsp.name,
                ft = lang.lsp.filetypes,
                cmd = lang.lsp.cmd,
            })
        end
    end

    if vim.fn.filereadable(state.lsp_state_file) == 1 then
        local ok, data = pcall(vim.fn.json_decode, vim.fn.readfile(state.lsp_state_file)[1])
        if ok then state.enabled_lsps = data end
    else
        for _, lsp in ipairs(state.lsp_configs) do
            state.enabled_lsps[lsp.name] = true
        end
    end
    
    -- Create window
    local width, height = 70, 15
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' ⚙  Settings ',
        title_pos = 'center',
    })
    
    -- Hide cursor in settings window
    local original_guicursor = vim.o.guicursor

    local function update_settings_cursor()
        local cursorline_bg = vim.api.nvim_get_hl(0, {name = 'CursorLine'}).bg
        if cursorline_bg then
            local bg_hex = string.format("#%06x", cursorline_bg)
            vim.api.nvim_set_hl(0, 'SettingsCursor', { 
                fg = bg_hex,
                bg = bg_hex,
                blend = 100,  -- Add blend as well
            })
        end
    end

    update_settings_cursor()
    -- Use hor1 (1-pixel horizontal) with the color-matched highlight
    vim.opt.guicursor = 'n-v-c-sm:hor1-SettingsCursor,i-ci-ve:hor1-SettingsCursor,r-cr-o:hor1-SettingsCursor'

    vim.api.nvim_create_autocmd({'WinEnter', 'BufEnter'}, {
        buffer = buf,
        callback = function()
            update_settings_cursor()
            vim.opt.guicursor = 'n-v-c-sm:hor1-SettingsCursor,i-ci-ve:hor1-SettingsCursor,r-cr-o:hor1-SettingsCursor'
        end
    })

    vim.api.nvim_create_autocmd({'WinLeave', 'BufLeave'}, {
        buffer = buf,
        callback = function()
            vim.opt.guicursor = original_guicursor
        end
    })

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline = true
    vim.wo[win].cursorcolumn = false
    vim.wo[win].signcolumn = 'no'

    -- Helper to update cursor color after colorscheme change
    local function update_cursor_hl()
        local bg = vim.api.nvim_get_hl(0, {name = 'CursorLine'}).bg
        if bg then
            local hex = string.format("#%06x", bg)
            vim.api.nvim_set_hl(0, 'SettingsHiddenCursor', { fg = hex, bg = hex })
        end
    end
    
    -- Menu definitions
    local menus = {
        main = {
            {"🎨", "Colorscheme", "Change editor colorscheme", function() state.view, state.selection = "colorscheme", 1; for i, s in ipairs(vim.fn.getcompletion('', 'color')) do if s == state.saved_cs then state.selection = i break end end end},
            {"🔧", "LSP Servers", "Toggle language servers on/off", function() state.view, state.selection = "lsp", 1 end},
            {"🤖", "AI Companion", "Configure AI coding assistant", function() state.view, state.selection = "ai", 1 end},
            {"🖥", "Display Settings", "Line numbers, signs, wrapping, etc.", function() state.view, state.selection = "display", 1 end},
            {"✏ ", "Editor Behavior", "Tabs, scrolling, mouse, clipboard, formatting", function() state.view, state.selection = "editor", 1 end},
            {"🌿", "Git Integration", "Git signs and blame settings", function() state.view, state.selection = "git", 1 end},
            {"🩺", "Diagnostics", "LSP diagnostic display options", function() state.view, state.selection = "diagnostics", 1 end},
        },
        display = {
            {"Line Numbers", function() local m = vim.wo.relativenumber and "relative" or (vim.wo.number and "absolute" or "off"); return m == "off" and "[ ]" or (m == "absolute" and "[#]" or "[~]") end, function() local m = vim.wo.relativenumber and "relative" or (vim.wo.number and "absolute" or "off"); if m == "off" then vim.wo.number, vim.wo.relativenumber = true, false elseif m == "absolute" then vim.wo.number, vim.wo.relativenumber = true, true else vim.wo.number, vim.wo.relativenumber = false, false end end},
            {"Sign Column", function() return vim.wo.signcolumn == "yes" and "[✓]" or (vim.wo.signcolumn == "auto" and "[~]" or "[ ]") end, function() vim.wo.signcolumn = vim.wo.signcolumn == "yes" and "no" or (vim.wo.signcolumn == "no" and "auto" or "yes") end},
            {"Cursor Line", function() return vim.wo.cursorline and "[✓]" or "[ ]" end, function() vim.wo.cursorline = not vim.wo.cursorline end},
            {"Line Wrapping", function() return vim.wo.wrap and "[✓]" or "[ ]" end, function() vim.wo.wrap = not vim.wo.wrap end},
            {"Color Column", function() return vim.wo.colorcolumn == "" and "[ ]" or (vim.wo.colorcolumn == "80" and "[80]" or "[120]") end, function() vim.wo.colorcolumn = vim.wo.colorcolumn == "" and "80" or (vim.wo.colorcolumn == "80" and "120" or "") end},
            {"Bufferline Tabs", function() return _G.bufferline_visible and "[✓]" or "[ ]" end, function() _G.bufferline_visible = not _G.bufferline_visible; local f = io.open(vim.fn.stdpath('data') .. '/bufferline_visible', 'w'); if f then f:write(_G.bufferline_visible and '1' or '0'); f:close() end; vim.o.showtabline = _G.bufferline_visible and 2 or 0; vim.notify("Bufferline " .. (_G.bufferline_visible and "shown" or "hidden"), vim.log.levels.INFO) end},
            {"Satellite Scrollbar", function() return _G.satellite_enabled and "[✓]" or "[ ]" end, function() _G.satellite_enabled = not _G.satellite_enabled; local f = io.open(vim.fn.stdpath('data') .. '/satellite_enabled', 'w'); if f then f:write(_G.satellite_enabled and '1' or '0'); f:close() end; if _G.satellite_enabled then require('satellite').setup({current_only = false, winblend = 50, zindex = 40, excluded_filetypes = {'neo-tree', 'TelescopePrompt'}, width = 2, handlers = {cursor = {enable = true}, diagnostic = {enable = true}, gitsigns = {enable = true}, marks = {enable = true}, quickfix = {enable = true}}}) else require('satellite').disable() end; vim.notify("Satellite scrollbar " .. (_G.satellite_enabled and "enabled" or "disabled"), vim.log.levels.INFO) end},
        },
        editor = {
            {"Tab Width", function() return "Spaces: " .. vim.bo.tabstop end, function() local t = vim.bo.tabstop; vim.bo.tabstop, vim.bo.shiftwidth = (t == 2 and 4 or (t == 4 and 8 or 2)), (t == 2 and 4 or (t == 4 and 8 or 2)) end},
            {"Scroll Offset", function() return "Lines: " .. vim.o.scrolloff end, function() local s = vim.o.scrolloff; vim.o.scrolloff = s == 0 and 4 or (s == 4 and 8 or (s == 8 and 12 or 0)) end},
            {separator = true},
            {"Expand Tabs", function() return vim.bo.expandtab and "[✓] Spaces" or "[ ] Tabs" end, function() vim.bo.expandtab = not vim.bo.expandtab end},
            {"Mouse Support", function() return vim.o.mouse == "a" and "[✓]" or "[ ]" end, function() vim.o.mouse = vim.o.mouse == "a" and "" or "a" end},
            {"System Clipboard", function() return vim.o.clipboard == "unnamedplus" and "[✓]" or "[ ]" end, function() vim.o.clipboard = vim.o.clipboard == "unnamedplus" and "" or "unnamedplus" end},
            {"Spell Check", function() return vim.wo.spell and "[✓]" or "[ ]" end, function() vim.wo.spell = not vim.wo.spell end},
            {"Auto-format", function() return _G.autoformat_enabled and "[✓]" or "[ ]" end, function() _G.autoformat_enabled = not _G.autoformat_enabled; vim.notify("Auto-format: " .. (_G.autoformat_enabled and "ON" or "OFF"), _G.autoformat_enabled and vim.log.levels.INFO or vim.log.levels.WARN) end},
            {separator = true},
            {"Smooth Scrolling", function() return _G.neoscroll_enabled and "[✓]" or "[ ]" end, function() _G.neoscroll_enabled = not _G.neoscroll_enabled; local f = io.open(vim.fn.stdpath('data') .. '/neoscroll_enabled', 'w'); if f then f:write(_G.neoscroll_enabled and '1' or '0'); f:close() end; if _G.neoscroll_enabled then require('neoscroll').setup({mappings = {}, hide_cursor = true, stop_eof = true, respect_scrolloff = false, cursor_scrolls_alone = true, easing = 'linear', performance_mode = false}); local neoscroll = require('neoscroll'); vim.keymap.set({'n', 'v', 'x'}, '<PageUp>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<PageDown>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-b>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-f>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-u>', function() neoscroll.scroll(-vim.wo.scroll, {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-d>', function() neoscroll.scroll(vim.wo.scroll, {move_cursor=true, duration=_G.neoscroll_duration}) end) else pcall(vim.keymap.del, {'n', 'v', 'x'}, '<PageUp>'); pcall(vim.keymap.del, {'n', 'v', 'x'}, '<PageDown>'); pcall(vim.keymap.del, {'n', 'v', 'x'}, '<C-b>'); pcall(vim.keymap.del, {'n', 'v', 'x'}, '<C-f>'); pcall(vim.keymap.del, {'n', 'v', 'x'}, '<C-u>'); pcall(vim.keymap.del, {'n', 'v', 'x'}, '<C-d>') end; vim.notify("Smooth scrolling " .. (_G.neoscroll_enabled and "enabled" or "disabled"), vim.log.levels.INFO) end},
            {"Scroll Duration", function() return _G.neoscroll_enabled and (_G.neoscroll_duration .. "ms") or "[disabled]" end, function() if not _G.neoscroll_enabled then vim.notify("Enable smooth scrolling first", vim.log.levels.WARN); return end; _G.neoscroll_duration = (_G.neoscroll_duration + 50 > 1000) and 50 or (_G.neoscroll_duration + 50); local f = io.open(vim.fn.stdpath('data') .. '/neoscroll_duration', 'w'); if f then f:write(tostring(_G.neoscroll_duration)); f:close() end; local neoscroll = require('neoscroll'); vim.keymap.set({'n', 'v', 'x'}, '<PageUp>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<PageDown>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-b>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-f>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-u>', function() neoscroll.scroll(-vim.wo.scroll, {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.keymap.set({'n', 'v', 'x'}, '<C-d>', function() neoscroll.scroll(vim.wo.scroll, {move_cursor=true, duration=_G.neoscroll_duration}) end); vim.notify("Scroll duration: " .. _G.neoscroll_duration .. "ms", vim.log.levels.INFO) end},
        },
        git = {
            {"Git Signs", function() local ok, g = pcall(require, 'gitsigns.config'); return (ok and g and g.config and g.config.signcolumn) and "[✓]" or "[ ]" end, function() require('gitsigns').toggle_signs() end},
            {"Git Blame", function() local ok, g = pcall(require, 'gitsigns.config'); return (ok and g and g.config and g.config.current_line_blame) and "[✓]" or "[ ]" end, function() require('gitsigns').toggle_current_line_blame() end},
            {"Git Line Highlight", function() local ok, g = pcall(require, 'gitsigns.config'); return (ok and g and g.config and g.config.linehl) and "[✓]" or "[ ]" end, function() require('gitsigns').toggle_linehl() end},
        },
        diagnostics = {
            {"Virtual Text", function() return vim.diagnostic.config().virtual_text and "[✓]" or "[ ]" end, function() vim.diagnostic.config({virtual_text = not vim.diagnostic.config().virtual_text}) end},
            {"Diagnostic Signs", function() return vim.diagnostic.config().signs and "[✓]" or "[ ]" end, function() vim.diagnostic.config({signs = not vim.diagnostic.config().signs}) end},
            {"Underline Diagnostics", function() return vim.diagnostic.config().underline and "[✓]" or "[ ]" end, function() vim.diagnostic.config({underline = not vim.diagnostic.config().underline}) end},
            {"Update in Insert", function() return vim.diagnostic.config().update_in_insert and "[✓]" or "[ ]" end, function() vim.diagnostic.config({update_in_insert = not vim.diagnostic.config().update_in_insert}) end},
        },
        ai = {
            {"AI Companion", function() return _G.ai_companion.enabled and "[✓]" or "[ ]" end, function() toggle_ai_companion() end},
            {"Current Provider", function() return _G.ai_companion.provider:upper() end, function() local providers = {"claude", "openai", "copilot", "gemini", "ollama"}; local current_idx = 1; for i, p in ipairs(providers) do if p == _G.ai_companion.provider then current_idx = i break end end; local next_idx = (current_idx % #providers) + 1; switch_ai_provider(providers[next_idx]) end},
            {"Auto Suggestions", function() return _G.ai_companion.auto_suggestions and "[✓]" or "[ ]" end, function() toggle_auto_suggestions() end},
            {"Dual Boost Mode", function() return _G.ai_companion.dual_boost and "[✓]" or "[ ]" end, function() toggle_dual_boost() end},
            {"Use Avante.nvim", function() return _G.ai_companion.use_avante and "[✓] (needs Rust)" or "[ ] (Copilot only)" end, function() _G.ai_companion.use_avante = not _G.ai_companion.use_avante; save_ai_companion_settings(); vim.notify("Use Avante: " .. (_G.ai_companion.use_avante and "ON (restart required)" or "OFF"), vim.log.levels.INFO) end},
            {separator = true},
            {"Claude API Key", function() 
                local key = _G.ai_companion.api_keys.anthropic
                if key == "" then
                    return vim.env.ANTHROPIC_API_KEY and "[env]" or "[not set]"
                else
                    return "[" .. key:sub(1, 7) .. "...]"
                end
            end, function() set_api_key("claude") end},
            {"OpenAI API Key", function() 
                local key = _G.ai_companion.api_keys.openai
                if key == "" then
                    return vim.env.OPENAI_API_KEY and "[env]" or "[not set]"
                else
                    return "[" .. key:sub(1, 7) .. "...]"
                end
            end, function() set_api_key("openai") end},
            {"Gemini API Key", function() 
                local key = _G.ai_companion.api_keys.gemini
                if key == "" then
                    return vim.env.GEMINI_API_KEY and "[env]" or "[not set]"
                else
                    return "[" .. key:sub(1, 7) .. "...]"
                end
            end, function() set_api_key("gemini") end},
            {separator = true},
            {"Ollama Enabled", function() return _G.ai_companion.ollama.enabled and "[✓]" or "[ ]" end, function() toggle_ollama() end},
            {"Ollama Model", function() return "[" .. _G.ai_companion.ollama.model .. "]" end, function() set_ollama_model() end},
            {"Ollama Endpoint", function() return "[" .. _G.ai_companion.ollama.endpoint .. "]" end, function() configure_ollama_endpoint() end},
            {"Test Ollama", function() return "" end, function() test_ollama_connection() end},
            {separator = true},
            {"Setup Copilot", function() return "" end, function() setup_copilot() end},
            {"Check Copilot Status", function() return "" end, function() check_copilot_status() end},
            {separator = true},
            {"Clear All API Keys", function() return "" end, function()
                _G.ai_companion.api_keys.anthropic = ""
                _G.ai_companion.api_keys.openai = ""
                _G.ai_companion.api_keys.gemini = ""
                save_ai_companion_settings()
                vim.notify("All API keys cleared", vim.log.levels.INFO)
            end},
            {"Toggle AI Panel", function() return "" end, function() vim.cmd("AvanteToggle") end},
        },
    }
    
    -- View metadata
    local view_info = {
        main = {title = ' ⚙  Settings ', footer = ' j/k=Navigate | Enter/Space=Select | q/Esc=Close '},
        colorscheme = {title = ' 🎨 Colorschemes ', footer = ' j/k=Navigate | Enter=Apply & Save | Esc=Cancel | q=Back '},
        lsp = {title = ' 🔧 LSP Servers ', footer = ' j/k=Navigate | Space/Enter=Toggle | r=Restart | q=Back '},
        ai = {title = ' 🤖 AI Companion ', footer = ' j/k=Navigate | Space/Enter=Toggle | q=Back '},
        display = {title = ' 🖥  Display Settings ', footer = ' j/k=Navigate | Space/Enter=Toggle | q=Back '},
        editor = {title = ' ✏  Editor Behavior ', footer = ' j/k=Navigate | Space/Enter=Toggle | q=Back '},
        git = {title = ' 🌿 Git Integration ', footer = ' j/k=Navigate | Space/Enter=Toggle | q=Back '},
        diagnostics = {title = ' 🩺 Diagnostics ', footer = ' j/k=Navigate | Space/Enter=Toggle | q=Back '},
    }


-- Render
    local function render()
        vim.bo[buf].modifiable = true
        vim.api.nvim_set_hl(0, 'SettingsFooter', { reverse = true })
        
        local lines = {""}
        local info = view_info[state.view]
        
        if state.view == "main" then
            -- Calculate max label width for main menu
            local max_label_width = 0
            for i, item in ipairs(menus.main) do
                local label_len = #item[1] + #item[2] + 1  -- emoji + space + text
                if label_len > max_label_width then
                    max_label_width = label_len
                end
            end
            
            for i, item in ipairs(menus.main) do
                local label = item[1] .. " " .. item[2]
                local desc = item[3]
                if i == state.selection then
                    local padding = max_label_width - #label + 20
                    lines[#lines+1] = string.format("► %s%s - %s", label, string.rep(" ", padding), desc)
                else
                    lines[#lines+1] = string.format("  %s", label)
                end
            end
        elseif state.view == "colorscheme" then
            local schemes = vim.fn.getcompletion('', 'color')
            -- Calculate visible range (show only height - 1 items at a time)
            local start_idx = math.max(1, state.selection - math.floor((height - 1) / 2))
            local end_idx = math.min(#schemes, start_idx + height - 2)
            -- Adjust start if we're near the end
            if end_idx - start_idx < height - 2 then
                start_idx = math.max(1, end_idx - height + 2)
            end
            
            for i = start_idx, end_idx do
                local scheme = schemes[i]
                local line = scheme .. (scheme == state.saved_cs and " (current)" or "")
                if i == state.selection then
                    pcall(function() vim.cmd('colorscheme ' .. scheme) end)
                    vim.api.nvim_set_hl(0, 'SettingsFooter', { reverse = true })
                    update_cursor_hl()
                    lines[#lines+1] = "> " .. line
                else
                    lines[#lines+1] = "  " .. line
                end
            end
        elseif state.view == "lsp" then
            -- Calculate max label width for LSP view
            local max_label_width = 0
            for i, lsp in ipairs(state.lsp_configs) do
                if #lsp.name > max_label_width then
                    max_label_width = #lsp.name
                end
            end
            
            for i, lsp in ipairs(state.lsp_configs) do
                local status = state.enabled_lsps[lsp.name] and "[✓]" or "[ ]"
                local avail = vim.fn.executable(lsp.cmd[1]) == 1 and "" or " (not installed)"
                local padding = max_label_width - #lsp.name + 20  -- Add 20 extra chars
                lines[#lines+1] = (i == state.selection and "> " or "  ") .. lsp.name .. string.rep(" ", padding) .. " " .. status .. avail
            end
        else
            -- Generic menu rendering for display/editor/git/diagnostics/ai
            local menu = menus[state.view]
            local item_idx = 0
            
            -- Calculate max label width for right-justification
            local max_label_width = 0
            for i, item in ipairs(menu) do
                if not item.separator then
                    local label = item[1]
                    if #label > max_label_width then
                        max_label_width = #label
                    end
                end
            end
            
            for i, item in ipairs(menu) do
                if item.separator then
                    lines[#lines+1] = ""
                else
                    item_idx = item_idx + 1
                    local label = item[1]
                    local status = type(item[2]) == "function" and item[2]() or item[2]
                    
                    -- Right-justify status by padding label with extra spacing
                    local padding = max_label_width - #label + 20  -- Add 20 extra chars
                    local padded_label = label .. string.rep(" ", padding)
                    
                    lines[#lines+1] = (item_idx == state.selection and "> " or "  ") .. padded_label .. " " .. status
                end
            end
        end
        
        -- Pad to height - 1 (leave room for footer)
        while #lines < height do
            lines[#lines + 1] = ""
        end
        
        -- Add footer
        local padding = math.max(0, math.floor((width - #info.footer) / 2))
        lines[#lines + 1] = string.rep(" ", padding) .. info.footer .. string.rep(" ", width - padding - #info.footer)
        
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_win_set_config(win, {
            relative = 'editor', 
            width = width, 
            height = height + 1, 
            row = math.floor((vim.o.lines - (height + 1)) / 2), 
            col = math.floor((vim.o.columns - width) / 2),
            title = info.title, 
            title_pos = 'center'
        })
        
        -- Set cursor (for colorscheme view, calculate relative position)
        local cursor_line
        if state.view == "colorscheme" then
            local schemes = vim.fn.getcompletion('', 'color')
            local start_idx = math.max(1, state.selection - math.floor((height - 1) / 2))
            local end_idx = math.min(#schemes, start_idx + height - 2)
            
            -- Adjust start if we're near the end
            if end_idx - start_idx < height - 2 then
                start_idx = math.max(1, end_idx - height + 2)
            end
            
            -- Cursor is at: selection - start_idx + 2 (for empty first line and 1-indexed)
            cursor_line = state.selection - start_idx + 2
        elseif state.view == "editor" or state.view == "ai" or state.view == "display" then
            -- For views with separators, count them before current selection
            local menu = menus[state.view]
            local item_count = 0
            cursor_line = 1  -- Start at line 1 (empty first line)
            for i, item in ipairs(menu) do
                if item.separator then
                    cursor_line = cursor_line + 1
                else
                    item_count = item_count + 1
                    cursor_line = cursor_line + 1
                    if item_count == state.selection then
                        break
                    end
                end
            end
        else
            cursor_line = state.selection + 1
        end
        
        vim.api.nvim_win_set_cursor(win, {cursor_line, 0})
        
        -- Footer highlight
        local ns = vim.api.nvim_create_namespace('settings_footer')
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, {
            end_line = #lines - 1, 
            end_col = #lines[#lines], 
            hl_group = 'SettingsFooter', 
            hl_eol = true, 
            priority = 1000
        })
        
        vim.bo[buf].modifiable = false
    end
    
    -- Get max items for current view
    local function get_max_items()
        if state.view == "main" then return #menus.main
        elseif state.view == "colorscheme" then return #vim.fn.getcompletion('', 'color')
        elseif state.view == "lsp" then return #state.lsp_configs
        else
            local count = 0
            for _, item in ipairs(menus[state.view] or {}) do
                if not item.separator then count = count + 1 end
            end
            return count
        end
    end
    
    -- Actions
    local function select()
        if state.view == "main" then
            menus.main[state.selection][4]()
            render()
        elseif state.view == "colorscheme" then
            local scheme = vim.fn.getcompletion('', 'color')[state.selection]
            if pcall(function() vim.cmd('colorscheme ' .. scheme) end) then
                local f = io.open(vim.fn.stdpath('data') .. '/current_colorscheme.txt', 'w')
                if f then f:write(scheme); f:close() end
                state.saved_cs, state.original_cs = scheme, scheme
                vim.notify('Colorscheme saved: ' .. scheme, vim.log.levels.INFO)
                state.view, state.selection = "main", 1
                render()
            end
        elseif state.view == "lsp" then
            local lsp = state.lsp_configs[state.selection]
            state.enabled_lsps[lsp.name] = not state.enabled_lsps[lsp.name]
            local f = io.open(state.lsp_state_file, 'w')
            if f then f:write(vim.fn.json_encode(state.enabled_lsps)); f:close() end
            vim.notify(lsp.name .. " " .. (state.enabled_lsps[lsp.name] and "enabled" or "disabled"), vim.log.levels.INFO)
            render()
        else
            local menu = menus[state.view]
            local item_idx = 0
            for _, item in ipairs(menu) do
                if not item.separator then
                    item_idx = item_idx + 1
                    if item_idx == state.selection then item[3](); render(); break end
                end
            end
        end
    end
    
    local function go_back()
        if state.view == "colorscheme" then
            pcall(function() vim.cmd('colorscheme ' .. state.original_cs) end)
        end
        if state.view == "main" then
            vim.api.nvim_win_close(win, true)
        else
            state.view, state.selection = "main", 1
            render()
        end
    end
    
    -- Keymaps
    local function map(key, fn) vim.keymap.set('n', key, fn, {buffer = buf, nowait = true}) end
    map('j', function() if state.selection < get_max_items() then state.selection = state.selection + 1; render() end end)
    map('k', function() if state.selection > 1 then state.selection = state.selection - 1; render() end end)
    map('<Down>', function() if state.selection < get_max_items() then state.selection = state.selection + 1; render() end end)
    map('<Up>', function() if state.selection > 1 then state.selection = state.selection - 1; render() end end)
    map('<CR>', select)
    map('<Space>', select)
    map('q', go_back)
    map('<Esc>', go_back)
    map('r', function()
        if state.view == "lsp" then
            vim.api.nvim_win_close(win, true)
            for _, c in ipairs(vim.lsp.get_clients()) do c.stop() end
            vim.notify("Stopping all LSP clients...", vim.log.levels.INFO)
            vim.defer_fn(function()
                for _, b in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == '' then
                        local ft = vim.bo[b].filetype
                        if ft ~= '' then vim.api.nvim_exec_autocmds('FileType', {pattern = ft}) end
                    end
                end
                vim.notify("LSP clients restarted", vim.log.levels.INFO)
            end, 500)
        end
    end)
    
    for _, key in ipairs({'h', 'l', 'w', 'b', 'e', '0', '$', 'gg', 'G', '{', '}', 'H', 'M', 'L', '<Left>', '<Right>'}) do
        map(key, function() end)
    end
    
    render()
end
-- }}}




-- ============================================================================
-- PLUGIN CONFIGURATION {{{
-- ============================================================================

-- Auto-session {{{
local neotree_state = vim.fn.stdpath('data') .. '/neotree_session.txt'

vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        local open = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ok, ft = pcall(vim.api.nvim_buf_get_option, buf, 'filetype')
            if ok and ft == 'neo-tree' then open = true break end
        end
        
        local f = io.open(neotree_state, 'w')
        if f then f:write(open and '1' or '0'); f:close() end
    end
})

require('auto-session').setup({
    log_level = 'error',
    auto_session_root_dir = vim.fn.stdpath('data') .. '/sessions/',
    auto_session_enabled = true,
    auto_save_enabled = true,
    auto_restore_enabled = true,
    auto_session_suppress_dirs = { '~/', '~/Downloads', '/', '/tmp' },
    pre_save_cmds = {"silent! Neotree close"},
    post_restore_cmds = {
        function()
            vim.defer_fn(function()
                local f = io.open(neotree_state, 'r')
                if f then
                    if f:read('*all') == '1' then vim.cmd('Neotree show') end
                    f:close()
                end
            end, 200)
        end
    },
})
-- }}}

-- Simple plugins {{{
require('nvim-autopairs').setup({})
require('gitsigns').setup({
    signs = {
        add = { text = '│' },
        change = { text = '│' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
    },
})


require('Comment').setup({
    padding = true,
    sticky = true,
    ignore = '^$',
    toggler = {line = 'gcc', block = 'gbc'},
    opleader = {line = 'gc', block = 'gb'},
    extra = {above = 'gcO', below = 'gco', eol = 'gcA'},
    mappings = {basic = true, extra = true},
})

map('n', '<leader>/', 'gcc', 'Toggle comment', { remap = true })
map('v', '<leader>/', 'gc', 'Toggle comment', { remap = true })



-- Build Treesitter parsers list from language config
local treesitter_parsers = {}
for _, lang in ipairs(_G.supported_languages) do
    if lang.treesitter then
        for _, parser in ipairs(lang.treesitter) do
            table.insert(treesitter_parsers, parser)
        end
    end
end

require('nvim-treesitter.configs').setup({
    ensure_installed = treesitter_parsers,
    highlight = { enable = true },
    indent = { enable = true },
})


require('mini.statusline').setup()
--require("mini.pick").setup()
require("oil").setup()
require("cmake-tools").setup({})
require("typst-preview").setup()
-- }}}

-- nvim-ufo {{{
require('ufo').setup({
    provider_selector = function() return {'treesitter', 'indent'} end,
    preview = {
        win_config = {
            border = {'╭', '─', '╮', '│', '╯', '─', '╰', '│'},
            winhighlight = 'Normal:Folded',
            winblend = 0
        },
        mappings = {scrollU = '<C-u>', scrollD = '<C-d>', jumpTop = '[', jumpBot = ']'}
    },
    fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (' 󰁂 %d '):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        
        for _, chunk in ipairs(virtText) do
            local chunkText = chunk[1]
            local chunkWidth = vim.fn.strdisplaywidth(chunkText)
            if targetWidth > curWidth + chunkWidth then
                table.insert(newVirtText, chunk)
            else
                chunkText = truncate(chunkText, targetWidth - curWidth)
                table.insert(newVirtText, {chunkText, chunk[2]})
                chunkWidth = vim.fn.strdisplaywidth(chunkText)
                if curWidth + chunkWidth < targetWidth then
                    suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
                end
                break
            end
            curWidth = curWidth + chunkWidth
        end
        
        table.insert(newVirtText, {suffix, 'MoreMsg'})
        return newVirtText
    end
})
-- }}}


-- Bufferline {{{
require('bufferline').setup({
    options = {
        mode = "buffers",
        numbers = "none",
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        indicator = {
            icon = '▎',
            style = 'icon',
        },
        buffer_close_icon = '󰅖',
        modified_icon = '●',
        close_icon = '',
        left_trunc_marker = '',
        right_trunc_marker = '',
        max_name_length = 18,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or " "
            return " " .. icon .. count
        end,
        offsets = {
            {
                filetype = "neo-tree",
                text = "File Explorer",
                text_align = "center",
                separator = true
            }
        },
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
        separator_style = "thin",
        always_show_bufferline = _G.bufferline_visible or true,  -- Controlled by setting
    }
})

-- Keymaps for bufferline
-- map('n', '<leader>zb', ':BufferLinePick<CR>', 'Pick buffer')
-- map('n', '<leader>zB', ':BufferLinePickClose<CR>', 'Pick close buffer')
-- map('n', '[b', ':BufferLineCyclePrev<CR>', 'Previous buffer')
-- map('n', ']b', ':BufferLineCycleNext<CR>', 'Next buffer')
--map('n', '<leader>bd', ':bdelete<CR>', 'Delete buffer')
map('n', '<leader>bD', ':BufferLineCloseOthers<CR>', 'Delete other buffers')
-- map('n', '<leader>bh', ':BufferLineCloseLeft<CR>', 'Delete buffers to left')
-- map('n', '<leader>bl', ':BufferLineCloseRight<CR>', 'Delete buffers to right')



-- }}}


-- Telescope {{{
require('telescope').setup({
    defaults = {
        mappings = {
            i = {
                ["<C-j>"] = require('telescope.actions').move_selection_next,
                ["<C-k>"] = require('telescope.actions').move_selection_previous,
                ["<C-q>"] = require('telescope.actions').close,  -- Ctrl-q to close
                ["<Up>"] = false,      -- Disable up arrow
                ["<Down>"] = false,    -- Disable down arrow
                ["<Left>"] = false,    -- Optional: disable left
                ["<Right>"] = false,   -- Optional: disable right
            },
            n = {
                ["<Up>"] = false,      -- Disable in normal mode too
                ["<Down>"] = false,
                ["<Left>"] = false,
                ["<Right>"] = false,
            },
        },
        prompt_prefix = " ",
        selection_caret = " ",
        path_display = { "truncate" },
        file_ignore_patterns = { 
            "node_modules", 
            ".git/", 
            "build/",
            ".cache/",
            ".nvim/",
        },
        layout_config = {
            horizontal = {
                preview_width = 0.55,
            },
        },
    },
    pickers = {
        find_files = {
            hidden = false,
            find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*", "--glob", "!**/build/*", "--glob", "!**/.cache/*", "--glob", "!**/.nvim/*" },
        },
    },
})
-- }}}


-- Harpoon 2 {{{
local harpoon = require("harpoon")
harpoon:setup({
    settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
    },
})
-- }}}


-- Neoscroll {{{
if _G.neoscroll_enabled then
    require('neoscroll').setup({
        mappings = {},  -- Disable default mappings, we'll set our own
        hide_cursor = true,
        stop_eof = true,
        respect_scrolloff = false,
        cursor_scrolls_alone = true,
        easing = 'linear',
        pre_hook = nil,
        post_hook = nil,
        performance_mode = false,
    })

    -- Custom PageUp/PageDown with 300ms animation
    local neoscroll = require('neoscroll')
    map({'n', 'v', 'x'}, '<PageUp>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=200}) end, 'Scroll page up')
    map({'n', 'v', 'x'}, '<PageDown>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=200}) end, 'Scroll page down')
    map({'n', 'v', 'x'}, '<C-b>', function() neoscroll.scroll(-vim.api.nvim_win_get_height(0), {move_cursor=true, duration=200}) end, 'Scroll back full page')
    map({'n', 'v', 'x'}, '<C-f>', function() neoscroll.scroll(vim.api.nvim_win_get_height(0), {move_cursor=true, duration=200}) end, 'Scroll forward full page')
    map({'n', 'v', 'x'}, '<C-u>', function() neoscroll.scroll(-vim.wo.scroll, {move_cursor=true, duration=200}) end, 'Scroll up half page')
    map({'n', 'v', 'x'}, '<C-d>', function() neoscroll.scroll(vim.wo.scroll, {move_cursor=true, duration=200}) end, 'Scroll down half page')
end
-- }}}



-- Satellite (scrollbar with annotations) {{{
if _G.satellite_enabled then
    require('satellite').setup({
        current_only = false,
        winblend = 50,
        zindex = 40,
        excluded_filetypes = {'neo-tree', 'TelescopePrompt'},
        width = 2,
        handlers = {
            cursor = {
                enable = true,
                symbols = { '⎺', '⎻', '⎼', '⎽' }
            },
            diagnostic = {
                enable = true,
                signs = {'-', '=', '≡'},
                min_severity = vim.diagnostic.severity.HINT,
            },
            gitsigns = {
                enable = true,
                signs = {
                    add = '│',
                    change = '│',
                    delete = '-',
                }
            },
            marks = {
                enable = true,
                show_builtins = false,
                key = 'm'
            },
            quickfix = {
                enable = true,
                signs = {'━', '━', '━'},
            }
        },
    })
end
-- }}}


-- Mason (only if enabled) {{{
if _G.mason_enabled then
    require('mason').setup({
        ui = {
            icons = {
                package_installed = "✓",
                package_pending = "➜",
                package_uninstalled = "✗"
            },
            border = "rounded",
        }
    })

    require('mason-lspconfig').setup({
        ensure_installed = {
            'clangd',
            'cmake',
            'lua_ls',
            'bashls',
            'ts_ls',
            'html',
            'cssls',
        },
        automatic_installation = true,
    })
    
end
-- }}}



-- DAP {{{
local dap = require('dap')
local dapui = require('dapui')

_G.neotree_was_open_before_dap = false

local function set_debug_maps()
    temp_map('n', 'C', function() require('dap').continue() end, 'Continue')
    temp_map('n', 'N', function() require('dap').step_over() end, 'Step Over')
    temp_map('n', 'S', function() require('dap').step_into() end, 'Step Into')
    temp_map('n', 'F', function() require('dap').step_out() end, 'Step Out')
    temp_map('n', 'B', function()
        require('dap').toggle_breakpoint()
        pcall(function() require('dapui').update_render() end)
    end, 'Breakpoint')
    temp_map('n', 'R', function() require('dap').restart() end, 'Restart')
    temp_map('n', 'Q', function() require('dap').terminate() end, 'Quit')
    temp_map('n', 'H', function() require('dap.ui.widgets').hover() end, 'Hover')
    
    -- Layout switcher during debug
    temp_map('n', 'L', function()
        _G.switch_dap_layout()
    end, 'Switch DAP Layout')
    
end

local function clear_debug_maps()
    clear_all_temp_maps()
    vim.notify("Debug ended", vim.log.levels.INFO)
end

-- Define multiple layouts
local dap_layouts = {
    -- Layout 1: TUI/ncurses apps (terminal on right, full height)
    tui = {
        {
            elements = {
                { id = "scopes", size = 0.30 },
                { id = "breakpoints", size = 0.20 },
                { id = "stacks", size = 0.25 },
                { id = "watches", size = 0.25 },
            },
            size = 40,  -- Width in columns for the left panel
            position = "left",
        },
        {
            elements = {
                { id = "console", size = 0.7 },
                { id = "repl", size = 0.3 },
            },
            size = 80,  -- Width in columns for the right panel (terminal area)
            position = "right",
        },
    },
    
    -- Layout 2: GUI/non-TUI apps (console at bottom)
    gui = {
        {
            elements = {
                { id = "scopes", size = 0.25 },
                { id = "breakpoints", size = 0.25 },
                { id = "stacks", size = 0.25 },
                { id = "watches", size = 0.25 },
            },
            size = 40,
            position = "left",
        },
        {
            elements = {
                { id = "repl", size = 0.5 },
                { id = "console", size = 0.5 },
            },
            size = 15,  -- Height in rows for bottom panel
            position = "bottom",
        },
    },
    
    -- Layout 3: Minimal (just console at bottom, for external terminals)
    minimal = {
        {
            elements = {
                { id = "scopes", size = 0.25 },
                { id = "breakpoints", size = 0.25 },
                { id = "stacks", size = 0.25 },
                { id = "watches", size = 0.25 },
            },
            size = 40,
            position = "left",
        },
        {
            elements = {
                { id = "console", size = 1.0 },
            },
            size = 10,
            position = "bottom",
        },
    },
}

-- Current layout tracking
_G.current_dap_layout = "tui"  -- Default layout
_G.terminal_bufnr = nil  -- Track the terminal buffer
_G.terminal_win = nil  -- Track the terminal window

-- Function to find the program I/O terminal (not codelldb adapter or gdb terminals)
local function find_program_terminal()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
            local bufname = vim.api.nvim_buf_get_name(buf)
            -- Look for the tty terminal (has "tty >" in the name)
            if bufname:match("tty%s*>") then
                return buf
            end
        end
    end
    return nil
end

-- Function to switch layouts
function _G.switch_dap_layout()
    -- Simple approach: Don't allow switching FROM tui layout
    -- The terminal window will be lost when switching away
    if _G.current_dap_layout == "tui" then
        vim.notify("Cannot switch from TUI layout (terminal would be lost).\nRestart debug to use a different layout.", vim.log.levels.WARN)
        return
    end
    
    local layouts = {"tui", "gui", "minimal"}
    local current_idx = 1
    
    for i, name in ipairs(layouts) do
        if name == _G.current_dap_layout then
            current_idx = i
            break
        end
    end
    
    -- Cycle to next layout
    local next_idx = (current_idx % #layouts) + 1
    _G.current_dap_layout = layouts[next_idx]
    
    -- Close DAP UI
    dapui.close()
    
    -- Update the layout configuration
    require('dapui').setup({
        layouts = dap_layouts[_G.current_dap_layout],
        controls = {enabled = true, element = "repl"},
        floating = {
            max_height = nil,
            max_width = nil,
            border = "rounded",
            mappings = {close = { "q", "<Esc>" }},
        },
        windows = { indent = 1 },
        render = {max_type_length = nil, max_value_lines = 100},
    })
    
    dapui.open()
    
    vim.notify("DAP Layout: " .. _G.current_dap_layout, vim.log.levels.INFO)
end

dap.adapters.codelldb = {
    type = 'server',
    port = "${port}",
    executable = {
        command = vim.fn.expand('~/.local/share/codelldb/extension/adapter/codelldb'),
        args = {"--port", "${port}"},
    }
}

dap.configurations.cpp = {
    {
        name = "Launch with Terminal",
        type = "codelldb",
        request = "launch",
        program = function()
            local exes = find_cmake_executables()
            
            if #exes == 0 then
                vim.notify("No executables found", vim.log.levels.ERROR)
                return nil
            end
            
            if _G.last_cmake_target then
                for _, exe in ipairs(exes) do
                    if exe.path == _G.last_cmake_target.path then
                        return exe.path
                    end
                end
            end
            
            if #exes == 1 then
                _G.last_cmake_target = exes[1]
                return exes[1].path
            end
            
            return nil
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
        stdio = function()
            if _G.debug_terminal_tty then
                return {_G.debug_terminal_tty, _G.debug_terminal_tty, _G.debug_terminal_tty}
            end
            return nil
        end,
        terminal = 'external',
    },
}
dap.configurations.c = dap.configurations.cpp

-- Initial setup with default layout
dapui.setup({
    layouts = dap_layouts[_G.current_dap_layout],
    controls = {enabled = true, element = "repl"},
    floating = {
        max_height = nil,
        max_width = nil,
        border = "rounded",
        mappings = {close = { "q", "<Esc>" }},
    },
    windows = { indent = 1 },
    render = {max_type_length = nil, max_value_lines = 100},
})

dap.listeners.after.event_initialized["dapui_config"] = function()
    _G.neotree_was_open_before_dap = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ok, ft = pcall(vim.api.nvim_buf_get_option, buf, 'filetype')
        if ok and ft == 'neo-tree' then
            _G.neotree_was_open_before_dap = true
            break
        end
    end

    vim.cmd("silent! Neotree close")
    
    -- Exit insert mode BEFORE opening DAP UI
    vim.cmd('stopinsert')
    
    dapui.open()
    set_debug_maps()
    
    -- Force terminal resize after DAP UI opens
    vim.defer_fn(function()
        -- Find the dap-terminal buffer and force a resize
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
                local bufname = vim.api.nvim_buf_get_name(buf)
                if bufname:match("%[dap%-terminal%]") then
                    -- Find the window containing this buffer
                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                        if vim.api.nvim_win_get_buf(win) == buf then
                            -- Send a SIGWINCH signal to the terminal to notify it of size change
                            local chan = vim.api.nvim_buf_get_var(buf, 'terminal_job_id')
                            vim.fn.jobsend(chan, '\x00')  -- Dummy data to trigger refresh
                            break
                        end
                    end
                    break
                end
            end
        end
        
        -- Find and focus code buffer
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == '' then
                vim.api.nvim_set_current_win(win)
                vim.cmd('stopinsert')
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
                break
            end
        end
    end, 200)
end

dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
    clear_debug_maps()
    _G.debug_terminal_tty = nil
    
    vim.cmd('stopinsert')
    
    if _G.neotree_was_open_before_dap then
        vim.defer_fn(function()
            vim.cmd("Neotree show")
            -- Give focus back to editor
            vim.defer_fn(function()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    local ft = vim.bo[buf].filetype
                    if vim.bo[buf].buftype == '' and ft ~= 'neo-tree' then
                        vim.api.nvim_set_current_win(win)
                        vim.cmd('stopinsert')
                        break
                    end
                end
            end, 150)
        end, 100)
    end
end

dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
    clear_debug_maps()
    _G.debug_terminal_tty = nil
    
    vim.cmd('stopinsert')
    
    if _G.neotree_was_open_before_dap then
        vim.defer_fn(function()
            vim.cmd("Neotree show")
            -- Give focus back to editor
            vim.defer_fn(function()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    local ft = vim.bo[buf].filetype
                    if vim.bo[buf].buftype == '' and ft ~= 'neo-tree' then
                        vim.api.nvim_set_current_win(win)
                        vim.cmd('stopinsert')
                        break
                    end
                end
            end, 150)
        end, 100)
    end
end

vim.fn.sign_define('DapBreakpoint', {text='🔴', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='➲', texthl='DapStopped', linehl='DapStoppedLine', numhl=''})

vim.api.nvim_set_hl(0, 'DapStoppedLine', { reverse = true })
vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#ff0000' })
vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = '#61afef' })
vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#ff0000' })
-- }}}

-- DAP Projects {{{
require('nvim-dap-projects').config_paths = { '.nvim/breakpoints.json' }

vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
        local root = find_project_root()
        local cfg_path = root .. '/.nvim/breakpoints.json'
        local cfg_dir = root .. '/.nvim'
        
        if vim.fn.isdirectory(cfg_dir) == 0 then
            vim.fn.mkdir(cfg_dir, 'p')
        end
        
        local bps = require('dap.breakpoints').get()
        local bp_data = {}
        
        for buf, buf_bps in pairs(bps) do
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= '' then
                bp_data[name] = buf_bps
            end
        end
        
        if next(bp_data) then
            local f = io.open(cfg_path, 'w')
            if f then
                f:write(vim.fn.json_encode(bp_data))
                f:close()
            end
        end
    end,
})

vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
        vim.defer_fn(function()
            local cfg_path = find_project_root() .. '/.nvim/breakpoints.json'
            
            if vim.fn.filereadable(cfg_path) == 1 then
                local f = io.open(cfg_path, 'r')
                if f then
                    local content = f:read('*all')
                    f:close()
                    
                    local ok, data = pcall(vim.fn.json_decode, content)
                    if ok and data then
                        for filepath, file_bps in pairs(data) do
                            if vim.fn.filereadable(filepath) == 1 then
                                local bufnr = vim.fn.bufnr(filepath, false)
                                if bufnr == -1 then
                                    vim.api.nvim_create_autocmd('BufReadPost', {
                                        pattern = filepath,
                                        once = true,
                                        callback = function(ev)
                                            for _, bp in ipairs(file_bps) do
                                                require('dap.breakpoints').set({}, ev.buf, bp.line)
                                            end
                                        end,
                                    })
                                else
                                    for _, bp in ipairs(file_bps) do
                                        require('dap.breakpoints').set({}, bufnr, bp.line)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end, 100)
    end,
})
-- }}}

-- Neo-tree {{{
require("neo-tree").setup({
    close_if_last_window = true,
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    source_selector = {winbar = false, statusline = false},
    event_handlers = {
        {
            event = "neo_tree_buffer_enter",
            handler = function()
                vim.opt_local.number = false
                vim.opt_local.relativenumber = false
            end,
        },
    },
    default_component_configs = {
        indent = {padding = 0, with_markers = true},
        icon = {
            folder_closed = "",
            folder_open = "",
            folder_empty = "",
            default = "",
        },
        git_status = {
            symbols = {
                added = "✚",
                modified = "",
                deleted = "✖",
                renamed = "➜",
                untracked = "★",
                ignored = "◌",
                unstaged = "✗",
                staged = "✓",
                conflict = "",
            },
        },
    },
    window = {
        position = "left",
        width = 30,
        mappings = {
            ["<space>"] = false,
            ["<cr>"] = "open",
            ["o"] = "open",
            ["S"] = "open_split",
            ["s"] = "open_vsplit",
            ["t"] = "open_tabnew",
            ["w"] = "open_with_window_picker",
            ["C"] = "close_node",
            ["z"] = "close_all_nodes",
            ["a"] = {"add", config = {show_path = "relative"}},
            ["d"] = "delete",
            ["r"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
            ["R"] = "refresh",
            ["?"] = "show_help",
        },
    },
    filesystem = {
        filtered_items = {
            visible = false,
            hide_dotfiles = false,
            hide_gitignored = false,
        },
        follow_current_file = {enabled = true},
        use_libuv_file_watcher = true,
    },
})
-- }}}

-- Yazi {{{
require("yazi").setup({
    open_for_directories = false,
    keymaps = {
        show_help = '<f1>',
        open_file_in_vertical_split = '<c-v>',
        open_file_in_horizontal_split = '<c-x>',
        open_file_in_tab = '<c-t>',
        grep_in_directory = '<c-s>',
        replace_in_directory = '<c-g>',
        cycle_open_buffers = '<tab>',
        copy_relative_path_to_selected_files = '<c-y>',
        send_to_quickfix_list = '<c-q>',
    },
})
-- }}}

-- }}}

-- ============================================================================
-- MISC {{{
-- ============================================================================

vim.cmd([[
    cnoreabbrev W w
    cnoreabbrev Q q
    cnoreabbrev Wq wq
    cnoreabbrev WQ wq
    cnoreabbrev Qa qa
]])

-- }}}



-- ============================================================================
-- KEYBINDINGS {{{
-- ============================================================================

-- Basic {{{
map('n', '<leader>w', ':write<CR>', 'Save file')
map('n', '<leader>W', ':wa<CR>', 'Save all files')
map('n', '<leader>q', ':quit<CR>', 'Quit window')
map('n', '<leader>Q', ':qa<CR>', 'Quit all')
map('n', '<leader>o', ':update<CR> :source<CR>', 'Reload config')
map('n', '<Esc>', ':nohlsearch<CR>', 'Clear highlight', {silent = true})
map('n', '<leader>x', ':xa<CR>', 'Save all and quit')
-- }}}


-- Settings {{{
map_group('<leader>S', 'Settings')
map('n', '<leader>S', _G.show_settings_window, 'Settings')
-- }}}


-- Windows {{{
map('n', '<C-h>', '<C-w>h', 'Left split')
map('n', '<C-j>', '<C-w>j', 'Bottom split')
map('n', '<C-k>', '<C-w>k', 'Top split')
map('n', '<C-l>', '<C-w>l', 'Right split')

map('n', '<C-Left>', '<C-w>h', 'Left split')
map('n', '<C-Right>', '<C-w>l', 'Right split')
map('n', '<C-Up>', '<C-w>k', 'Top split')
map('n', '<C-Down>', '<C-w>j', 'Bottom split')

map_group('<leader>w', 'Windows/Save')
map('n', '<C-M-Left>', ':leftabove vsplit<CR>', 'Split left', {silent = true})
map('n', '<C-M-Right>', ':rightbelow vsplit<CR>', 'Split right', {silent = true})
map('n', '<C-M-Up>', ':leftabove split<CR>', 'Split above', {silent = true})
map('n', '<C-M-Down>', ':rightbelow split<CR>', 'Split below', {silent = true})

map('n', '<leader>wh', ':leftabove vsplit<CR>', 'Split left', {silent = true})
map('n', '<leader>wl', ':rightbelow vsplit<CR>', 'Split right', {silent = true})
map('n', '<leader>wk', ':leftabove split<CR>', 'Split above', {silent = true})
map('n', '<leader>wj', ':rightbelow split<CR>', 'Split below', {silent = true})
-- }}}

-- Buffers {{{
map('n', '<Tab>', ':bnext<CR>', 'Next buffer')
map('n', '<S-Tab>', ':bprevious<CR>', 'Previous buffer')
map('n', '<leader>bd', ':bdelete<CR>', 'Delete buffer')
map('n', '<leader>bn', ':bnext<CR>', 'Next buffer')
map('n', '<leader>bp', ':bprevious<CR>', 'Previous buffer')
-- }}}

-- Jump List {{{
map('n', '<C-o>', '<C-o>', 'Jump back')
map('n', '<C-i>', '<C-i>', 'Jump forward')
-- }}}

-- Paste/Yank {{{
map('x', 'p', '"_dP', 'Paste without yanking')
map('v', 'y', 'ygv<Esc>', 'Yank and restore cursor')
-- }}}

-- LSP {{{
map_group('<leader>l', 'LSP')
map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
map('n', 'gr', vim.lsp.buf.references, 'Go to references')
map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
map('n', 'K', vim.lsp.buf.hover, 'Hover documentation')
map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code actions')
map('n', '<leader>lf', vim.lsp.buf.format, 'Format code')
map('v', '<leader>lf', vim.lsp.buf.format, 'Format selection')

_G.autoformat_enabled = true
map('n', '<leader>lF', function()
    _G.autoformat_enabled = not _G.autoformat_enabled
    vim.notify("Auto-format: " .. (_G.autoformat_enabled and "ON" or "OFF"),
               _G.autoformat_enabled and vim.log.levels.INFO or vim.log.levels.WARN)
end, 'Toggle auto-format')
-- }}}

-- AI Companion {{{
map_group('<leader>a', 'AI Companion')
map('n', '<leader>aa', ':AvanteAsk<CR>', 'Ask AI')
map('v', '<leader>aa', ':AvanteAsk<CR>', 'Ask AI (selection)')
map('n', '<leader>ac', ':AvanteChat<CR>', 'AI Chat')
map('n', '<leader>ae', ':AvanteEdit<CR>', 'Edit with AI')
map('v', '<leader>ae', ':AvanteEdit<CR>', 'Edit with AI (selection)')
map('n', '<leader>at', ':AvanteToggle<CR>', 'Toggle AI panel')
map('n', '<leader>ar', ':AvanteRefresh<CR>', 'Refresh AI')
map('n', '<leader>af', ':AvanteFocus<CR>', 'Focus AI panel')
map('n', '<leader>as', _G.toggle_auto_suggestions, 'Toggle auto suggestions')
map('n', '<leader>ap', function()
    local providers = {"claude", "openai", "copilot", "gemini"}
    vim.ui.select(providers, {
        prompt = 'Select AI Provider:',
        format_item = function(item)
            return item:upper() .. (_G.ai_companion.provider == item and " (current)" or "")
        end,
    }, function(choice)
        if choice then
            switch_ai_provider(choice)
        end
    end)
end, 'Switch provider')
-- }}}

-- Diagnostics {{{
map_group('<leader>e', 'Errors/Diagnostics')
map('n', '[d', vim.diagnostic.goto_prev, 'Previous diagnostic')
map('n', ']d', vim.diagnostic.goto_next, 'Next diagnostic')
map('n', '[e', function()
    vim.diagnostic.goto_prev({severity = vim.diagnostic.severity.ERROR})
end, 'Previous error')
map('n', ']e', function()
    vim.diagnostic.goto_next({severity = vim.diagnostic.severity.ERROR})
end, 'Next error')
map('n', '<leader>e', vim.diagnostic.open_float, 'Show diagnostic')
map('n', '<leader>el', vim.diagnostic.setloclist, 'Error list (buffer)')
map('n', '<leader>ew', vim.diagnostic.setqflist, 'Error list (workspace)')
-- }}}

-- File Explorers {{{
map('n', '-', '<CMD>Oil<CR>', 'Oil')
map('n', '<leader>n', '<CMD>Neotree toggle<CR>', 'NeoTree')
map('n', '<leader>y', '<CMD>Yazi<CR>', 'Yazi')
map('n', '<leader>Y', '<CMD>Yazi cwd<CR>', 'Yazi (cwd)')
-- }}}

-- Marks {{{
map_group('<leader>m', 'Marks')
map('n', '<leader>m1', "m1", 'Set mark 1')
map('n', '<leader>m2', "m2", 'Set mark 2')
map('n', '<leader>m3', "m3", 'Set mark 3')
map('n', '<leader>m4', "m4", 'Set mark 4')
map('n', '<leader>m5', "m5", 'Set mark 5')

map('n', '<leader>1', "'1", 'Jump to mark 1')
map('n', '<leader>2', "'2", 'Jump to mark 2')
map('n', '<leader>3', "'3", 'Jump to mark 3')
map('n', '<leader>4', "'4", 'Jump to mark 4')
map('n', '<leader>5', "'5", 'Jump to mark 5')
-- }}}

-- Folding {{{
map('n', 'zR', function() require('ufo').openAllFolds() end, 'Open all folds')
map('n', 'zM', function() require('ufo').closeAllFolds() end, 'Close all folds')
map('n', 'zr', function() require('ufo').openFoldsExceptKinds() end, 'Open folds except kinds')
map('n', 'zm', function() require('ufo').closeFoldsWith() end, 'Close folds with')
map('n', 'zK', function()
    local winid = require('ufo').peekFoldedLinesUnderCursor()
    if not winid then vim.lsp.buf.hover() end
end, 'Peek fold')
-- }}}

-- -- Find (Mini-pick) {{{
-- map_group('<leader>f', 'Find')
-- map('n', '<leader>ff', '<CMD>Pick files<CR>', 'Files')
-- map('n', '<leader>fg', '<CMD>Pick grep_live<CR>', 'Grep')
-- map('n', '<leader>fw', function()
    -- require('mini.pick').builtin.grep_live({ pattern = vim.fn.expand('<cword>') })
-- end, 'Word under cursor')
-- map('n', '<leader>fb', '<CMD>Pick buffers<CR>', 'Buffers')
-- map('n', '<leader>fo', '<CMD>Pick oldfiles<CR>', 'Recent files')
-- map('n', '<leader>fl', '<CMD>Pick buf_lines<CR>', 'Lines')
-- map('n', '<leader>fh', '<CMD>Pick help<CR>', 'Help')
-- -- }}}

-- Find (Telescope) {{{
map_group('<leader>f', 'Find')
map('n', '<leader>ff', '<cmd>Telescope find_files<CR>', 'Files')
map('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', 'Grep')
map('n', '<leader>fw', '<cmd>Telescope grep_string<CR>', 'Word under cursor')
map('n', '<leader>fb', '<cmd>Telescope buffers<CR>', 'Buffers')
map('n', '<leader>fo', '<cmd>Telescope oldfiles<CR>', 'Recent files')
map('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', 'Help')
map('n', '<leader>fr', '<cmd>Telescope resume<CR>', 'Resume last search')
map('n', '<leader>fc', '<cmd>Telescope commands<CR>', 'Commands')
map('n', '<leader>fk', '<cmd>Telescope keymaps<CR>', 'Keymaps')
-- }}}

-- Harpoon2 {{{
map_group('<leader>h', 'Harpoon')
map('n', '<leader>ha', function() harpoon:list():add() end, 'Add file')
map('n', '<leader>hh', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, 'Toggle menu')
map('n', '<leader>h1', function() harpoon:list():select(1) end, 'File 1')
map('n', '<leader>h2', function() harpoon:list():select(2) end, 'File 2')
map('n', '<leader>h3', function() harpoon:list():select(3) end, 'File 3')
map('n', '<leader>h4', function() harpoon:list():select(4) end, 'File 4')
map('n', '<leader>h5', function() harpoon:list():select(5) end, 'File 5')
map('n', '<leader>hn', function() harpoon:list():next() end, 'Next file')
map('n', '<leader>hp', function() harpoon:list():prev() end, 'Prev file')

map('n', '<M-1>', function() harpoon:list():select(1) end, 'Harpoon 1')
map('n', '<M-2>', function() harpoon:list():select(2) end, 'Harpoon 2')
map('n', '<M-3>', function() harpoon:list():select(3) end, 'Harpoon 3')
map('n', '<M-4>', function() harpoon:list():select(4) end, 'Harpoon 4')
-- }}}



-- Sessions {{{
--map_group('<leader>s', 'Session')
--map('n', '<leader>sd', ':SessionDelete<CR>', 'Delete')
--map('n', '<leader>sf', ':Autosession search<CR>', 'Find')
--map('n', '<leader>ss', ':mksession! .session.vim<CR>', 'Save')
--map('n', '<leader>sl', ':source .session.vim<CR>', 'Load')
-- }}}

-- C++ {{{
map('n', '<leader>a', function()
    local ext = vim.fn.expand('%:e')
    local base = vim.fn.expand('%:r')
    if ext == 'cpp' or ext == 'cc' or ext == 'c' then
        vim.cmd('edit ' .. base .. '.h')
    elseif ext == 'h' or ext == 'hpp' then
        for _, source_ext in ipairs({'cpp', 'cc', 'c'}) do
            if vim.fn.filereadable(base .. '.' .. source_ext) == 1 then
                vim.cmd('edit ' .. base .. '.' .. source_ext)
                return
            end
        end
    end
end, 'Toggle header/source')
-- }}}

-- Build {{{
map_group('<leader>b', 'Build')

map('n', '<leader>bp', function()
    local root = find_project_root()
    vim.notify("Project root: " .. root .. (root == vim.fn.getcwd() and " (current)" or ""), vim.log.levels.INFO)
end, 'Show project root')

map('n', '<leader>bP', cd_to_project_root, 'CD to project root')

map('n', '<leader>bc', function()
    local root = cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    if vim.fn.filereadable(root .. '/CMakeLists.txt') == 0 then
        vim.notify("CMakeLists.txt not found", vim.log.levels.ERROR)
        return
    end
    
    vim.cmd('!cmake -B ' .. vim.fn.shellescape(build_dir) .. ' -S ' .. vim.fn.shellescape(root) .. ' -DCMAKE_EXPORT_COMPILE_COMMANDS=ON')
end, 'Configure CMake')

map('n', '<leader>bb', function()
    local root = cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    if vim.fn.filereadable(root .. '/CMakeLists.txt') == 0 then
        vim.notify("CMakeLists.txt not found", vim.log.levels.ERROR)
        return
    end
    
    if vim.fn.filereadable(build_dir .. '/CMakeCache.txt') == 0 then
        vim.notify("Build not configured. Run <leader>bc first.", vim.log.levels.WARN)
        return
    end
    
    vim.cmd('!cmake --build ' .. vim.fn.shellescape(build_dir))
end, 'Build project')

map('n', '<leader>br', _G.cmake_run_with_picker, 'Build & Run')

map('n', '<leader>bt', function()
    cd_to_project_root()
    local build_dir = ensure_build_dir()
    
    if vim.fn.filereadable(build_dir .. '/CMakeCache.txt') == 0 then
        vim.notify("Build not configured.", vim.log.levels.WARN)
        return
    end
    
    vim.cmd('!ctest --test-dir ' .. vim.fn.shellescape(build_dir))
end, 'Run tests')

--map('n', '<leader>m', ':make<CR>', 'Make')
map('n', '<leader>cs', function()
    _G.last_cmake_target = nil
    print("Target cache cleared.")
end, 'Clear cached target')
map('t', '<C-q>', '<C-\\><C-n>:q<CR>', 'Close terminal')
-- }}}

-- Git {{{
map_group('<leader>g', 'Git')
map('n', '<leader>gg', function()
    if vim.fn.executable('lazygit') == 0 then
        vim.notify('lazygit not installed', vim.log.levels.ERROR)
        return
    end
    
    if vim.bo.modified then vim.cmd('write') end
    
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.95)
    local height = math.floor(vim.o.lines * 0.95)
    
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
    })
    
    vim.bo[buf].buflisted = false
    vim.bo[buf].bufhidden = 'wipe'
    
    vim.fn.termopen('lazygit', {
        on_exit = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
            vim.cmd('checktime')
        end,
    })
    
    vim.cmd('startinsert')
    vim.keymap.set('t', 'q', function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf })
end, 'Lazygit (floating)')

map('n', '<leader>gG', function()
    if vim.fn.executable('lazygit') == 0 then
        vim.notify('lazygit not installed', vim.log.levels.ERROR)
        return
    end
    
    vim.cmd('tabnew')
    vim.fn.termopen('lazygit', {
        on_exit = function()
            vim.cmd('tabclose')
            vim.cmd('checktime')
        end,
    })
    vim.cmd('startinsert')
end, 'Lazygit (tab)')

map('n', ']c', ':Gitsigns next_hunk<CR>', 'Next hunk')
map('n', '[c', ':Gitsigns prev_hunk<CR>', 'Previous hunk')
map('n', '<leader>gp', ':Gitsigns preview_hunk<CR>', 'Preview hunk')
map('n', '<leader>gb', ':Gitsigns blame_line<CR>', 'Blame')
-- }}}

-- Quickfix {{{
map_group('<leader>c', 'CMake/Quickfix')
map('n', '<leader>co', ':copen<CR>', 'Open quickfix')
map('n', '<leader>cc', ':cclose<CR>', 'Close quickfix')
map('n', '[q', ':cprev<CR>', 'Previous')
map('n', ']q', ':cnext<CR>', 'Next')
-- }}}

-- Debug {{{
map_group('<leader>d', 'Debug')

map('n', '<leader>dd', function() require('dap').continue() end, 'Debug (DAP)')
map('n', '<leader>dD', function() require('dap').continue() end, 'Debug (console)')
map('n', '<leader>dg', _G.debug_in_terminal, 'Debug (GDB)')

map('n', '<leader>db', function()
    require('dap').toggle_breakpoint()
    -- Refresh DAP UI if it's open
    pcall(function() require('dapui').update_render() end)
end, 'Toggle breakpoint')

map('n', '<F9>', function()
    require('dap').toggle_breakpoint()
    -- Refresh DAP UI if it's open
    pcall(function() require('dapui').update_render() end)
end, 'Toggle breakpoint')

map('n', '<F5>', function() 
    if vim.bo.filetype == 'neo-tree' or vim.bo.buftype ~= '' then
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, 'buftype') == '' then
                local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
                if ft ~= 'neo-tree' then
                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                        if vim.api.nvim_win_get_buf(win) == buf then
                            vim.api.nvim_set_current_win(win)
                            require('dap').continue()
                            return
                        end
                    end
                end
            end
        end
        vim.notify("No code buffer found", vim.log.levels.WARN)
    else
        require('dap').continue()
    end
end, 'Start/Continue debugging')

map('n', '<F10>', function() require('dap').step_over() end, 'Step over')
map('n', '<S-F10>', function() require('dap').step_into() end, 'Step into')
map('n', '<S-F11>', function() require('dap').step_out() end, 'Step out')
map('n', '<F6>', function() require('dap').restart() end, 'Restart debug')
map('n', '<F8>', function() require('dap').terminate() end, 'Stop debug')


map('n', '<leader>dn', function() require('dap').step_over() end, 'Step over')
map('n', '<leader>ds', function() require('dap').step_into() end, 'Step into')
map('n', '<leader>df', function() require('dap').step_out() end, 'Step out')
map('n', '<leader>dr', function() require('dap').restart() end, 'Restart')
map('n', '<leader>dR', function() require('dap').repl.open() end, 'REPL')
map('n', '<leader>dq', function() require('dap').terminate() end, 'Quit')
map('n', '<leader>du', function() require('dapui').toggle() end, 'Toggle UI')
map('n', '<leader>dh', function() require('dap.ui.widgets').hover() end, 'Hover')

map('n', '<leader>dU', function()
    require('dapui').toggle()
    vim.cmd("Neotree show")
end, 'Toggle UI (keep NeoTree)')

map('n', '<leader>dB', function()
    require('dap').clear_breakpoints()
    
    -- Also delete the persisted breakpoints file
    local config_path = find_project_root() .. '/.nvim/breakpoints.json'
    if vim.fn.filereadable(config_path) == 1 then
        vim.fn.delete(config_path)
    end
    
    -- Refresh DAP UI if it's open
    pcall(function() require('dapui').update_render() end)
    
    vim.notify("All breakpoints cleared and deleted from disk", vim.log.levels.INFO)
end, 'Clear all breakpoints')

map('n', '<leader>dl', function()
    local bps = require('dap.breakpoints').get()
    local qf = {}
    
    for buf, buf_bps in pairs(bps) do
        local bufname = vim.api.nvim_buf_get_name(buf)
        if bufname ~= '' then
            for _, bp in ipairs(buf_bps) do
                table.insert(qf, {bufnr = buf, lnum = bp.line, text = "Breakpoint", type = "I"})
            end
        end
    end
    
    if #qf > 0 then
        vim.fn.setqflist(qf, 'r')
        vim.cmd('copen')
        vim.notify("Showing " .. #qf .. " breakpoint(s)", vim.log.levels.INFO)
    else
        vim.notify("No breakpoints set", vim.log.levels.WARN)
    end
end, 'List breakpoints')

map('n', '<leader>dX', function()
    -- Delete persisted breakpoints file without clearing current session
    local config_path = find_project_root() .. '/.nvim/breakpoints.json'
    if vim.fn.filereadable(config_path) == 1 then
        vim.fn.delete(config_path)
        vim.notify("Deleted persisted breakpoints from disk", vim.log.levels.INFO)
    else
        vim.notify("No persisted breakpoints file found", vim.log.levels.WARN)
    end
end, 'Delete persisted breakpoints file')
-- }}}

-- Other {{{
map_group('<leader>t', 'Terminal/Toggle')
map('n', '<leader>u', ':UndotreeToggle<CR>', 'Undo tree')
map('n', '<leader>tt', ':terminal<CR>', 'Terminal')

-- Easy escape from terminal mode
map('t', '<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode')

-- Terminal mode window navigation (use Ctrl+\ Ctrl+n first, then navigate)
map('t', '<C-\\><C-h>', '<C-\\><C-n><C-w>h', 'Navigate left from terminal')
map('t', '<C-\\><C-j>', '<C-\\><C-n><C-w>j', 'Navigate down from terminal')
map('t', '<C-\\><C-k>', '<C-\\><C-n><C-w>k', 'Navigate up from terminal')
map('t', '<C-\\><C-l>', '<C-\\><C-n><C-w>l', 'Navigate right from terminal')
-- }}}


-- }}}



-- ============================================================================
-- REGISTER WHICH-KEY {{{
-- ============================================================================

register_whichkey()

-- }}}

-- ============================================================================
-- END OF CONFIGURATION
-- ===========================================================================