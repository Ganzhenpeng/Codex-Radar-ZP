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
  assert.match(source, /function Initialize-SkinMenu/);
  assert.match(source, /\$skinButton\.Add_Click\(\{ Show-SkinMenu \$skinButton \}\)/);
  assert.match(source, /function Start-SkinAnimations/);
  assert.match(source, /LinearGradientBrush/);
});

test("小圆球按剩余额度绘制圆环", () => {
  assert.match(source, /x:Name="CompactQuotaArc"/);
  assert.match(source, /\$compactRemaining = if \(\$null -ne \$compactBucket\) \{ \$compactBucket\.remainingPercent \}/);
  assert.match(source, /Set-CompactQuotaArc \$compactRemaining/);
});

test("周额度文字承接额度详情入口，Tibo 发帖和预测分两行", () => {
  assert.match(source, /x:Name="WeeklyUsageButton"/);
  assert.match(source, /\$weeklyUsageButton\.Add_Click\(\{ Start-Process 'http:\/\/127\.0\.0\.1:43721\/usage\.html' \}\)/);
  assert.doesNotMatch(source, /x:Name="UsageButton"/);
  assert.match(source, /x:Name="TiboForecastLine"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2"/);
  assert.match(source, /x:Name="WeeklyPacePanel" Grid.Row="3"/, "使用速度应下移到 Tibo 信息之后");
  assert.match(source, /x:Name="WeeklyUsageButton"[^>]+FontSize="12\.5"/);
  assert.match(source, /x:Name="TiboTimeLine" Foreground="#FFFFCF4A" FontSize="12\.5"/);
  assert.match(source, /x:Name="WeeklyResetLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboForecastLine"[^>]+FontSize="12"/);
  assert.match(source, /x:Name="TiboPanel" Grid.Row="2" Margin="0,11,0,0"/);
  assert.match(source, /\$postedAt = Format-BeijingDayShort \(\[string\]\$watch\.observedAt\)/);
  assert.match(source, /Format-BeijingDayShort/);
  assert.match(source, /\[char\]0xFF1A/);
  assert.match(source, /Posted64='Mjflj7cxM\+\+8mjM4'/, "当前发表时间应使用日期格式");
  assert.match(source, /Forecast64='57qmMjjlj7cxM\+\+8mjAw'/, "当前预测时间应显示在第二行");
  assert.match(source, /VGlib\+mHjee9ru\+8iA==/, "标题应为 Tibo 重置");
});
