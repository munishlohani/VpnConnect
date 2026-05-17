#!/bin/bash

# ============================================
# VPNConnect Installer
# ============================================

# This script is only applicable for MacOS and Linux
set -e

# Guard against environment leakage when the installer is launched from another
# Python-driven tool session (e.g. Hermes terminal tool). A pre-set PYTHONPATH
# can force pip/entrypoints to import a different checkout than the one being
# installed, which makes fresh installs appear broken or stale.
if [ -n "${PYTHONPATH:-}" ]; then
    echo "⚠ Ignoring inherited PYTHONPATH during install to avoid module shadowing"
    unset PYTHONPATH
fi
if [ -n "${PYTHONHOME:-}" ]; then
    echo "⚠ Ignoring inherited PYTHONHOME during install"
    unset PYTHONHOME
fi

# Prevent uv from discovering config files (uv.toml, pyproject.toml) from the
# wrong user's home directory when running under sudo -u <user>.  See #21269.
export UV_NO_CONFIG=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configs
REPO_URL_SSH="git@github.com:munishlohani/VpnConnect.git"
REPO_URL_HTTPS="https://github.com/munishlohani/VpnConnect.git"
INSTALL_DIR=""

# Options
USE_VENV=true
BRANCH="main"
PYTHON_VERSION="3.11"

# Tracking variables
UV_CMD=""
PYTHON_PATH=""
PYTHON_FOUND_VERSION=""

# Detect non-interactive mode (e.g. curl | bash)
# When stdin is not a terminal, read -p will fail with EOF,
# causing set -e to silently abort the entire script.
if [ -t 0 ]; then
    IS_INTERACTIVE=true
else
    IS_INTERACTIVE=false
fi

# Detect OS and distro
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if command -v lsb_release &> /dev/null; then
            DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        elif [ -f /etc/os-release ]; then
            DISTRO=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        else
            DISTRO="unknown"
        fi
        # Check for Termux
        if [[ "$PREFIX" == *"termux"* ]]; then
            DISTRO="termux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        DISTRO="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
        DISTRO="windows"
    else
        OS="unknown"
        DISTRO="unknown"
    fi
}

print_banner() {
    echo ""
    echo -e "${MAGENTA}${BOLD}"
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│               VPNConnect Installer                      │"
    echo "├─────────────────────────────────────────────────────────┤"
    echo "│ An open source Cisco AnyConnect Compatible VPN Client   │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_completion_banner() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│            Installation Complete! 🎉                    │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

log_info() {
    echo -e "${CYAN}→${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ask_install_dir() {
    local default_dir="${HOME}/VPNConnect"
    
    echo ""
    log_info "Where would you like to install VPNConnect?"
    echo -e "  ${CYAN}Default: $default_dir${NC}"
    
    if [ "$IS_INTERACTIVE" = true ]; then
        read -p "  Enter installation directory (or press Enter for default): " user_dir
        
        if [ -z "$user_dir" ]; then
            INSTALL_DIR="$default_dir"
        else
            # Expand ~ to home directory
            INSTALL_DIR="${user_dir/#\~/$HOME}"
        fi
    else
        # Non-interactive mode, use default
        INSTALL_DIR="$default_dir"
    fi
    
    log_success "Installation directory: $INSTALL_DIR"
}

# ============================================================================
# Dependency checks
# ============================================================================

install_uv() {
    if [ "$DISTRO" = "termux" ]; then
        log_info "Termux detected — using Python's stdlib venv + pip instead of uv"
        UV_CMD=""
        return 0
    fi

    log_info "Checking for uv package manager..."

    # Check common locations for uv
    if command -v uv &> /dev/null; then
        UV_CMD="uv"
        UV_VERSION=$($UV_CMD --version 2>/dev/null)
        log_success "uv found ($UV_VERSION)"
        return 0
    fi

    # Check ~/.local/bin (default uv install location) even if not on PATH yet
    if [ -x "$HOME/.local/bin/uv" ]; then
        UV_CMD="$HOME/.local/bin/uv"
        UV_VERSION=$($UV_CMD --version 2>/dev/null)
        log_success "uv found at ~/.local/bin ($UV_VERSION)"
        return 0
    fi

    # Check ~/.cargo/bin (alternative uv install location)
    if [ -x "$HOME/.cargo/bin/uv" ]; then
        UV_CMD="$HOME/.cargo/bin/uv"
        UV_VERSION=$($UV_CMD --version 2>/dev/null)
        log_success "uv found at ~/.cargo/bin ($UV_VERSION)"
        return 0
    fi

    # Install uv
    log_info "Installing uv (fast Python package manager)..."
    local _uv_install_log _uv_installer
    _uv_install_log="$(mktemp 2>/dev/null || echo "/tmp/vpnconnect-uv-install.$$.log")"
    _uv_installer="$(mktemp 2>/dev/null || echo "/tmp/vpnconnect-uv-installer.$$.sh")"
    
    if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
        log_error "Failed to download uv installer from https://astral.sh/uv/install.sh"
        log_info "curl output:"
        sed 's/^/    /' "$_uv_install_log" >&2
        log_info "Install manually: https://docs.astral.sh/uv/getting-started/installation/"
        rm -f "$_uv_install_log" "$_uv_installer"
        exit 1
    fi
    
    if sh "$_uv_installer" >>"$_uv_install_log" 2>&1; then
        rm -f "$_uv_installer"
        # uv installs to ~/.local/bin by default
        if [ -x "$HOME/.local/bin/uv" ]; then
            UV_CMD="$HOME/.local/bin/uv"
        elif [ -x "$HOME/.cargo/bin/uv" ]; then
            UV_CMD="$HOME/.cargo/bin/uv"
        elif command -v uv &> /dev/null; then
            UV_CMD="uv"
        else
            log_error "uv installer reported success but binary not found on PATH"
            log_info "Installer output:"
            sed 's/^/    /' "$_uv_install_log" >&2
            log_info "Try adding ~/.local/bin to your PATH and re-running"
            rm -f "$_uv_install_log"
            exit 1
        fi
        rm -f "$_uv_install_log"
        UV_VERSION=$($UV_CMD --version 2>/dev/null)
        log_success "uv installed ($UV_VERSION)"
    else
        log_error "Failed to install uv"
        log_info "Installer output:"
        sed 's/^/    /' "$_uv_install_log" >&2
        log_info "Install manually: https://docs.astral.sh/uv/getting-started/installation/"
        rm -f "$_uv_install_log" "$_uv_installer"
        exit 1
    fi
}

check_python() {
    if [ "$DISTRO" = "termux" ]; then
        log_info "Checking Termux Python (>= 3.11)..."
        if command -v python >/dev/null 2>&1; then
            PYTHON_PATH="$(command -v python)"
            if "$PYTHON_PATH" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
                PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
                log_success "Python found: $PYTHON_FOUND_VERSION"
                return 0
            fi
        fi

        log_info "Installing Python via pkg..."
        pkg install -y python >/dev/null
        PYTHON_PATH="$(command -v python)"
        PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
        log_success "Python installed: $PYTHON_FOUND_VERSION"
        return 0
    fi

    log_info "Checking Python (>= 3.11)..."

    # First check if any Python >= 3.11 is already available on the system
    # Try python3 first (most common)
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_PATH="$(command -v python3)"
        if "$PYTHON_PATH" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
            PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
            log_success "Python found: $PYTHON_FOUND_VERSION"
            return 0
        fi
    fi

    # Check if python (without 3) is available and meets version requirement
    if command -v python >/dev/null 2>&1; then
        PYTHON_PATH="$(command -v python)"
        if "$PYTHON_PATH" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
            PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
            log_success "Python found: $PYTHON_FOUND_VERSION"
            return 0
        fi
    fi

    # Try python3.11, python3.12, python3.13, etc. (common on macOS with brew)
    for py_version in python3.13 python3.12 python3.11; do
        if command -v "$py_version" >/dev/null 2>&1; then
            PYTHON_PATH="$(command -v $py_version)"
            PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
            log_success "Python found: $PYTHON_FOUND_VERSION"
            return 0
        fi
    done

    # Let uv handle Python — it can download and manage Python versions
    log_info "Python >= 3.11 not found, installing via uv..."
    if "$UV_CMD" python install "$PYTHON_VERSION" 2>&1 | grep -v "^Downloading\|^Installing" | head -20; then
        PYTHON_PATH="$("$UV_CMD" python find "$PYTHON_VERSION")"
        PYTHON_FOUND_VERSION="$("$PYTHON_PATH" --version 2>/dev/null)"
        log_success "Python installed: $PYTHON_FOUND_VERSION"
    else
        log_error "Failed to install Python"
        log_info "Please install Python 3.11 or higher manually, then re-run this script"
        exit 1
    fi
}

check_git() {
    log_info "Checking Git..."

    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        log_success "Git $GIT_VERSION found"
        return 0
    fi

    log_error "Git not found"

    if [ "$DISTRO" = "termux" ]; then
        log_info "Installing Git via pkg..."
        pkg install -y git >/dev/null
        if command -v git >/dev/null 2>&1; then
            GIT_VERSION=$(git --version | awk '{print $3}')
            log_success "Git $GIT_VERSION installed"
            return 0
        fi
    fi

    log_info "Please install Git:"

    case "$OS" in
        linux)
            case "$DISTRO" in
                ubuntu|debian)
                    log_info "  sudo apt update && sudo apt install git"
                    ;;
                fedora)
                    log_info "  sudo dnf install git"
                    ;;
                arch)
                    log_info "  sudo pacman -S git"
                    ;;
                *)
                    log_info "  Use your package manager to install git"
                    ;;
            esac
            ;;
        android)
            log_info "  pkg install git"
            ;;
        macos)
            log_info "  xcode-select --install"
            log_info "  Or: brew install git"
            ;;
    esac

    exit 1
}

# ============================================================================
# Installation
# ============================================================================

clone_repo() {
    log_info "Installing to $INSTALL_DIR..."

    if [ -d "$INSTALL_DIR" ]; then
        if [ -d "$INSTALL_DIR/.git" ]; then
            log_warn "Existing installation found at $INSTALL_DIR"
            log_info "Pulling latest changes..."
            cd "$INSTALL_DIR"
            git pull origin "$BRANCH" 2>/dev/null || log_warn "Could not pull latest changes"
            return 0
        else
            log_error "Directory exists but is not a git repository: $INSTALL_DIR"
            log_info "Remove it or choose a different directory"
            exit 1
        fi
    else
        # Try SSH first (for private repo access), fall back to HTTPS
        # GIT_SSH_COMMAND disables interactive prompts and sets a short timeout
        # so SSH fails fast instead of hanging when no key is configured.
        log_info "Trying SSH clone..."
        if GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
           git clone --branch "$BRANCH" "$REPO_URL_SSH" "$INSTALL_DIR" 2>/dev/null; then
            log_success "Cloned via SSH"
        else
            rm -rf "$INSTALL_DIR" 2>/dev/null  # Clean up partial SSH clone
            log_info "SSH failed, trying HTTPS..."
            if git clone --branch "$BRANCH" "$REPO_URL_HTTPS" "$INSTALL_DIR"; then
                log_success "Cloned via HTTPS"
            else
                log_error "Failed to clone repository"
                log_info "Make sure you have internet connection and the repository is accessible"
                exit 1
            fi
        fi
    fi

    cd "$INSTALL_DIR"
    log_success "Repository ready"
}

setup_venv() {
    if [ "$USE_VENV" = false ]; then
        log_info "Skipping virtual environment (--no-venv)"
        return 0
    fi

    log_info "Creating virtual environment..."

    if [ -d ".venv" ]; then
        log_info "Virtual environment already exists, recreating..."
        rm -rf .venv
    fi

    if [ "$DISTRO" = "termux" ]; then
        # Termux doesn't have uv, use python -m venv
        "$PYTHON_PATH" -m venv .venv
    else
        # Use uv venv with the Python we found
        if [ -n "$PYTHON_PATH" ]; then
            $UV_CMD venv .venv --python "$PYTHON_PATH"
        else
            $UV_CMD venv .venv
        fi
    fi

    log_success "Virtual environment created"
}

install_deps() {
    log_info "Installing VPNConnect and dependencies..."

    # Use uv to install the project as a tool
    if [ "$DISTRO" = "termux" ]; then
        # Termux doesn't have uv, use pip directly
        log_info "Installing with pip..."
        . .venv/bin/activate
        pip install -e . >/dev/null 2>&1
        deactivate
    else
        # Use uv tool install
        $UV_CMD tool install . --with-editable
    fi

    log_success "Dependencies installed"
}

verify_installation() {
    log_info "Verifying installation..."

    # Check if connect-vpn command is available
    if command -v connect-vpn &> /dev/null; then
        log_success "connect-vpn command is available"
        return 0
    fi

    # If not in PATH, check if it's in the venv
    if [ -f "$INSTALL_DIR/.venv/bin/connect-vpn" ]; then
        log_warn "connect-vpn found in virtual environment"
        log_info "To use it, you may need to activate the environment or add it to PATH"
        return 0
    fi

    log_error "Could not verify connect-vpn installation"
    log_info "Try running: source $INSTALL_DIR/.venv/bin/activate"
    exit 1
}

print_next_steps() {
    echo ""
    echo -e "${GREEN}${BOLD}Next Steps:${NC}"
    echo ""
    echo "1. To use VPNConnect, run:"
    echo -e "   ${CYAN}connect-vpn${NC}"
    echo ""
    echo "2. If the command is not found, activate the virtual environment:"
    echo -e "   ${CYAN}source $INSTALL_DIR/.venv/bin/activate${NC}"
    echo ""
    echo "3. Or update your PATH by adding this line to your ~/.bashrc or ~/.zshrc:"
    echo -e "   ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
    echo "4. For more information, visit:"
    echo -e "   ${CYAN}https://github.com/munishlohani/VpnConnect${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_banner

    # Check if running on Windows
    if [ "$OS" = "windows" ]; then
        log_error "This installer is not compatible with Windows"
        log_info "Please use the Windows-specific installer or WSL2"
        exit 1
    fi

    if [ "$OS" = "unknown" ]; then
        log_error "Could not detect your operating system"
        log_info "This installer only supports Linux and macOS"
        exit 1
    fi

    log_info "Detected: $OS ($DISTRO)"
    echo ""

    # Step 0: Ask for installation directory
    ask_install_dir

    # Step 1: Check for Git
    log_step "Step 1/6: Checking Git"
    check_git

    # Step 2: Install/check uv
    log_step "Step 2/6: Installing/Checking Package Manager (uv)"
    install_uv

    # Step 3: Check Python
    log_step "Step 3/6: Installing/Checking Python"
    check_python

    # Step 4: Clone repository
    log_step "Step 4/6: Downloading VPNConnect"
    clone_repo

    # Step 5: Setup virtual environment and install dependencies
    log_step "Step 5/6: Setting Up VPNConnect"
    setup_venv
    install_deps

    # Step 6: Verify installation
    log_step "Step 6/6: Verifying Installation"
    log_info "Verifying installation..."
    verify_installation

    # Print completion banner and next steps
    print_completion_banner
    print_next_steps

    log_success "VPNConnect installer completed successfully!"
}

# Run main function
main
