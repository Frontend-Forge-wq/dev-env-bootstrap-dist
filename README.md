# Dev Env Bootstrap — Distribution

本仓库是公共“发行仓库”，仅用于提供公开可访问的脚本入口（Raw 链接），脚本内容由私有源仓库自动同步，便于在新机器上“一条命令”完成终端环境初始化，无需本地令牌。

- 源仓库（私有）：Frontend-Forge-wq/dev-env-bootstrap
- 同步分支：源仓库 `main` → 发行仓库 `main`
- 包含内容：`scripts/` 目录下的入口与平台脚本（不包含任何凭据或敏感数据）

## 🧭 目录

- 快速开始
- 脚本入口与链接模板
- 稳定版本（固定 commit）
- 参数速查
- 常见问题
- 安全说明
- 来源与更新

---

## 🚀 快速开始

- macOS（zsh/bash）
  - 交互默认同意：
    - `curl -fsSL https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/macos/bootstrap-macos.sh | bash -s -- --yes`
  - 非交互与代理示例：
    - `curl -fsSL https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/macos/bootstrap-macos.sh | bash -s -- -- --non-interactive --proxy "http://127.0.0.1:7890"`

- Windows（PowerShell 7）
  - 非交互：
    - `irm https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/windows/bootstrap-windows.ps1 | iex -ArgumentList '-NonInteractive'`
  - 代理示例：
    - `irm https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/windows/bootstrap-windows.ps1 | iex -ArgumentList '-NonInteractive -Proxy http://127.0.0.1:7890'`

- 跨平台入口（自动分发到对应平台脚本）
  - macOS：
    - `curl -fsSL https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/bootstrap.sh | bash`

> 提示：命令中的 `-s --` 会将后续参数传递给脚本本身，请按需添加。

---

## 🔗 脚本入口与链接模板

- macOS 主脚本：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/macos/bootstrap-macos.sh`
- Windows 主脚本：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/windows/bootstrap-windows.ps1`
- 跨平台入口：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/main/scripts/bootstrap.sh`

> Raw 链接指向发行仓库的 `main` 分支最新内容。源仓库推送到 `main` 后，工作流会自动同步到发行仓库，通常 1–2 分钟内生效。

---

## 📌 稳定版本（固定 commit）

如果希望执行“不可变版本”（更可审计/更稳定），将链接中的 `main` 替换为发行仓库目标提交的 `<commit-sha>`：

- macOS：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/<commit-sha>/scripts/macos/bootstrap-macos.sh`
- Windows：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/<commit-sha>/scripts/windows/bootstrap-windows.ps1`
- 跨平台入口：
  - `https://raw.githubusercontent.com/Frontend-Forge-wq/dev-env-bootstrap-dist/<commit-sha>/scripts/bootstrap.sh`

> `<commit-sha>` 可在本仓库的 “Commits” 页面复制。固定版本适用于需要严格审计或受控升级的场景。

---

## 🧩 参数速查（摘要）

- macOS
  - `--non-interactive` / `--yes`：非交互执行、默认同意
  - `--proxy <url>`：设置网络代理（支持 `http(s)` 或 SOCKS5，如 `http://127.0.0.1:7890`）
  - `--pnpm-home` / `--pnpm-store` / `--npm-prefix`：自定义 pnpm/npm 路径
  - `--node <lts|latest|具体版本>`：Node 版本选择
  - `--install-all-tools`：批量安装常用 CLI（`git,iterm2,fzf,fd,rg,bat,zoxide`）
  - `--skip-tools`、`--skip-iterm`、`--iterm2-profile`、`--iterm2-font`
  - `--result-report-dir`：执行结果清单输出目录

- Windows（PowerShell）
  - `-NonInteractive` / `-Yes`：非交互执行、默认同意
  - `-Proxy <url>`：设置网络代理（如 `http://127.0.0.1:7890`）
  - `-PNPMHome` / `-PnpmStore` / `-NpmPrefix` / `-Node`
  - `-Editors`、`-DevTools`、`-InstallDir`、`-SkipTools`、`-Theme`
  - `-ResultReportDir`：执行结果清单输出目录

> 完整参数与细节请参考源仓库 README。

---

## ❓ 常见问题

- 链接返回 404：
  - 路径或文件名不正确；请从上面的“脚本入口与链接模板”复制。
  - 使用了固定 commit 链接但该提交中不含该文件。

- 执行报错或网络慢：
  - 可使用脚本的代理参数：macOS `--proxy`，Windows `-Proxy`。
  - 确保目标机器具备基础工具：macOS 默认有 `curl`；Windows 使用 PowerShell 7 的 `irm/iex`。

- 为什么脚本内容可能会变化：
  - 发行仓库 `main` 始终跟随源仓库 `main` 最新同步。如需稳定性，建议使用“固定 commit 链接”。

---

## 🔒 安全说明

- 本仓库公开，仅托管脚本原文，不包含任何令牌或敏感配置。
- 建议在源仓库维护脚本时避免嵌入内部凭据、机密 URL 或个人信息。
- 一键执行方式（`curl|bash` / `irm|iex`）适合可信来源；如果需要额外防护，请使用“固定 commit 链接”并审阅脚本内容。

---

## 🔄 来源与更新

- 来源：`Frontend-Forge-wq/dev-env-bootstrap`（私有）
- 更新机制：源仓库 `main` 推送后，CI 自动同步到发行仓库 `main`，只覆盖 `scripts/` 目录；无变更则不提交。
- 延迟：通常 1–2 分钟，取决于 GitHub Actions 队列与网络。

---
