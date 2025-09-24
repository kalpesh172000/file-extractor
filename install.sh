#!/bin/bash

# File Extractor Installation Script
# This script installs the file-extractor CLI tool on Ubuntu/Debian systems

set -e

BINARY_NAME="file-extractor"
INSTALL_DIR="/usr/local/bin"
REPO_URL="https://github.com/yourusername/file-extractor"
VERSION="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "This script should not be run as root. Please run as a regular user."
        print_warning "The script will use sudo when necessary."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if Go is installed
    if ! command -v go >/dev/null 2>&1; then
        print_status "Go is not installed. Installing Go..."
        install_go
    fi
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    print_status "Cloning repository..."
    if git clone "$REPO_URL" .; then
        print_success "Repository cloned"
    else
        print_error "Failed to clone repository"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    print_status "Building binary..."
    if go build -o "$BINARY_NAME" .; then
        print_success "Build completed"
    else
        print_error "Build failed"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    print_status "Installing binary to ${INSTALL_DIR}..."
    sudo cp "$BINARY_NAME" "${INSTALL_DIR}/"
    sudo chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    print_success "Installation from source completed!"
}

# Install Go if not present
install_go() {
    print_status "Installing Go..."
    
    local go_version="1.21.0"
    local go_arch
    case $(uname -m) in
        x86_64) go_arch="amd64" ;;
        aarch64) go_arch="arm64" ;;
        armv7l) go_arch="armv6l" ;;
        *) 
            print_error "Unsupported architecture for Go installation"
            exit 1
            ;;
    esac
    
    local go_package="go${go_version}.linux-${go_arch}.tar.gz"
    local go_url="https://golang.org/dl/${go_package}"
    
    print_status "Downloading Go ${go_version}..."
    curl -fsSL "$go_url" -o "/tmp/${go_package}"
    
    print_status "Installing Go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${go_package}"
    
    # Add Go to PATH if not already there
    if ! echo "$PATH" | grep -q "/usr/local/go/bin"; then
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile > /dev/null
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    rm "/tmp/${go_package}"
    print_success "Go installation completed"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local version_output
        version_output=$($BINARY_NAME --version 2>/dev/null || echo "unknown")
        print_success "Installation verified: $version_output"
        
        print_status "Testing basic functionality..."
        if $BINARY_NAME --help >/dev/null 2>&1; then
            print_success "Basic functionality test passed"
        else
            print_warning "Installation successful but basic test failed"
        fi
    else
        print_error "Installation verification failed"
        print_error "Binary not found in PATH"
        exit 1
    fi
}

# Uninstall function
uninstall() {
    print_status "Uninstalling ${BINARY_NAME}..."
    
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        sudo rm "${INSTALL_DIR}/${BINARY_NAME}"
        print_success "Uninstallation completed"
    else
        print_warning "Binary not found, nothing to uninstall"
    fi
}

# Show usage
show_usage() {
    echo "File Extractor Installation Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo "  --help, -h          Show this help message"
    echo "  --uninstall, -u     Uninstall the tool"
    echo "  --version VERSION   Install specific version (default: latest)"
    echo "  --source, -s        Force installation from source"
    echo "  --check, -c         Check if tool is already installed"
    echo
    echo "EXAMPLES:"
    echo "  $0                  # Install latest version"
    echo "  $0 --version 1.0.0  # Install specific version"
    echo "  $0 --source         # Install from source"
    echo "  $0 --uninstall      # Uninstall"
    echo "  $0 --check          # Check installation"
}

# Check if already installed
check_installation() {
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local current_version
        current_version=$($BINARY_NAME --version 2>/dev/null || echo "unknown version")
        print_success "File Extractor is already installed: $current_version"
        print_status "Location: $(which $BINARY_NAME)"
        return 0
    else
        print_warning "File Extractor is not installed"
        return 1
    fi
}

# Main installation function
main() {
    local force_source=false
    local check_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --uninstall|-u)
                uninstall
                exit 0
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --source|-s)
                force_source=true
                shift
                ;;
            --check|-c)
                check_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Show header
    echo "=========================================="
    echo "  File Extractor Installation Script"
    echo "=========================================="
    echo
    
    if [ "$check_only" = true ]; then
        check_installation
        exit $?
    fi
    
    # Run installation steps
    check_root
    check_requirements
    
    # Check if already installed
    if check_installation; then
        read -p "File Extractor is already installed. Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Install
    if [ "$force_source" = true ]; then
        install_from_source
    else
        if ! install_from_release; then
            print_warning "Release installation failed, trying source installation..."
            install_from_source
        fi
    fi
    
    verify_installation
    
    echo
    echo "=========================================="
    print_success "Installation completed successfully!"
    echo "=========================================="
    echo
    print_status "You can now use the '${BINARY_NAME}' command from anywhere."
    print_status "Try '${BINARY_NAME} --help' to see all available options."
    echo
    print_status "Example usage:"
    echo "  ${BINARY_NAME} -d ./myproject -ie '.go,.py,.js' -ed 'node_modules,.git'"
    echo
}

# Run main function with all arguments
main "$@" we're on a supported system
    if [[ ! -f /etc/debian_version ]] && [[ ! -f /etc/lsb-release ]]; then
        print_error "This installer is designed for Ubuntu/Debian systems."
        exit 1
    fi
    
    # Check if required tools are available
    local missing_tools=()
    
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")
    command -v tar >/dev/null 2>&1 || missing_tools+=("tar")
    command -v sudo >/dev/null 2>&1 || missing_tools+=("sudo")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Installing missing tools..."
        sudo apt-get update
        sudo apt-get install -y "${missing_tools[@]}"
    fi
    
    print_success "System requirements satisfied"
}

# Install from pre-built binary (GitHub releases)
install_from_release() {
    print_status "Installing from GitHub releases..."
    
    # Detect architecture
    local arch
    case $(uname -m) in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *) 
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    local os="linux"
    local filename="${BINARY_NAME}-${os}-${arch}"
    local download_url
    
    if [ "$VERSION" = "latest" ]; then
        download_url="${REPO_URL}/releases/latest/download/${filename}"
    else
        download_url="${REPO_URL}/releases/download/v${VERSION}/${filename}"
    fi
    
    print_status "Downloading ${filename}..."
    local temp_dir=$(mktemp -d)
    
    if curl -fsSL "$download_url" -o "${temp_dir}/${BINARY_NAME}"; then
        print_success "Download completed"
    else
        print_error "Failed to download binary. Falling back to source installation."
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install binary
    print_status "Installing binary to ${INSTALL_DIR}..."
    chmod +x "${temp_dir}/${BINARY_NAME}"
    sudo cp "${temp_dir}/${BINARY_NAME}" "${INSTALL_DIR}/"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    print_success "Installation completed!"
    return 0
}

# Install from source
install_from_source() {
    print_status "Installing from source..."
    
    # Check if
