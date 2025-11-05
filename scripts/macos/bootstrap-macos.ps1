# bootstrap-macos.ps1 - macOS 初始化骨架（待完善）
[CmdletBinding()]param(
  [string]$Proxy = '',
  [string]$Theme = '',
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Continue'
function Info($m){ Write-Host "[+] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

try {
  $PersistProxy = $false
  if ($Proxy) {
    $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy; Info "已设置代理为 $Proxy"
  } elseif (-not $NonInteractive) {
    Write-Host "== 代理配置 ==" -ForegroundColor Cyan
    $useProxy = Read-Host "是否启用 HTTP(S) 代理? (Y/n)"
    if (($useProxy -eq '') -or ($useProxy -match '^[Yy]$')) {
      $portSel = Read-Host "输入代理端口 (默认: 7890)"
      if (-not ($portSel -match '^[0-9]+$') -or [string]::IsNullOrWhiteSpace($portSel)) { $portSel = '7890' }
      $Proxy = "http://127.0.0.1:$portSel"
      $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy; Ok "代理已启用: $Proxy"
      $persistAns = Read-Host "是否写入 `$PROFILE 持久化代理设置? (Y/n)"
      if (($persistAns -eq '') -or ($persistAns -match '^[Yy]$')) { $PersistProxy = $true }
    } else { Info '已选择不启用代理（可通过 -Proxy 传入或稍后手动配置）。' }
  }

  # 基础检查：Homebrew
  if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
    Warn '未检测到 Homebrew。后续实现将使用 brew 安装工具包。'
    Warn '请先安装 Homebrew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  } else {
    Info '已检测到 Homebrew（具体安装步骤后续补充）。'
  }

  # 主题与配置占位目录
  $scriptRoot = Split-Path -Parent $PSCommandPath
  $repoThemes = Join-Path $scriptRoot '..\..\themes'
  $poshThemes = Join-Path $HOME '.poshthemes'
  if (!(Test-Path $poshThemes)) { New-Item -ItemType Directory -Path $poshThemes | Out-Null }
  if (Test-Path $repoThemes) {
    Get-ChildItem -Path $repoThemes -Filter '*.omp.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
      Copy-Item -Force $_.FullName (Join-Path $poshThemes $_.Name)
    }
    Ok "已复制仓库主题到: $poshThemes"
  }

  # 持久化代理设置（如在开头交互选择了持久化）
  if ($PersistProxy -and $Proxy) {
    $profilePath = $PROFILE
    if (!(Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath | Out-Null; Info "创建配置文件: $profilePath" }
    $marker = '# 系统代理设置'
    $exists = Select-String -Path $profilePath -Pattern ([regex]::Escape($marker)) -ErrorAction SilentlyContinue
    if (-not $exists) {
      $blk = @"
# 系统代理设置
`$env:HTTP_PROXY = "$Proxy"
`$env:HTTPS_PROXY = "$Proxy"
"@
      Add-Content -Path $profilePath -Value $blk
      Ok "已写入配置块: $marker"
    } else { Ok "配置块已存在，跳过: $marker" }
  }

  # fdignore（与Windows一致）
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
  Set-Content -Path $fdIgnorePath -Value $fdIgnore -Encoding UTF8; Ok "fdignore 写入: $fdIgnorePath"

  # PowerShell Profile 路径（pwsh on macOS）
  $profilePath = $PROFILE
  if (!(Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath | Out-Null; Info "创建配置文件: $profilePath" }

  # TODO: 后续补充：brew 安装 fzf/fd/rg/bat/zoxide、oh-my-posh 等；主题切换与持久化；Node + pnpm
  Warn 'macOS 初始化尚未完成，当前仅做结构占位与主题复制。'
} catch {
  Err ("macOS 初始化骨架执行失败: " + $_.Exception.Message)
}