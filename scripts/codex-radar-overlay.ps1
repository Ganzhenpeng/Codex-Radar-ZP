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

function ConvertTo-DateTimeOffset($instant) {
  if ($null -eq $instant -or [string]::IsNullOrWhiteSpace([string]$instant)) { return $null }
  if ($instant -is [DateTimeOffset]) { return [DateTimeOffset]$instant }
  if ($instant -is [DateTime]) { return [DateTimeOffset]([DateTime]$instant) }
  try {
    return [DateTimeOffset]::Parse([string]$instant, [Globalization.CultureInfo]::InvariantCulture)
  } catch {
    try { return [DateTimeOffset]::Parse([string]$instant, [Globalization.CultureInfo]::CurrentCulture) } catch { return $null }
  }
}

function Format-BeijingShort($instant) {
  try {
    $parsed = ConvertTo-DateTimeOffset $instant
    if ($null -eq $parsed) { return $null }
    $local = [TimeZoneInfo]::ConvertTime($parsed, $script:beijingTimeZone)
    return "$($local.ToString('ddd', $script:zhCulture))$($local.ToString('HH:mm').Replace(':', [char]0xFF1A))"
  } catch { return $null }
}

function Format-BeijingDayShort($instant) {
  try {
    $parsed = ConvertTo-DateTimeOffset $instant
    if ($null -eq $parsed) { return $null }
    $local = [TimeZoneInfo]::ConvertTime($parsed, $script:beijingTimeZone)
    return "$($local.Day)$(TextFrom64 '5Y+3')$($local.ToString('HH:mm').Replace(':', [char]0xFF1A))"
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
        <Border x:Name="CompactBand" Width="54" Height="11" Background="#CC39C9E8" Opacity="0.72" RenderTransformOrigin="0.5,0.5" IsHitTestVisible="False">
          <Border.RenderTransform><RotateTransform Angle="-24"/></Border.RenderTransform>
        </Border>
        <Ellipse x:Name="CompactCore" Width="10" Height="10" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="9,9,0,0" Fill="#FFFF5CA8" Stroke="#CCFFFFFF" StrokeThickness="1" IsHitTestVisible="False"/>
        <Ellipse x:Name="CompactTrack" Margin="5" Fill="Transparent" Stroke="#665FDFFF" StrokeThickness="4"/>
        <Path x:Name="CompactQuotaArc" Fill="Transparent" Stroke="#FF65DFFF" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <TextBlock x:Name="CompactSkinGlyph" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,4,0,0" Background="Transparent" Foreground="#FFB7F3FF" FontFamily="Segoe UI Symbol" FontSize="15" FontWeight="Bold" TextAlignment="Center" IsHitTestVisible="False"/>
        <Border x:Name="CompactPercentBadge" Width="43" Height="23" HorizontalAlignment="Center" VerticalAlignment="Center" Background="#E6101C28" BorderBrush="#99FFFFFF" BorderThickness="1" CornerRadius="12" IsHitTestVisible="False"/>
        <TextBlock x:Name="CompactPercentLine" HorizontalAlignment="Center" VerticalAlignment="Center" Background="Transparent" Foreground="#FFFFFFFF" FontSize="16" FontWeight="Bold" TextAlignment="Center"/>
        <TextBlock x:Name="CompactSkinMark" HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,3" Background="Transparent" Foreground="#FFFFFFFF" FontFamily="Segoe UI" FontSize="7" FontWeight="Bold" TextAlignment="Center" IsHitTestVisible="False"/>
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
      </StackPanel>
      <StackPanel x:Name="TiboPanel" Grid.Row="2" Margin="0,11,0,0">
        <TextBlock x:Name="TiboTimeLine" Foreground="#FFFFCF4A" FontSize="12.5" FontWeight="ExtraBold" TextWrapping="NoWrap"/>
        <Grid Margin="0,3,0,0">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock x:Name="TiboForecastLine" Grid.Column="0" Margin="0,3,0,0" Foreground="#FFFFFFFF" FontSize="12" FontWeight="Bold" TextWrapping="NoWrap"/>
          <Button x:Name="TiboDetailButton" Grid.Column="1" Margin="7,0,0,0" Padding="3,1" Background="#C0152639" BorderBrush="#5D91FFE2" BorderThickness="1" Foreground="#FF91FFE2" FontSize="11.5" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
          <Button x:Name="SkinButton" Grid.Column="2" Width="20" Margin="5,0,0,0" Padding="0" Background="#C0152639" BorderBrush="#5D8FEAFF" BorderThickness="1" Foreground="#FF8FEAFF" FontFamily="Segoe UI Symbol" FontSize="12" FontWeight="Bold"><Button.Effect><DropShadowEffect Color="#FF000000" BlurRadius="4" ShadowDepth="1" Opacity="0.95"/></Button.Effect></Button>
        </Grid>
      </StackPanel>
      <StackPanel x:Name="WeeklyPacePanel" Grid.Row="3" Margin="0,7,0,0" Visibility="Collapsed">
        <TextBlock x:Name="WeeklyPaceLine" FontSize="12.5" FontWeight="Bold" Foreground="#FFFFE1A1" TextTrimming="CharacterEllipsis"/>
        <Grid Width="164" Height="8" Margin="0,3,0,0" HorizontalAlignment="Left">
          <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="#FF398FEF" CornerRadius="3,0,0,3"/>
          <Border Grid.Column="1" Background="#FF70DFAF"/>
          <Border Grid.Column="2" Background="#FFEF6B70" CornerRadius="0,3,3,0"/>
          <Border x:Name="WeeklyPaceMarker" Grid.ColumnSpan="3" HorizontalAlignment="Left" Width="4" Background="#FFFFFFFF" CornerRadius="2"/>
        </Grid>
      </StackPanel>
      <TextBlock x:Name="UnavailableLine" Grid.Row="4" Margin="0,7,18,0" FontSize="12" FontWeight="Bold" Foreground="#FFFFFFFF" Visibility="Collapsed"/>
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
$compactBand = $window.FindName('CompactBand')
$compactCore = $window.FindName('CompactCore')
$compactTrack = $window.FindName('CompactTrack')
$compactQuotaArc = $window.FindName('CompactQuotaArc')
$compactSkinGlyph = $window.FindName('CompactSkinGlyph')
$compactPercentBadge = $window.FindName('CompactPercentBadge')
$compactPercentLine = $window.FindName('CompactPercentLine')
$compactSkinMark = $window.FindName('CompactSkinMark')
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
$weeklyPacePanel = $window.FindName('WeeklyPacePanel')
$weeklyPaceLine = $window.FindName('WeeklyPaceLine')
$weeklyPaceMarker = $window.FindName('WeeklyPaceMarker')
$unavailableLine = $window.FindName('UnavailableLine')
$tiboPanel = $window.FindName('TiboPanel')
$tiboTimeLine = $window.FindName('TiboTimeLine')
$tiboForecastLine = $window.FindName('TiboForecastLine')
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
$skinButton.Content = [char]0x2726
$tiboTimeLine.ToolTip = TextFrom64 '56ys5LiJ5pa56aKE5rWL77yM5LiN5piv5a6Y5pa55om/6K+6'
$tiboForecastLine.ToolTip = $tiboTimeLine.ToolTip
$closeButton.ToolTip = TextFrom64 '5YWz6Zet5pys5qyh5pi+56S6'

$script:closedForCurrentProcess = $null
$script:lastTargetProcess = $null
$script:positionInitialised = $false
$script:isExpanded = $false
$script:expandedHeight = 166
$script:collapseAt = $null
$script:skinIndex = 0
$script:skinPopup = $null
$script:skinButtons = @()
$script:skins = @(
  [pscustomobject]@{ Key='digi-egg'; Name64='5pWw56CB6JuL'; Glyph64='4peI'; Mark='DIGI'; Shell='#F00B334A'; Border='#FF66E4FF'; Track='#77456F83'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FFFFE56A'; Band='#E639D3F3'; Core='#FFFF4AA2'; Badge='#EC10202C'; MarkColor='#FF9DF4FF'; Shadow='#FF31CBFF'; GlyphSize=17; Angle=-28 },
  [pscustomobject]@{ Key='dragon-orb'; Name64='5Zub5pif6b6Z54+g'; Glyph64='4piF4piF4piF4piF'; Mark='4 STAR'; Shell='#F0F28A16'; Border='#FFFFD044'; Track='#88FFE29A'; Arc='#FFFFFFFF'; Text='#FF2B1100'; Glyph='#FFE11B22'; Band='#D9FFB02A'; Core='#FFE11B22'; Badge='#EFFFF1C7'; MarkColor='#FF7A1A00'; Shadow='#FFFF6A19'; GlyphSize=10; Angle=20 },
  [pscustomobject]@{ Key='cyber-core'; Name64='6LWb5Y2a5qC45b+D'; Glyph64='4pym'; Mark='CYBER'; Shell='#F006101B'; Border='#FF00F5C8'; Track='#77506B79'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FFFF2BD6'; Band='#D900F5C8'; Core='#FF4BA3FF'; Badge='#EC07131D'; MarkColor='#FF6BFFE5'; Shadow='#FF00F5C8'; GlyphSize=19; Angle=-18 },
  [pscustomobject]@{ Key='pixel-slime'; Name64='5YOP57Sg5Y+y6I6x5aeG'; Glyph64='4peP'; Mark='SLIME'; Shell='#F01D7549'; Border='#FFA6FF78'; Track='#7773C995'; Arc='#FFFFFFFF'; Text='#FF102B18'; Glyph='#FFFFFFFF'; Band='#D969F0A8'; Core='#FFFFF06A'; Badge='#E9D8FFD0'; MarkColor='#FFFFFFFF'; Shadow='#FF43E785'; GlyphSize=18; Angle=10 },
  [pscustomobject]@{ Key='magic-planet'; Name64='6a2U5rOV5pif55CD'; Glyph64='4pyn'; Mark='MAGIC'; Shell='#F0441B72'; Border='#FFFF94E9'; Track='#777D5BA0'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FFFFE56A'; Band='#D9C06CFF'; Core='#FF72EEFF'; Badge='#EC28113E'; MarkColor='#FFFFB8EF'; Shadow='#FFE75CFF'; GlyphSize=20; Angle=-35 },
  [pscustomobject]@{ Key='steam-gear'; Name64='6JK45rG96b2/6L2u'; Glyph64='4pqZ'; Mark='STEAM'; Shell='#F04C3321'; Border='#FFFFC86B'; Track='#778B704F'; Arc='#FFFFFFFF'; Text='#FFFFF4D9'; Glyph='#FFFFD790'; Band='#D99A6134'; Core='#FF63D1C5'; Badge='#ED241B15'; MarkColor='#FFFFDDA2'; Shadow='#FFB87737'; GlyphSize=19; Angle=32 },
  [pscustomobject]@{ Key='deep-drop'; Name64='5rex5rW35rC05ru0'; Glyph64='4peG'; Mark='DEEP'; Shell='#F006396B'; Border='#FF61D8FF'; Track='#77568DB8'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FF9CE8FF'; Band='#D92E91E6'; Core='#FFFFFFFF'; Badge='#EC062A48'; MarkColor='#FFB8F2FF'; Shadow='#FF208FFF'; GlyphSize=19; Angle=-20 },
  [pscustomobject]@{ Key='lava-sun'; Name64='54aU5bKp5aSq6Ziz'; Glyph64='4piA'; Mark='LAVA'; Shell='#F0731B08'; Border='#FFFFCC3C'; Track='#77C25725'; Arc='#FFFFFFFF'; Text='#FF321000'; Glyph='#FFFFE86B'; Band='#E5FF4A16'; Core='#FFFFFFFF'; Badge='#EDFDD469'; MarkColor='#FFFFF0AF'; Shadow='#FFFF451D'; GlyphSize=20; Angle=24 },
  [pscustomobject]@{ Key='moon-cat'; Name64='5pyI5YWJ54yr55y8'; Glyph64='4peJ'; Mark='MOON'; Shell='#F0121D52'; Border='#FFC7D7FF'; Track='#7762779F'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FFFFF3A8'; Band='#D97680DB'; Core='#FF89F0FF'; Badge='#EC111936'; MarkColor='#FFDCE6FF'; Shadow='#FF7B8FFF'; GlyphSize=20; Angle=-14 },
  [pscustomobject]@{ Key='quantum-hole'; Name64='6YeP5a2Q6buR5rSe'; Glyph64='4peO'; Mark='Q-BIT'; Shell='#F0010208'; Border='#FFAD72FF'; Track='#775B3D83'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FF4FE8FF'; Band='#D9742CFF'; Core='#FFFF4FD8'; Badge='#EF06030E'; MarkColor='#FFCDA8FF'; Shadow='#FF7B38FF'; GlyphSize=20; Angle=42 },
  [pscustomobject]@{ Key='rainbow-candy'; Name64='5b2p6Jm557OW55CD'; Glyph64='4pym'; Mark='CANDY'; Shell='#F0D62F83'; Border='#FFFFD6EC'; Track='#77FF9FCD'; Arc='#FFFFFFFF'; Text='#FF4A1130'; Glyph='#FFFFF36B'; Band='#E573E7FF'; Core='#FF72FFA8'; Badge='#F0FFE3F1'; MarkColor='#FFFFFFFF'; Shadow='#FFFF4FA3'; GlyphSize=20; Angle=-33 },
  [pscustomobject]@{ Key='space-pod'; Name64='5aSq56m66Iix'; Glyph64='4qyh'; Mark='SPACE'; Shell='#F02D3D49'; Border='#FFC1F2FF'; Track='#77738D9A'; Arc='#FFFFFFFF'; Text='#FFFFFFFF'; Glyph='#FFBDF7FF'; Band='#D95E7C91'; Core='#FFFFA83E'; Badge='#EC17232C'; MarkColor='#FFD8F8FF'; Shadow='#FF6CC9E8'; GlyphSize=19; Angle=16 }
)
function ConvertTo-Brush([string]$value) {
  return (New-Object Windows.Media.BrushConverter).ConvertFromString($value)
}

function Apply-Skin {
  $skin = $script:skins[$script:skinIndex]
  $shellGradient = New-Object Windows.Media.LinearGradientBrush
  $shellGradient.StartPoint = New-Object Windows.Point -ArgumentList 0.15, 0.05
  $shellGradient.EndPoint = New-Object Windows.Point -ArgumentList 0.85, 0.95
  $highlightStop = New-Object Windows.Media.GradientStop
  $highlightStop.Color = [Windows.Media.ColorConverter]::ConvertFromString($skin.Band)
  $highlightStop.Offset = 0
  $shellStop = New-Object Windows.Media.GradientStop
  $shellStop.Color = [Windows.Media.ColorConverter]::ConvertFromString($skin.Shell)
  $shellStop.Offset = 0.58
  $shadowStop = New-Object Windows.Media.GradientStop
  $shadowStop.Color = [Windows.Media.ColorConverter]::ConvertFromString('#F0020710')
  $shadowStop.Offset = 1
  [void]$shellGradient.GradientStops.Add($highlightStop)
  [void]$shellGradient.GradientStops.Add($shellStop)
  [void]$shellGradient.GradientStops.Add($shadowStop)
  $compactShell.Fill = $shellGradient
  $compactShell.Stroke = ConvertTo-Brush $skin.Border
  $compactBand.Background = ConvertTo-Brush $skin.Band
  $compactBand.RenderTransform.Angle = [double]$skin.Angle
  $compactCore.Fill = ConvertTo-Brush $skin.Core
  $compactTrack.Stroke = ConvertTo-Brush $skin.Track
  $compactQuotaArc.Stroke = ConvertTo-Brush $skin.Arc
  $compactPercentBadge.Background = ConvertTo-Brush $skin.Badge
  $compactPercentBadge.BorderBrush = ConvertTo-Brush $skin.Border
  $compactPercentLine.Foreground = ConvertTo-Brush $skin.Text
  $compactSkinGlyph.Foreground = ConvertTo-Brush $skin.Glyph
  $compactSkinGlyph.FontSize = [double]$skin.GlyphSize
  $compactSkinGlyph.Text = TextFrom64 $skin.Glyph64
  $compactSkinMark.Foreground = ConvertTo-Brush $skin.MarkColor
  $compactSkinMark.Text = [string]$skin.Mark
  $compactShell.Effect.Color = [Windows.Media.ColorConverter]::ConvertFromString($skin.Shadow)
  $skinName = TextFrom64 $skin.Name64
  $skinButton.ToolTip = "$(TextFrom64 '5b2T5YmN55qu6IKk77ya')$skinName · $(TextFrom64 '54K55Ye75Iqk5o2i6IKk')"
  if ($script:skinButtons.Count -gt 0) {
    for ($index = 0; $index -lt $script:skinButtons.Count; $index++) {
      $selected = $index -eq $script:skinIndex
      $borderSize = if ($selected) { 2 } else { 1 }
      $script:skinButtons[$index].BorderThickness = New-Object Windows.Thickness -ArgumentList $borderSize
      $script:skinButtons[$index].BorderBrush = ConvertTo-Brush $(if ($selected) { $script:skins[$index].Border } else { '#FF3B5366' })
      $script:skinButtons[$index].Background = ConvertTo-Brush $(if ($selected) { '#FF173249' } else { '#FF0B1721' })
    }
  }
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

function New-SkinPreview($skin) {
  $preview = New-Object Windows.Controls.Grid
  $preview.Width = 46
  $preview.Height = 46
  $preview.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $clip = New-Object Windows.Media.EllipseGeometry
  $clip.Center = New-Object Windows.Point -ArgumentList 23, 23
  $clip.RadiusX = 22
  $clip.RadiusY = 22
  $preview.Clip = $clip

  $shell = New-Object Windows.Shapes.Ellipse
  $shell.Fill = ConvertTo-Brush $skin.Shell
  $shell.Stroke = ConvertTo-Brush $skin.Border
  $shell.StrokeThickness = 2
  [void]$preview.Children.Add($shell)

  $band = New-Object Windows.Controls.Border
  $band.Width = 44
  $band.Height = 8
  $band.Background = ConvertTo-Brush $skin.Band
  $band.Opacity = 0.86
  $band.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $band.VerticalAlignment = [Windows.VerticalAlignment]::Center
  $band.RenderTransformOrigin = New-Object Windows.Point -ArgumentList 0.5, 0.5
  $band.RenderTransform = New-Object Windows.Media.RotateTransform -ArgumentList ([double]$skin.Angle)
  [void]$preview.Children.Add($band)

  $core = New-Object Windows.Shapes.Ellipse
  $core.Width = 8
  $core.Height = 8
  $core.Margin = New-Object Windows.Thickness -ArgumentList 7, 7, 0, 0
  $core.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
  $core.VerticalAlignment = [Windows.VerticalAlignment]::Top
  $core.Fill = ConvertTo-Brush $skin.Core
  $core.Stroke = ConvertTo-Brush '#CCFFFFFF'
  $core.StrokeThickness = 1
  [void]$preview.Children.Add($core)

  $glyph = New-Object Windows.Controls.TextBlock
  $glyph.Text = TextFrom64 $skin.Glyph64
  $glyph.Foreground = ConvertTo-Brush $skin.Glyph
  $glyph.FontFamily = New-Object Windows.Media.FontFamily 'Segoe UI Symbol'
  $glyph.FontSize = [Math]::Min(15, [double]$skin.GlyphSize)
  $glyph.FontWeight = [Windows.FontWeights]::Bold
  $glyph.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $glyph.VerticalAlignment = [Windows.VerticalAlignment]::Top
  $glyph.Margin = New-Object Windows.Thickness -ArgumentList 0, 2, 0, 0
  [void]$preview.Children.Add($glyph)

  $badge = New-Object Windows.Controls.Border
  $badge.Width = 34
  $badge.Height = 17
  $badge.Background = ConvertTo-Brush $skin.Badge
  $badge.BorderBrush = ConvertTo-Brush $skin.Border
  $badge.BorderThickness = New-Object Windows.Thickness -ArgumentList 1
  $badge.CornerRadius = New-Object Windows.CornerRadius -ArgumentList 9
  $badge.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center
  [void]$preview.Children.Add($badge)

  $percent = New-Object Windows.Controls.TextBlock
  $percent.Text = '62%'
  $percent.Foreground = ConvertTo-Brush $skin.Text
  $percent.FontSize = 10
  $percent.FontWeight = [Windows.FontWeights]::Bold
  $percent.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $percent.VerticalAlignment = [Windows.VerticalAlignment]::Center
  [void]$preview.Children.Add($percent)

  $mark = New-Object Windows.Controls.TextBlock
  $mark.Text = [string]$skin.Mark
  $mark.Foreground = ConvertTo-Brush $skin.MarkColor
  $mark.FontSize = 5.8
  $mark.FontWeight = [Windows.FontWeights]::Bold
  $mark.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
  $mark.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
  $mark.Margin = New-Object Windows.Thickness -ArgumentList 0, 0, 0, 2
  [void]$preview.Children.Add($mark)

  return $preview
}

function Initialize-SkinPicker {
  $popup = New-Object Windows.Controls.Primitives.Popup
  $popup.AllowsTransparency = $true
  $popup.StaysOpen = $false
  $popup.Placement = [Windows.Controls.Primitives.PlacementMode]::Bottom
  $popup.Add_Opened({ $script:collapseAt = $null })
  $popup.Add_Closed({ if ($script:isExpanded) { $script:collapseAt = [DateTime]::UtcNow.AddSeconds(4) } })

  $frame = New-Object Windows.Controls.Border
  $frame.Background = ConvertTo-Brush '#FA08131D'
  $frame.BorderBrush = ConvertTo-Brush '#FF5B819B'
  $frame.BorderThickness = New-Object Windows.Thickness -ArgumentList 1
  $frame.CornerRadius = New-Object Windows.CornerRadius -ArgumentList 10
  $frame.Padding = New-Object Windows.Thickness -ArgumentList 7
  $frame.Effect = New-Object Windows.Media.Effects.DropShadowEffect
  $frame.Effect.Color = [Windows.Media.Colors]::Black
  $frame.Effect.BlurRadius = 16
  $frame.Effect.Opacity = 0.8

  $tiles = New-Object Windows.Controls.WrapPanel
  $tiles.Width = 216
  $script:skinButtons = @()
  for ($index = 0; $index -lt $script:skins.Count; $index++) {
    $skin = $script:skins[$index]
    $button = New-Object Windows.Controls.Button
    $button.Width = 66
    $button.Height = 76
    $button.Margin = New-Object Windows.Thickness -ArgumentList 3
    $button.Padding = New-Object Windows.Thickness -ArgumentList 4
    $button.Tag = $index
    $button.ToolTip = TextFrom64 $skin.Name64

    $content = New-Object Windows.Controls.StackPanel
    [void]$content.Children.Add((New-SkinPreview $skin))
    $caption = New-Object Windows.Controls.TextBlock
    $caption.Text = TextFrom64 $skin.Name64
    $caption.Foreground = ConvertTo-Brush '#FFEAF7FF'
    $caption.FontSize = 9.5
    $caption.FontWeight = [Windows.FontWeights]::SemiBold
    $caption.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $caption.Margin = New-Object Windows.Thickness -ArgumentList 0, 3, 0, 0
    [void]$content.Children.Add($caption)
    $button.Content = $content
    $button.Add_Click({
      param($sender, $eventArgs)
      $script:skinIndex = [int]$sender.Tag
      Apply-Skin
      Save-OverlayPosition
      $script:skinPopup.IsOpen = $false
    })
    [void]$tiles.Children.Add($button)
    $script:skinButtons += $button
  }
  $frame.Child = $tiles
  $popup.Child = $frame
  $script:skinPopup = $popup
}

function Show-SkinPicker($target) {
  if ($null -eq $script:skinPopup) { Initialize-SkinPicker }
  Apply-Skin
  $script:skinPopup.PlacementTarget = $target
  $script:skinPopup.IsOpen = $true
}

function Start-SkinAnimations {
  $rotation = New-Object Windows.Media.RotateTransform
  $rotation.CenterX = 29
  $rotation.CenterY = 29
  $compactQuotaArc.RenderTransform = $rotation
  $spin = New-Object Windows.Media.Animation.DoubleAnimation
  $spin.From = 0
  $spin.To = 360
  $spin.Duration = [TimeSpan]::FromSeconds(12)
  $spin.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
  $rotation.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $spin)

  $pulse = New-Object Windows.Media.Animation.DoubleAnimation
  $pulse.From = 0.42
  $pulse.To = 1
  $pulse.Duration = [TimeSpan]::FromSeconds(1.4)
  $pulse.AutoReverse = $true
  $pulse.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
  $compactCore.BeginAnimation([Windows.UIElement]::OpacityProperty, $pulse)
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
  if ($null -eq $pace -or $pace.status -eq 'warming_up') { $weeklyPacePanel.Visibility = [Windows.Visibility]::Collapsed; $weeklyPaceLine.Text = ''; $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0); return }
  $label = if ($pace.status -eq 'fast') { TextFrom64 '5YGP5b+r' } elseif ($pace.status -eq 'slow') { TextFrom64 '5YGP5oWi' } else { TextFrom64 '5Z2H5YyA' }
  $multiplier = if ($null -ne $pace.paceMultiplier) { " $($pace.paceMultiplier)x" } else { '' }
  $weeklyPaceLine.Text = "$(TextFrom64 '6YCf5bqm77ya')$label$multiplier  $($pace.usedPercent)/$($pace.expectedUsedPercent)%"
  $multiplierForMarker = if ($null -ne $pace.paceMultiplier) { [double]$pace.paceMultiplier } else { 1 }
  $position = [Math]::Max(5, [Math]::Min(95, 50 + (($multiplierForMarker - 1) * 30)))
  $weeklyPaceMarker.Margin = New-Object Windows.Thickness(([Math]::Round((164 * $position / 100) - 2, 1)), 0, 0, 0)
  $weeklyPacePanel.Visibility = [Windows.Visibility]::Visible
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
    if ($hasWeekly) { Set-CurrentUsagePace $state.account.usagePace } else { $weeklyPacePanel.Visibility = [Windows.Visibility]::Collapsed; $weeklyPaceLine.Text = ''; $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0) }
    if (-not $hasMain -and -not $hasWeekly) {
      $unavailableLine.Visibility = [Windows.Visibility]::Visible
      $script:expandedHeight = 86
    } else {
      $unavailableLine.Visibility = [Windows.Visibility]::Collapsed
      $script:expandedHeight = if ($hasMain -and $hasWeekly) { 188 } elseif ($hasWeekly) { 154 } else { 118 }
    }
    $watch = $state.public.activeWatch
    if ($null -ne $watch) {
      $postedAt = Format-BeijingDayShort $watch.observedAt
      $deadlineAt = Format-BeijingDayShort $watch.expiresAt
      $timeLabel = if ($postedAt) { $postedAt } else { TextFrom64 '5b6F5a6a' }
      $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$timeLabel$(TextFrom64 '77yJ')"
      $forecastLabel = if ($deadlineAt) { "$(TextFrom64 '57qm')$deadlineAt" } else { TextFrom64 '6aKE5rWL5pe26Ze05b6F5a6a' }
      $tiboForecastLine.Text = $forecastLabel
      $script:expandedHeight += 20
    } else {
      $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$(TextFrom64 '5peg')$(TextFrom64 '77yJ')"
      $tiboForecastLine.Text = ''
    }
  } catch {
    Set-QuotaPanel $mainPanel $mainPercentLine $mainResetLine $mainMeterSegments $null '#FF65DFFF' | Out-Null
    Set-QuotaPanel $weeklyPanel $weeklyPercentLine $weeklyResetLine $weeklyMeterSegments $null '#FFFFB84D' | Out-Null
    $weeklyPaceLine.Text = ''
    $weeklyPacePanel.Visibility = [Windows.Visibility]::Collapsed
    $weeklyPaceMarker.Margin = New-Object Windows.Thickness(80, 0, 0, 0)
    $unavailableLine.Visibility = [Windows.Visibility]::Visible
    $tiboTimeLine.Text = "$(TextFrom64 'VGlib+mHjee9ru+8iA==')$(TextFrom64 '5peg')$(TextFrom64 '77yJ')"
    $tiboForecastLine.Text = ''
    $compactPercentLine.Text = [char]0x2014
    Set-CompactQuotaArc $null
    $script:expandedHeight = 86
  }
  Show-NearTopRight
}

Initialize-SkinPicker
Start-SkinAnimations

$closeButton.Add_Click({
  $script:closedForCurrentProcess = $script:lastTargetProcess
  Collapse-Overlay
  $window.Hide()
})
$weeklyUsageButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/usage.html' })
$tiboDetailButton.Add_Click({ Start-Process 'http://127.0.0.1:43721/' })
$skinButton.Add_Click({ Show-SkinPicker $skinButton })
$root.Add_MouseLeftButtonDown({
  if (-not $closeButton.IsMouseOver -and -not $weeklyUsageButton.IsMouseOver -and -not $tiboDetailButton.IsMouseOver -and -not $skinButton.IsMouseOver) { try { $window.DragMove() } catch { } }
})
$root.Add_MouseLeftButtonUp({ Save-OverlayPosition })
$compactPanel.Add_MouseEnter({ Expand-Overlay })
$compactPanel.Add_MouseRightButtonDown({
  param($sender, $eventArgs)
  $eventArgs.Handled = $true
  Show-SkinPicker $compactPanel
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
