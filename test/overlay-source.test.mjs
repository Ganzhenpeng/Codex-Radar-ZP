import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../scripts/codex-radar-overlay.ps1", import.meta.url), "utf8");
const installerSource = await readFile(new URL("../scripts/install-autostart.ps1", import.meta.url), "utf8");
const detachedLauncherSource = await readFile(new URL("../scripts/start-detached-radar.ps1", import.meta.url), "utf8");

test("浮窗提供 12 套可持久化皮肤", () => {
  const names = [...source.matchAll(/Name64='([^']+)'/g)].map((match) => Buffer.from(match[1], "base64").toString("utf8"));
  assert.deepEqual(names, [
    "数码蛋", "四星龙珠", "赛博核心", "像素史莱姆", "魔法星球", "蒸汽齿轮",
    "深海水滴", "熔岩太阳", "月光猫眼", "量子黑洞", "彩虹糖球", "太空舱",
  ]);
  assert.match(source, /skin = \$script:skins\[\$script:skinIndex\]\.Key/);
  assert.match(source, /\$compactPanel\.Add_MouseRightButtonDown/);
  for (const layer of ["CompactBand", "CompactCore", "CompactPercentBadge", "CompactSkinMark"]) {
    assert.match(source, new RegExp(`x:Name="${layer}"`), `${layer} skin layer missing`);
  }
  assert.match(source, /function Initialize-SkinPicker/);
  assert.match(source, /function New-SkinPreview/);
  assert.match(source, /Windows\.Controls\.WrapPanel/);
  assert.match(source, /\$button\.Content = \$content/);
  assert.match(source, /\$skinButton\.Add_Click\(\{ Show-SkinPicker \$skinButton \}\)/);
  assert.doesNotMatch(source, /Windows\.Controls\.ContextMenu/);
  assert.match(source, /function Start-SkinAnimations/);
  assert.match(source, /LinearGradientBrush/);
});

test("小圆球按剩余额度绘制圆环", () => {
  assert.match(source, /x:Name="CompactQuotaArc"/);
  assert.match(source, /\$compactRemaining = if \(\$null -ne \$compactBucket\) \{ \$compactBucket\.remainingPercent \}/);
  assert.match(source, /Set-CompactQuotaArc \$compactRemaining/);
});

test("自启动安装器会在当前登录会话立即启动并验证雷达", () => {
  assert.match(installerSource, /function Test-RadarRuntime/);
  assert.match(installerSource, /function Wait-RadarRuntime/);
  assert.match(installerSource, /Start-ScheduledTask -TaskName \$name/);
  assert.match(installerSource, /\$detachedStartScript/);
  assert.match(installerSource, /-File `"\$detachedStartScript`"/);
  assert.match(installerSource, /Invoke-WebRequest[\s\S]*?127\.0\.0\.1:43721\/healthz/);
  assert.match(installerSource, /\$overlayScript/);
  assert.match(detachedLauncherSource, /CREATE_BREAKAWAY_FROM_JOB/);
  assert.match(detachedLauncherSource, /CreateProcess/);
  assert.match(detachedLauncherSource, /\[uint32\]0x09000000/);
});

test("展开浮窗在远离后延时收起，小球下方显示 Tibo 预测上限倒计时", () => {
  assert.match(source, /x:Name="CompactTiboCountdownBadge"/);
  assert.match(source, /x:Name="CompactTiboCountdownLine"/);
  assert.match(source, /function Update-CompactTiboCountdown/);
  assert.match(source, /\$script:tiboForecastDeadline = ConvertTo-DateTimeOffset \$watch\.expiresAt/);
  assert.match(source, /\$remaining = \$script:tiboForecastDeadline\.ToUniversalTime\(\) - \[DateTimeOffset\]::UtcNow/);
  assert.match(source, /\$remainingHours = \[Math\]::Max\(0, \[Math\]::Ceiling\(\$remaining\.TotalHours\)\)/, "至多小时应向上取整");
  assert.match(source, /\$compactTiboCountdownLine\.Text = "\$\(TextFrom64 '6Iez5aSa'\)\$\(\$remainingHours\.ToString\('0'\)\)h"/);
  assert.doesNotMatch(source, /x:Name="CompactTiboCaption"/, "小球下方不应堆叠额外说明");
  assert.match(source, /\$countdownTimer\.Interval = \[TimeSpan\]::FromMinutes\(1\)/, "倒计时应本地每分钟更新");
  assert.match(source, /public static extern bool GetCursorPos\(out POINT point\)/, "应读取系统指针坐标");
  assert.match(source, /function Test-CursorInsideOverlay/);
  assert.match(source, /\$script:hoverExitPaddingPx = 24/, "指针应离开窗口外围一定距离");
  assert.match(source, /\$script:hoverExitDelay = \[TimeSpan\]::FromMilliseconds\(1500\)/, "远离后应延时 1\.5 秒");
  assert.match(source, /Test-CursorInsideOverlay \$script:hoverExitPaddingPx/);
  assert.match(source, /\$script:outsideExpandedSince = \[DateTime\]::UtcNow/);
  assert.match(source, /\$hoverExitTimer\.Interval = \[TimeSpan\]::FromMilliseconds\(100\)/);
  assert.match(source, /\[DateTime\]::UtcNow - \$script:outsideExpandedSince[\s\S]*?Collapse-Overlay; Save-OverlayPosition/);
  assert.doesNotMatch(source, /\$root\.Add_MouseLeave/, "不应再由灵敏的 MouseLeave 直接收起");
  assert.doesNotMatch(source, /AddSeconds\(4\)/, "离开不应再等待 4 秒");
  assert.match(source, /\$compactTiboCountdownBadge\.BeginAnimation/, "倒计时标签应有脉冲效果");
});

test("周额度文字承接额度详情入口，Tibo 栏与周额度统一排版", () => {
  assert.match(source, /x:Name="WeeklyUsageButton"/);
  assert.match(source, /\$weeklyUsageButton\.Add_Click\(\{ Start-Process 'http:\/\/127\.0\.0\.1:43721\/usage\.html' \}\)/);
  assert.doesNotMatch(source, /x:Name="UsageButton"/);
  assert.match(source, /x:Name="TiboForecastLine"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2"/);
  assert.match(source, /x:Name="WeeklyPacePanel" Grid.Row="3"/, "使用速度应下移到 Tibo 信息之后");
  assert.match(source, /x:Name="WeeklyUsageButton"[^>]+FontSize="12\.5"/);
  assert.match(source, /x:Name="TiboLabel"[^>]+FontSize="12\.5" FontWeight="Bold" Foreground="#FFFFC766"/);
  assert.doesNotMatch(source, /x:Name="TiboMeter\d+"/, "Tibo 预测不应伪装成额度进度");
  assert.doesNotMatch(source, /x:Name="TiboProbabilityLine"/, "不在浮窗里显示误导性的预测进度数字");
  assert.match(source, /VGlib\+eJqeeQhumHjee9rg==/, "标题应为 Tibo 物理重置");
  assert.match(source, /x:Name="WeeklyResetLine"[^>]+FontSize="12"/);
  assert.doesNotMatch(source, /x:Name="TiboTimeLine"/, "Tibo 标题与发表时间应合并为第一行");
  assert.match(source, /x:Name="TiboForecastLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2" Margin="0,11,0,0"/);
  assert.match(source, /\$postedAt = Format-BeijingMonthDayShort \$watch\.observedAt/);
  assert.match(source, /function Format-BeijingMonthDayShort/);
  assert.match(source, /ToString\('MM-dd'\)/, "Tibo 时间应使用月-日格式");
  assert.match(source, /function ConvertTo-DateTimeOffset/);
  assert.match(source, /\[char\]0xFF1A/);
  assert.doesNotMatch(source, /tiboDisplayOverrides/, "示例时间不得写死为事件覆盖");
  assert.match(source, /\$timeLabel = if \(\$postedAt\)/, "发表时间必须来自当前信号");
  assert.match(source, /\$forecastLabel = if \(\$deadlineAt\)/, "预测时间必须来自当前预测窗口");
  assert.match(source, /\$tiboLabel\.Text = "\$\(TextFrom64 'VGlib\+eJqeeQhumHjee9rg=='\)\$\(\[char\]0xFF1A\)\$timeLabel \$\(TextFrom64 '5Y\+R6KGo'\)"/, "第一行应为标题、时间和发表");
  assert.match(source, /\$\(TextFrom64 '57qm'\) \$deadlineAt \$\(TextFrom64 '6YeN572u'\)/, "第二行应为约、时间和重置");
});
