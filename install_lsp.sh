#!/usr/bin/env bash

set -e  # Exit on error

echo "LSP Server Installation Script"
echo "=============================="

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution"
    exit 1
fi

echo "Detected distribution: $DISTRO"
echo ""

case $DISTRO in
    rocky|rhel|centos|fedora)
        echo "Installing for Rocky Linux / RHEL-based system..."
        
        echo "Installing system packages..."
        sudo dnf install -y \
            clang-tools-extra \
            nodejs \
            npm \
            python3-pip \
            wget \
            unzip
        
        echo "Installing LSP servers via npm..."
        sudo npm install -g \
            bash-language-server \
            typescript \
            typescript-language-server \
            vscode-langservers-extracted
        
        echo ""
        echo "Installing CMake LSP via pip..."
        pip3 install --user cmake-language-server
        
        echo ""
        echo "Installing Lua Language Server manually..."
        cd /tmp
        curl -L -o lua-ls.tar.gz https://github.com/LuaLS/lua-language-server/releases/download/3.13.4/lua-language-server-3.13.4-linux-x64.tar.gz
        sudo mkdir -p /opt/lua-language-server
        sudo tar -xzf lua-ls.tar.gz -C /opt/lua-language-server
        sudo ln -sf /opt/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server
        
        # Fix permissions for lua-language-server cache directory
        echo "Setting up lua-language-server permissions..."
        sudo mkdir -p /opt/lua-language-server/log/cache
        sudo chmod 777 /opt/lua-language-server/log/cache
        
        rm lua-ls.tar.gz
        echo "Lua Language Server installed to /opt/lua-language-server"
        
        echo ""
        echo "=============================="
        echo "Optional: Install Yazi file manager"
        echo "=============================="
        read -p "Would you like to install Yazi? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Installing Yazi..."
            cd /tmp
            curl -LO https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
            unzip -q yazi-x86_64-unknown-linux-gnu.zip
            sudo mv yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
            rm -rf yazi-x86_64-unknown-linux-gnu*
            echo "Yazi installed successfully!"
        else
            echo "Skipping Yazi installation. You can install it later from:"
            echo "  https://github.com/sxyazi/yazi/releases"
        fi
        ;;
        
    arch|manjaro)
        echo "Installing for Arch Linux..."
        
        echo "Installing system packages..."
        sudo pacman -S --noconfirm --needed \
            lua-language-server \
            bash-language-server \
            clang \
            nodejs \
            npm \
            typescript-language-server \
            python-pip \
            wget \
            unzip
        
        echo "Installing Node-based LSP servers..."
        sudo npm install -g \
            vscode-langservers-extracted
        
        echo "Installing CMake LSP via pip..."
        pip install --user cmake-language-server
        
        echo ""
        echo "=============================="
        echo "Optional: Install Yazi file manager"
        echo "=============================="
        read -p "Would you like to install Yazi? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Installing Yazi..."
            sudo pacman -S --noconfirm yazi
            echo "Yazi installed successfully!"
        else
            echo "Skipping Yazi installation. Install later with: sudo pacman -S yazi"
        fi
        ;;
        
    ubuntu|debian|pop)
        echo "Installing for Ubuntu / Debian..."
        
        echo "Updating package list..."
        sudo apt update
        
        echo "Installing system packages..."
        sudo apt install -y \
            lua-language-server \
            bash-language-server \
            clangd \
            nodejs \
            npm \
            python3-pip \
            wget \
            unzip
        
        echo "Installing Node-based LSP servers..."
        sudo npm install -g \
            typescript \
            typescript-language-server \
            vscode-langservers-extracted
        
        echo "Installing CMake LSP via pip..."
        pip3 install --user cmake-language-server
        
        echo ""
        echo "=============================="
        echo "Optional: Install Yazi file manager"
        echo "=============================="
        read -p "Would you like to install Yazi? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Checking for cargo..."
            if command -v cargo &> /dev/null; then
                echo "Installing Yazi via cargo..."
                cargo install --locked yazi-fm
                echo "Yazi installed successfully!"
            else
                echo "Cargo not found. Installing Yazi from binary..."
                cd /tmp
                curl -LO https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
                unzip -q yazi-x86_64-unknown-linux-gnu.zip
                sudo mv yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
                rm -rf yazi-x86_64-unknown-linux-gnu*
                echo "Yazi installed successfully!"
            fi
        else
            echo "Skipping Yazi installation. Install later with:"
            echo "  cargo install --locked yazi-fm"
            echo "  OR download from: https://github.com/sxyazi/yazi/releases"
        fi
        ;;
        
    *)
        echo "Unsupported distribution: $DISTRO"
        echo "Please install LSP servers manually."
        exit 1
        ;;
esac

echo ""
echo "=============================="
echo "Installing CodeLLDB (Debug Adapter)"
echo "=============================="

echo "Creating CodeLLDB directory..."
mkdir -p ~/.local/share/codelldb
cd ~/.local/share/codelldb

echo "Downloading CodeLLDB..."
wget -q https://github.com/vadimcn/codelldb/releases/download/v1.10.0/codelldb-x86_64-linux.vsix

echo "Extracting..."
unzip -q codelldb-x86_64-linux.vsix

echo "Setting permissions..."
chmod +x extension/adapter/codelldb

echo "Testing CodeLLDB installation..."
if ./extension/adapter/codelldb --version > /dev/null 2>&1; then
    echo "✓ CodeLLDB installed successfully!"
else
    echo "✗ CodeLLDB installation may have issues"
fi

echo ""
echo "=============================="
echo "Installation complete!"
echo ""
echo "Installed LSP servers:"
echo "  - lua_ls (Lua)"
echo "  - bashls (Bash)"
echo "  - clangd (C++)"
echo "  - ts_ls (JavaScript/TypeScript)"
echo "  - html (HTML)"
echo "  - cssls (CSS)"
echo "  - cmake-language-server (CMake)"
echo ""
echo "Installed Debug Adapters:"
echo "  - CodeLLDB (C/C++/Rust) at ~/.local/share/codelldb"
echo ""
if command -v yazi &> /dev/null; then
    echo "  ✓ Yazi file manager installed"
else
    echo "  ✗ Yazi not installed (optional)"
fi
echo ""
echo "IMPORTANT: Add pip local bin to PATH"
echo "Add this to your ~/.bashrc or ~/.zshrc:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
echo ""
echo "Then reload your shell: source ~/.bashrc"
echo ""
echo "Next steps:"
echo "  1. Reload shell to get cmake-language-server in PATH"
echo "  2. Start Neovim: nvim"
echo "  3. Wait for plugins to download (first launch only)"
echo "  4. Install Treesitter parsers: :TSInstall c cpp cmake bash lua javascript html css"
echo "  5. Check LSP status in a C++ file: :lua print(vim.inspect(vim.lsp.get_clients()))"
echo ""
echo "Press <Space> in Neovim to see all keybindings with which-key!"