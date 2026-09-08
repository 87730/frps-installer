# frps-installer

A lightweight, automated FRP server (frps) installer and system service manager for Linux.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

---

## Features

- **Automated Architecture Detection**: Automatically detects system architecture (`amd64`, `arm64`, `arm`, `386`, `riscv64`) and downloads the matching FRP release.
- **Dual Source Acceleration**: Automatically attempts direct download from GitHub; falls back to mirror acceleration if connection times out.
- **Systemd Integration**: Configures, enables, and manages `frps.service` automatically.
- **Secure Default Configuration**: Auto-generates `frps.toml` with a secure random authentication token.
- **Interactive Management Console**: Simple numeric menu for status inspection, starting, stopping, restarting, log viewing, and uninstallation.
- **Clean Command Line Shortcut**: Automatically registers `frps-admin` for convenient service management.
- **Zero Emoji Style**: Clean, standard UNIX terminal output.

---

## One-Click Installation

Run the following command on your server:

```bash
curl -fsSL https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

Alternatively, with `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

---

## Management Console

Once installed, manage your FRPS service at any time by running:

```bash
sudo frps-admin
```

This launches the interactive menu:

```text
============================================================
                  FRPS Management Console                   
============================================================
  Status: Running (Active)
------------------------------------------------------------
  1. Start Service
  2. Restart Service
  3. Stop Service
  4. View Recent Logs
  5. View Configuration File
  6. Reinstall / Update FRPS
  7. Uninstall FRPS
  0. Exit
============================================================
```

---

## Non-Interactive CLI Shortcuts

You can also pass arguments directly to the script or `frps-admin`:

```bash
sudo frps-admin start       # Start the service
sudo frps-admin stop        # Stop the service
sudo frps-admin restart     # Restart the service
sudo frps-admin status      # Show current status
sudo frps-admin logs        # Stream recent logs
sudo frps-admin config      # Output current configuration
sudo frps-admin uninstall   # Uninstall FRPS
```

---

## File Structure

| Component | Path | Description |
| :--- | :--- | :--- |
| **Binary** | `/usr/local/bin/frps` | FRPS executable binary |
| **Configuration** | `/etc/frp/frps.toml` | Main configuration file (port, token, etc.) |
| **Systemd Service** | `/etc/systemd/system/frps.service` | System service daemon configuration |
| **Management Tool** | `/usr/local/bin/frps-admin` | Interactive management CLI shortcut |

---

## Network & Firewall Configuration

By default, FRPS listens on TCP port `7000`. Ensure that your firewall or cloud provider security group allows inbound traffic on this port:

```bash
# UFW (Ubuntu / Debian)
sudo ufw allow 7000/tcp

# Firewalld (CentOS / Alma / Rocky / Fedora)
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
