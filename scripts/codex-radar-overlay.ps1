param()
$ErrorActionPreference = 'Stop'
$rootPath = Split-Path -Parent $PSScriptRoot
$positionPath = Join-Path $rootPath 'data\overlay-position.json'

if ($PSVersionTable.PSEdition -ne 'Desktop') {
  $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  & $windowsPowerShell -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath
  exit $LASTEXITCODE
}

Add-Type -AssemblyName PresentationFramework

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CodexRadarNative {
  [StructLayout(LayoutKind.Sequential)] public struct RECT {
    public int Left; public int Top; public int Right; public int Bottom;
  }
  [DllImport("user32.dll", SetLastError=true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
}
'@

function TextFrom64([string]$value) {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))
}

$script:beijingTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
$script:zhCulture = [Globalization.CultureInfo]::GetCultureInfo('zh-CN')

function Format-BeijingShort([string]$instant) {
  if ([string]::IsNullOrWhiteSpace($instant)) { return $null }
  try {
    $parsed = [DateTimeOffset]::Parse($instant, [Globalization.CultureInfo]::InvariantCulture)
    $local = [TimeZoneInfo]::ConvertTime($parsed, $script:beijingTimeZone)
    return "$($local.ToString('ddd', $script:zhCulture))$($local.ToString('HH:mm'))"
  } catch { return $null }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="60" Height="60" WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False"
        Topmost="True" Opacity="1" FontFamily="Microsoft YaHei UI, Segoe UI"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="Grayscale">
  <Border x:Name="Root" Background="Transparent" BorderBrush="Transparent" BorderThickness="0" Padding="0">
    <Grid>
      <Grid x:Name="CompactPanel" Width="58" Height="58" Cursor="Hand">
        <Ellipse Fill="#EA102538" Stroke="#FF65DFFF" StrokeThickness="2">
          <Ellipse.Effect><DropShadowEffect Color="#FF35D7FF" BlurRadius="12" ShadowDepth="0" Opacity="0.58"/></Ellipse.Effect>
        </Ellipse>
        <Ellipse Margin="5" Fill="Transparent" Stroke="#665FDFFF" StrokeThickness="1"/>
        <TextBlock x:Name="CompactPercentLine" HorizontalAlignment="Center" VerticalAlignment="Center" Background="Transparent" Foreground="#FFFFFFFF" FontSize="16" FontWeight="Bold" TextAlignment="Center"/>
      </Grid>
      <Grid x:Name="ExpandedPanel" Margin="5" Visibility="Collapsed">
      <Grid.Resources>
        <Style TargetType="TextBlock">
          <Setter Property="Effect"><Setter.Value><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Setter.Value></Setter>
          <Setter Property="Background" Value="#C0152639"/>
          <Setter Property="HorizontalAlignment" Value="Left"/>
        </Style>
      </Grid.Resources>
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
      <StackPanel x:Name="MainPanel" Grid.Row="0" Margin="0,0,18,0" Visibility="Collapsed">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="40"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock x:Name="MainLabel" FontSize="12.5" FontWeight="Bold" Foreground="#FF8FEAFF"/>
          <Border Grid.Column="1" Height="9" Margin="2,2,0,0" Background="#41273F58" CornerRadius="5" Padding="2">
            <UniformGrid Columns="6" Rows="1">
              <Border x:Name="MainMeter01" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="MainMeter02" Margin="0,0,1,0" CornerRadius="2"/>
              <Border x:Name="MainMeter03" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="MainMeter04" Margin="0,0,1,0" CornerRadius="2"/>
              <Border x:Name="MainMeter05" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="MainMeter06" CornerRadius="2"/>
            </UniformGrid>
          </Border>
          <TextBlock x:Name="MainPercentLine" Grid.Column="2" Margin="7,0,0,0" FontSize="12" FontWeight="Bold" Foreground="#FFFFFFFF"/>
        </Grid>
        <TextBlock x:Name="MainResetLine" Margin="42,2,0,0" FontSize="10.5" FontWeight="SemiBold" Foreground="#FFFFFFFF"/>
      </StackPanel>
      <StackPanel x:Name="WeeklyPanel" Grid.Row="1" Margin="0,5,18,0" Visibility="Collapsed">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="40"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock x:Name="WeeklyLabel" FontSize="12.5" FontWeight="Bold" Foreground="#FFFFC766"/>
          <Border Grid.Column="1" Height="9" Margin="2,2,0,0" Background="#41273F58" CornerRadius="5" Padding="2">
            <UniformGrid Columns="6" Rows="1">
              <Border x:Name="WeeklyMeter01" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="WeeklyMeter02" Margin="0,0,1,0" CornerRadius="2"/>
              <Border x:Name="WeeklyMeter03" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="WeeklyMeter04" Margin="0,0,1,0" CornerRadius="2"/>
              <Border x:Name="WeeklyMeter05" Margin="0,0,1,0" CornerRadius="2"/><Border x:Name="WeeklyMeter06" CornerRadius="2"/>
            </UniformGrid>
          </Border>
          <TextBlock x:Name="WeeklyPercentLine" Grid.Column="2" Margin="7,0,0,0" FontSize="14.5" FontWeight="Bold" Foreground="#FFFFE1A1"/>
        </Grid>
        <TextBlock x:Name="WeeklyResetLine" Margin="0,3,0,0" FontSize="12" FontWeight="Bold" Foreground="#FFFFFFFF" TextWrapping="NoWrap"/>
        <TextBlock x:Name="WeeklyPaceLine" Margin="0,4,0,0" FontSize="12.5" FontWeight="Bold" Foreground="#FFFFE1A1" TextTrimming="CharacterEllipsis"/>
        <Grid Width="164" Height="8" Margin="0,3,0,0" HorizontalAlignment="Left">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#FF398FEF" CornerRadius="3,0,0,3"/>
          <Border Grid.Column="1" Background="#FF70DFAF"/>
          <Border Grid.Column="2" Background="#FFEF6B70" CornerRadius="0,3,3,0"/>
          <Border x:Name="WeeklyPaceMarker" Grid.ColumnSpan="3" HorizontalAlignment="Left" Width="4" Background="#FFFFFFFF" CornerRadius="2"/>
        </Grid>
      </StackPanel>
      <TextBlock x:Name="UnavailableLine" Grid.Row="2" Margin="0,5,18,0" FontSize="12" FontWeight="Bold" Foreground="#FFFFFFFF" Visibility="Collapsed"/>
      <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,5,0,0">
        <Button x:Name="UsageButton" Padding="3,1" Background="#C0152639" BorderBrush="#5D8FEAFF" BorderThickness="1" Foreground="#FF8FEAFF" FontSize="11.5" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
      </StackPanel>
      <StackPanel Grid.Row="4" Margin="0,2,0,0">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock x:Name="TiboTimeLine" Grid.Column="0" Foreground="#FFFFFFFF" FontSize="11.5" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
          <Button x:Name="TiboDetailButton" Grid.Column="1" Margin="8,0,0,0" Padding="3,1" Background="#C0152639" BorderBrush="#5D91FFE2" BorderThickness="1" Foreground="#FF91FFE2" FontSize="12" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
        </Grid>
        <TextBlock x:Name="TiboForecastLine" Margin="0,2,0,0" Foreground="#FFFFE1A1" FontSize="10.5" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
      <Button x:Name="CloseButton" Grid.Row="0" HorizontalAlignment="Right" VerticalAlignment="Top" Panel.ZIndex="2" Width="18" Height="18" Margin="4,-2,-2,0" Content="x" FontFamily="Segoe UI" FontSize="11" FontWeight="Bold" Foreground="#FFFFFFFF" Background="Transparent" BorderBrush="Transparent" BorderThickness="0" ToolTip="Close for this Codex session"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$root = $window.FindName('Root')
$compactPanel = $window.FindName('CompactPanel')
$compactPercentLine = $window.FindName('CompactPercentLine')
$expandedPanel = $window.FindName('ExpandedPanel')
$closeButton = $window.FindName('CloseButton')
$mainPanel = $window.FindName('MainPanel')
$mainLabel = $window.FindName('MainLabel')
$mainPercentLine = $window.FindName('MainPercentLine')
$mainResetLine = $window.FindName('MainResetLine')
$weeklyPanel = $window.FindName('WeeklyPanel')
$weeklyLabel = $window.FindName('WeeklyLabel')
$weeklyPercentLine = $window.FindName('WeeklyPercentLine')
$weeklyResetLine = $window.FindName('WeeklyResetLine')
$weeklyPaceLine = $window.FindName('WeeklyPaceLine')
$weeklyPaceMarker = $window.FindName('WeeklyPaceMarker')
$unavailableLine = $window.FindName('UnavailableLine')
$tiboTimeLine = $window.FindName('TiboTimeLine')
$tiboForecastLine = $window.FindName('TiboForecastLine')
$usageButton = $window.FindName('UsageButton')
$tiboDetailButton = $window.FindName('TiboDetailButton')
$mainMeterSegments = @(1..6 | ForEach-Object { $window.FindName(('MainMeter{0:D2}' -f $_)) })
$weeklyMeterSegments = @(1..6 | ForEach-Object { $window.FindName(('WeeklyMeter{0:D2}' -f $_)) })

$closeButton.Content = [char]0x00D7
$mainLabel.Text = TextFrom64 '5Li76aKd5bqm'
$weeklyLabel.Text = TextFrom64 '5ZGo6aKd5bqm'
$unavailableLine.Text = TextFrom64 '5Liq5Lq66aKd5bqm5pqC5LiN5Y+v6K+7'
$usageButton.Content = TextFrom64 '6aKd5bqm5oC76KeI'
$tiboDetailButton.Content = TextFrom64 '6K+m5oOF'
$closeButton.ToolTip = TextFrom64 '5YWz6Zet5pys5qyh5pi+56S6'

$script:closedForCurrentProcess = $null
$script:lastTargetProcess = $null
$script:positionInitialised = $false
$script:isExpanded = $false
$script:expandedHeight = 188
$script:collapseAt = $null

function Clamp-OverlayToWorkArea {
  $work = [System.Windows.SystemParameters]::WorkArea
  if ($window.Left + $window.Width -gt $work.Right) { $window.Left = [Math]::Max($work.Left, $work.Right - $window.Width - 6) }
  if ($window.Top + $window.Height -gt $work.Bottom) { $window.Top = [Math]::Max($work.Top, $work.Bottom - $window.Height - 6) }
  if ($window.Left -lt $work.Left) { $window.Left = $work.Left + 6 }
  if ($window.Top -lt $work.Top) { $window.Top = $work.Top + 6 }
}

function Apply-OverlayMode {
  if ($script:isExpanded) {
    $compactPanel.Visibility = [Windows.Visibility]::Collapsed
    $expandedPanel.Visibility = [Windows.Visibility]::Visible
    $window.Width = 236
    $window.Height = $script:expandedHeight
  } else {
    $expandedPanel.Visibility = [Windows.Visibility]::Collapsed
    $compactPanel.Visibility = [Windows.Visibility]::Visible
    $window.Width = 60
    $window.Height = 60
  }
  Clamp-OverlayToWorkArea
}

function Expand-Overlay {
  $script:isExpanded = $true
  $script:collapseAt = $null
  Apply-OverlayMode
}

function Collapse-Overlay {
  $script:isExpanded = $false
  $script:collapseAt = $null
  Apply-OverlayMode
}

function Save-OverlayPosition {
  try {
    $payload = [pscustomobject]@{ left = [Math]::Round($window.Left, 1); top = [Math]::Round($window.Top, 1); savedAt = [DateTime]::UtcNow.ToString('o') }
    $temporary = "$positionPath.$PID.tmp"
    $payload | ConvertTo-Json -Compress | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $positionPath -Force
  } catch { }
}

function Restore-OverlayPosition {
  if ($script:positionInitialised) { return }
  $script:positionInitialised = $true
  $work = [System.Windows.SystemParameters]::WorkArea
  try {
    $saved = Get-Content -LiteralPath $positionPath -Raw | ConvertFrom-Json
    $left = [double]$saved.left
    $top = [double]$saved.top
    if ($left -ge $work.Left -and $left -le ($work.Right - 40) -and $top -ge $work.Top -and $top -le ($work.Bottom - 40)) {
      $window.Left = $left
      $window.Top = $top
      return
    }
  } catch { }
  $target = Get-CodexProcess
  if ($null -ne $target) {
    $rect = New-Object CodexRadarNative+RECT
    if ([CodexRadarNative]::GetWindowRect($target.MainWindowHandle, [ref]$rect)) {
      $dpi = [CodexRadarNative]::GetDpiForWindow($target.MainWindowHandle)
      if ($dpi -lt 96) { $dpi = 96 }
      $toDip = 96.0 / $dpi
      $window.Left = [Math]::Round(($rect.Left * $toDip) + 14, 1)
      $window.Top = [Math]::Round(($rect.Bottom * $toDip) - $window.Height - 42, 1)
      return
    }
  }
  $window.Left = $work.Left + 18
  $window.Top = $work.Bottom - $window.Height - 42
}

function Get-CodexProcess {
  $candidates = @(Get-Process -Name ChatGPT, codex -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })
  if ($candidates.Count -eq 0) { return $null }
  return $candidates | Select-Object -First 1
}

function Format-Reset([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { return ([char]0x2014) }
  try { return ([DateTimeOffset]::Parse($value)).ToLocalTime().ToString('MM-dd HH:mm') } catch { return ([char]0x2014) }
}

function Set-QuotaMeter($segments, $usedPercent, [string]$activeColor) {
  $filled = 0
  if ($null -ne $usedPercent) {
    try {
      $value = [Math]::Min(100, [Math]::Max(0, [double]$usedPercent))
      $filled = [Math]::Ceiling($value / (100 / $segments.Count))
    } catch { $filled = 0 }
  }
  for ($index = 0; $index -lt $segments.Count; $index++) {
    $segments[$index].Background = if ($index -lt $filled) { $activeColor } else { '#2F8DA9C0' }
  }
}

function Set-QuotaPanel($panel, $percentLine, $resetLine, $segments, $bucket, [string]$activeColor, [bool]$preferRemaining = $false) {
  if ($null -eq $bucket -or $null -eq $bucket.usedPercent) {
    $panel.Visibility = [Windows.Visibility]::Collapsed
    Set-QuotaMeter $segments $null $activeColor
    return $false
  }
  $usedLabel = TextFrom64 '5bey55So'
  $remainingLabel = TextFrom64 '5L2Z'
  $resetLabel = TextFrom64 '5oGi5aSN'
  $separator = [char]0x00B7
  $displayPercent = if ($preferRemaining) { $bucket.remainingPercent } else { $bucket.usedPercent }
  $detailLabel = if ($preferRemaining) { $usedLabel } else { $remainingLabel }
  $detailPercent = if ($preferRemaining) { $bucket.usedPercent } else { $bucket.remainingPercent }
  $percentLine.Text = if ($preferRemaining) { "$remainingLabel$displayPercent%" } else { "$displayPercent%" }
  $resetLine.Text = "$detailLabel $detailPercent%  $separator  $resetLabel $((Format-Reset $bucket.resetsAt))"
  Set-QuotaMeter $segments $displayPercent $activeColor
  $panel.Visibility = [Windows.Visibility]::Visible
  return $true
}

function Set-CurrentUsagePace($pace) {
  if ($null -eq $pace -or $pace.status -eq 'warming_up') { $weeklyPaceLine.Text = ''; $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0); return }
  $label = if ($pace.status -eq 'fast') { TextFrom64 '5YGP5b+r' } elseif ($pace.status -eq 'slow') { TextFrom64 '5YGP5oWi' } else { TextFrom64 '5Z2H5YyA' }
  $multiplier = if ($null -ne $pace.paceMultiplier) { " $($pace.paceMultiplier)x" } else { '' }
  $weeklyPaceLine.Text = "$(TextFrom64 '6YCf5bqm77ya')$label$multiplier  $($pace.usedPercent)/$($pace.expectedUsedPercent)%"
  $multiplierForMarker = if ($null -ne $pace.paceMultiplier) { [double]$pace.paceMultiplier } else { 1 }
  $position = [Math]::Max(5, [Math]::Min(95, 50 + (($multiplierForMarker - 1) * 30)))
  $weeklyPaceMarker.Margin = New-Object Windows.Thickness(([Math]::Round((164 * $position / 100) - 2, 1)), 0, 0, 0)
}

function Show-NearTopRight {
  Restore-OverlayPosition
  Apply-OverlayMode
  if (-not $window.IsVisible) { $window.Show() }
}

function Update-Overlay {
  $target = Get-CodexProcess
  if ($null -eq $target) {
    $script:lastTargetProcess = $null
    $script:closedForCurrentProcess = $null
    if ($window.IsVisible) { $window.Hide() }
    return
  }
  if ($script:lastTargetProcess -ne $target.Id) {
    $script:lastTargetProcess = $target.Id
    $script:closedForCurrentProcess = $null
    Collapse-Overlay
  }
  if ($script:closedForCurrentProcess -eq $target.Id) {
    if ($window.IsVisible) { $window.Hide() }
    return
  }
  try {
    $state = Invoke-RestMethod -UseBasicParsing -TimeoutSec 4 -Uri 'http://127.0.0.1:43721/api/state'
    $codexBuckets = @($state.account.buckets | Where-Object { $_.limitId -eq 'codex' -or $_.limitId -eq 'codex:secondary' })
    $mainBucket = $state.account.displayWindows.main
    $weeklyBucket = $state.account.displayWindows.weekly
    if ($null -eq $mainBucket) {
      $mainBucket = $codexBuckets | Where-Object { $null -ne $_.windowDurationMins -and $_.windowDurationMins -gt 0 -and $_.windowDurationMins -le 1440 } | Sort-Object windowDurationMins | Select-Object -First 1
    }
    if ($null -eq $weeklyBucket) {
      $weeklyBucket = $codexBuckets | Where-Object { $null -ne $_.windowDurationMins -and $_.windowDurationMins -ge 8640 } | Sort-Object windowDurationMins -Descending | Select-Object -First 1
    }
    $hasMain = Set-QuotaPanel $mainPanel $mainPercentLine $mainResetLine $mainMeterSegments $mainBucket '#FF65DFFF'
    $hasWeekly = Set-QuotaPanel $weeklyPanel $weeklyPercentLine $weeklyResetLine $weeklyMeterSegments $weeklyBucket '#FFFFD06B' $true
    $compactBucket = if ($hasWeekly) { $weeklyBucket } elseif ($hasMain) { $mainBucket } else { $null }
    $compactPercentLine.Text = if ($null -ne $compactBucket -and $null -ne $compactBucket.remainingPercent) { "$($compactBucket.remainingPercent)%" } else { ([char]0x2014) }
    if ($hasWeekly) { Set-CurrentUsagePace $state.account.usagePace } else { $weeklyPaceLine.Text = ''; $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0) }
    if (-not $hasMain -and -not $hasWeekly) {
      $unavailableLine.Visibility = [Windows.Visibility]::Visible
      $script:expandedHeight = 116
    } else {
      $unavailableLine.Visibility = [Windows.Visibility]::Collapsed
      $script:expandedHeight = if ($hasMain -and $hasWeekly) { 226 } elseif ($hasWeekly) { 188 } else { 164 }
    }
    $watch = $state.public.activeWatch
    if ($null -ne $watch -and -not [string]::IsNullOrWhiteSpace([string]$watch.text) -and -not [string]::IsNullOrWhiteSpace([string]$watch.forecastWindow)) {
      $postedAt = Format-BeijingShort ([string]$watch.observedAt)
      $deadlineAt = Format-BeijingShort ([string]$watch.expiresAt)
      $tiboTimeLine.Text = if ($postedAt) { "$(TextFrom64 'VGlib++8iA==')$postedAt$(TextFrom64 '77yJ77ya')" } else { TextFrom64 'VGlibyDph43nva7ml7bpl7TvvJo=' }
      $tiboForecastLine.Text = if ($deadlineAt) { "$(TextFrom64 '6aKE6K6h')$deadlineAt$(TextFrom64 '5YmN77yI56ys5LiJ5pa56aKE5rWL77yJ')" } else { "$($watch.forecastWindow) $(TextFrom64 '77yI56ys5LiJ5pa56aKE5rWL77yJ')" }
      $script:expandedHeight += 19
    } else {
      $tiboTimeLine.Text = "$(TextFrom64 'VGlibyDph43nva7ml7bpl7TvvJo=')$(TextFrom64 '5peg')"
      $tiboForecastLine.Text = ''
    }
  } catch {
    Set-QuotaPanel $mainPanel $mainPercentLine $mainResetLine $mainMeterSegments $null '#FF65DFFF' | Out-Null
    Set-QuotaPanel $weeklyPanel $weeklyPercentLine $weeklyResetLine $weeklyMeterSegments $null '#FFFFB84D' | Out-Null
    $weeklyPaceLine.Text = ''
    $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0)
    $unavailableLine.Visibility = [Windows.Visibility]::Visible
    $tiboTimeLine.Text = "$(TextFrom64 'VGlibyDph43nva7ml7bpl7TvvJo=')$(TextFrom64 '5peg')"
    $tiboForecastLine.Text = ''
    $compactPercentLine.Text = [char]0x2014
    $script:expandedHeight = 116
  }
  Show-NearTopRight
}

$closeButton.Add_Click({
  $script:closedForCurrentProcess = $script:lastTargetProcess
  Collapse-Overlay
  $window.Hide()
})
$usageButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/usage.html' })
$tiboDetailButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/' })
$root.Add_MouseLeftButtonDown({
  if (-not $closeButton.IsMouseOver -and -not $usageButton.IsMouseOver -and -not $tiboDetailButton.IsMouseOver) { try { $window.DragMove() } catch { } }
})
$root.Add_MouseLeftButtonUp({ Save-OverlayPosition })
$compactPanel.Add_MouseEnter({ Expand-Overlay })
$root.Add_MouseEnter({ $script:collapseAt = $null })
$root.Add_MouseLeave({ if ($script:isExpanded) { $script:collapseAt = [DateTime]::UtcNow.AddSeconds(4) } })
$stateTimer = New-Object Windows.Threading.DispatcherTimer
$stateTimer.Interval = [TimeSpan]::FromSeconds(20)
$stateTimer.Add_Tick({ Update-Overlay })
$collapseTimer = New-Object Windows.Threading.DispatcherTimer
$collapseTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$collapseTimer.Add_Tick({
  if ($script:isExpanded -and $null -ne $script:collapseAt -and [DateTime]::UtcNow -ge $script:collapseAt -and -not $root.IsMouseOver) { Collapse-Overlay; Save-OverlayPosition }
})
$window.Add_Closed({ $stateTimer.Stop(); $collapseTimer.Stop() })

Update-Overlay
$stateTimer.Start()
$collapseTimer.Start()
[Windows.Threading.Dispatcher]::Run()
