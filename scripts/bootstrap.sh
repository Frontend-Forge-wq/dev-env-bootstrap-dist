#!/usr/bin/env bash
set -euo pipefail

# 跨平台入口（bash/zsh），根据系统分发到对应初始化脚本

# 帮助与用法
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "用法: bash ./scripts/bootstrap.sh [参数]"
      echo "说明: 未识别的参数将原样转发到平台脚本 (macOS/Windows)"
      echo "示例 (macOS): --non-interactive --pnpm-home \"$HOME/DevTools/pnpm\" --pnpm-store \"$HOME/DevCache/pnpm-store/v3\" --npm-prefix \"$HOME/.npm-global\" --node lts --skip-tools \"fd,ripgrep,bat\" --iterm2-profile \"WQ-Default\" --iterm2-font \"MesloLGS NF Regular 13\" --browsers \"chrome,edge,firefox\" --editors \"vscode,cursor,trae,trae-cn\" --dev-tools \"rust,python,docker,jdk,android,android-tools\""
      echo "示例 (Windows): -NonInteractive -PNPMHome \"D:\\DevTools\\pnpm\" -PnpmStore \"D:\\DevCache\\pnpm-store\\v3\" -NpmPrefix \"D:\\DevTools\\node-global\" -Node lts -SkipTools \"fd,bat,nerd-font-meslo\" -InstallDir \"C:\\DevTools\" -Browsers \"chrome,edge,firefox\" -Editors \"vscode,cursor,trae,trae-cn\" -DevTools \"rust,python,docker,jdk,android,android-tools\""
      exit 0
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WIN_PS="$SCRIPT_DIR/windows/bootstrap-windows.ps1"
MAC_PS="$SCRIPT_DIR/macos/bootstrap-macos.ps1"
MAC_SH="$SCRIPT_DIR/macos/bootstrap-macos.sh"

unameOut="$(uname)"
case "$unameOut" in
  Darwin)
    if [ -f "$MAC_SH" ]; then
      echo "[+] 检测到 macOS，分发到: $MAC_SH"
      exec bash "$MAC_SH" "$@"
    elif command -v pwsh >/dev/null 2>&1; then
      echo "[+] 未发现 macOS zsh 脚本，回退到: $MAC_PS"
      exec pwsh -NoProfile -File "$MAC_PS" "$@"
    else
      echo "[x] 未检测到 macOS 脚本与 PowerShell (pwsh)。请安装 brew/pwsh 或手动执行 macOS 脚本。"
      exit 1
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    if command -v pwsh >/dev/null 2>&1; then
      echo "[+] 检测到 Windows，分发到: $WIN_PS"
      exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS" "$@"
    else
      echo "[x] 未检测到 PowerShell (pwsh)。请使用 scripts/DevEnvBootstrap.cmd 或安装 PowerShell 7。"
      exit 1
    fi
    ;;
  *)
    echo "[!] 当前系统暂未支持（仅 Windows 与 macOS）。"
    exit 1
    ;;
esac