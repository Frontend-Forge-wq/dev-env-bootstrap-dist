# --- 导航与文件系统操作 ---
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ..... { Set-Location ../../../.. }
function ~ { Set-Location $HOME } # 快速回到用户主目录
function c { Clear-Host } # 清空控制台
function ls { Get-ChildItem @args } # 列出当前目录内容 (Windows 默认有 dir，但 ls 更通用)
function ll { Get-ChildItem -Force @args } # 显示隐藏文件和目录
function la { Get-ChildItem -Force -Recurse @args } # 递归列出所有文件和目录，包括隐藏
function mkd { New-Item -ItemType Directory @args } # 创建目录，例如 mkd my-folder
function touch { New-Item -ItemType File @args } # 创建文件，例如 touch index.js
function rmrf { Remove-Item -Recurse -Force @args } # 强制递归删除文件或目录，**慎用！**
function cp { Copy-Item @args } # 复制文件或目录
function mv { Move-Item @args } # 移动文件或目录
function cat { Get-Content @args } # 查看文件内容
function less { Get-Content @args | more } # 分页查看文件内容 (Windows 的 more 命令)
function grep { Select-String @args } # 查找文件中的文本 (PowerShell 的 Select-String)
function open { Invoke-Item @args } # 使用默认程序打开文件或目录，例如 open . 会打开当前目录的资源管理器
function pwd { Get-Location } # 显示当前工作目录

# --- 包管理工具 (npm/yarn/pnpm) ---
# pnpm 相关
function pr { pnpm run @args }
function pi { pnpm install @args }
function ps { pnpm start @args }
function pd { pnpm dev @args }
function pt { pnpm test @args }
function pb { pnpm build @args }
function pu { pnpm update @args }
function pc { pnpm create @args }
function pa { pnpm add @args } # pnpm add
function prf { pnpm remove @args } # pnpm remove

# npm 相关
function ni { npm install @args }
function ns { npm start @args }
function nd { npm run dev @args }
function nb { npm run build @args }
function nt { npm test @args }
function nu { npm update @args }
function nci { npm ci @args }
function npx { npx @args }
function na { npm add @args } # npm add
function nrf { npm uninstall @args } # npm uninstall

# yarn 相关
function yi { yarn install @args }
function ys { yarn start @args }
function yd { yarn dev @args }
function yb { yarn build @args }
function yt { yarn test @args }
function yu { yarn upgrade @args }
function yc { yarn create @args }
function ya { yarn add @args } # yarn add
function yrf { yarn remove @args } # yarn remove

# --- Git 相关 ---
function ga { git add @args }
function gc { git commit @args }
function gps { git push @args }
function gpl { git pull @args }
function gs { git status @args }
function gb { git branch @args }
function gco { git checkout @args }
function gd { git diff @args }
function gl { git log --oneline --decorate --all @args }
function gca { git commit --amend @args }
function grb { git rebase @args }
function gcl { git clone @args }
function grm { git rm @args }
function grs { git reset @args }
function gst { git stash @args }
function gpop { git stash pop @args }
function gsw { git switch @args }
function gmg { git merge @args }
function gfo { git fetch origin @args } # git fetch origin
function gcp { git cherry-pick @args } # git cherry-pick
function gbl { git blame @args } # git blame
function glog { git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit @args } # 更美观的 git log

# --- Docker 相关 ---
function dps { docker ps @args }
function dpsa { docker ps -a @args }
function dco { docker compose @args }
function dcup { docker compose up -d @args }
function dcdown { docker compose down @args }
function dclogs { docker compose logs -f @args }
function dcb { docker compose build @args }
function dce { docker compose exec @args }
function dcr { docker compose restart @args } # docker compose restart
function dci { docker images @args } # docker images
function dcv { docker volume @args } # docker volume

# --- 进程管理 ---
function psg { Get-Process | Where-Object { $_.ProcessName -like "*$($args[0])*" } } # 根据名称查找进程
function killp { Stop-Process -Id $args[0] -Force } # 强制终止进程 (根据 PID)

# --- 编辑器相关 ---
function code { code . @args } # 在当前目录打开 VS Code
function subl { subl . @args } # 在当前目录打开 Sublime Text
function idea { idea . @args } # 在当前目录打开 IntelliJ IDEA

# --- 前端开发工具链 (示例，根据你实际使用的工具调整) ---
function vite { vite @args }
function webpack { webpack @args }
function gulp { gulp @args }
function grunt { grunt @args }
function eslint { eslint @args }
function prettier { prettier @args }
function ts { tsc @args } # TypeScript 编译器

# --- 系统代理（可选）---
# 默认端口 7890。如需启用，取消下列注释并调整端口。
# $env:HTTP_PROXY = "http://127.0.0.1:7890"
# $env:HTTPS_PROXY = "http://127.0.0.1:7890"

