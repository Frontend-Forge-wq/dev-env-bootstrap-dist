#!/usr/bin/env bash
set -euo pipefail

# macOS zsh 初始化脚本
# - 安装/检测 Homebrew、iTerm2、oh-my-zsh 及插件
# - 安装 nvm + Node（默认 LTS）
# - 安装 pnpm，并配置 PNPM_HOME 与 npm prefix，使全局依赖在不同 Node 版本间可复用
# - 幂等：多次运行不会重复安装或破坏现有配置

info()  { printf "[+] %s\n" "$*"; }
ok()    { printf "[OK] %s\n" "$*"; }
warn()  { printf "[!] %s\n" "$*"; }
err()   { printf "[x] %s\n" "$*"; }

ZSHRC="$HOME/.zshrc"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# 仓库路径与 iTerm2 偏好目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ITERM2_REPO_PREFS_DIR="$REPO_ROOT/snippets/macos/iterm2"

# 发行仓库原始链接（远程模式下下载默认配置）
# 可通过环境变量覆盖：DEV_ENV_DIST_REPO=owner/repo，DEV_ENV_DIST_BRANCH=branch
DIST_REPO="${DEV_ENV_DIST_REPO:-Frontend-Forge-wq/dev-env-bootstrap-dist}"
DIST_BRANCH="${DEV_ENV_DIST_BRANCH:-main}"
DIST_BASE="https://raw.githubusercontent.com/${DIST_REPO}/${DIST_BRANCH}"

# 参数解析（非交互与路径自定义）
YES=0
NONI=0
PNPM_HOME_OPT=""
PNPM_STORE_OPT=""
NPM_PREFIX_OPT=""
BROWSERS_SEL=""
EDITORS_SEL=""
DEVTOOLS_SEL=""
INSTALL_ALL_TOOLS=0
SKIP_ITERM=0
SKIP_TOOLS=""
NODE_SEL=""
ITERM2_PROFILE_NAME=""
ITERM2_FONT_OPT=""
RESULT_REPORT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1; NONI=1; shift ;;
    --non-interactive) NONI=1; shift ;;
    --pnpm-home) PNPM_HOME_OPT="$2"; shift 2 ;;
    --pnpm-store) PNPM_STORE_OPT="$2"; shift 2 ;;
    --npm-prefix) NPM_PREFIX_OPT="$2"; shift 2 ;;
    --install-all-tools) INSTALL_ALL_TOOLS=1; shift ;;
    --skip-iterm) SKIP_ITERM=1; shift ;;
    --skip-tools) SKIP_TOOLS="$2"; shift 2 ;;
    --node) NODE_SEL="$2"; shift 2 ;;
    --iterm2-profile) ITERM2_PROFILE_NAME="$2"; shift 2 ;;
    --iterm2-font) ITERM2_FONT_OPT="$2"; shift 2 ;;
    --browsers) BROWSERS_SEL="$2"; shift 2 ;;
    --editors) EDITORS_SEL="$2"; shift 2 ;;
    --dev-tools) DEVTOOLS_SEL="$2"; shift 2 ;;
    --result-report-dir) RESULT_REPORT_DIR="$2"; shift 2 ;;
    *) warn "未知参数: $1"; shift ;;
  esac
done

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "未检测到 Homebrew，开始安装…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew 已安装"
  else
    info "已检测到 Homebrew"
    brew update || true
  fi
}

# 从仓库偏好目录应用 iTerm2 配置（如存在）
apply_iterm2_prefs_from_repo() {
  local dir="$ITERM2_REPO_PREFS_DIR"
  local plist="$dir/com.googlecode.iterm2.plist"
  if [[ -f "$plist" ]]; then
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$dir"
    ok "iTerm2 已配置为从仓库目录加载偏好：$dir"
  else
    # 远程模式回退：从发行仓库下载偏好到用户目录
    local local_dir="$HOME/.config/dev-env-bootstrap/iterm2"
    mkdir -p "$local_dir"
    if curl -fsSL "${DIST_BASE}/snippets/macos/iterm2/com.googlecode.iterm2.plist" -o "$local_dir/com.googlecode.iterm2.plist"; then
      defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
      defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$local_dir"
      ok "iTerm2 已配置为从发行仓库加载偏好：$local_dir"
    else
      info "未发现仓库偏好且发行仓库下载失败，跳过 iTerm2 偏好应用"
    fi
  fi
}

# 检测并安装 Meslo Nerd Font（用于终端图标显示）
is_meslo_installed() {
  local candidates=("$HOME/Library/Fonts/MesloLGS NF Regular.ttf" "/Library/Fonts/MesloLGS NF Regular.ttf")
  for f in "${candidates[@]}"; do [[ -f "$f" ]] && return 0; done
  return 1
}

ensure_meslo_nerd_font() {
  if is_meslo_installed; then
    info "已检测到 MesloLGS NF 字体"
    return
  fi
  info "安装 Meslo Nerd Font"
  brew tap homebrew/cask-fonts || true
  brew install --cask font-meslo-lg-nerd-font || true
  if is_meslo_installed; then ok "Meslo Nerd Font 安装完成"; else warn "未检测到 Meslo Nerd Font（可稍后手动安装）"; fi
}

# 浏览器列表与安装（多选 + 已安装检测）
_mac_browser_defs() {
  # name|token|cask|app_path
  cat <<EOF
Google Chrome|chrome|google-chrome|/Applications/Google Chrome.app
Microsoft Edge|edge|microsoft-edge|/Applications/Microsoft Edge.app
Firefox|firefox|firefox|/Applications/Firefox.app
EOF
}

is_browser_installed_macos() {
  local cask="$1" app="$2"
  [[ -d "$app" ]] && return 0
  brew list --cask 2>/dev/null | grep -q "^${cask}$" && return 0
  return 1
}

install_browsers_macos() {
  local selected=()
  if [[ -n "$BROWSERS_SEL" ]]; then
    IFS=',' read -r -a selected <<< "$BROWSERS_SEL"
  elif [[ "$NONI" -eq 1 ]]; then
    info "非交互模式且未指定 --browsers，跳过浏览器安装"
    return
  else
    info "可选浏览器（多选，输入逗号分隔编号，或 all 安装全部）："
    local i=1; while IFS='|' read -r name token cask app; do
      echo "  $i) $name"
      i=$((i+1))
    done < <(_mac_browser_defs)
    read -r -p "选择编号（如: 1,3,5；空回车跳过）：" ans || true
    if [[ -z "$ans" ]]; then info "未选择浏览器，跳过"; return; fi
    if [[ "$ans" == all ]]; then
      while IFS='|' read -r name token cask app; do selected+=("$token"); done < <(_mac_browser_defs)
    else
      IFS=',' read -r -a idxs <<< "$ans"
      local i=1; while IFS='|' read -r name token cask app; do
        for n in "${idxs[@]}"; do [[ "$n" -eq "$i" ]] && selected+=("$token"); done
        i=$((i+1))
      done < <(_mac_browser_defs)
    fi
  fi

  if [[ ${#selected[@]} -eq 0 ]]; then info "未选择浏览器，跳过"; return; fi
  brew tap homebrew/cask || true
  while IFS='|' read -r name token cask app; do
    local pick=0
    for t in "${selected[@]}"; do [[ "$t" == "$token" ]] && pick=1; done
    [[ "$pick" -eq 1 ]] || continue
    if is_browser_installed_macos "$cask" "$app"; then
      info "已安装：$name（检测到 $app 或 brew cask）"
      continue
    fi
    info "安装：$name（$cask）"
    if brew install --cask "$cask"; then
      ok "$name 安装完成"
    else
      warn "$name 安装失败（可稍后手动安装）"
    fi
  done < <(_mac_browser_defs)
}

# 编辑器列表与安装（多选 + 已安装检测）
_mac_editor_defs() {
  # name|token|cask|app_path|note
  cat <<EOF
Visual Studio Code|vscode|visual-studio-code|/Applications/Visual Studio Code.app|
Cursor|cursor|cursor|/Applications/Cursor.app|
Trae|trae||/Applications/Trae.app|暂未收录到 Homebrew，需手动安装（https://trae.ai/ 或 https://trae.cool/）
Trae CN|trae-cn||/Applications/Trae CN.app|暂未收录到 Homebrew，需手动安装（https://trae.cool/）
EOF
}

is_editor_installed_macos() {
  local cask="$1" app="$2"
  [[ -d "$app" ]] && return 0
  [[ -n "$cask" ]] && brew list --cask 2>/dev/null | grep -q "^${cask}$" && return 0
  return 1
}

install_editors_macos() {
  local selected=()
  if [[ -n "$EDITORS_SEL" ]]; then IFS=',' read -r -a selected <<< "$EDITORS_SEL";
  elif [[ "$NONI" -eq 1 ]]; then selected=(vscode cursor);
  else
    info "可选编辑器（多选，输入逗号分隔编号）："
    local i=1; while IFS='|' read -r name token cask app note; do echo "  $i) $name${note:+（$note）}"; i=$((i+1)); done < <(_mac_editor_defs)
    read -r -p "选择编号（如: 1,2；空回车跳过）：" ans || true
    IFS=',' read -r -a idxs <<< "$ans"
    local i=1; while IFS='|' read -r name token cask app note; do
      for n in "${idxs[@]}"; do [[ "$n" -eq "$i" ]] && selected+=("$token"); done
      i=$((i+1))
    done < <(_mac_editor_defs)
  fi

  if [[ ${#selected[@]} -eq 0 ]]; then info "未选择编辑器，跳过"; return; fi
  brew tap homebrew/cask || true
  while IFS='|' read -r name token cask app note; do
    local pick=0; for t in "${selected[@]}"; do [[ "$t" == "$token" ]] && pick=1; done; [[ "$pick" -eq 1 ]] || continue
    if is_editor_installed_macos "$cask" "$app"; then info "已安装：$name（检测到 $app 或 brew cask）"; continue; fi
    if [[ -z "$cask" ]]; then warn "$name 无法通过 brew 安装，请访问官网手动安装。$note"; continue; fi
    info "安装：$name（$cask）"; if brew install --cask "$cask"; then ok "$name 安装完成，安装路径：$app"; else warn "$name 安装失败"; fi
  done < <(_mac_editor_defs)
}

# 开发工具（Rust/Python/Docker/JDK/Android）多选安装
_mac_devtool_defs() {
  # name|token|type|pkg|note
  cat <<EOF
Rust (rustup)|rust|cask|rustup-init|安装后默认目录：$HOME/.cargo 与 $HOME/.rustup
Python 3|python|formula|python|安装位置以 which python3 为准
Docker Desktop|docker|cask|docker|安装位置：/Applications/Docker.app
JDK (Temurin)|jdk|cask|temurin|安装后可通过 /usr/libexec/java_home 查询 JAVA_HOME
Android Studio|android|cask|android-studio|安装位置：/Applications/Android Studio.app
Android Platform Tools|android-tools|formula|android-platform-tools|adb 等命令行工具
EOF
}

install_devtools_macos() {
  local selected=()
  if [[ -n "$DEVTOOLS_SEL" ]]; then IFS=',' read -r -a selected <<< "$DEVTOOLS_SEL";
  elif [[ "$NONI" -eq 1 ]]; then selected=(rust python docker jdk android android-tools);
  else
    info "开发工具可选项（多选，逗号分隔编号）："
    local i=1; while IFS='|' read -r name token type pkg note; do echo "  $i) $name（$note）"; i=$((i+1)); done < <(_mac_devtool_defs)
    read -r -p "选择编号（如: 1,3；空回车跳过）：" ans || true
    IFS=',' read -r -a idxs <<< "$ans"
    local i=1; while IFS='|' read -r name token type pkg note; do
      for n in "${idxs[@]}"; do [[ "$n" -eq "$i" ]] && selected+=("$token"); done
      i=$((i+1))
    done < <(_mac_devtool_defs)
  fi

  if [[ ${#selected[@]} -eq 0 ]]; then info "未选择开发工具，跳过"; return; fi
  brew tap homebrew/cask || true
  while IFS='|' read -r name token type pkg note; do
    local pick=0; for t in "${selected[@]}"; do [[ "$t" == "$token" ]] && pick=1; done; [[ "$pick" -eq 1 ]] || continue
    info "安装：$name"
    if [[ "$type" == cask ]]; then brew install --cask "$pkg" || true; else brew install "$pkg" || true; fi
    case "$token" in
      rust)
        if command -v rustup-init >/dev/null 2>&1; then rustup-init -y || true; fi
        info "Rust 默认安装路径：$HOME/.cargo 与 $HOME/.rustup"
        ;;
      python)
        if command -v python3 >/dev/null 2>&1; then ok "Python3: $(python3 -V) at $(which python3)"; fi
        ;;
      jdk)
        if command -v /usr/libexec/java_home >/dev/null 2>&1; then ok "JAVA_HOME: $(/usr/libexec/java_home)"; fi
        ;;
      android)
        info "Android Studio 安装位置：/Applications/Android Studio.app"
        ;;
      docker)
        info "Docker Desktop 安装位置：/Applications/Docker.app"
        ;;
    esac
  done < <(_mac_devtool_defs)
}

# Git 全局配置（交互式）
ensure_git_config_macos() {
  if ! command -v git >/dev/null 2>&1; then warn "未检测到 git（可通过可选工具或 Xcode Command Line Tools 安装）"; return; fi
  info "\n== Git 全局配置 =="
  local name email ans
  if [[ "$NONI" -eq 1 ]]; then
    git config --global init.defaultBranch main || true
    git config --global core.autocrlf input || true
    git config --global core.filemode false || true
    git config --global credential.helper osxkeychain || true
    ok "已设置基础 Git 选项（非交互模式）"
  else
    read -r -p "设置 user.name（留空跳过）：" name || true
    [[ -n "$name" ]] && git config --global user.name "$name"
    read -r -p "设置 user.email（留空跳过）：" email || true
    [[ -n "$email" ]] && git config --global user.email "$email"
    read -r -p "默认分支设为 main? (Y/n) " ans || true; if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then git config --global init.defaultBranch main; fi
    read -r -p "core.autocrlf 设为 input? (Y/n) " ans || true; if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then git config --global core.autocrlf input; fi
    read -r -p "core.filemode 设为 false? (Y/n) " ans || true; if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then git config --global core.filemode false; fi
    read -r -p "启用 osxkeychain 作为凭据管理器? (Y/n) " ans || true; if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then git config --global credential.helper osxkeychain; fi
    ok "Git 全局配置完成"
  fi
}
# 生成/更新一个简洁的默认 Profile，并设为默认
ensure_iterm2_default_profile() {
  local dir="$ITERM2_REPO_PREFS_DIR"
  local plist="$dir/com.googlecode.iterm2.plist"
  local name
  name="${ITERM2_PROFILE_NAME:-WQ-Default}"
  mkdir -p "$dir"
  if [[ ! -f "$plist" ]]; then
    cat > "$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>New Bookmarks</key>
  <array/>
</dict></plist>
PLIST
  fi
  # 转为 XML 以便编辑
  plutil -convert xml1 "$plist" >/dev/null 2>&1 || true
  local guid existing
  # 若已存在默认 GUID 则复用，否则生成新的
  existing=$(/usr/libexec/PlistBuddy -c "Print :Default Bookmark Guid" "$plist" 2>/dev/null || true)
  if [[ -n "$existing" ]]; then guid="$existing"; else guid="$(uuidgen)"; fi
  # 确保 New Bookmarks 数组存在
  /usr/libexec/PlistBuddy -c "Print :New Bookmarks" "$plist" >/dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Add :New Bookmarks array" "$plist"
  # 若该 GUID 尚未出现，则在开头插入一个基本 profile
  if ! grep -q "$guid" "$plist"; then
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0 dict" "$plist" || true
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0:Name string $name" "$plist" || true
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0:Guid string $guid" "$plist" || true
    # 选择字体：优先使用 MesloLGS NF，其次 Menlo-Regular
    local fontSel
    if [[ -n "$ITERM2_FONT_OPT" ]]; then
      fontSel="$ITERM2_FONT_OPT"
    elif is_meslo_installed; then
      fontSel="MesloLGS NF Regular 13"
    else
      fontSel="Menlo-Regular 13"
    fi
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0:Normal Font string $fontSel" "$plist" || true
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0:Custom Command string No" "$plist" || true
    /usr/libexec/PlistBuddy -c "Add :New Bookmarks:0:Working Directory string Home" "$plist" || true
  fi
  /usr/libexec/PlistBuddy -c "Set :Default Bookmark Guid $guid" "$plist" || true
  ok "iTerm2 默认 Profile 已配置：$name（GUID=$guid）"
}

brew_install() {
  local pkg="$1"
  if brew list --formula --versions "$pkg" >/dev/null 2>&1 || brew list --cask --versions "$pkg" >/dev/null 2>&1; then
    info "已安装: $pkg"
    if [[ "$pkg" == iterm2 ]]; then
      apply_iterm2_prefs_from_repo || true
    fi
  else
    info "安装: $pkg"
    if [[ "$pkg" == iterm2 || "$pkg" == powershell ]]; then
      brew install --cask "$pkg"
    else
      brew install "$pkg"
    fi
    if [[ "$pkg" == iterm2 ]]; then
      apply_iterm2_prefs_from_repo || true
    fi
  fi
}

backup_zshrc() {
  if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "$ZSHRC.bak.$TIMESTAMP"
    info "已备份 ~/.zshrc 到: $ZSHRC.bak.$TIMESTAMP"
  else
    touch "$ZSHRC"
    info "创建空的 ~/.zshrc"
  fi
}

ensure_ohmyzsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    info "已检测到 oh-my-zsh"
  else
    info "安装 oh-my-zsh"
    export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "oh-my-zsh 安装完成"
  fi
}

ensure_zsh_plugins() {
  local ZSH_CUSTOM
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$ZSH_CUSTOM/plugins"
  # zsh-autosuggestions
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    ok "已安装插件: zsh-autosuggestions"
  else
    info "插件已存在: zsh-autosuggestions"
  fi
  # zsh-syntax-highlighting（必须在插件列表最后）
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    ok "已安装插件: zsh-syntax-highlighting"
  else
    info "插件已存在: zsh-syntax-highlighting"
  fi
  # z（跳转工具）
  brew_install z
}

ensure_powerlevel10k() {
  # 尝试核心源与 tap 源
  if brew list --versions powerlevel10k >/dev/null 2>&1; then
    info "已安装: powerlevel10k"
  else
    if brew install powerlevel10k >/dev/null 2>&1; then
      ok "已安装: powerlevel10k"
    else
      brew tap romkatv/powerlevel10k || true
      brew install romkatv/powerlevel10k/powerlevel10k || true
    fi
  fi
}

install_optional_tools() {
  # 交互或批量安装常用 CLI 工具与 iTerm2
  local items=("git" "iterm2" "fzf" "fd" "ripgrep" "bat" "zoxide")
  local should_install
  should_install() {
    local name="$1"
    # 空则全部安装
    [[ -z "$SKIP_TOOLS" ]] && return 0
    local lc_name
    lc_name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    # 逗号分隔列表，做小写比对
    IFS=',' read -r -a _arr <<< "$SKIP_TOOLS"
    for raw in "${_arr[@]}"; do
      local tok
      tok="$(echo "$raw" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
      [[ "$tok" == "$lc_name" ]] && return 1
    done
    return 0
  }
  if [[ "$INSTALL_ALL_TOOLS" -eq 1 ]]; then
    for item in "${items[@]}"; do
      if [[ "$item" == "iterm2" && "$SKIP_ITERM" -eq 1 ]]; then
        info "已跳过 iTerm2（按参数指定）"
        continue
      fi
      if should_install "$item"; then
        brew_install "$item"
      else
        info "已跳过 ${item}（按参数指定）"
      fi
    done
    return
  fi

  for item in "${items[@]}"; do
    local ans
    if [[ "$item" == "iterm2" && "$SKIP_ITERM" -eq 1 ]]; then
      info "已跳过 iTerm2（按参数指定）"
      continue
    fi
    if ! should_install "$item"; then
      info "已跳过 ${item}（按参数指定）"
      continue
    fi
    read -r -p "是否安装 ${item}? (Y/n) " ans || true
    if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then
      brew_install "$item"
    else
      info "跳过安装: ${item}"
    fi
  done
}

update_plugins_line() {
  # 将插件列表更新为目标：git z zsh-autosuggestions zsh-syntax-highlighting
  # 若存在 plugins= 行，则替换；若不存在，则插入到 source oh-my-zsh.sh 之前；否则追加到文件末尾
  local desired='plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)'
  if grep -qE '^\s*plugins\s*=\s*\(' "$ZSHRC"; then
    sed -i.bak "$ZSHRC" -E -e "s/^\s*plugins\s*=\s*\(.*\)\s*$/$desired/"
    ok "已更新 ~/.zshrc 插件列表"
  else
    if grep -qE '^\s*source\s+\$ZSH/.oh-my-zsh\.sh' "$ZSHRC"; then
      # 插入到 oh-my-zsh 源加载之前
      awk -v ins="$desired" '
        BEGIN{added=0}
        /^\s*source\s+\$ZSH\/oh-my-zsh\.sh/ && added==0 {print ins; added=1}
        {print}
      ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
      ok "已在 oh-my-zsh 加载前插入插件列表"
    else
      echo "$desired" >> "$ZSHRC"
      ok "已追加插件列表到 ~/.zshrc 末尾"
    fi
  fi
}

ensure_nvm_and_node() {
  brew_install nvm
  mkdir -p "$HOME/.nvm"
  # 将 nvm 初始化加入 ~/.zshrc（幂等）
  local nvm_block_start="# >>> DevEnvBootstrap:nvm >>>"
  local nvm_block_end="# <<< DevEnvBootstrap:nvm <<<"
  if ! grep -q "$nvm_block_start" "$ZSHRC"; then
    cat >> "$ZSHRC" <<'EOF'
# >>> DevEnvBootstrap:nvm >>>
export NVM_DIR="$HOME/.nvm"
if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
  . "$(brew --prefix)/opt/nvm/nvm.sh"
elif [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
fi
# <<< DevEnvBootstrap:nvm <<<
EOF
    ok "已写入 nvm 初始化到 ~/.zshrc"
  else
    info "nvm 初始化块已存在于 ~/.zshrc"
  fi

  # 当前会话加载 nvm
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
    . "$(brew --prefix)/opt/nvm/nvm.sh"
  elif [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  fi

  if command -v nvm >/dev/null 2>&1; then
    # 基于参数选择 Node 版本：默认 LTS；latest（node）；或具体版本号
    local sel
    sel=${NODE_SEL:-lts}
    if ! command -v node >/dev/null 2>&1; then
      if [[ "$sel" == "latest" ]]; then
        info "安装最新稳定版 Node"
        nvm install node
        nvm alias default node
        nvm use default
        ok "Node(latest) 已安装并启用"
      elif [[ "$sel" == "lts" || "$sel" == "lts/*" ]]; then
        info "安装最新 LTS Node"
        nvm install --lts
        nvm alias default 'lts/*'
        nvm use default
        ok "Node(LTS) 已安装并启用"
      else
        info "安装指定 Node 版本: $sel"
        nvm install "$sel"
        nvm alias default "$sel"
        nvm use default
        ok "Node($sel) 已安装并启用"
      fi
    else
      info "已检测到 Node: $(node -v)"
    fi
  else
    warn "nvm 未可用，请重新打开终端或手动 source ~/.zshrc 后重试"
  fi
}

ensure_pnpm_and_globals() {
  # 使用 Homebrew 安装 pnpm（避免依赖某个特定 Node 版本的 corepack 安装）
  brew_install pnpm

  # 交互式设置 PNPM_HOME / store-dir / NPM_CONFIG_PREFIX，并写入 ~/.zshrc（幂等更新）
  local pnpm_block_start="# >>> DevEnvBootstrap:pnpm/npm >>>"
  local pnpm_block_end="# <<< DevEnvBootstrap:pnpm/npm <<<"

  local default_pnpm_home="$HOME/Library/pnpm"
  local pnpm_home_sel
  if [[ -n "$PNPM_HOME_OPT" ]]; then pnpm_home_sel="$PNPM_HOME_OPT";
  elif [[ "$NONI" -eq 1 || "$YES" -eq 1 ]]; then pnpm_home_sel="$default_pnpm_home";
  else read -r -p "设置 PNPM_HOME (默认: $default_pnpm_home): " pnpm_home_sel || true; [[ -z "$pnpm_home_sel" ]] && pnpm_home_sel="$default_pnpm_home"; fi

  local default_store_dir="$pnpm_home_sel/store/v3"
  local pnpm_store_sel
  if [[ -n "$PNPM_STORE_OPT" ]]; then pnpm_store_sel="$PNPM_STORE_OPT";
  elif [[ "$NONI" -eq 1 || "$YES" -eq 1 ]]; then pnpm_store_sel="$default_store_dir";
  else read -r -p "设置 pnpm store-dir (默认: $default_store_dir): " pnpm_store_sel || true; [[ -z "$pnpm_store_sel" ]] && pnpm_store_sel="$default_store_dir"; fi

  local default_npm_prefix="$HOME/.npm-global"
  local npm_prefix_sel
  if [[ -n "$NPM_PREFIX_OPT" ]]; then npm_prefix_sel="$NPM_PREFIX_OPT";
  elif [[ "$NONI" -eq 1 || "$YES" -eq 1 ]]; then npm_prefix_sel="$default_npm_prefix";
  else read -r -p "设置 npm 前缀 NPM_CONFIG_PREFIX (默认: $default_npm_prefix): " npm_prefix_sel || true; [[ -z "$npm_prefix_sel" ]] && npm_prefix_sel="$default_npm_prefix"; fi

  mkdir -p "$pnpm_home_sel" "$pnpm_store_sel" "$npm_prefix_sel/bin"

  # 删除旧的配置块，再写入新的（保证内容更新）
  if grep -q "$pnpm_block_start" "$ZSHRC"; then
    sed -i.bak -e "/$pnpm_block_start/,/$pnpm_block_end/d" "$ZSHRC"
  fi

  cat >> "$ZSHRC" <<EOF
# >>> DevEnvBootstrap:pnpm/npm >>>
# 使 pnpm 全局安装的 CLI 在不同 Node 版本间可共用
export PNPM_HOME="$pnpm_home_sel"
case ":\$PATH:" in
  *":\$PNPM_HOME:"*) ;;
  *) export PATH="\$PNPM_HOME:\$PATH";;
esac

# 统一 npm 全局目录，使 npm -g 安装的 CLI 跨 Node 版本可见
export NPM_CONFIG_PREFIX="$npm_prefix_sel"
case ":\$PATH:" in
  *":\$NPM_CONFIG_PREFIX/bin:"*) ;;
  *) export PATH="\$NPM_CONFIG_PREFIX/bin:\$PATH";;
esac
# <<< DevEnvBootstrap:pnpm/npm <<<
EOF
  ok "已写入 pnpm/npm 路径到 ~/.zshrc：PNPM_HOME=$pnpm_home_sel, NPM_CONFIG_PREFIX=$npm_prefix_sel"

  # 将配置应用到当前会话（尽量减少用户重启成本）
  export PNPM_HOME="$pnpm_home_sel"
  export NPM_CONFIG_PREFIX="$npm_prefix_sel"

  if command -v pnpm >/dev/null 2>&1; then
    pnpm config set store-dir "$pnpm_store_sel" >/dev/null 2>&1 || true
  fi
  if command -v npm >/dev/null 2>&1; then
    npm config set prefix "$npm_prefix_sel" >/dev/null 2>&1 || true
  fi
}

ensure_fdignore() {
  local fdignore="$HOME/.fdignore"
  cat > "$fdignore" <<'EOF'
node_modules
.dist
dist
.build
.cache
.next
out
tmp
temp
coverage
EOF
  ok "fdignore 写入: $fdignore"
}

# 生成执行结果清单（Markdown），便于后续查看与调整
generate_result_manifest_macos() {
  local out_dir
  out_dir="${RESULT_REPORT_DIR:-$HOME/Documents/DevEnvBootstrap/reports}"
  mkdir -p "$out_dir" || true
  local out_file="$out_dir/DevEnvBootstrap-Report-macos-$TIMESTAMP.md"

  # 系统信息
  local os_ver kernel brew_prefix
  os_ver=$(sw_vers -productVersion 2>/dev/null || echo "")
  kernel=$(uname -a 2>/dev/null || echo "")
  brew_prefix=$(brew --prefix 2>/dev/null || echo "")

  # Git
  local git_path git_ver git_name git_email init_branch autocrlf filemode credential
  if command -v git >/dev/null 2>&1; then
    git_path=$(command -v git)
    git_ver=$(git --version 2>/dev/null || echo "")
    git_name=$(git config --global user.name 2>/dev/null || echo "")
    git_email=$(git config --global user.email 2>/dev/null || echo "")
    init_branch=$(git config --global init.defaultBranch 2>/dev/null || echo "")
    autocrlf=$(git config --global core.autocrlf 2>/dev/null || echo "")
    filemode=$(git config --global core.filemode 2>/dev/null || echo "")
    credential=$(git config --global credential.helper 2>/dev/null || echo "")
  fi

  # Node / nvm
  local node_path node_ver nvm_ver nvm_dir
  if command -v node >/dev/null 2>&1; then node_path=$(command -v node); node_ver=$(node -v 2>/dev/null || echo ""); fi
  if command -v nvm >/dev/null 2>&1; then nvm_ver=$(nvm --version 2>/dev/null || echo ""); fi
  nvm_dir=${NVM_DIR:-"$HOME/.nvm"}

  # pnpm / npm
  local pnpm_path pnpm_ver pnpm_store npm_path npm_ver npm_prefix pnpm_home
  if command -v pnpm >/dev/null 2>&1; then
    pnpm_path=$(command -v pnpm)
    pnpm_ver=$(pnpm -v 2>/dev/null || echo "")
    pnpm_store=$(pnpm config get store-dir 2>/dev/null || echo "")
  fi
  if command -v npm >/dev/null 2>&1; then
    npm_path=$(command -v npm)
    npm_ver=$(npm -v 2>/dev/null || echo "")
    npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
  fi
  pnpm_home=${PNPM_HOME:-""}

  # 常用 CLI
  local fzf_path fzf_ver fd_path fd_ver rg_path rg_ver bat_path bat_ver zoxide_path zoxide_ver
  if command -v fzf >/dev/null 2>&1; then fzf_path=$(command -v fzf); fzf_ver=$(fzf --version 2>/dev/null | head -n1 || echo ""); fi
  if command -v fd >/dev/null 2>&1; then fd_path=$(command -v fd); fd_ver=$(fd --version 2>/dev/null || echo ""); fi
  if command -v rg >/dev/null 2>&1; then rg_path=$(command -v rg); rg_ver=$(rg --version 2>/dev/null | head -n1 || echo ""); fi
  if command -v bat >/dev/null 2>&1; then bat_path=$(command -v bat); bat_ver=$(bat --version 2>/dev/null || echo ""); fi
  if command -v zoxide >/dev/null 2>&1; then zoxide_path=$(command -v zoxide); zoxide_ver=$(zoxide --version 2>/dev/null || echo ""); fi

  # iTerm2 偏好与 Profile
  local iterm_load iterm_custom_dir iterm_plist iterm_guid iterm_font
  iterm_load=$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || echo "")
  iterm_custom_dir=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || echo "")
  iterm_plist="$ITERM2_REPO_PREFS_DIR/com.googlecode.iterm2.plist"
  iterm_guid=$(/usr/libexec/PlistBuddy -c "Print :Default Bookmark Guid" "$iterm_plist" 2>/dev/null || echo "")
  iterm_font=$(/usr/libexec/PlistBuddy -c "Print :New Bookmarks:0:Normal Font" "$iterm_plist" 2>/dev/null || echo "")

  # zsh 配置
  local zsh_theme_line plugins_line fdignore_path ohmyzsh_dir p10k_prefix
  zsh_theme_line=$(grep -E '^\s*ZSH_THEME=' "$ZSHRC" 2>/dev/null || echo "")
  plugins_line=$(grep -E '^\s*plugins\s*=\s*\(' "$ZSHRC" 2>/dev/null || echo "")
  fdignore_path="$HOME/.fdignore"
  [[ -d "$HOME/.oh-my-zsh" ]] && ohmyzsh_dir="$HOME/.oh-my-zsh" || ohmyzsh_dir=""
  p10k_prefix=$(brew --prefix powerlevel10k 2>/dev/null || echo "")

  # 编辑器与浏览器检测
  local editor_rows browser_rows
  editor_rows=""
  while IFS='|' read -r name token cask app note; do
    local installed="否"; local path="-"
    if [[ -d "$app" ]] || { [[ -n "$cask" ]] && brew list --cask 2>/dev/null | grep -q "^${cask}$"; }; then installed="是"; path="$app"; fi
    editor_rows+="- ${name}: ${installed}（路径：${path}）\n"
  done < <(_mac_editor_defs)

  browser_rows=""
  while IFS='|' read -r name token cask app; do
    local installed="否"; local path="-"
    if [[ -d "$app" ]] || brew list --cask 2>/dev/null | grep -q "^${cask}$"; then installed="是"; path="$app"; fi
    browser_rows+="- ${name}: ${installed}（路径：${path}）\n"
  done < <(_mac_browser_defs)

  cat > "$out_file" <<EOF
# 开发环境初始化结果清单（macOS）

- 时间：$TIMESTAMP
- 系统：${os_ver:-未知}
- 内核：${kernel:-未知}
- Homebrew 前缀：${brew_prefix:-未知}

## 工具与版本
- Git：路径=${git_path:-未安装}，版本=${git_ver:-未安装}
  - user.name=${git_name:-未设置}，user.email=${git_email:-未设置}
  - init.defaultBranch=${init_branch:-未设置}，core.autocrlf=${autocrlf:-未设置}，core.filemode=${filemode:-未设置}
  - credential.helper=${credential:-未设置}
- Node：路径=${node_path:-未安装}，版本=${node_ver:-未安装}
- nvm：版本=${nvm_ver:-未知}，目录=${nvm_dir}
- pnpm：路径=${pnpm_path:-未安装}，版本=${pnpm_ver:-未安装}
  - PNPM_HOME=${pnpm_home:-未设置}，store-dir=${pnpm_store:-未设置}
- npm：路径=${npm_path:-未安装}，版本=${npm_ver:-未安装}
  - prefix=${npm_prefix:-未设置}
- fzf：路径=${fzf_path:-未安装}，版本=${fzf_ver:-未安装}
- fd：路径=${fd_path:-未安装}，版本=${fd_ver:-未安装}
- ripgrep：路径=${rg_path:-未安装}，版本=${rg_ver:-未安装}
- bat：路径=${bat_path:-未安装}，版本=${bat_ver:-未安装}
- zoxide：路径=${zoxide_path:-未安装}，版本=${zoxide_ver:-未安装}

## 终端与外观
- iTerm2 偏好：LoadPrefsFromCustomFolder=${iterm_load:-未设置}，自定义目录=${iterm_custom_dir:-未设置}
- iTerm2 仓库偏好路径：$ITERM2_REPO_PREFS_DIR
- 默认 Profile GUID：${iterm_guid:-未知}
- 默认 Profile 字体：${iterm_font:-未知}
- Meslo Nerd Font：$(is_meslo_installed && echo 已安装 || echo 未检测到)

## zsh 配置
- ~/.zshrc：$ZSHRC
- ZSH_THEME 行：${zsh_theme_line:-未设置}
- 插件行：${plugins_line:-未设置}
- oh-my-zsh 目录：${ohmyzsh_dir:-未安装}
- powerlevel10k 前缀：${p10k_prefix:-未安装}
- fdignore：${fdignore_path}

## 编辑器
${editor_rows}

## 浏览器
${browser_rows}

## 下一步建议
- 重新打开 iTerm2 或执行 `source ~/.zshrc` 使配置生效。
- VSCode：在命令面板执行 `Shell Command: Install 'code' command in PATH`。
- 使用 `nvm ls` 与 `nvm use <版本>` 切换 Node 版本。
- 如需变更 pnpm/npm 全局目录，修改 ~/.zshrc 中 PNPM_HOME 与 NPM_CONFIG_PREFIX。
- 若 Homebrew 未在路径中，可在 `~/.zprofile` 添加 `eval "$($(command -v brew)/bin/brew shellenv)"`。

EOF

  ok "结果清单已生成：$out_file"
}

maybe_set_p10k_theme() {
  # 若尚未设置 ZSH_THEME，则设置为 powerlevel10k
  if ! grep -qE '^\s*ZSH_THEME=' "$ZSHRC"; then
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
    ok "已设置 ZSH_THEME=powerlevel10k/powerlevel10k"
  else
    info "已存在 ZSH_THEME，保持现有配置"
  fi
}

main() {
  info "开始 macOS 开发环境初始化（zsh）"
  ensure_brew
  backup_zshrc

  # 基础工具（可选安装）
  install_optional_tools
  # Git 全局配置（在安装/检测到 git 后）
  ensure_git_config_macos
  # 字体（用于图标显示）：若未安装则自动安装
  ensure_meslo_nerd_font
  # 浏览器（多选安装，支持 --browsers "chrome,edge,firefox,firefox-dev,brave,vivaldi,opera"）
  # 浏览器（多选安装，支持 --browsers "chrome,edge,firefox"）
  install_browsers_macos
  # 编辑器（多选安装，支持 --editors "vscode,cursor,trae,trae-cn"）
  install_editors_macos
  # 为 iTerm2 准备默认 Profile（可通过 --iterm2-profile 指定名称）
  ensure_iterm2_default_profile

  # oh-my-zsh 与插件
  ensure_ohmyzsh
  ensure_zsh_plugins
  update_plugins_line
  ensure_powerlevel10k
  maybe_set_p10k_theme

  # Node 管理与包管理器
  ensure_nvm_and_node
  ensure_pnpm_and_globals
  # 开发工具（Rust/Python/Docker/JDK/Android）多选安装
  install_devtools_macos

  # 质量与便利
  ensure_fdignore

  # 执行结果清单
  generate_result_manifest_macos

  ok "macOS 初始化完成。请重新打开 iTerm2 或执行 'source ~/.zshrc' 生效。"
}

main "$@"