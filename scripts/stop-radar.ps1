param()
$ErrorActionPreference = 'Stop'
$root = (Split-Path -Parent $PSScriptRoot).TrimEnd('\')
$overlay = Join-Path $PSScriptRoot 'codex-radar-overlay.ps1'
$overlayProcesses = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$overlay*" }
foreach ($overlayProcess in $overlayProcesses) {
  Stop-Process -Id $overlayProcess.ProcessId -ErrorAction SilentlyContinue
}
$pidFile = Join-Path $root 'data\server.pid'
if (-not (Test-Path -LiteralPath $pidFile)) { Write-Host '未找到雷达 PID 文件。'; exit 0 }
$id = [int](Get-Content -LiteralPath $pidFile -Raw)
$process = Get-CimInstance Win32_Process -Filter "ProcessId = $id" -ErrorAction SilentlyContinue
$listener = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 43721 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $process -or $null -eq $listener -or $listener.OwningProcess -ne $id -or $process.Name -notlike 'node*' -or $process.CommandLine -notlike '*server.mjs*') { Write-Host 'PID 或监听端口不属于此雷达服务，未停止任何进程。'; exit 0 }
Stop-Process -Id $id -ErrorAction Stop
Write-Host '已停止雷达服务；历史与缓存数据未删除。'
