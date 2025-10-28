# bootstrap.ps1 - 跨平台入口与分发
[CmdletBinding()]param(
  [string]$Proxy = '',
  [string]$Theme = '',
  [switch]$NonInteractive,
  [switch]$Help,
  [Parameter(ValueFromRemainingArguments=$true)] [string[]]$ForwardArgs
)

$ErrorActionPreference = 'Continue'
function Info($m){ Write-Host "[+] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[x] $m" -ForegroundColor Red }

$scriptRoot = Split-Path -Parent $PSCommandPath
$winScript = Join-Path $scriptRoot 'windows\bootstrap-windows.ps1'
$macScript = Join-Path $scriptRoot 'macos\bootstrap-macos.ps1'

try {
  if ($Help) {
    Write-Host "用法: pwsh -NoProfile -File ./scripts/bootstrap.ps1 [参数]" -ForegroundColor Cyan
    Write-Host "参数: -Proxy, -Theme, -NonInteractive, 其余参数原样转发至平台脚本" -ForegroundColor Cyan
    Write-Host "例子 (Windows): -PNPMHome 'D:\\DevTools\\pnpm' -PnpmStore 'D:\\DevCache\\pnpm-store\\v3' -NpmPrefix 'D:\\DevTools\\node-global' -Node lts -SkipTools 'fd,bat' -InstallDir 'C:\\DevTools' -Browsers 'chrome,edge,firefox' -Editors 'vscode,cursor,trae,trae-cn' -DevTools 'rust,python,docker,jdk,android,android-tools'" -ForegroundColor Cyan
    Write-Host "例子 (macOS): --pnpm-home '$HOME/DevTools/pnpm' --pnpm-store '$HOME/DevCache/pnpm-store/v3' --npm-prefix '$HOME/.npm-global' --node lts --skip-tools 'fd,ripgrep,bat' --browsers 'chrome,edge,firefox' --editors 'vscode,cursor,trae,trae-cn' --dev-tools 'rust,python,docker,jdk,android,android-tools'" -ForegroundColor Cyan
    return
  }
  # 代理透传（由子脚本具体处理）
  if ($Proxy) { $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy }

  $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
  $isMacOS = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)

  if ($isWindows) {
    if (Test-Path $winScript) {
      Info "检测到 Windows，分发到: $winScript"
      & $winScript -Proxy $Proxy -Theme $Theme -NonInteractive:$NonInteractive $ForwardArgs
    } else {
      Err "未找到 Windows 脚本: $winScript"
    }
  } elseif ($isMacOS) {
    if (Test-Path $macScript) {
      Info "检测到 macOS，分发到: $macScript"
      & $macScript -Proxy $Proxy -Theme $Theme -NonInteractive:$NonInteractive $ForwardArgs
    } else {
      Err "未找到 macOS 脚本: $macScript"
    }
  } else {
    Warn '当前系统暂未支持（仅 Windows 与 macOS）。'
  }
} catch {
  Err ("入口执行失败: " + $_.Exception.Message)
}