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
    return "$($local.ToString('ddd', $script:zhCulture))$($local.ToString('HH:mm').Replace(':', [char]0xFF1A))"
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
        <Ellipse x:Name="CompactShell" Fill="#EA102538" Stroke="#FF65DFFF" StrokeThickness="2">
          <Ellipse.Effect><DropShadowEffect Color="#FF35D7FF" BlurRadius="12" ShadowDepth="0" Opacity="0.58"/></Ellipse.Effect>
        </Ellipse>
        <Ellipse x:Name="CompactTrack" Margin="5" Fill="Transparent" Stroke="#665FDFFF" StrokeThickness="4"/>
        <Path x:Name="CompactQuotaArc" Fill="Transparent" Stroke="#FF65DFFF" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <TextBlock x:Name="CompactSkinGlyph" HorizontalAlignment="Center" VerticalAlignment="Center" Background="Transparent" Foreground="#99B7F3FF" FontFamily="Segoe UI Symbol" FontSize="28" FontWeight="Bold" TextAlignment="Center" IsHitTestVisible="False"/>
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
          <Button x:Name="WeeklyUsageButton" Padding="0" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" Background="Transparent" BorderBrush="Transparent" BorderThickness="0" Foreground="#FFFFC766" FontSize="12.5" FontWeight="Bold" Cursor="Hand"/>
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
      <Grid Grid.Row="3" Margin="0,6,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock x:Name="TiboTimeLine" Grid.Column="0" Foreground="#FFFFFFFF" FontSize="11.5" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
        <Button x:Name="TiboDetailButton" Grid.Column="1" Margin="7,0,0,0" Padding="3,1" Background="#C0152639" BorderBrush="#5D91FFE2" BorderThickness="1" Foreground="#FF91FFE2" FontSize="11.5" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
        <Button x:Name="SkinButton" Grid.Column="2" Margin="5,0,0,0" Padding="3,1" Background="#C0152639" BorderBrush="#5D8FEAFF" BorderThickness="1" Foreground="#FF8FEAFF" FontSize="11.5" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
      </Grid>
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
$compactShell = $window.FindName('CompactShell')
$compactTrack = $window.FindName('CompactTrack')
$compactQuotaArc = $window.FindName('CompactQuotaArc')
$compactSkinGlyph = $window.FindName('CompactSkinGlyph')
$compactPercentLine = $window.FindName('CompactPercentLine')
$expandedPanel = $window.FindName('ExpandedPanel')
$closeButton = $window.FindName('CloseButton')
$mainPanel = $window.FindName('MainPanel')
$mainLabel = $window.FindName('MainLabel')
$mainPercentLine = $window.FindName('MainPercentLine')
$mainResetLine = $window.FindName('MainResetLine')
$weeklyPanel = $window.FindName('WeeklyPanel')
$weeklyUsageButton = $window.FindName('WeeklyUsageButton')
$weeklyPercentLine = $window.FindName('WeeklyPercentLine')
$weeklyResetLine = $window.FindName('WeeklyResetLine')
$weeklyPaceLine = $window.FindName('WeeklyPaceLine')
$weeklyPaceMarker = $window.FindName('WeeklyPaceMarker')
$unavailableLine = $window.FindName('UnavailableLine')
$tiboTimeLine = $window.FindName('TiboTimeLine')
$tiboDetailButton = $window.FindName('TiboDetailButton')
$skinButton = $window.FindName('SkinButton')
$mainMeterSegments = @(1..6 | ForEach-Object { $window.FindName(('MainMeter{0:D2}' -f $_)) })
$weeklyMeterSegments = @(1..6 | ForEach-Object { $window.FindName(('WeeklyMeter{0:D2}' -f $_)) })

$closeButton.Content = [char]0x00D7
$mainLabel.Text = TextFrom64 '5Li76aKd5bqm'
$weeklyUsageButton.Content = TextFrom64 '5ZGo6aKd5bqm'
$weeklyUsageButton.ToolTip = TextFrom64 '54K55Ye75omT5byA6aKd5bqm5oC76KeI'
$unavailableLine.Text = TextFrom64 '5Liq5Lq66aKd5bqm5pqC5LiN5Y+v6K+7'
$tiboDetailButton.Content = TextFrom64 '6K+m5oOF'
$skinButton.Content = TextFrom64 '5o2i6IKk'
$closeButton.ToolTip = TextFrom64 '5YWz6Zet5pys5qyh5pi+56S6'

$script:closedForCurrentProcess = $null
$script:lastTargetProcess = $null
$script:positionInitialised = $false
$script:isExpanded = $false
$script:expandedHeight = 166
$script:collapseAt = $null
$script:skinIndex = 0
$script:skins = @(
  [pscustomobject]@{ Key='digi-egg'; Name64='5pWw56CB6JuL'; Glyph64='4peI'; Shell='#EE102B3D'; Border='#FF66E4FF'; Track='#553B6B80'; Arc='#FF66E4FF'; Text='#FFFFFFFF'; Glyph='#8896F6FF'; Shadow='#FF31CBFF'; GlyphSize=29 },
  [pscustomobject]@{ Key='dragon-orb'; Name64='5Zub5pif6b6Z54+g'; Glyph64='4piF4piF4piF4piF'; Shell='#F0E87918'; Border='#FFFFB12E'; Track='#66FFD08A'; Arc='#FFFFE16C'; Text='#FF281406'; Glyph='#D9C81919'; Shadow='#FFFF7A1A'; GlyphSize=10 },
  [pscustomobject]@{ Key='cyber-core'; Name64='6LWb5Y2a5qC45b+D'; Glyph64='4pym'; Shell='#F00A1523'; Border='#FF00F5C8'; Track='#55486A80'; Arc='#FF00F5C8'; Text='#FFFFFFFF'; Glyph='#9938BDF8'; Shadow='#FF00F5C8'; GlyphSize=32 },
  [pscustomobject]@{ Key='pixel-slime'; Name64='5YOP57Sg5Y+y6I6x5aeG'; Glyph64='4peP'; Shell='#EF173D35'; Border='#FF69F0A8'; Track='#5550A783'; Arc='#FF9BFF7A'; Text='#FFFFFFFF'; Glyph='#8876F7C0'; Shadow='#FF58E799'; GlyphSize=30 },
  [pscustomobject]@{ Key='magic-planet'; Name64='6a2U5rOV5pif55CD'; Glyph64='4pyn'; Shell='#F02A1746'; Border='#FFC799FF'; Track='#556E4B88'; Arc='#FFFF8DEB'; Text='#FFFFFFFF'; Glyph='#99D8B4FF'; Shadow='#FFB46CFF'; GlyphSize=32 },
  [pscustomobject]@{ Key='steam-gear'; Name64='6JK45rG96b2/6L2u'; Glyph64='4pqZ'; Shell='#F0372D25'; Border='#FFD7AA67'; Track='#556D5A43'; Arc='#FFFFC46E'; Text='#FFFFF6E8'; Glyph='#99E2BD84'; Shadow='#FFAD7439'; GlyphSize=29 },
  [pscustomobject]@{ Key='deep-drop'; Name64='5rex5rW35rC05ru0'; Glyph64='4peG'; Shell='#F0082843'; Border='#FF58BFFF'; Track='#55436D8C'; Arc='#FF66E4FF'; Text='#FFFFFFFF'; Glyph='#8869B8FF'; Shadow='#FF2A8BFF'; GlyphSize=30 },
  [pscustomobject]@{ Key='lava-sun'; Name64='54aU5bKp5aSq6Ziz'; Glyph64='4piA'; Shell='#F046160B'; Border='#FFFF6A2A'; Track='#557A3A28'; Arc='#FFFFD24C'; Text='#FFFFFFFF'; Glyph='#99FF9A36'; Shadow='#FFFF4C20'; GlyphSize=31 },
  [pscustomobject]@{ Key='moon-cat'; Name64='5pyI5YWJ54yr55y8'; Glyph64='4peJ'; Shell='#F00F1734'; Border='#FF9AB8FF'; Track='#554B5D91'; Arc='#FFD9E5FF'; Text='#FFFFFFFF'; Glyph='#99A98AFF'; Shadow='#FF7D8FFF'; GlyphSize=31 },
  [pscustomobject]@{ Key='quantum-hole'; Name64='6YeP5a2Q6buR5rSe'; Glyph64='4peO'; Shell='#F0040710'; Border='#FF9D72FF'; Track='#55432E69'; Arc='#FF43E7FF'; Text='#FFFFFFFF'; Glyph='#99C145FF'; Shadow='#FF733CFF'; GlyphSize=32 },
  [pscustomobject]@{ Key='rainbow-candy'; Name64='5b2p6Jm557OW55CD'; Glyph64='4pym'; Shell='#F0392543'; Border='#FFFF89C8'; Track='#555C4E72'; Arc='#FF78E8FF'; Text='#FFFFFFFF'; Glyph='#99FFD36B'; Shadow='#FFFF71CB'; GlyphSize=31 },
  [pscustomobject]@{ Key='space-pod'; Name64='5aSq56m66Iix'; Glyph64='4qyh'; Shell='#F012202D'; Border='#FF93B7CC'; Track='#55445C69'; Arc='#FFB8F2FF'; Text='#FFFFFFFF'; Glyph='#8898C7D9'; Shadow='#FF6CBEDB'; GlyphSize=29 }
)

function ConvertTo-Brush([string]$value) {
  return (New-Object Windows.Media.BrushConverter).ConvertFromString($value)
}

function Apply-Skin {
  $skin = $script:skins[$script:skinIndex]
  $compactShell.Fill = ConvertTo-Brush $skin.Shell
  $compactShell.Stroke = ConvertTo-Brush $skin.Border
  $compactTrack.Stroke = ConvertTo-Brush $skin.Track
  $compactQuotaArc.Stroke = ConvertTo-Brush $skin.Arc
  $compactPercentLine.Foreground = ConvertTo-Brush $skin.Text
  $compactSkinGlyph.Foreground = ConvertTo-Brush $skin.Glyph
  $compactSkinGlyph.FontSize = [double]$skin.GlyphSize
  $compactSkinGlyph.Text = TextFrom64 $skin.Glyph64
  $compactShell.Effect.Color = [Windows.Media.ColorConverter]::ConvertFromString($skin.Shadow)
  $skinName = TextFrom64 $skin.Name64
  $skinButton.ToolTip = "$(TextFrom64 '5b2T5YmN55qu6IKk77ya')$skinName · $(TextFrom64 '54K55Ye75Iqk5o2i6IKk')"
}

function Set-CompactQuotaArc($remainingPercent) {
  if ($null -eq $remainingPercent) { $compactQuotaArc.Data = $null; return }
  try { $value = [Math]::Min(100, [Math]::Max(0, [double]$remainingPercent)) } catch { $compactQuotaArc.Data = $null; return }
  if ($value -le 0) { $compactQuotaArc.Data = $null; return }
  if ($value -ge 99.95) {
    $circle = New-Object Windows.Media.EllipseGeometry
    $circle.Center = New-Object Windows.Point -ArgumentList 29, 29
    $circle.RadiusX = 24
    $circle.RadiusY = 24
    $compactQuotaArc.Data = $circle
    return
  }
  $angle = 360 * $value / 100
  $endRadians = (-90 + $angle) * [Math]::PI / 180
  $figure = New-Object Windows.Media.PathFigure
  $figure.StartPoint = New-Object Windows.Point -ArgumentList 29, 5
  $figure.IsClosed = $false
  $arc = New-Object Windows.Media.ArcSegment
  $arc.Point = New-Object Windows.Point -ArgumentList (29 + (24 * [Math]::Cos($endRadians))), (29 + (24 * [Math]::Sin($endRadians)))
  $arc.Size = New-Object Windows.Size -ArgumentList 24, 24
  $arc.IsLargeArc = $angle -gt 180
  $arc.SweepDirection = [Windows.Media.SweepDirection]::Clockwise
  [void]$figure.Segments.Add($arc)
  $geometry = New-Object Windows.Media.PathGeometry
  [void]$geometry.Figures.Add($figure)
  $compactQuotaArc.Data = $geometry
}

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
    $payload = [pscustomobject]@{ left = [Math]::Round($window.Left, 1); top = [Math]::Round($window.Top, 1); skin = $script:skins[$script:skinIndex].Key; savedAt = [DateTime]::UtcNow.ToString('o') }
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
    if (-not [string]::IsNullOrWhiteSpace([string]$saved.skin)) {
      for ($index = 0; $index -lt $script:skins.Count; $index++) {
        if ($script:skins[$index].Key -eq [string]$saved.skin) { $script:skinIndex = $index; break }
      }
    }
    Apply-Skin
    $left = [double]$saved.left
    $top = [double]$saved.top
    if ($left -ge $work.Left -and $left -le ($work.Right - 40) -and $top -ge $work.Top -and $top -le ($work.Bottom - 40)) {
      $window.Left = $left
      $window.Top = $top
      return
    }
  } catch { Apply-Skin }
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
    $compactRemaining = if ($null -ne $compactBucket) { $compactBucket.remainingPercent } else { $null }
    Set-CompactQuotaArc $compactRemaining
    if ($hasWeekly) { Set-CurrentUsagePace $state.account.usagePace } else { $weeklyPaceLine.Text = ''; $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0) }
    if (-not $hasMain -and -not $hasWeekly) {
      $unavailableLine.Visibility = [Windows.Visibility]::Visible
      $script:expandedHeight = 86
    } else {
      $unavailableLine.Visibility = [Windows.Visibility]::Collapsed
      $script:expandedHeight = if ($hasMain -and $hasWeekly) { 188 } elseif ($hasWeekly) { 154 } else { 118 }
    }
    $watch = $state.public.activeWatch
    if ($null -ne $watch) {
      $deadlineAt = Format-BeijingShort ([string]$watch.expiresAt)
      $timeLabel = if ($deadlineAt) { $deadlineAt } else { TextFrom64 '5b6F5a6a' }
      $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$timeLabel$(TextFrom64 '77yJ')$(TextFrom64 '77ya6aKE5rWL5pe26Ze0')"
    } else {
      $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$(TextFrom64 '5peg')$(TextFrom64 '77yJ')"
    }
  } catch {
    Set-QuotaPanel $mainPanel $mainPercentLine $mainResetLine $mainMeterSegments $null '#FF65DFFF' | Out-Null
    Set-QuotaPanel $weeklyPanel $weeklyPercentLine $weeklyResetLine $weeklyMeterSegments $null '#FFFFB84D' | Out-Null
    $weeklyPaceLine.Text = ''
    $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0)
    $unavailableLine.Visibility = [Windows.Visibility]::Visible
    $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$(TextFrom64 '5peg')$(TextFrom64 '77yJ')"
    $compactPercentLine.Text = [char]0x2014
    Set-CompactQuotaArc $null
    $script:expandedHeight = 86
  }
  Show-NearTopRight
}

$closeButton.Add_Click({
  $script:closedForCurrentProcess = $script:lastTargetProcess
  Collapse-Overlay
  $window.Hide()
})
$weeklyUsageButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/usage.html' })
$tiboDetailButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/' })
$skinButton.Add_Click({
  $script:skinIndex = ($script:skinIndex + 1) % $script:skins.Count
  Apply-Skin
  Save-OverlayPosition
})
$root.Add_MouseLeftButtonDown({
  if (-not $closeButton.IsMouseOver -and -not $weeklyUsageButton.IsMouseOver -and -not $tiboDetailButton.IsMouseOver -and -not $skinButton.IsMouseOver) { try { $window.DragMove() } catch { } }
})
$root.Add_MouseLeftButtonUp({ Save-OverlayPosition })
$compactPanel.Add_MouseEnter({ Expand-Overlay })
$compactPanel.Add_MouseRightButtonDown({
  $script:skinIndex = ($script:skinIndex + 1) % $script:skins.Count
  Apply-Skin
  Save-OverlayPosition
})
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
