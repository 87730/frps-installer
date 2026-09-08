#!/usr/bin/env bash
# ============================================================
# Project: frps-installer
# Description: FRP server one-click installer and service manager
#              FRP 服务端一键安装与系统服务管理脚本
# Repository: https://github.com/87730/frps-installer
# ============================================================

set -o pipefail

# 1. Paths & Constants / 路径与常量
FRPS_BIN="/usr/local/bin/frps"
CONFIG_DIR="/etc/frp"
CONFIG_FILE="/etc/frp/frps.toml"
SERVICE_FILE="/etc/systemd/system/frps.service"
ADMIN_SCRIPT="/usr/local/bin/frps-admin"
TMP_DIR="/tmp/frps-installer"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh"
MIRROR_SCRIPT_URL="https://ghproxy.net/https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh"

# 2. Colors & Prefixes / 颜色与前缀定义
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

# 3. Root check / 权限检查
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            msg_info "检测到非 root 用户，尝试通过 sudo 提权... / Non-root user detected. Escalating via sudo..."
            exec sudo bash "$0" "$@"
        else
            msg_err "此脚本需要 root 权限，请以 root 身份运行或安装 sudo。 / This script requires root privileges."
            exit 1
        fi
    fi
}

# 4. Dependency installation / 安装必要依赖
install_dependencies() {
    msg_info "检查系统依赖环境... / Checking system dependencies..."
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

    msg_info "正在安装缺失依赖: ${needed[*]} / Installing dependencies..."
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
        msg_warn "未能识别包管理器，请确保 curl、tar 和 wget 已安装。 / Please ensure curl, tar, and wget are installed."
    fi
}

# 5. Architecture detection / 架构检测
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

# 6. Version detection / 获取最新版本号 (优先302重定向，防API限流)
get_latest_version() {
    local ver=""
    local redirected_url

    # 方式一：通过 GitHub Release 页面 302 重定向获取
    redirected_url="$(curl -fsSL -o /dev/null -w "%{url_effective}" --connect-timeout 8 https://github.com/fatedier/frp/releases/latest 2>/dev/null)"
    if [ -n "$redirected_url" ]; then
        ver="$(basename "$redirected_url" | sed -E 's/^v//')"
    fi

    # 方式二：备选走 GitHub API
    if [ -z "$ver" ]; then
        ver="$(curl -sSL --connect-timeout 8 https://api.github.com/repos/fatedier/frp/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    fi

    # 方式三：国内镜像源检测重定向
    if [ -z "$ver" ]; then
        redirected_url="$(curl -fsSL -o /dev/null -w "%{url_effective}" --connect-timeout 8 https://ghproxy.net/https://github.com/fatedier/frp/releases/latest 2>/dev/null)"
        if [ -n "$redirected_url" ]; then
            ver="$(basename "$redirected_url" | sed -E 's/^v//')"
        fi
    fi

    # 兜底已知稳定新版
    if [ -z "$ver" ] || [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        ver="0.71.0"
    fi
    echo "$ver"
}

# 7. Check if installed / 检查是否已安装
is_installed() {
    if [ -f "$FRPS_BIN" ] && [ -f "$SERVICE_FILE" ]; then
        return 0
    fi
    return 1
}

# 8. Status display / 获取服务运行状态
get_service_status() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo -e "${YELLOW}systemd 不可用 / systemd not available${NC}"
        return
    fi

    if systemctl is-active --quiet frps; then
        echo -e "${GREEN}运行中 / Running (Active)${NC}"
    elif [ -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}已停止 / Stopped (Inactive)${NC}"
    else
        echo -e "${RED}未安装 / Not installed${NC}"
    fi
}

# 9. Install core logic / 核心安装流程 (流派A：纯净无横线排版)
install_frps() {
    echo ""
    echo -e "${CYAN}  FRPS 服务端安装 / Starting FRPS Installation${NC}"
    echo ""

    install_dependencies

    local arch
    arch="$(detect_arch)"
    if [ "$arch" = "unsupported" ]; then
        msg_err "不支持的系统架构 / Unsupported CPU architecture: $(uname -m)"
        exit 1
    fi
    msg_info "检测到硬件架构 / Detected architecture: $arch"

    msg_info "获取 FRP 最新版本号 / Fetching latest FRP version..."
    local version
    version="$(get_latest_version)"
    msg_info "安装版本 / Installing FRP version: v$version"

    local archive_name="frp_${version}_linux_${arch}.tar.gz"
    local dl_url="https://github.com/fatedier/frp/releases/download/v${version}/${archive_name}"
    local mirror_url="https://ghproxy.net/${dl_url}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || exit 1

    msg_info "下载 FRP 二进制压缩包 / Downloading FRP package..."
    if ! curl -fL --connect-timeout 10 --retry 2 "$dl_url" -o "$archive_name"; then
        msg_warn "官方源下载超时，自动切换至国内镜像加速 / Retrying with mirror acceleration..."
        if ! curl -fL --connect-timeout 15 --retry 2 "$mirror_url" -o "$archive_name"; then
            msg_err "官方源及加速源均下载失败，请检查网络连接 / Download failed from all sources."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi

    msg_info "解压二进制程序 / Extracting package..."
    tar -zxf "$archive_name"
    local extracted_dir="frp_${version}_linux_${arch}"
    if [ ! -d "$extracted_dir" ]; then
        msg_err "解压失败，未找到目录 / Extraction failed: $extracted_dir not found."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # 安装二进制程序
    msg_info "安装核心二进制到 / Installing binary: $FRPS_BIN..."
    cp -f "$extracted_dir/frps" "$FRPS_BIN"
    chmod +x "$FRPS_BIN"

    # 初始化配置目录与默认配置
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        msg_info "正在生成默认配置文件 / Generating default config: $CONFIG_FILE..."
        local token
        token="$(head -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)"
        cat > "$CONFIG_FILE" <<EOF
# frps configuration
# 文档 / Documentation: https://gofrp.org/docs/examples/

bindPort = 7000

# 客户端连接认证 Token / Client authentication token
auth.token = "${token}"

# 控制台仪表盘配置 (可选) / Dashboard configuration (optional)
# webServer.addr = "0.0.0.0"
# webServer.port = 7500
# webServer.user = "admin"
# webServer.password = "admin123"

# 日志配置 / Log configuration
log.to = "/var/log/frps.log"
log.level = "info"
log.maxDays = 3
EOF
        msg_ok "配置文件已生成 (默认端口: 7000, 随机通信Token: $token)"
    else
        msg_info "检测到已存在配置文件，保留原有配置 / Existing config preserved."
    fi

    # 配置 systemd 服务守护进程
    msg_info "配置 systemd 服务守护进程 / Configuring systemd service..."
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

    # 注册系统全局管理快捷命令
    if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "-bash" ] && [ "$0" != "sh" ]; then
        cp -f "$0" "$ADMIN_SCRIPT" 2>/dev/null || true
    else
        if ! curl -fsSL --connect-timeout 8 "$RAW_SCRIPT_URL" -o "$ADMIN_SCRIPT" 2>/dev/null; then
            curl -fsSL --connect-timeout 10 "$MIRROR_SCRIPT_URL" -o "$ADMIN_SCRIPT" 2>/dev/null || true
        fi
    fi
    chmod +x "$ADMIN_SCRIPT" 2>/dev/null || true

    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable frps >/dev/null 2>&1
        systemctl restart frps
        msg_ok "FRPS 服务已启动并设置开机自启 / Service enabled and started!"
    else
        msg_warn "当前环境不支持 systemd，请手动运行 / Please start manually:"
        msg_warn "  $FRPS_BIN -c $CONFIG_FILE &"
    fi

    # 清理临时文件
    rm -rf "$TMP_DIR"

    echo ""
    echo -e "${GREEN}  FRPS 安装完成 / Installation Completed${NC}"
    echo "  核心程序 / Binary Path : $FRPS_BIN"
    echo "  配置文件 / Config File : $CONFIG_FILE"
    echo "  服务端口 / Port        : 7000 (请在安全组及防火墙放行该端口)"
    echo "  管理命令 / Admin CLI   : frps-admin"
    echo ""
}

# 10. Uninstall logic / 卸载逻辑
uninstall_frps() {
    echo ""
    echo -e "${RED}  卸载 FRPS / Uninstalling FRPS${NC}"
    echo ""

    read -rp "  确认彻底卸载 FRPS 吗？/ Are you sure to uninstall? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        msg_info "取消卸载。 / Uninstallation canceled."
        return 0
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop frps >/dev/null 2>&1 || true
        systemctl disable frps >/dev/null 2>&1 || true
        msg_ok "服务已停止并取消开机自启。 / Service stopped and disabled."
    fi

    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        msg_ok "服务文件已清理 / Service file removed: $SERVICE_FILE"
    fi

    if [ -f "$FRPS_BIN" ]; then
        rm -f "$FRPS_BIN"
        msg_ok "程序文件已清理 / Binary removed: $FRPS_BIN"
    fi

    if [ -f "$ADMIN_SCRIPT" ]; then
        rm -f "$ADMIN_SCRIPT"
    fi

    if [ -d "$CONFIG_DIR" ]; then
        read -rp "  是否删除配置目录与数据 / Remove config dir ($CONFIG_DIR)? (y/N): " del_conf
        if [[ "$del_conf" =~ ^[yY]$ ]]; then
            rm -rf "$CONFIG_DIR"
            msg_ok "配置目录已清除 / Configuration removed: $CONFIG_DIR"
        else
            msg_info "保留配置目录 / Configuration preserved: $CONFIG_DIR"
        fi
    fi

    echo ""
    msg_ok "FRPS 已从系统中彻底卸载。 / FRPS uninstalled successfully."
    echo ""
}

# 11. Service control functions / 服务控制函数
start_service() {
    if systemctl is-active --quiet frps; then
        msg_warn "FRPS 服务已在运行中。 / Service is already running."
    else
        systemctl start frps
        msg_ok "FRPS 服务已启动。 / Service started."
    fi
}

stop_service() {
    if ! systemctl is-active --quiet frps; then
        msg_warn "FRPS 服务未在运行。 / Service is already stopped."
    else
        systemctl stop frps
        msg_ok "FRPS 服务已停止。 / Service stopped."
    fi
}

restart_service() {
    systemctl restart frps
    msg_ok "FRPS 服务已重启。 / Service restarted."
}

view_logs() {
    msg_info "正在输出最近日志 (按 Ctrl+C 退出) / Streaming logs (Ctrl+C to exit)..."
    journalctl -u frps -n 50 -f
}

view_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e "${CYAN}  配置文件内容 / Config Content ($CONFIG_FILE):${NC}"
        cat "$CONFIG_FILE"
        echo ""
    else
        msg_err "未找到配置文件 / Config file not found: $CONFIG_FILE"
    fi
}

edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        msg_err "未找到配置文件 / Config file not found: $CONFIG_FILE"
        return 1
    fi

    local editor="vi"
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    fi

    msg_info "正在使用 $editor 编辑配置文件... / Opening config with $editor..."
    "$editor" "$CONFIG_FILE"

    echo ""
    read -rp "  配置已修改，是否重启 FRPS 服务以生效？/ Restart service now? (Y/n): " restart_confirm
    if [[ ! "$restart_confirm" =~ ^[nN]$ ]]; then
        restart_service
    fi
}

# 12. Interactive management menu / 交互式管理菜单 (流派A：极简空行排版，绝不折行)
show_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}  FRPS 管理面板 / Management Console${NC}"
        echo -n "  状态 / Status: "
        get_service_status
        echo ""
        echo "  1. 启动服务 / Start Service"
        echo "  2. 重启服务 / Restart Service"
        echo "  3. 停止服务 / Stop Service"
        echo "  4. 实时日志 / View Recent Logs"
        echo "  5. 查看配置 / View Configuration File"
        echo "  6. 修改配置 / Edit Configuration File"
        echo "  7. 重装更新 / Reinstall or Update FRPS"
        echo "  8. 彻底卸载 / Uninstall FRPS"
        echo "  0. 退出面板 / Exit"
        echo ""
        read -rp "  请选择操作 / Select option [0-8]: " choice

        case "$choice" in
            1) start_service ;;
            2) restart_service ;;
            3) stop_service ;;
            4) view_logs ;;
            5) view_config ;;
            6) edit_config ;;
            7) install_frps ;;
            8) uninstall_frps; break ;;
            0) exit 0 ;;
            *) msg_warn "无效选项，请输入 0-8。 / Invalid selection [0-8]." ;;
        esac
    done
}

# 13. Main entry point / 主入口
main() {
    check_root

    # 非交互式参数直通
    case "$1" in
        install)   install_frps; exit 0 ;;
        uninstall) uninstall_frps; exit 0 ;;
        start)     start_service; exit 0 ;;
        stop)      stop_service; exit 0 ;;
        restart)   restart_service; exit 0 ;;
        status)    get_service_status; exit 0 ;;
        config)    view_config; exit 0 ;;
        edit)      edit_config; exit 0 ;;
        logs)      view_logs; exit 0 ;;
    esac

    # 交互模式：已安装则展示菜单，未安装则执行安装
    if is_installed; then
        show_menu
    else
        install_frps
    fi
}

main "$@"
