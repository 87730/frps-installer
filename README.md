# frps-installer

FRP 服务端 (frps) 一键安装与系统服务管理脚本。

[简体中文](README.md) | [English](README.en.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

---

## 项目特性

- **架构自适应**：自动识别系统 CPU 架构（`amd64`、`arm64`、`arm`、`386`、`riscv64`），自动拉取匹配的官方二进制发布包。
- **国内外双源加速**：优先直连 GitHub 官方源；若检测到国内 VPS 网络超时，自动平滑切换至镜像加速节点下载。
- **Systemd 服务托管**：自动配置、注册并启用 `frps.service` 系统守护进程，支持开机自启与崩溃自动重启。
- **安全配置生成**：自动生成 `frps.toml` 配置文件，默认生成 16 位高强度随机通信 Token。
- **交互式管理面板**：提供直观的数字菜单，随时查看运行状态、启动、停止、重启、查看实时日志或彻底卸载。
- **全局管理快捷命令**：安装完成后自动注册 `frps-admin` 系统命令，无需重复下载脚本。
- **纯净无 Emoji**：遵循专业 UNIX 终端排版规范，输出干净工整。

---

## 一键安装

在服务器终端执行以下命令即可全自动安装：

```bash
curl -fsSL https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

如果系统未预装 `curl`，亦可使用 `wget`：

```bash
wget -qO- https://raw.githubusercontent.com/87730/frps-installer/main/frps.sh | sudo bash
```

---

## 服务管理面板

安装完成后，在服务器任意路径运行以下命令即可唤出管理面板：

```bash
sudo frps-admin
```

管理面板预览：

```text
============================================================
             FRPS 服务管理面板 / Management Console         
============================================================
  状态 / Status: 运行中 / Running (Active)
------------------------------------------------------------
  1. 启动服务 / Start Service
  2. 重启服务 / Restart Service
  3. 停止服务 / Stop Service
  4. 查看实时日志 / View Recent Logs
  5. 查看配置文件 / View Configuration File
  6. 重新安装与更新 / Reinstall or Update FRPS
  7. 卸载 FRPS / Uninstall FRPS
  0. 退出 / Exit
============================================================
```

---

## 非交互式命令行快捷指令

除了交互菜单，亦可直接在终端或自动化脚本中调用子命令执行快捷操作：

```bash
sudo frps-admin start       # 启动服务
sudo frps-admin stop        # 停止服务
sudo frps-admin restart     # 重启服务
sudo frps-admin status      # 查看当前运行状态
sudo frps-admin logs        # 查看实时运行日志
sudo frps-admin config      # 查看当前配置文件内容
sudo frps-admin uninstall   # 彻底卸载 FRPS
```

---

## 文件与目录结构

| 组件名称 | 系统路径 | 说明 |
| :--- | :--- | :--- |
| **可执行二进制** | `/usr/local/bin/frps` | FRPS 核心服务端程序 |
| **配置文件** | `/etc/frp/frps.toml` | 包含端口、Token 与高级设置的主配置文件 |
| **Systemd 服务** | `/etc/systemd/system/frps.service` | 系统服务守护进程配置 |
| **管理工具命令** | `/usr/local/bin/frps-admin` | 交互式管理终端命令快捷方式 |

---

## 防火墙与安全组配置

FRPS 默认监听 `7000` 端口。请确保在系统防火墙及云服务商安全组中放行该端口：

```bash
# UFW (Ubuntu / Debian)
sudo ufw allow 7000/tcp

# Firewalld (CentOS / RHEL / Fedora / AlmaLinux / Rocky Linux)
sudo firewall-cmd --zone=public --add-port=7000/tcp --permanent
sudo firewall-cmd --reload
```

---

## 支持的操作系统

- Ubuntu (18.04+)
- Debian (10+)
- CentOS / RHEL (7+)
- AlmaLinux / Rocky Linux
- Fedora
- Arch Linux
- openSUSE
- Alpine Linux

---

## 开源协议

本项目基于 [MIT License](LICENSE) 协议开源。
