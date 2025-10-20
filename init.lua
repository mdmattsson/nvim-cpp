-- vim: foldmethod=marker foldlevel=99 foldmarker={{{,}}}
-- ============================================================================
-- nvim-cpp: A SMART NEOVIM C++ DEVELOPMENT CONFIGURATION
-- A minimal, fast, and powerful Neovim configuration optimized for C++/CMake development using Neovim 0.12's native package manager and LSP.
-- Author: Michael Mattsson <michael@mattsson.net>
-- ============================================================================

-- First run: Checks if LSPs are installed
-- LSPs missing: Shows dialog with 3 options:
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
-- FIRST RUN SETUP {{{
-- ============================================================================

local data_dir = vim.fn.stdpath('data')
local first_run_marker = data_dir .. '/init_completed'

-- Check if this is the first run
if vim.fn.filereadable(first_run_marker) == 0 then
    -- First run detected
    vim.notify("First run detected - checking LSP installation...", vim.log.levels.INFO)
    
    -- Check if LSPs are installed
    local lsps_to_check = {
        {name = 'clangd', cmd = 'clangd'},
        {name = 'lua-language-server', cmd = 'lua-language-server'},
        {name = 'bash-language-server', cmd = 'bash-language-server'},
        {name = 'typescript-language-server', cmd = 'typescript-language-server'},
        {name = 'cmake-language-server', cmd = 'cmake-language-server'},
    }
    
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

-- }}}

-- ============================================================================
-- PLUGINS {{{
-- ============================================================================

vim.pack.add({
    {src="https://github.com/vague2k/vague.nvim"},
    {src="https://github.com/folke/tokyonight.nvim"},
    {src="https://github.com/askfiy/visual_studio_code"},
    {src="https://github.com/navarasu/onedark.nvim"},
    {src="https://github.com/projekt0n/github-nvim-theme"},
    {src="https://github.com/stevearc/oil.nvim"},
    {src="https://github.com/echasnovski/mini.pick"},
    {src="https://github.com/nvim-neo-tree/neo-tree.nvim"},
    {src="https://github.com/mikavilpas/yazi.nvim"},
    {src="https://github.com/rmagatti/auto-session"},
    {src="https://github.com/echasnovski/mini.statusline"},
    {src="https://github.com/lewis6991/gitsigns.nvim"},
    {src="https://github.com/folke/which-key.nvim"},
    {src="https://github.com/nvim-tree/nvim-web-devicons"},
    {src="https://github.com/MunifTanjim/nui.nvim"},
    {src="https://github.com/kevinhwang91/nvim-ufo"},
    {src="https://github.com/kevinhwang91/promise-async"},
    {src="https://github.com/numToStr/Comment.nvim"},
    {src="https://github.com/windwp/nvim-autopairs"},
    {src="https://github.com/mbbill/undotree"},
    {src="https://github.com/nvim-treesitter/nvim-treesitter"},
    {src="https://github.com/nvim-lua/plenary.nvim"},
    {src="https://github.com/Civitasv/cmake-tools.nvim"},
    {src="https://github.com/mfussenegger/nvim-dap"},
    {src="https://github.com/rcarriga/nvim-dap-ui"},
    {src="https://github.com/ldelossa/nvim-dap-projects"},
    {src="https://github.com/nvim-neotest/nvim-nio"},
    {src="https://github.com/chomosuke/typst-preview.nvim"},
    -- Conditionally load Mason
    _G.mason_enabled and {src="https://github.com/williamboman/mason.nvim"} or nil,
    _G.mason_enabled and {src="https://github.com/williamboman/mason-lspconfig.nvim"} or nil,
    
})

-- }}}

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
map_group('<leader>h', 'Marks')
map('n', '<leader>h1', "m1", 'Set mark 1')
map('n', '<leader>h2', "m2", 'Set mark 2')
map('n', '<leader>h3', "m3", 'Set mark 3')
map('n', '<leader>h4', "m4", 'Set mark 4')
map('n', '<leader>h5', "m5", 'Set mark 5')

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

-- Find {{{
map_group('<leader>f', 'Find')
map('n', '<leader>ff', '<CMD>Pick files<CR>', 'Files')
map('n', '<leader>fg', '<CMD>Pick grep_live<CR>', 'Grep')
map('n', '<leader>fw', function()
    require('mini.pick').builtin.grep_live({ pattern = vim.fn.expand('<cword>') })
end, 'Word under cursor')
map('n', '<leader>fb', '<CMD>Pick buffers<CR>', 'Buffers')
map('n', '<leader>fo', '<CMD>Pick oldfiles<CR>', 'Recent files')
map('n', '<leader>fl', '<CMD>Pick buf_lines<CR>', 'Lines')
map('n', '<leader>fh', '<CMD>Pick help<CR>', 'Help')
-- }}}

-- Sessions {{{
map_group('<leader>s', 'Session')
map('n', '<leader>sd', ':SessionDelete<CR>', 'Delete')
map('n', '<leader>sf', ':Autosession search<CR>', 'Find')
map('n', '<leader>ss', ':mksession! .session.vim<CR>', 'Save')
map('n', '<leader>sl', ':source .session.vim<CR>', 'Load')
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

map('n', '<leader>m', ':make<CR>', 'Make')
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

-- Colorscheme {{{
map('n', '<leader>fc', function()
    local original = vim.g.colors_name or 'visual_studio_code'
    local schemes = vim.fn.getcompletion('', 'color')
    
    require('mini.pick').start({
        source = {
            items = schemes,
            name = 'Colorschemes',
            preview = function(_, item)
                pcall(function() vim.cmd('colorscheme ' .. item) end)
            end,
            choose = function(item)
                if item then
                    local ok = pcall(function() vim.cmd('colorscheme ' .. item) end)
                    
                    if ok then
                        local file = io.open(vim.fn.stdpath('data') .. '/current_colorscheme.txt', 'w')
                        if file then
                            file:write(item)
                            file:close()
                        end
                        print('Saved: ' .. item)
                    else
                        vim.cmd('colorscheme ' .. original)
                        vim.notify('Failed to load: ' .. item, vim.log.levels.ERROR)
                    end
                else
                    pcall(function() vim.cmd('colorscheme ' .. original) end)
                end
            end,
        },
    })
end, 'Colorscheme picker')
-- }}}

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

vim.lsp.enable({"lua_ls", "bashls", "clangd", "ts_ls", "html", "cssls", "cmake"})

local lsp_servers = {
    {ft = {'c', 'cpp', 'objc', 'objcpp'}, name = 'clangd', cmd = {'clangd', '--background-index', '--clang-tidy', '--header-insertion=iwyu', '--completion-style=detailed', '--function-arg-placeholders', '--pch-storage=memory'}},
    {ft = {'lua'}, name = 'lua_ls', cmd = {'lua-language-server'}},
    {ft = {'sh', 'bash'}, name = 'bashls', cmd = {'bash-language-server', 'start'}},
    {ft = {'javascript', 'typescript', 'javascriptreact', 'typescriptreact'}, name = 'ts_ls', cmd = {'typescript-language-server', '--stdio'}},
    {ft = {'html'}, name = 'html', cmd = {'vscode-html-language-server', '--stdio'}},
    {ft = {'css', 'scss', 'less'}, name = 'cssls', cmd = {'vscode-css-language-server', '--stdio'}},
    {ft = {'cmake'}, name = 'cmake', cmd = {'cmake-language-server'}},
}

for _, srv in ipairs(lsp_servers) do
    vim.api.nvim_create_autocmd('FileType', {
        pattern = srv.ft,
        callback = function()
            vim.lsp.start({name = srv.name, cmd = srv.cmd})
        end,
    })
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

require('nvim-treesitter.configs').setup({
    ensure_installed = { "c", "cpp", "cmake", "make", "bash", "lua", "javascript", "html", "css" },
    highlight = { enable = true },
    indent = { enable = true },
})

require('mini.statusline').setup()
require("mini.pick").setup()
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
    
    -- Add Mason keymap
    map('n', '<leader>lm', ':Mason<CR>', 'Mason installer')
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
-- REGISTER WHICH-KEY {{{
-- ============================================================================

register_whichkey()

-- }}}

-- ============================================================================
-- END OF CONFIGURATION
-- ============================================================================
