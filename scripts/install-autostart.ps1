param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$name = 'Codex Reset Radar'
$startScript = Join-Path $PSScriptRoot 'start-radar-overlay.ps1'
$overlayScript = Join-Path $PSScriptRoot 'codex-radar-overlay.ps1'
$detachedStartScript = Join-Path $PSScriptRoot 'start-detached-radar.ps1'
$systemPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Reset Radar.lnk'

function Test-RadarRuntime {
  $overlayRunning = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$overlayScript*" }).Count -gt 0
  if (-not $overlayRunning) { return $false }
  try {
    $health = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri 'http://127.0.0.1:43721/healthz'
    return $health.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Wait-RadarRuntime {
  for ($attempt = 0; $attempt -lt 16; $attempt++) {
    if (Test-RadarRuntime) { return $true }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startScript`" -Foreground"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5) -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$taskCreated = $false
$taskError = $null
try {
  Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
  $taskCreated = $null -ne (Get-ScheduledTask -TaskName $name -ErrorAction Stop)
} catch {
  $taskCreated = $false
  $taskError = $_.Exception.Message
}
if ($taskCreated) {
  if (Test-Path -LiteralPath $startupShortcut) { Remove-Item -LiteralPath $startupShortcut -Force }
  Start-ScheduledTask -TaskName $name -ErrorAction Stop
  if (-not (Wait-RadarRuntime)) { throw "Created $name, but its service and overlay did not start in the current session." }
  Write-Host "Created and started verified user logon task: $name"
  exit 0
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = $systemPowerShell
$shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$detachedStartScript`""
$shortcut.WorkingDirectory = $root
$shortcut.WindowStyle = 7
$shortcut.Description = 'Starts the detached local Codex Reset Radar watchdog and quota overlay.'
$shortcut.Save()
if (-not (Test-Path -LiteralPath $startupShortcut)) { throw 'Unable to create the user Startup shortcut.' }
& $systemPowerShell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $detachedStartScript
if ($LASTEXITCODE -ne 0) { throw 'Unable to start the detached Codex Radar watchdog in the current session.' }
if (-not (Wait-RadarRuntime)) { throw 'Created the Startup shortcut, but its service and overlay did not start in the current session.' }
if (-not [string]::IsNullOrWhiteSpace($taskError)) { Write-Warning "Task Scheduler was unavailable: $taskError" }
Write-Host 'Created and started a verified user Startup shortcut instead.'
