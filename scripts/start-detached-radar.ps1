param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$overlayScript = Join-Path $PSScriptRoot 'codex-radar-overlay.ps1'
$startScript = Join-Path $PSScriptRoot 'start-radar-overlay.ps1'
$systemPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$existing = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$overlayScript*" })
if ($existing.Count -gt 0) { exit 0 }

Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class CodexRadarDetachedLauncher {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct STARTUPINFO {
    public int cb;
    public string lpReserved;
    public string lpDesktop;
    public string lpTitle;
    public int dwX;
    public int dwY;
    public int dwXSize;
    public int dwYSize;
    public int dwXCountChars;
    public int dwYCountChars;
    public int dwFillAttribute;
    public int dwFlags;
    public short wShowWindow;
    public short cbReserved2;
    public IntPtr lpReserved2;
    public IntPtr hStdInput;
    public IntPtr hStdOutput;
    public IntPtr hStdError;
  }

  [StructLayout(LayoutKind.Sequential)]
  public struct PROCESS_INFORMATION {
    public IntPtr hProcess;
    public IntPtr hThread;
    public int dwProcessId;
    public int dwThreadId;
  }

  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool CreateProcess(
    string applicationName,
    StringBuilder commandLine,
    IntPtr processAttributes,
    IntPtr threadAttributes,
    [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
    uint creationFlags,
    IntPtr environment,
    string currentDirectory,
    ref STARTUPINFO startupInfo,
    out PROCESS_INFORMATION processInformation);

  [DllImport("kernel32.dll", SetLastError = true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool CloseHandle(IntPtr handle);
}
'@

$commandLine = New-Object System.Text.StringBuilder
[void]$commandLine.Append(('"{0}" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -Foreground' -f $systemPowerShell, $startScript))
$startupInfo = New-Object CodexRadarDetachedLauncher+STARTUPINFO
$startupInfo.cb = [Runtime.InteropServices.Marshal]::SizeOf($startupInfo)
$startupInfo.dwFlags = 1
$startupInfo.wShowWindow = 0
$processInfo = New-Object CodexRadarDetachedLauncher+PROCESS_INFORMATION
$creationFlags = [uint32]0x09000000 # CREATE_BREAKAWAY_FROM_JOB | CREATE_NO_WINDOW
$started = [CodexRadarDetachedLauncher]::CreateProcess($systemPowerShell, $commandLine, [IntPtr]::Zero, [IntPtr]::Zero, $false, $creationFlags, [IntPtr]::Zero, $root, [ref]$startupInfo, [ref]$processInfo)
if (-not $started) {
  $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
  throw (New-Object ComponentModel.Win32Exception($errorCode, "Unable to start the detached Codex Radar watchdog (Win32 error $errorCode)."))
}
try {
  Write-Output "Started detached Codex Radar watchdog PID $($processInfo.dwProcessId)."
} finally {
  if ($processInfo.hThread -ne [IntPtr]::Zero) { [void][CodexRadarDetachedLauncher]::CloseHandle($processInfo.hThread) }
  if ($processInfo.hProcess -ne [IntPtr]::Zero) { [void][CodexRadarDetachedLauncher]::CloseHandle($processInfo.hProcess) }
}
