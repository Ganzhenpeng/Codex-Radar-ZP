param()
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'stop-radar.ps1')
Unregister-ScheduledTask -TaskName 'Codex Reset Radar' -Confirm:$false -ErrorAction SilentlyContinue
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Reset Radar.lnk'
if (Test-Path -LiteralPath $startupShortcut) { Remove-Item -LiteralPath $startupShortcut -Force }
Write-Host '已注销计划任务或 Startup 快捷方式；历史与缓存数据未删除。'
