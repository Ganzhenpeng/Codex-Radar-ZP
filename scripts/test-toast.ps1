param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
  $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
  exit $LASTEXITCODE
}
[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] > $null
$title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('Q29kZXgg6YeN572u6Zu36L6+5rWL6K+V'))
$body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('6L+Z5piv5LiA5p2h5pys5Zyw5rWL6K+V6YCa55+l77yM5LiN5Luj6KGo6aKd5bqm6YeN572u5oiW5YWs5byA5YWs5ZGK44CC'))
$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$text = $xml.GetElementsByTagName('text')
$null = $text.Item(0).AppendChild($xml.CreateTextNode($title))
$null = $text.Item(1).AppendChild($xml.CreateTextNode($body))
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Codex Reset Radar').Show([Windows.UI.Notifications.ToastNotification]::new($xml))
Write-Host 'Test Toast sent. It does not write any radar event or dedupe state.'
