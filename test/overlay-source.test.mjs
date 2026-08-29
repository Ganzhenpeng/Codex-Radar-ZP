import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../scripts/codex-radar-overlay.ps1", import.meta.url), "utf8");

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

test("周额度文字承接额度详情入口，Tibo 栏与周额度统一排版", () => {
  assert.match(source, /x:Name="WeeklyUsageButton"/);
  assert.match(source, /\$weeklyUsageButton\.Add_Click\(\{ Start-Process 'http:\/\/127\.0\.0\.1:43721\/usage\.html' \}\)/);
  assert.doesNotMatch(source, /x:Name="UsageButton"/);
  assert.match(source, /x:Name="TiboForecastLine"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2"/);
  assert.match(source, /x:Name="WeeklyPacePanel" Grid.Row="3"/, "使用速度应下移到 Tibo 信息之后");
  assert.match(source, /x:Name="WeeklyUsageButton"[^>]+FontSize="12\.5"/);
  assert.match(source, /x:Name="TiboLabel" FontSize="12\.5" FontWeight="Bold" Foreground="#FFFFC766"/);
  assert.doesNotMatch(source, /x:Name="TiboMeter\d+"/, "Tibo 预测不应伪装成额度进度");
  assert.doesNotMatch(source, /x:Name="TiboProbabilityLine"/, "不在浮窗里显示误导性的预测进度数字");
  assert.match(source, /VGlib\+eJqeeQhumHjee9rg==/, "标题应为 Tibo 物理重置");
  assert.match(source, /x:Name="WeeklyResetLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboTimeLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboForecastLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2" Margin="0,11,0,0"/);
  assert.match(source, /\$postedAt = Format-BeijingDayShort \$watch\.observedAt/);
  assert.match(source, /Format-BeijingDayShort/);
  assert.match(source, /function ConvertTo-DateTimeOffset/);
  assert.match(source, /\[char\]0xFF1A/);
  assert.doesNotMatch(source, /tiboDisplayOverrides/, "示例时间不得写死为事件覆盖");
  assert.match(source, /\$timeLabel = if \(\$postedAt\)/, "发表时间必须来自当前信号");
  assert.match(source, /\$forecastLabel = if \(\$deadlineAt\)/, "预测时间必须来自当前预测窗口");
  assert.match(source, /\$tiboTimeLine\.Text = "\$\(TextFrom64 '5Y\+R6KGo'\) \$timeLabel"/, "发表时间必须单独显示");
  assert.match(source, /\$\(TextFrom64 '6aKE5rWL'\) \$\(TextFrom64 '57qm'\)\$deadlineAt/, "预测重置时间必须单独显示");
});
