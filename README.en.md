# frps-installer

A lightweight, automated FRP server (frps) installer and system service manager for Linux.

[简体中文](README.md) | [English](README.en.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

---

## Features

- **Always Installs Latest Version**: Automatically fetches the latest official FRP release via 302 redirect resolution without being constrained by anonymous GitHub API rate limits.
- **Automated Architecture Detection**: Automatically detects system CPU architecture (`amd64`, `arm64`, `arm`, `386`, `riscv64`) and downloads the matching official binary release.
- **Dual Source Acceleration**: Prioritizes direct GitHub downloads; automatically falls back to mirror acceleration if the connection times out.
- **Systemd Service Integration**: Automatically creates, registers, and enables `frps.service` for auto-start on boot and automatic failure recovery.
- **Secure Default Configuration**: Generates `frps.toml` with a secure 16-character random authentication token.
- **Interactive Management Console**: Clean numerical menu for status inspection, starting, stopping, restarting, config editing, log viewing, and uninstallation.
- **Global Management Shortcut**: Automatically registers the `frps-admin` command for convenient system-wide management.
- **Zero Emoji Style**: Adheres strictly to clean UNIX terminal formatting with zero emojis.

---

## One-Click Installation

Run the following command on your server:

```bash
curl -fsSL https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

Alternatively, using `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

---

## Management Console

Once installed, manage your FRPS service from any terminal location:

```bash
sudo frps-admin
```

Console preview:

```text
  FRPS 管理面板 / Management Console
  状态 / Status: 运行中 / Running (Active)

  1. 启动服务 / Start Service
  2. 重启服务 / Restart Service
  3. 停止服务 / Stop Service
  4. 实时日志 / View Recent Logs
  5. 查看配置 / View Configuration File
  6. 修改配置 / Edit Configuration File
  7. 重装更新 / Reinstall or Update FRPS
  8. 彻底卸载 / Uninstall FRPS
  0. 退出面板 / Exit
```

---

## Non-Interactive CLI Shortcuts

You can also pass arguments directly to `frps-admin` for automation and scripts:

```bash
sudo frps-admin start       # Start the service
sudo frps-admin stop        # Stop the service
sudo frps-admin restart     # Restart the service
sudo frps-admin status      # Check current service status
sudo frps-admin logs        # Stream real-time logs
sudo frps-admin config      # Display current configuration
sudo frps-admin edit        # Edit configuration and reload
sudo frps-admin uninstall   # Completely uninstall FRPS
```

---

## File Structure

| Component | System Path | Description |
| :--- | :--- | :--- |
| **Binary** | `/usr/local/bin/frps` | FRPS executable binary |
| **Configuration** | `/etc/frp/frps.toml` | Main configuration file (port, token, etc.) |
| **Systemd Service** | `/etc/systemd/system/frps.service` | System service daemon configuration |
| **Management Tool** | `/usr/local/bin/frps-admin` | Global management CLI shortcut |

---

## Network & Firewall Configuration

By default, FRPS listens on TCP port `7000`. Ensure that inbound traffic on this port is allowed in your firewall and cloud security groups:

```bash
# UFW (Ubuntu / Debian)
sudo ufw allow 7000/tcp

# Firewalld (CentOS / RHEL / Fedora / AlmaLinux / Rocky Linux)
sudo firewall-cmd --zone=public --add-port=7000/tcp --permanent
sudo firewall-cmd --reload
```

---

## Supported Operating Systems

- Ubuntu (18.04+)
- Debian (10+)
- CentOS / RHEL (7+)
- AlmaLinux / Rocky Linux
- Fedora
- Arch Linux
- openSUSE
- Alpine Linux

---

## License

This project is open source and available under the [MIT License](LICENSE).
