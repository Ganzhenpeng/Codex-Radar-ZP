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
});

test("小圆球按剩余额度绘制圆环", () => {
  assert.match(source, /x:Name="CompactQuotaArc"/);
  assert.match(source, /\$compactRemaining = if \(\$null -ne \$compactBucket\) \{ \$compactBucket\.remainingPercent \}/);
  assert.match(source, /Set-CompactQuotaArc \$compactRemaining/);
});

test("周额度文字承接额度详情入口，Tibo 使用单行紧凑格式", () => {
  assert.match(source, /x:Name="WeeklyUsageButton"/);
  assert.match(source, /\$weeklyUsageButton\.Add_Click\(\{ Start-Process 'http:\/\/127\.0\.0\.1:43721\/usage\.html' \}\)/);
  assert.doesNotMatch(source, /x:Name="UsageButton"/);
  assert.doesNotMatch(source, /TiboForecastLine/);
  assert.match(source, /Format-BeijingShort/);
  assert.match(source, /\[char\]0xFF1A/);
  assert.match(source, /77ya6aKE5rWL5pe26Ze0/, "活跃信号必须明确标注为预测时间");
});
