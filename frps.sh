#!/usr/bin/env bash
# ============================================================
# Project: frps-installer
# Description: FRP server one-click installer and service manager
# Repository: https://github.com/87730/frps-installer
# ============================================================

set -o pipefail

# 1. Paths & Constants
FRPS_BIN="/usr/local/bin/frps"
CONFIG_DIR="/etc/frp"
CONFIG_FILE="/etc/frp/frps.toml"
SERVICE_FILE="/etc/systemd/system/frps.service"
ADMIN_SCRIPT="/usr/local/bin/frps-admin"
TMP_DIR="/tmp/frps-installer"

# 2. Colors & Prefixes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

msg_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
msg_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
msg_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
msg_err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# 3. Root check
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            msg_info "Non-root user detected. Escalating via sudo..."
            exec sudo bash "$0" "$@"
        else
            msg_err "This script requires root privileges. Please run as root or install sudo."
            exit 1
        fi
    fi
}

# 4. Dependency installation
install_dependencies() {
    msg_info "Checking necessary dependencies..."
    local deps=("curl" "tar" "wget")
    local needed=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            needed+=("$dep")
        fi
    done

    if [ ${#needed[@]} -eq 0 ]; then
        return 0
    fi

    msg_info "Installing missing dependencies: ${needed[*]}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y "${needed[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${needed[@]}"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "${needed[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "${needed[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        zypper install -y "${needed[@]}"
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache "${needed[@]}"
    else
        msg_warn "Package manager not identified. Please ensure curl, tar, and wget are installed."
    fi
}

# 5. Architecture detection
detect_arch() {
    local raw_arch
    raw_arch="$(uname -m)"
    case "$raw_arch" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv7)  echo "arm" ;;
        armv6l|armv6)  echo "arm" ;;
        i386|i686)     echo "386" ;;
        riscv64)       echo "riscv64" ;;
        *)             echo "unsupported" ;;
    esac
}

# 6. Version detection
get_latest_version() {
    local ver
    ver="$(curl -sSL --connect-timeout 8 https://api.github.com/repos/fatedier/frp/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    if [ -z "$ver" ]; then
        # Fallback version if API limit reached or network blocked
        ver="0.61.1"
    fi
    echo "$ver"
}

# 7. Check if installed
is_installed() {
    if [ -f "$FRPS_BIN" ] && [ -f "$SERVICE_FILE" ]; then
        return 0
    fi
    return 1
}

# 8. Status display
get_service_status() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "${YELLOW}systemd not available${NC}"
        return
    fi

    if systemctl is-active --quiet frps; then
        echo -e "${GREEN}Running (Active)${NC}"
    elif [ -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}Stopped (Inactive)${NC}"
    else
        echo -e "${RED}Not installed${NC}"
    fi
}

# 9. Install core logic
install_frps() {
    echo ""
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo -e "${CYAN}             FRPS Installation Process                      ${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"

    install_dependencies

    local arch
    arch="$(detect_arch)"
    if [ "$arch" = "unsupported" ]; then
        msg_err "Unsupported CPU architecture: $(uname -m)"
        exit 1
    fi
    msg_info "Detected architecture: $arch"

    msg_info "Fetching latest FRP version..."
    local version
    version="$(get_latest_version)"
    msg_info "Target FRP version: v$version"

    local archive_name="frp_${version}_linux_${arch}.tar.gz"
    local dl_url="https://github.com/fatedier/frp/releases/download/v${version}/${archive_name}"
    local mirror_url="https://ghproxy.net/${dl_url}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || exit 1

    msg_info "Downloading FRP binary package..."
    if ! curl -fL --connect-timeout 10 --retry 2 "$dl_url" -o "$archive_name"; then
        msg_warn "Direct download from GitHub failed or timed out. Trying mirror acceleration..."
        if ! curl -fL --connect-timeout 15 --retry 2 "$mirror_url" -o "$archive_name"; then
            msg_err "Failed to download frp package from both official and mirror sources."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi

    msg_info "Extracting package..."
    tar -zxf "$archive_name"
    local extracted_dir="frp_${version}_linux_${arch}"
    if [ ! -d "$extracted_dir" ]; then
        msg_err "Extraction failed: directory $extracted_dir not found."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Install binary
    msg_info "Installing binary to $FRPS_BIN..."
    cp -f "$extracted_dir/frps" "$FRPS_BIN"
    chmod +x "$FRPS_BIN"

    # Setup config
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        msg_info "Generating default configuration at $CONFIG_FILE..."
        local token
        token="$(head -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)"
        cat > "$CONFIG_FILE" <<EOF
# frps configuration
# Documentation: https://gofrp.org/docs/examples/

bindPort = 7000

# Authentication token for clients
auth.token = "${token}"

# Dashboard configuration (optional)
# webServer.addr = "0.0.0.0"
# webServer.port = 7500
# webServer.user = "admin"
# webServer.password = "admin123"

# Log configuration
log.to = "/var/log/frps.log"
log.level = "info"
log.maxDays = 3
EOF
        msg_ok "Configuration generated with bindPort = 7000 and auth.token = $token"
    else
        msg_info "Existing configuration found at $CONFIG_FILE (preserved)."
    fi

    # Setup systemd service
    msg_info "Configuring systemd service ($SERVICE_FILE)..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=FRP Server Daemon
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=$FRPS_BIN -c $CONFIG_FILE
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # Setup management command shortcut
    cp -f "$0" "$ADMIN_SCRIPT" 2>/dev/null || true
    chmod +x "$ADMIN_SCRIPT" 2>/dev/null || true

    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable frps >/dev/null 2>&1
        systemctl restart frps
        msg_ok "FRPS service enabled and started successfully!"
    else
        msg_warn "systemd not available in this environment. Please start manually:"
        msg_warn "  $FRPS_BIN -c $CONFIG_FILE &"
    fi

    # Cleanup
    rm -rf "$TMP_DIR"

    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}             Installation Completed Successfully           ${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo "  Binary Path    : $FRPS_BIN"
    echo "  Config File    : $CONFIG_FILE"
    echo "  Default Port   : 7000 (Please ensure port 7000 is open in firewall)"
    echo "  Admin Command  : frps-admin"
    echo "============================================================"
    echo ""
}

# 10. Uninstall logic
uninstall_frps() {
    echo ""
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${RED}             Uninstalling FRPS                              ${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"

    read -rp "Are you sure you want to completely uninstall FRPS? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        msg_info "Uninstallation canceled."
        return 0
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop frps >/dev/null 2>&1 || true
        systemctl disable frps >/dev/null 2>&1 || true
        msg_ok "Service stopped and disabled."
    fi

    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        msg_ok "Service file removed: $SERVICE_FILE"
    fi

    if [ -f "$FRPS_BIN" ]; then
        rm -f "$FRPS_BIN"
        msg_ok "Binary removed: $FRPS_BIN"
    fi

    if [ -f "$ADMIN_SCRIPT" ]; then
        rm -f "$ADMIN_SCRIPT"
    fi

    if [ -d "$CONFIG_DIR" ]; then
        read -rp "Remove configuration directory ($CONFIG_DIR)? (y/N): " del_conf
        if [[ "$del_conf" =~ ^[yY]$ ]]; then
            rm -rf "$CONFIG_DIR"
            msg_ok "Configuration removed: $CONFIG_DIR"
        else
            msg_info "Configuration preserved at $CONFIG_DIR"
        fi
    fi

    msg_ok "FRPS has been completely removed from the system."
}

# 11. Service control functions
start_service() {
    if systemctl is-active --quiet frps; then
        msg_warn "FRPS service is already running."
    else
        systemctl start frps
        msg_ok "FRPS service started."
    fi
}

stop_service() {
    if ! systemctl is-active --quiet frps; then
        msg_warn "FRPS service is already stopped."
    else
        systemctl stop frps
        msg_ok "FRPS service stopped."
    fi
}

restart_service() {
    systemctl restart frps
    msg_ok "FRPS service restarted."
}

view_logs() {
    msg_info "Showing recent logs (Ctrl+C to exit)..."
    journalctl -u frps -n 50 -f
}

view_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}--- Current Config ($CONFIG_FILE) ---${NC}"
        cat "$CONFIG_FILE"
        echo -e "${CYAN}-----------------------------------------${NC}"
    else
        msg_err "Configuration file not found: $CONFIG_FILE"
    fi
}

# 12. Interactive management menu
show_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}============================================================${NC}"
        echo -e "${CYAN}                  FRPS Management Console                   ${NC}"
        echo -e "${BLUE}============================================================${NC}"
        echo -n "  Status: "
        get_service_status
        echo -e "${BLUE}------------------------------------------------------------${NC}"
        echo "  1. Start Service"
        echo "  2. Restart Service"
        echo "  3. Stop Service"
        echo "  4. View Recent Logs"
        echo "  5. View Configuration File"
        echo "  6. Reinstall / Update FRPS"
        echo "  7. Uninstall FRPS"
        echo "  0. Exit"
        echo -e "${BLUE}============================================================${NC}"
        read -rp "Please select an option [0-7]: " choice

        case "$choice" in
            1) start_service ;;
            2) restart_service ;;
            3) stop_service ;;
            4) view_logs ;;
            5) view_config ;;
            6) install_frps ;;
            7) uninstall_frps; break ;;
            0) exit 0 ;;
            *) msg_warn "Invalid selection. Please enter 0-7." ;;
        esac
    done
}

# 13. Main entry point
main() {
    check_root

    # If parameters given (non-interactive shortcuts)
    case "$1" in
        install)   install_frps; exit 0 ;;
        uninstall) uninstall_frps; exit 0 ;;
        start)     start_service; exit 0 ;;
        stop)      stop_service; exit 0 ;;
        restart)   restart_service; exit 0 ;;
        status)    get_service_status; exit 0 ;;
        config)    view_config; exit 0 ;;
        logs)      view_logs; exit 0 ;;
    esac

    # Interactive mode: if already installed, open menu; otherwise install
    if is_installed; then
        show_menu
    else
        install_frps
    fi
}

main "$@"
