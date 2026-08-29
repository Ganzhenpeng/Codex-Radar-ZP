param([switch]$Foreground)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$serverStart = Join-Path $PSScriptRoot 'start-radar.ps1'
$overlay = Join-Path $PSScriptRoot 'codex-radar-overlay.ps1'
& $serverStart
$existing = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$overlay*" }
if ($null -ne $existing) { exit 0 }
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if ($Foreground) {
  & $windowsPowerShell -NoProfile -STA -ExecutionPolicy Bypass -File $overlay
  exit $LASTEXITCODE
}
Start-Process -FilePath $windowsPowerShell -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$overlay`"" -WindowStyle Hidden
