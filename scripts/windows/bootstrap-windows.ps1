# DevEnvBootstrap.ps1 - 一键初始化你的 PowerShell + fzf/fd + PSFzf + oh-my-posh
[CmdletBinding()]param(
  [string]$Proxy = '',
  [string]$Theme = '',            # 主题名（不带后缀），如: omp-wq-minimal、jandedobbeleer
  [switch]$NonInteractive,        # 非交互模式：若提供 $Theme，则直接应用并持久化；否则跳过选择
  [switch]$Yes,                   # 对交互问题默认选择“是”，适合自动化
  [string]$PNPMHome = '',         # 自定义 PNPM_HOME，如 D:\DevTools\pnpm
  [string]$PnpmStore = '',        # 自定义 pnpm store-dir，如 D:\DevCache\pnpm-store\v3
  [string]$NpmPrefix = '',        # 自定义 npm prefix，如 D:\DevTools\node-global
  [string]$NvmRoot = '',          # NVM settings.txt 的 root（Node 版本目录）
  [string]$NvmSymlink = '',       # NVM settings.txt 的 path（Node 链接目录）
  [string]$Node = '',             # 统一 Node 选择：lts/latest/x.y.z
  [string]$NodeChoice = '',       # 兼容旧参数：lts/latest/version 或 1/2/3
  [string]$NodeVersion = '',      # 兼容旧参数：当 NodeChoice=version 时使用
  [string]$SkipTools = '',        # 跳过安装工具（逗号分隔）：fzf,fd,oh-my-posh,bat,ripgrep,zoxide,nerd-font-meslo
  [string]$Browsers = '',         # 安装的浏览器（逗号分隔）：chrome,edge,firefox
  [string]$Editors = '',          # 安装的编辑器（逗号分隔）：vscode,cursor,trae,trae-cn
  [string]$DevTools = '',         # 安装的开发工具（逗号分隔）：rust,python,docker,jdk,android,android-tools
  [string]$InstallDir = '',       # 安装目录（可选；为空则交互选择，默认 C:\DevTools）
  [string]$ResultReportDir = ''   # 执行结果清单输出目录（可选；为空则稍后交互选择）
)

$ErrorActionPreference = 'Continue'
function Info($m){ Write-Host "[+] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

# 发行仓库原始链接（远程模式下下载默认配置）
# 可通过环境变量覆盖：DEV_ENV_DIST_REPO=owner/repo，DEV_ENV_DIST_BRANCH=branch
$Global:DistRepo = if ($env:DEV_ENV_DIST_REPO) { $env:DEV_ENV_DIST_REPO } else { 'Frontend-Forge-wq/dev-env-bootstrap-dist' }
$Global:DistBranch = if ($env:DEV_ENV_DIST_BRANCH) { $env:DEV_ENV_DIST_BRANCH } else { 'main' }
$Global:DistBase = "https://raw.githubusercontent.com/$Global:DistRepo/$Global:DistBranch"

# 0) 可选代理设置
if ($Proxy) { $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy; Info "已设置代理为 $Proxy" }

# 1) 确认 winget 存在
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Err '未发现 winget，请先通过 Microsoft Store 安装 App Installer 后重试。'; return }

# 2) 准备 WinGet Links 路径与 PATH
$links = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
if (!(Test-Path $links)) { New-Item -ItemType Directory -Path $links | Out-Null; Info "创建 WinGet Links: $links" }
function Ensure-Path($dir){ if ([string]::IsNullOrWhiteSpace($dir)) { return }; $paths = $env:Path -split ';' | Where-Object { $_ -ne '' }; if ($paths -notcontains $dir) { [Environment]::SetEnvironmentVariable('PATH', ($env:Path + ';' + $dir), 'User'); $env:Path = $env:Path + ';' + $dir; Info "已将路径加入 PATH: $dir" } }
Ensure-Path $links

# 是否写入 PowerShell 配置到 $PROFILE（别名/快捷键/主题初始化等）
$Global:WriteProfile = $true
if (-not ($NonInteractive -or $Yes)) {
  $ans = Read-Host '是否写入 PowerShell 配置到 `$PROFILE（别名/快捷键/主题初始化等）? (Y/n)'
  if ($ans -match '^[Nn]$') { $Global:WriteProfile = $false }
}

# 选择安装目录（交互，可传入 -InstallDir 覆盖）
try {
  if (-not [string]::IsNullOrWhiteSpace($InstallDir)) {
    $Global:InstallBaseDir = $InstallDir
  } elseif ($NonInteractive -or $Yes) {
    $Global:InstallBaseDir = 'C:\DevTools'
  } else {
    $defaultDir = 'C:\DevTools'
    $sel = Read-Host ("选择安装目录（默认: " + $defaultDir + ")")
    $Global:InstallBaseDir = if ([string]::IsNullOrWhiteSpace($sel)) { $defaultDir } else { $sel }
  }
  if (!(Test-Path $Global:InstallBaseDir)) { New-Item -ItemType Directory -Path $Global:InstallBaseDir -ErrorAction SilentlyContinue | Out-Null }
  Info ("安装目录: " + $Global:InstallBaseDir)
} catch { Warn '安装目录选择失败（已使用默认 C:\DevTools）。'; $Global:InstallBaseDir = 'C:\DevTools' }

# 3) 安装核心工具（交互多选，默认安装全部；支持 -SkipTools 跳过）
$wingetOpts = "--silent --accept-package-agreements --accept-source-agreements"
function WinGetInstall($id){ Info "安装/更新 $id"; winget install --id $id -e $wingetOpts | Out-Null }
function WingetInstallWithLocation($id, $location){
  try { Info ("安装/更新 " + $id + " 到 " + $location); winget install --id $id -e $wingetOpts --location $location | Out-Null }
  catch { Warn ($id + " 不支持 --location，使用默认路径安装"); winget install --id $id -e $wingetOpts | Out-Null }
}
function ShouldInstall($name){ if ([string]::IsNullOrWhiteSpace($SkipTools)) { return $true }; $list = $SkipTools.Split(',') | ForEach-Object { $_.Trim().ToLower() }; return ($list -notcontains $name.ToLower()) }
try {
  Write-Host "\n== 核心 CLI 工具安装 ==" -ForegroundColor Cyan
  function Get-CoreToolDefs(){
    $list = @()
    $list += [PSCustomObject]@{ Name='fzf'; Key='fzf'; WingetId='junegunn.fzf' }
    $list += [PSCustomObject]@{ Name='fd'; Key='fd'; WingetId='sharkdp.fd' }
    $list += [PSCustomObject]@{ Name='ripgrep'; Key='ripgrep'; WingetId='BurntSushi.ripgrep' }
    $list += [PSCustomObject]@{ Name='bat'; Key='bat'; WingetId='sharkdp.bat' }
    $list += [PSCustomObject]@{ Name='zoxide'; Key='zoxide'; WingetId='ajeetdsouza.zoxide' }
    $list += [PSCustomObject]@{ Name='oh-my-posh'; Key='oh-my-posh'; WingetId='JanDeDobbeleer.OhMyPosh' }
    $list += [PSCustomObject]@{ Name='Nerd Font (Meslo)'; Key='nerd-font-meslo'; WingetId='NerdFonts.Meslo' }
    return $list
  }
  $defs = Get-CoreToolDefs
  $selectedKeys = @()
  if ($NonInteractive -or $Yes) {
    foreach ($d in $defs) { if (ShouldInstall $d.Key) { $selectedKeys += $d.Key } }
    Info "自动模式：将安装全部未在 -SkipTools 中的核心工具"
  } else {
    for ($i=0; $i -lt $defs.Count; $i++) { Write-Host ("[" + $i + "] " + $defs[$i].Name) }
    $raw = Read-Host "输入编号（逗号分隔；直接回车安装全部；输入 none 跳过）"
    if ([string]::IsNullOrWhiteSpace($raw)) {
      $selectedKeys = $defs | ForEach-Object { $_.Key }
    } elseif ($raw -match '^(none|skip)$') {
      $selectedKeys = @()
    } else {
      $idx = $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ }
      foreach ($n in $idx) { if ($n -ge 0 -and $n -lt $defs.Count) { $selectedKeys += $defs[$n].Key } }
    }
  }
  foreach ($key in $selectedKeys) {
    if (-not (ShouldInstall $key)) { Info ("按参数跳过: " + $key); continue }
    $def = ($defs | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
    if ($def) { WinGetInstall $def.WingetId }
  }
} catch { Warn '核心工具安装流程执行失败（已跳过）。' }

try {
  Write-Host "\n== PowerShell 模块安装 ==" -ForegroundColor Cyan
  $doMods = if ($NonInteractive -or $Yes) { 'y' } else { Read-Host '是否安装 PSFzf、posh-git、Terminal-Icons? (Y/n)' }
  if (($doMods -eq '') -or ($doMods -match '^[Yy]$')) {
    try { Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction SilentlyContinue | Out-Null } catch {}
    try { Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
    function InstallModuleIfMissing($name){ if (-not (Get-Module -ListAvailable -Name $name)) { Info "安装模块: $name"; Install-Module -Name $name -Scope CurrentUser -Force -AllowClobber } else { Ok "模块已存在: $name" } }
    InstallModuleIfMissing 'PSFzf'
    InstallModuleIfMissing 'posh-git'
    InstallModuleIfMissing 'Terminal-Icons'
  } else { Info '已跳过模块安装。' }
} catch { Warn '模块安装流程失败（已跳过）。' }

function Ensure-WinGetExeLink($exeName){ $pkgRoot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"; $exe = Get-ChildItem -Path $pkgRoot -Recurse -Filter $exeName -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $exeName } | Select-Object -First 1; if ($exe) { $linkPath = Join-Path $links $exeName; if (-not (Test-Path $linkPath)) { New-Item -ItemType HardLink -Path $linkPath -Target $exe.FullName | Out-Null; Ok "创建硬链接: $linkPath -> $($exe.FullName)" } else { Ok "硬链接已存在: $linkPath" } } else { Warn "未在 winget 包目录找到 $exeName" } }
try {
  Write-Host "\n== WinGet Links 硬链接 ==" -ForegroundColor Cyan
  $doLinks = if ($NonInteractive -or $Yes) { 'y' } else { Read-Host '是否为 fzf/fd 创建硬链接以稳定 PATH 发现? (Y/n)' }
  if (($doLinks -eq '') -or ($doLinks -match '^[Yy]$')) {
    if (ShouldInstall 'fzf') { Ensure-WinGetExeLink 'fzf.exe' }
    if (ShouldInstall 'fd') { Ensure-WinGetExeLink 'fd.exe' }
  } else { Info '已跳过硬链接创建。' }
} catch {}

# 6) 写入 oh-my-posh 主题文件（可选，便于后续交互切换）
$themesDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"; if (!(Test-Path $themesDir)) { New-Item -ItemType Directory -Path $themesDir | Out-Null }
$themePath = Join-Path $themesDir 'omp-wq.omp.json'
$themeJson = @"
{
  "`$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "final_space": true,
  "palette": {
    "folder_fg": "#FFFFFF",
    "folder_bg": "#3B82F6",
    "git_fg": "#1F2937",
    "git_bg": "#F59E0B"
  },
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "type": "path",
          "style": "powerline",
          "foreground": "folder_fg",
          "background": "folder_bg",
          "properties": { "style": "folder" }
        },
        {
          "type": "git",
          "style": "powerline",
          "foreground": "git_fg",
          "background": "git_bg",
          "properties": {
            "fetch_status": true,
            "display_status": true,
            "display_stash_count": false,
            "display_upstream_icon": false
          }
        }
      ]
    }
  ]
}
"@
try {
  $doThemeFiles = if ($NonInteractive -or $Yes) { 'y' } else { Read-Host '是否写入/更新自定义主题文件 omp-wq.omp.json? (Y/n)' }
  if (($doThemeFiles -eq '') -or ($doThemeFiles -match '^[Yy]$')) {
    Set-Content -Path $themePath -Value $themeJson -Encoding UTF8; Ok "主题写入: $themePath"
    # 如果仓库内存在 themes 目录，则复制其中的主题到 oh-my-posh 主题目录，便于随时切换
    try {
      $scriptRoot = Split-Path -Parent $PSCommandPath
      $repoThemes = Join-Path $scriptRoot '..\..\snippets\windows\themes'
      if (Test-Path $repoThemes) {
        Get-ChildItem -Path $repoThemes -Filter '*.omp.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
          Copy-Item -Force $_.FullName (Join-Path $themesDir $_.Name)
        }
        Ok "已复制仓库主题到: $themesDir"
      } else {
        # 远程模式回退：从发行仓库下载主题文件到 oh-my-posh 主题目录
        $distThemeBase = "$Global:DistBase/snippets/windows/themes"
        $files = @('omp-default.omp.json','omp-wq-capsule.omp.json','omp-wq-minimal.omp.json','omp-wq-mono.omp.json','omp-wq-pastel.omp.json')
        foreach ($f in $files) {
          try {
            Invoke-WebRequest -Uri ("$distThemeBase/" + $f) -UseBasicParsing -OutFile (Join-Path $themesDir $f) -ErrorAction Stop | Out-Null
          } catch { }
        }
        Ok "已从发行仓库同步主题到: $themesDir"
      }
    } catch {}
  } else { Info '已跳过主题文件写入。' }
} catch {}

# 7) fdignore（加速与减少噪声）
$fdIgnorePath = Join-Path $HOME '.fdignore'
$fdIgnore = @"
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
"@
try {
  $doFd = if ($NonInteractive -or $Yes) { 'y' } else { Read-Host '是否写入 ~/.fdignore? (Y/n)' }
  if (($doFd -eq '') -or ($doFd -match '^[Yy]$')) { Set-Content -Path $fdIgnorePath -Value $fdIgnore -Encoding UTF8; Ok "fdignore 写入: $fdIgnorePath" }
  else { Info '已跳过 fdignore 写入。' }
} catch {}

# 8) 写入 PowerShell 配置块（幂等追加 + 备份）
$profilePath = $PROFILE
if ($Global:WriteProfile) {
  if (!(Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath | Out-Null; Info "创建配置文件: $profilePath" }
  else { try { $ts = Get-Date -Format 'yyyyMMddHHmmss'; Copy-Item $profilePath "$profilePath.$ts.bak" -ErrorAction SilentlyContinue; Ok "已备份配置: $profilePath.$ts.bak" } catch {} }
} else { Info '已跳过 `$PROFILE 初始化与备份。' }

function Add-ProfileBlock($marker, $content){
  if (-not $Global:WriteProfile) { Info ("跳过写入配置块（按确认设置）: " + $marker); return }
  $exists = Select-String -Path $profilePath -Pattern ([regex]::Escape($marker)) -ErrorAction SilentlyContinue
  if (-not $exists) { Add-Content -Path $profilePath -Value $content; Ok ("已写入配置块: " + $marker) } else { Ok ("配置块已存在，跳过: " + $marker) }
}

$fzfBootstrap = @"
# FZF PATH bootstrap
try {
  `$links = "`$env:LOCALAPPDATA\Microsoft\WinGet\Links"
  if (!(Test-Path `$links)) { New-Item -ItemType Directory -Path `$links | Out-Null }
  `$paths = `$env:Path -split ';'
  if (`$paths -notcontains `$links) {
    [Environment]::SetEnvironmentVariable('PATH', (`$env:Path + ';' + `$links), 'User')
    `$env:Path = `$env:Path + ';' + `$links
  }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    `$pkgRoot = "`$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    `$fzfExe = Get-ChildItem -Path `$pkgRoot -Recurse -Filter fzf.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (`$fzfExe) {
      `$linkPath = Join-Path `$links 'fzf.exe'
      if (-not (Test-Path `$linkPath)) { New-Item -ItemType HardLink -Path `$linkPath -Target `$fzfExe.FullName | Out-Null }
    }
  }
  Set-Alias fsf fzf
} catch {}
"@

$psfzfIntegration = @"
# PSFzf 文件/目录快捷键与 fd 集成
if (Get-Command fzf -ErrorAction SilentlyContinue) {
  if (Get-Command fd -ErrorAction SilentlyContinue) {
    `$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude .next --exclude coverage'
    `$env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude dist --exclude .next --exclude coverage'
  }
  if (Get-Command bat -ErrorAction SilentlyContinue) {
    `$env:FZF_DEFAULT_OPTS = '--height 45% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :300 {}" --preview-window right,60%,border'
  }
  try { Set-PsFzfOption -PSReadLineKeyHandler -File } catch {}
  try { Set-PsFzfOption -PSReadLineKeyHandler -Directory } catch {}
  try { Set-PsFzfOption -PSReadLineKeyHandler -History } catch {}
}
"@

$ompInit = @"
# 启用自定义 oh-my-posh 主题
try {
  oh-my-posh init pwsh --config "`$env:LOCALAPPDATA\Programs\oh-my-posh\themes\omp-wq.omp.json" | Invoke-Expression
} catch {}
"@

$customSrc = @"
# 用户自定义配置（函数/别名）
try {
  `$custom = Join-Path `$HOME 'Documents\PowerShell\UserProfile.custom.ps1'
  if (Test-Path `$custom) { . `$custom }
} catch {}
"@

Add-ProfileBlock '# FZF PATH bootstrap' $fzfBootstrap
Add-ProfileBlock '# PSFzf 文件/目录快捷键与 fd 集成' $psfzfIntegration
Add-ProfileBlock '# 启用自定义 oh-my-posh 主题' $ompInit
Add-ProfileBlock '# 用户自定义配置（函数/别名）' $customSrc

# 提供 oh-my-posh 主题切换助手（支持仓库主题与内置主题名），幂等追加
$ompSwitcher = @"
# oh-my-posh 主题切换助手
function omp-use([string]`$name) {
  try {
    `$themesDir = "`$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
    `$candidate = Join-Path `$themesDir ("`$name" + '.omp.json')
    if (Test-Path `$candidate) {
      oh-my-posh init pwsh --config `$candidate | Invoke-Expression
      Write-Host ("oh-my-posh -> " + `$name) -ForegroundColor Green
      return
    }
    # 尝试内置主题目录（oh-my-posh 会设置 POSH_THEMES_PATH）
    if (`$env:POSH_THEMES_PATH) {
      `$builtin = Join-Path `$env:POSH_THEMES_PATH ("`$name" + '.omp.json')
      if (Test-Path `$builtin) {
        oh-my-posh init pwsh --config `$builtin | Invoke-Expression
        Write-Host ("oh-my-posh -> builtin " + `$name) -ForegroundColor Green
        return
      }
    }
    Write-Host ("未找到主题: " + `$name) -ForegroundColor Yellow
  } catch {
    Write-Host "切换主题失败" -ForegroundColor Red
  }
}
Set-Alias omp omp-use
function omp-min { omp-use 'omp-wq-minimal' }
function omp-def { omp-use 'jandedobbeleer' }
"@
Add-ProfileBlock '# oh-my-posh 主题切换助手' $ompSwitcher

# === 主题交互选择与持久化 ===
function Get-ThemeCandidates() {
  $list = @()
  $sysDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes"
  if (Test-Path $sysDir) {
    $list += Get-ChildItem -Path $sysDir -Filter '*.omp.json' -File | ForEach-Object { [PSCustomObject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($_.Name); Path = $_.FullName; Source = 'system' } }
  }
  if ($env:POSH_THEMES_PATH -and (Test-Path $env:POSH_THEMES_PATH)) {
    $list += Get-ChildItem -Path $env:POSH_THEMES_PATH -Filter '*.omp.json' -File | ForEach-Object { [PSCustomObject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($_.Name); Path = $_.FullName; Source = 'builtin' } }
  }
  # 去重（按 Name）
  $list | Group-Object Name | ForEach-Object { $_.Group | Select-Object -First 1 }
}

function Ensure-ProfileTheme($path) {
  # 若存在 oh-my-posh init 行，替换其路径；否则追加初始化块
  $profilePath = $PROFILE
  $content = Get-Content -Raw -Path $profilePath -ErrorAction SilentlyContinue
  if ($null -ne $content -and ($content -match 'oh-my-posh init pwsh --config "[^"]+"')) {
    $new = $content -replace 'oh-my-posh init pwsh --config "[^"]+"', ('oh-my-posh init pwsh --config "' + $path + '"')
    Set-Content -Path $profilePath -Value $new -Encoding UTF8
    Ok "已更新 $PROFILE 默认主题 -> $path"
  } else {
    $blk = @"
# 启用自定义 oh-my-posh 主题
try {
  oh-my-posh init pwsh --config "$path" | Invoke-Expression
} catch {}
"@
    Add-ProfileBlock '# 启用自定义 oh-my-posh 主题' $blk
  }
}

function Apply-Theme($path) {
  try { oh-my-posh init pwsh --config $path | Invoke-Expression; Ok "已应用主题: $path" } catch { Warn "主题应用失败: $path" }
}

try {
  $themes = Get-ThemeCandidates
  if ($themes.Count -gt 0) {
    # 默认推荐主题（若存在）：omp-wq、omp-wq-minimal 或 jandedobbeleer
    $preferred = ($themes | Where-Object { $_.Name -eq 'omp-wq' } | Select-Object -First 1)
    if (-not $preferred) { $preferred = ($themes | Where-Object { $_.Name -eq 'omp-wq-minimal' } | Select-Object -First 1) }
    if (-not $preferred) { $preferred = ($themes | Where-Object { $_.Name -eq 'jandedobbeleer' -and $_.Source -eq 'builtin' } | Select-Object -First 1) }

    if ($Theme) {
      $selected = ($themes | Where-Object { $_.Name -eq $Theme } | Select-Object -First 1)
      if ($selected) { Apply-Theme $selected.Path; if ($NonInteractive) { Ensure-ProfileTheme $selected.Path } }
      else { Warn "未找到指定主题: $Theme" }
    } elseif (-not $NonInteractive) {
      Write-Host "检测到 $($themes.Count) 个主题。默认推荐: $($preferred.Name)。" -ForegroundColor Cyan
      $useDefault = Read-Host "是否使用默认推荐? (Y/n)"
      if (($useDefault -eq '') -or ($useDefault -match '^[Yy]$')) {
        Apply-Theme $preferred.Path
        $persist = Read-Host "是否将该主题设为默认并写入 `$PROFILE? (Y/n)"
        if (($persist -eq '') -or ($persist -match '^[Yy]$')) { Ensure-ProfileTheme $preferred.Path }
      } else {
        # 枚举列表供选择
        for ($i=0; $i -lt $themes.Count; $i++) {
          Write-Host ("[$i] " + $themes[$i].Name + " (" + $themes[$i].Source + ")")
        }
        $idx = Read-Host "输入编号以选择主题"
        if ($idx -match '^[0-9]+$' -and [int]$idx -ge 0 -and [int]$idx -lt $themes.Count) {
          $sel = $themes[[int]$idx]
          Apply-Theme $sel.Path
          $persist2 = Read-Host "是否将该主题设为默认并写入 `$PROFILE? (Y/n)"
          if (($persist2 -eq '') -or ($persist2 -match '^[Yy]$')) { Ensure-ProfileTheme $sel.Path }
        } else { Warn '选择无效，跳过主题切换。' }
      }
    } else {
      Info 'NonInteractive 模式：跳过交互式主题选择。'
    }
  } else { Warn '未找到任何主题文件，跳过交互式选择。' }
} catch { Warn '主题选择逻辑执行失败（已跳过）。' }

# 9) 浏览器安装（多选 + 已安装检测）
try {
  Write-Host "\n== 浏览器安装 ==" -ForegroundColor Cyan

  function Get-BrowserDefs() {
    $list = @()
    $list += [PSCustomObject]@{ Name='Google Chrome'; Key='chrome'; WingetId='Google.Chrome'; Cmd='chrome'; ExeCandidates=@('C:\Program Files\Google\Chrome\Application\chrome.exe','C:\Program Files (x86)\Google\Chrome\Application\chrome.exe') }
    $list += [PSCustomObject]@{ Name='Microsoft Edge'; Key='edge'; WingetId='Microsoft.Edge'; Cmd='msedge'; ExeCandidates=@('C:\Program Files\Microsoft\Edge\Application\msedge.exe','C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe') }
    $list += [PSCustomObject]@{ Name='Mozilla Firefox'; Key='firefox'; WingetId='Mozilla.Firefox'; Cmd='firefox'; ExeCandidates=@('C:\Program Files\Mozilla Firefox\firefox.exe','C:\Program Files (x86)\Mozilla Firefox\firefox.exe') }
    return $list
  }

  function Test-BrowserInstalled($def) {
    try { if ($def.Cmd -and (Get-Command $def.Cmd -ErrorAction SilentlyContinue)) { return $true } } catch {}
    foreach ($p in $def.ExeCandidates) { if (Test-Path $p) { return $true } }
    try {
      $out = (winget list --id $($def.WingetId) -e 2>$null | Out-String)
      if ($out -match [regex]::Escape($def.WingetId)) { return $true }
    } catch {}
    return $false
  }

  $defs = Get-BrowserDefs
  $selectedKeys = @()
  if (-not [string]::IsNullOrWhiteSpace($Browsers)) {
    $selectedKeys = $Browsers.Split(',') | ForEach-Object { $_.Trim().ToLower() }
  } elseif ($NonInteractive -or $Yes) {
    $selectedKeys = @('chrome','firefox')
  } else {
    Write-Host "可选浏览器：" -ForegroundColor Cyan
    for ($i=0; $i -lt $defs.Count; $i++) { Write-Host ("[$i] " + $defs[$i].Name) }
    $raw = Read-Host "输入编号（逗号分隔）进行多选，留空跳过"
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $idx = $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 0 -and $_ -lt $defs.Count }
      $selectedKeys = @()
      foreach ($n in $idx) { $selectedKeys += $defs[$n].Key }
    }
  }

  if ($selectedKeys.Count -eq 0) { Info '未选择浏览器，跳过安装。' }
  else {
    foreach ($key in $selectedKeys) {
      $def = ($defs | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
      if (-not $def) { Warn "未知浏览器: $key"; continue }
      if (Test-BrowserInstalled $def) { Ok ("已安装，跳过: " + $def.Name); continue }
      Info ("安装: " + $def.Name)
      try {
        winget install --id $($def.WingetId) -e $wingetOpts | Out-Null
        if (Test-BrowserInstalled $def) { Ok ("安装完成: " + $def.Name) } else { Warn ("安装可能失败: " + $def.Name) }
      } catch { Warn ("安装失败: " + $def.Name) }
    }
  }
} catch { Warn '浏览器安装流程执行失败（已跳过）。' }

# 10) 编辑器安装（多选 + 已安装检测 + 可选安装目录）
try {
  Write-Host "\n== 编辑器安装 ==" -ForegroundColor Cyan

  function Get-EditorDefs() {
    $list = @()
    $list += [PSCustomObject]@{ Name='Visual Studio Code'; Key='vscode'; WingetId='Microsoft.VisualStudioCode'; Cmd='code'; ExeCandidates=@("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe", 'C:\Program Files\Microsoft VS Code\Code.exe') }
    $list += [PSCustomObject]@{ Name='Cursor'; Key='cursor'; WingetId='Cursor.Cursor'; Cmd='cursor'; ExeCandidates=@("$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe", 'C:\Program Files\Cursor\Cursor.exe') }
    $list += [PSCustomObject]@{ Name='Trae'; Key='trae'; WingetId=''; Cmd=''; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='Trae CN'; Key='trae-cn'; WingetId=''; Cmd=''; ExeCandidates=@() }
    return $list
  }

  function Test-EditorInstalled($def) {
    try { if ($def.Cmd -and (Get-Command $def.Cmd -ErrorAction SilentlyContinue)) { return $true } } catch {}
    foreach ($p in $def.ExeCandidates) { if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path $p)) { return $true } }
    if ($def.WingetId) {
      try { $out = (winget list --id $($def.WingetId) -e 2>$null | Out-String); if ($out -match [regex]::Escape($def.WingetId)) { return $true } } catch {}
    }
    return $false
  }

  $defs = Get-EditorDefs
  $selectedKeys = @()
  if (-not [string]::IsNullOrWhiteSpace($Editors)) {
    $selectedKeys = $Editors.Split(',') | ForEach-Object { $_.Trim().ToLower() }
  } elseif ($NonInteractive -or $Yes) {
    $selectedKeys = @('vscode')
  } else {
    Write-Host "可选编辑器：" -ForegroundColor Cyan
    for ($i=0; $i -lt $defs.Count; $i++) { Write-Host ("[$i] " + $defs[$i].Name) }
    $raw = Read-Host "输入编号（逗号分隔）进行多选，留空跳过"
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $idx = $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 0 -and $_ -lt $defs.Count }
      $selectedKeys = @(); foreach ($n in $idx) { $selectedKeys += $defs[$n].Key }
    }
  }

  if ($selectedKeys.Count -eq 0) { Info '未选择编辑器，跳过安装。' }
  else {
    foreach ($key in $selectedKeys) {
      $def = ($defs | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
      if (-not $def) { Warn "未知编辑器: $key"; continue }
      if (Test-EditorInstalled $def) { Ok ("已安装，跳过: " + $def.Name); continue }
      if ($def.WingetId) {
        Info ("安装: " + $def.Name + " 到 " + $Global:InstallBaseDir)
        WingetInstallWithLocation $def.WingetId $Global:InstallBaseDir
        if (Test-EditorInstalled $def) { Ok ("安装完成: " + $def.Name + ", 路径可能位于 " + $Global:InstallBaseDir) } else { Warn ("安装可能失败: " + $def.Name) }
      } else {
        Warn ("无法通过 winget 安装: " + $def.Name)
        if ($key -eq 'trae') { Info '请前往 https://trae.ai 下载并安装（可选择目录为所选安装目录）。' }
        elseif ($key -eq 'trae-cn') { Info '请前往 https://cn.trae.ai 或镜像站下载并安装。' }
      }
    }
  }
} catch { Warn '编辑器安装流程执行失败（已跳过）。' }

# 11) 开发工具安装（多选 + 已安装检测 + 可选安装目录）
try {
  Write-Host "\n== 开发工具安装 ==" -ForegroundColor Cyan

  function Get-DevToolDefs() {
    $list = @()
    $list += [PSCustomObject]@{ Name='Rust (rustup)'; Key='rust'; WingetId='Rustlang.Rustup'; Cmd='rustup'; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='Python 3'; Key='python'; WingetId='Python.Python.3'; Cmd='python'; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='Docker Desktop'; Key='docker'; WingetId='Docker.DockerDesktop'; Cmd='docker'; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='JDK (Temurin 17)'; Key='jdk'; WingetId='EclipseAdoptium.Temurin.17.JDK'; Cmd='java'; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='Android Studio'; Key='android'; WingetId='Google.AndroidStudio'; Cmd='studio64'; ExeCandidates=@() }
    $list += [PSCustomObject]@{ Name='Android Platform Tools (ADB)'; Key='android-tools'; WingetId='Google.AndroidSDK.PlatformTools'; Cmd='adb'; ExeCandidates=@() }
    return $list
  }

  function Test-DevToolInstalled($def) {
    try { if ($def.Cmd -and (Get-Command $def.Cmd -ErrorAction SilentlyContinue)) { return $true } } catch {}
    if ($def.WingetId) {
      try { $out = (winget list --id $($def.WingetId) -e 2>$null | Out-String); if ($out -match [regex]::Escape($def.WingetId)) { return $true } } catch {}
    }
    return $false
  }

  $defs = Get-DevToolDefs
  $selectedKeys = @()
  if (-not [string]::IsNullOrWhiteSpace($DevTools)) {
    $selectedKeys = $DevTools.Split(',') | ForEach-Object { $_.Trim().ToLower() }
  } elseif ($NonInteractive -or $Yes) {
    $selectedKeys = @('rust','python','docker','jdk','android','android-tools')
  } else {
    Write-Host "可选开发工具：" -ForegroundColor Cyan
    for ($i=0; $i -lt $defs.Count; $i++) { Write-Host ("[$i] " + $defs[$i].Name) }
    $raw = Read-Host "输入编号（逗号分隔）进行多选，留空跳过"
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $idx = $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 0 -and $_ -lt $defs.Count }
      $selectedKeys = @(); foreach ($n in $idx) { $selectedKeys += $defs[$n].Key }
    }
  }

  if ($selectedKeys.Count -eq 0) { Info '未选择开发工具，跳过安装。' }
  else {
    foreach ($key in $selectedKeys) {
      $def = ($defs | Where-Object { $_.Key -eq $key } | Select-Object -First 1)
      if (-not $def) { Warn "未知开发工具: $key"; continue }
      if (Test-DevToolInstalled $def) { Ok ("已安装，跳过: " + $def.Name); continue }
      if ($def.WingetId) {
        Info ("安装: " + $def.Name + " 到 " + $Global:InstallBaseDir)
        WingetInstallWithLocation $def.WingetId $Global:InstallBaseDir
        if (Test-DevToolInstalled $def) { Ok ("安装完成: " + $def.Name) } else { Warn ("安装可能失败: " + $def.Name) }
        if ($key -eq 'docker') { Info 'Docker Desktop 安装后需要登录并启用 WSL2 集成（如需）。' }
        if ($key -eq 'rust') { Info 'Rust 将通过 rustup 管理，默认安装路径位于用户目录。' }
        if ($key -eq 'jdk') { Info 'JDK 安装后可通过 JAVA_HOME 环境变量或 where java 检查。' }
        if ($key -eq 'android') { Info 'Android Studio 可在首次启动中安装 SDK；如需仅命令行请同时选择 android-tools。' }
        if ($key -eq 'android-tools') { try { Ok ("adb: " + (adb version)) } catch {} }
      } else {
        Warn ("无法通过 winget 安装: " + $def.Name)
      }
    }
  }
} catch { Warn '开发工具安装流程执行失败（已跳过）。' }

# 12) Git 安装与全局配置（交互）
try {
  Write-Host "\n== Git 安装与全局配置 ==" -ForegroundColor Cyan
  $hasGit = (Get-Command git -ErrorAction SilentlyContinue)
  if (-not $hasGit) {
    if ($NonInteractive -or $Yes) { $ans = 'y' } else { $ans = Read-Host '未检测到 Git，是否安装? (Y/n)' }
    if (($ans -eq '') -or ($ans -match '^[Yy]$')) { WinGetInstall 'Git.Git' } else { Info '跳过 Git 安装。' }
  } else { Ok '已检测到 Git' }

  if (Get-Command git -ErrorAction SilentlyContinue) {
    $name = ''; $email = ''
    if ($NonInteractive -or $Yes) {
      git config --global init.defaultBranch main | Out-Null
      git config --global core.autocrlf true | Out-Null
      git config --global core.filemode false | Out-Null
      git config --global credential.helper manager | Out-Null
      Ok '已应用基础 Git 选项（默认分支 main，autocrlf=true，filemode=false，凭据管理器）'
    } else {
      $name = Read-Host '设置 user.name（留空跳过）'
      if (-not [string]::IsNullOrWhiteSpace($name)) { git config --global user.name "$name" | Out-Null }
      $email = Read-Host '设置 user.email（留空跳过）'
      if (-not [string]::IsNullOrWhiteSpace($email)) { git config --global user.email "$email" | Out-Null }
      $ans = Read-Host '默认分支设为 main? (Y/n)'; if (($ans -eq '') -or ($ans -match '^[Yy]$')) { git config --global init.defaultBranch main | Out-Null }
      $ans = Read-Host 'core.autocrlf 设为 true? (Y/n)'; if (($ans -eq '') -or ($ans -match '^[Yy]$')) { git config --global core.autocrlf true | Out-Null }
      $ans = Read-Host 'core.filemode 设为 false? (Y/n)'; if (($ans -eq '') -or ($ans -match '^[Yy]$')) { git config --global core.filemode false | Out-Null }
      $ans = Read-Host '启用凭据管理器 (manager)? (Y/n)'; if (($ans -eq '') -or ($ans -match '^[Yy]$')) { git config --global credential.helper manager | Out-Null }
      Ok 'Git 全局配置完成'
    }
    try { Info ("当前 Git 配置:\n" + (git config --global --list | Out-String)) } catch {}
  }
} catch { Warn 'Git 安装/配置失败（可手动运行 git config 设置）。' }

# 9) NVM / Node 安装与配置（交互式）
try {
  Write-Host "\n== NVM / Node 初始化 ==" -ForegroundColor Cyan
  $customNvm = if ($NonInteractive -or $Yes) { 'n' } else { Read-Host "是否自定义 NVM 安装位置? (Y/n)" }
  if (($customNvm -eq '') -or ($customNvm -match '^[Yy]$')) {
    Info '将以交互方式安装 NVM（安装过程中可选择路径）'
    winget install --id CoreyButler.NVMforWindows -e --accept-package-agreements --accept-source-agreements | Out-Null
  } else {
    WinGetInstall 'CoreyButler.NVMforWindows'
  }

  if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    Warn 'nvm 暂不可用，请重启 PowerShell 或手动将 NVM 目录加入 PATH 后重试。'
  } else {
    $nvmExe = (Get-Command nvm).Source
    $nvmHome = Split-Path -Parent $nvmExe
    $settings = Join-Path $nvmHome 'settings.txt'
    $rootDefault = if ($NvmRoot) { $NvmRoot } else { Join-Path $nvmHome 'nodejs' }
    $symlinkDefault = if ($NvmSymlink) { $NvmSymlink } else { 'C:\\Program Files\\nodejs' }
    if ($NonInteractive -or $Yes -or $NvmRoot -or $NvmSymlink) {
      $rootSel = $rootDefault
      $symlinkSel = $symlinkDefault
    } else {
      $rootSel = Read-Host "选择 Node 版本存放目录 (默认: $rootDefault)"
      if ([string]::IsNullOrWhiteSpace($rootSel)) { $rootSel = $rootDefault }
      $symlinkSel = Read-Host "选择 Node 可执行文件链接目录 (默认: $symlinkDefault)"
      if ([string]::IsNullOrWhiteSpace($symlinkSel)) { $symlinkSel = $symlinkDefault }
    }
    if (!(Test-Path $rootSel)) { New-Item -ItemType Directory -Path $rootSel -Force | Out-Null }
    if (!(Test-Path $symlinkSel)) { New-Item -ItemType Directory -Path $symlinkSel -Force | Out-Null }
    $archLine = 'arch: 64'
    $proxyLine = if ($Proxy) { "proxy: $Proxy" } else { 'proxy: none' }
    $settingsContent = "root: $rootSel`npath: $symlinkSel`n$archLine`n$proxyLine"
    Set-Content -Path $settings -Value $settingsContent -Encoding UTF8
    Ok "NVM settings.txt 更新: root=$rootSel, path=$symlinkSel"

    Write-Host 'Node 版本选择：lts / latest / 指定版本 或编号 1/2/3' -ForegroundColor Cyan
    $nodeSelRaw = if ($Node) { $Node } elseif ($NodeChoice) { $NodeChoice } elseif ($NonInteractive -or $Yes) { 'lts' } else { Read-Host '输入选项 (lts/latest/版本号 或 1/2/3)' }
    $choice = $nodeSelRaw
    $version = ''
    if ($choice -eq '1' -or $choice -match '^(lts)$') {
      $vText = nvm list available | Select-String -Pattern 'Latest LTS' | Select-Object -First 1
      if ($vText) { $version = ($vText -replace '.*:\s*([0-9\.]+).*','$1') }
      if (-not $version) { $version = '20.18.0' }
    } elseif ($choice -eq '2' -or $choice -match '^(latest)$') {
      $vText = nvm list available | Select-String -Pattern '^Latest\s' | Select-Object -First 1
      if ($vText) { $version = ($vText -replace '.*:\s*([0-9\.]+).*','$1') }
      if (-not $version) { $version = '21.6.2' }
    } else {
      if ($NodeVersion) { $version = $NodeVersion }
      elseif ($choice -match '^[0-9]+(\.[0-9]+){0,2}$') { $version = $choice }
      elseif ($NonInteractive -or $Yes) { $version = '' }
      else { $version = Read-Host '输入具体版本号（如 20.18.0）' }
    }
    if ($version) {
      Info "安装 Node $version"
      nvm install $version | Out-Null
      nvm use $version | Out-Null
      nvm on | Out-Null
      try { Ok ("node: " + (node -v)) } catch {}
      Ok "Node $version 已安装并启用"
    } else { Warn '未选择版本，跳过 Node 安装。' }
  }
} catch { Warn 'NVM/Node 初始化过程失败（可手动执行 nvm 命令重试）。' }

# 10) 安装与配置 pnpm
try {
  Write-Host "\n== pnpm 安装与配置 ==" -ForegroundColor Cyan
  $installPnpm = Read-Host '是否安装 pnpm? (Y/n)'
  if (($installPnpm -eq '') -or ($installPnpm -match '^[Yy]$')) {
    $method = Read-Host '安装方式：1) corepack  2) winget (输入 1/2，默认 1)'
    if ($method -eq '2') {
      WinGetInstall 'pnpm.pnpm'
    } else {
      try { corepack enable | Out-Null } catch {}
      $pnpmVer = Read-Host '选择 pnpm 版本（如 latest 或 9.x；默认 latest）'
      if ([string]::IsNullOrWhiteSpace($pnpmVer)) { $pnpmVer = 'latest' }
      corepack prepare pnpm@$pnpmVer --activate | Out-Null
    }

    # 交互/参数设置 PNPM_HOME 并持久化（跨 Node 版本可复用全局 CLI 的关键目录）
    $pnpmHomeDefault = if ($PNPMHome) { $PNPMHome } else { Join-Path $HOME 'AppData\Local\pnpm' }
    $pnpmHomeSel = if ($PNPMHome -or $NonInteractive -or $Yes) { $pnpmHomeDefault } else { Read-Host "设置 PNPM_HOME（默认: $pnpmHomeDefault）" }
    if ([string]::IsNullOrWhiteSpace($pnpmHomeSel)) { $pnpmHomeSel = $pnpmHomeDefault }
    Ensure-Path $pnpmHomeSel
    [Environment]::SetEnvironmentVariable('PNPM_HOME', $pnpmHomeSel, 'User')
    $env:PNPM_HOME = $pnpmHomeSel
    Ok "PNPM_HOME -> $pnpmHomeSel"

    # 初始化 pnpm（使用自定义 PNPM_HOME）
    try { pnpm setup | Out-Null } catch {}

    # 配置 store-dir（可减少 C 盘压力或指向更快磁盘）
    $storeDefault = if ($PnpmStore) { $PnpmStore } else { Join-Path $pnpmHomeSel 'store\v3' }
    $storeSel = if ($PnpmStore -or $NonInteractive -or $Yes) { $storeDefault } else { Read-Host "设置 pnpm store 路径（默认: $storeDefault）" }
    if ([string]::IsNullOrWhiteSpace($storeSel)) { $storeSel = $storeDefault }
    if (!(Test-Path $storeSel)) { New-Item -ItemType Directory -Path $storeSel -Force | Out-Null }
    pnpm config set store-dir "$storeSel" | Out-Null
    Ok "pnpm 已安装，store: $storeSel, home: $pnpmHomeSel"
  } else { Info '跳过 pnpm 安装。' }
} catch { Warn 'pnpm 安装/配置失败（可手动执行 pnpm setup 与 pnpm config）。' }

# 11) 配置 npm 全局目录与 PATH
try {
  Write-Host "\n== npm 全局目录设置 ==" -ForegroundColor Cyan
  $prefixDefault = if ($NpmPrefix) { $NpmPrefix } else { Join-Path $HOME 'AppData\Roaming\npm' }
  $prefixSel = if ($NpmPrefix -or $NonInteractive -or $Yes) { $prefixDefault } else { Read-Host "设置 npm 全局包目录 prefix（默认: $prefixDefault）" }
  if ([string]::IsNullOrWhiteSpace($prefixSel)) { $prefixSel = $prefixDefault }
  if (!(Test-Path $prefixSel)) { New-Item -ItemType Directory -Path $prefixSel -Force | Out-Null }
  npm config set prefix "$prefixSel" | Out-Null
  Ok "npm prefix -> $prefixSel"
} catch { Warn 'npm prefix 配置失败（可使用 npm config set prefix 手工设置）。' }

# 12) 写入包管理器 PATH 引导（幂等）
$pkgPathBlock = @"
# Node 包管理器 PATH 引导
try {
  # PNPM_HOME
  if (`$env:PNPM_HOME) {
    if ((`$env:Path -split ';') -notcontains `$env:PNPM_HOME) {
      [Environment]::SetEnvironmentVariable('PATH', (`$env:Path + ';' + `$env:PNPM_HOME), 'User')
      `$env:Path = `$env:Path + ';' + `$env:PNPM_HOME
    }
  } else {
    `$pnpmHome = Join-Path `$HOME 'AppData\Local\pnpm'
    if ((`$env:Path -split ';') -notcontains `$pnpmHome) {
      [Environment]::SetEnvironmentVariable('PATH', (`$env:Path + ';' + `$pnpmHome), 'User')
      `$env:Path = `$env:Path + ';' + `$pnpmHome
    }
  }
  # npm prefix bin
  try {
    `$prefix = (npm config get prefix)
    if (`$prefix -and ((`$env:Path -split ';') -notcontains `$prefix)) {
      [Environment]::SetEnvironmentVariable('PATH', (`$env:Path + ';' + `$prefix), 'User')
      `$env:Path = `$env:Path + ';' + `$prefix
    }
  } catch {}
} catch {}
"@
Add-ProfileBlock '# Node 包管理器 PATH 引导' $pkgPathBlock

# 9) 部署用户自定义片段（从仓库复制到用户目录）
try {
  $scriptRoot = Split-Path -Parent $PSCommandPath
  $customSrcRepo = Join-Path $scriptRoot '..\..\snippets\windows\UserProfile.custom.ps1'
  $customDest = Join-Path $HOME 'Documents\PowerShell\UserProfile.custom.ps1'
  if (Test-Path $customSrcRepo) {
    Copy-Item -Force $customSrcRepo $customDest
    Ok "已部署用户自定义片段: $customDest"
  } else {
    # 远程模式回退：从发行仓库下载用户自定义片段
    try {
      Invoke-WebRequest -Uri "$Global:DistBase/snippets/windows/UserProfile.custom.ps1" -UseBasicParsing -OutFile $customDest -ErrorAction Stop | Out-Null
      Ok "已从发行仓库部署用户自定义片段: $customDest"
    } catch { Info '未发现用户自定义片段（可选），跳过复制。' }
  }
} catch {}

# 10) 验证输出
try { Ok ("fzf: " + (fzf --version)) } catch { Warn 'fzf 未就绪' }
try { Ok ("fd: " + (fd --version)) } catch { Warn 'fd 未就绪' }
try { Ok ("oh-my-posh: " + (oh-my-posh --version)) } catch { Warn 'oh-my-posh 未就绪' }

Ok '完成！如需立刻生效，请执行: . $PROFILE 或重启 PowerShell'

# 13) 执行结果清单（Markdown）
try {
  $produceReport = $false
  if ($NonInteractive -or $Yes) { $produceReport = $true }
  else {
    $ans = Read-Host '是否生成执行结果清单（Markdown）? (Y/n)'
    if (($ans -eq '') -or ($ans -match '^[Yy]$')) { $produceReport = $true }
  }
  if ($produceReport) {
    $reportDirDefault = if ($ResultReportDir) { $ResultReportDir } else { Join-Path $HOME 'Documents\DevEnvBootstrap\reports' }
    $reportDirSel = if ($ResultReportDir -or $NonInteractive -or $Yes) { $reportDirDefault } else { Read-Host ("选择清单保存目录（默认: " + $reportDirDefault + ")") }
    if ([string]::IsNullOrWhiteSpace($reportDirSel)) { $reportDirSel = $reportDirDefault }
    if (!(Test-Path $reportDirSel)) { New-Item -ItemType Directory -Path $reportDirSel -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outPath = Join-Path $reportDirSel ("bootstrap-windows-result-" + $stamp + ".md")

    function Get-VersionSafe([string]$cmd, [string]$arg='--version') { try { (& $cmd $arg) | Select-Object -First 1 } catch { '' } }
    function Get-CmdPath([string]$cmd) { try { (Get-Command $cmd -ErrorAction SilentlyContinue).Source } catch { '' } }

    $lines = @()
    $lines += "# DevEnvBootstrap 执行结果清单"
    $lines += ""
    $lines += ("- 时间：" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $lines += ("- 安装目录：" + $Global:InstallBaseDir)
    $lines += ("- WinGet Links：" + $links)
    $lines += ("- `$PROFILE 写入：" + ($(if ($Global:WriteProfile) { '是' } else { '否' })))
    $lines += ""
    $lines += "## 核心工具"
    $lines += ("- fzf：" + (Get-VersionSafe 'fzf') + "  路径：" + (Get-CmdPath 'fzf'))
    $lines += ("- fd：" + (Get-VersionSafe 'fd' '--version') + "  路径：" + (Get-CmdPath 'fd'))
    $lines += ("- ripgrep：" + (Get-VersionSafe 'rg' '--version') + "  路径：" + (Get-CmdPath 'rg'))
    $lines += ("- bat：" + (Get-VersionSafe 'bat' '--version') + "  路径：" + (Get-CmdPath 'bat'))
    $lines += ("- zoxide：" + (Get-VersionSafe 'zoxide' '--version') + "  路径：" + (Get-CmdPath 'zoxide'))
    $lines += ("- oh-my-posh：" + (Get-VersionSafe 'oh-my-posh' '--version') + "  路径：" + (Get-CmdPath 'oh-my-posh'))
    $lines += ""
    $lines += "## Git"
    $lines += ("- 版本：" + (Get-VersionSafe 'git' '--version'))
    try { $lines += ("- 配置：\n" + ((git config --global --list) | Out-String).Trim()) } catch {}
    $lines += ""
    $lines += "## Node / 包管理器"
    try { $lines += ("- node：" + (Get-VersionSafe 'node' '--version')) } catch {}
    try { $lines += ("- pnpm：" + (Get-VersionSafe 'pnpm' '--version')) } catch {}
    try { $lines += ("- npm prefix：" + (npm config get prefix)) } catch {}
    try { $lines += ("- PNPM_HOME：" + $env:PNPM_HOME) } catch {}
    $lines += ""
    $lines += "## 主题"
    $lines += ("- 自定义主题文件：" + $themePath)
    try { $lines += ("- 当前 oh-my-posh 配置：" + ((Select-String -Path $PROFILE -Pattern 'oh-my-posh init pwsh --config "[^"]+"').Matches[0].Value)) } catch {}
    $lines += ""
    $lines += "## 其他文件路径"
    $lines += ("- ~/.fdignore：" + $fdIgnorePath)
    $lines += ("- `$PROFILE：" + $PROFILE)
    $lines += ""
    Set-Content -Path $outPath -Value ($lines -join "`n") -Encoding UTF8
    Ok ("执行结果清单已生成：" + $outPath)
  }
} catch { Warn '生成执行结果清单失败（已跳过）。' }
