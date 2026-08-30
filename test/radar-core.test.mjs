import test from "node:test";
import assert from "node:assert/strict";
import {
  derivedStatus, detectAccountChange, earliestForecastEstimate, localTranscriptTranslation, nextEligibleCheck, normaliseAccount, normaliseHistory,
  normalisePublicStatus, schedulerDecision, selectCodexQuotaWindows, shouldCheckPublic, signalType, weeklyUsagePace, updateProjectUsage,
} from "../lib/radar-core.mjs";

test("北京时间窗口、02:00 最后一次和排除时段", () => {
  assert.equal(schedulerDecision("2026-08-28T00:00:00.000Z").eligible, true, "北京时间 08:00");
  assert.equal(schedulerDecision("2026-08-28T18:00:00.000Z").eligible, true, "北京时间次日 02:00");
  assert.equal(schedulerDecision("2026-08-28T19:00:00.000Z").allowedNow, false, "北京时间 03:00");
  assert.equal(schedulerDecision("2026-08-28T12:00:00.000Z").allowedNow, false, "旧金山 05:00 休息");
});

test("America/Los_Angeles 夏令时切换仍由 IANA 时区判断", () => {
  const spring = schedulerDecision("2026-03-08T15:00:00.000Z");
  const fall = schedulerDecision("2026-11-01T16:00:00.000Z");
  assert.equal(typeof spring.allowedNow, "boolean");
  assert.equal(typeof fall.allowedNow, "boolean");
  assert.match(nextEligibleCheck("2026-11-01T16:15:00.000Z"), /Z$/);
});

test("公共 Tracker 每小时最多检查一次且不要求服务恰好整点启动", () => {
  assert.equal(shouldCheckPublic("2026-08-29T16:37:00.000Z", "2026-08-29T15:30:00.000Z"), true);
  assert.equal(shouldCheckPublic("2026-08-29T16:42:00.000Z", "2026-08-29T16:37:00.000Z"), false);
  assert.equal(shouldCheckPublic("2026-08-29T19:00:00.000Z", "2026-08-29T17:00:00.000Z"), false, "北京时间暂停时段不访问公共源");
});

test("Tracker 信号归类与原帖证据保持分离", () => {
  assert.equal(signalType("regular"), "full_reset");
  assert.equal(signalType("banked"), "banked_reset");
  assert.equal(signalType("active_watch"), "watch");
  assert.equal(signalType("unexpected"), "other");
  const parsed = normalisePublicStatus({ data: { latest_reset: { id: 1, reset_type: "regular", text: "reset", announced_at: "2026-08-01T00:00:00Z", source: { url: "https://x.example/1" } }, active_watch: { level: "elevated", reset_chance_percent: 45, forecast_window: "by end of sunday", observed_at: "2026-08-29T21:23:38Z", text: "This celebration is moved to tomorrow as the button was already pressed today.", source: { url: "https://x.example/2" } } } });
  assert.equal(parsed.latestReset.type, "full_reset");
  assert.equal(parsed.activeWatch.evidence, "第三方预测（非 OpenAI 承诺）");
  assert.equal(parsed.activeWatch.earliestAt, "2026-08-30T07:00:00.000Z", "周日结束窗口的最早估算是旧金山周日零点");
  assert.match(parsed.activeWatch.translationZh, /改到明天/);
  assert.equal(normaliseHistory({ data: [{ id: 2, reset_type: "banked", text: "card" }] })[0].type, "banked_reset");
});

test("最早估算只从可解释的 Tracker 周内窗口导出，并保留夏令时", () => {
  assert.equal(earliestForecastEstimate("by end of sunday", "2026-08-29T21:23:38Z"), "2026-08-30T07:00:00.000Z");
  assert.equal(earliestForecastEstimate("by end of sunday", "2026-11-06T21:23:38Z"), "2026-11-08T08:00:00.000Z", "冬令时零点应自动改为 UTC-8");
  assert.equal(earliestForecastEstimate("about tomorrow", "2026-08-29T21:23:38Z"), null, "无法解释的文字不应伪造精确最早时间");
  assert.equal(localTranscriptTranslation("a brand new message"), null, "未知新帖不应编造中文译文");
});

test("额度前后快照区别自然恢复、提前恢复与重置卡增加", () => {
  const previous = { buckets: [{ limitId: "codex", usedPercent: 80, resetsAt: "2026-08-30T12:00:00Z" }], resetCredits: { availableCount: 0 } };
  const early = { buckets: [{ limitId: "codex", usedPercent: 20 }], resetCredits: { availableCount: 1 } };
  const changes = detectAccountChange(previous, early, "2026-08-30T10:00:00Z");
  assert.equal(changes[0].kind, "early_recovery"); assert.equal(changes[1].kind, "credit_increase");
  assert.equal(detectAccountChange(previous, early, "2026-08-30T12:01:00Z")[0].kind, "natural_recovery");
});

test("字段缺失不转为零额度", () => {
  const account = normaliseAccount({ rateLimitsByLimitId: { codex: { displayName: "Codex" } } });
  assert.equal(account.buckets[0].usedPercent, null);
  assert.equal(account.buckets[0].remainingPercent, null);
});

test("新版 App Server 的 primary 和 secondary 窗口会被保留", () => {
  const account = normaliseAccount({ rateLimitsByLimitId: { codex: { limitName: "Codex", planType: "pro", primary: { usedPercent: 31, windowDurationMins: 300, resetsAt: "2026-08-30T12:00:00Z" }, secondary: { usedPercent: 67, windowDurationMins: 10_080, resetsAt: "2026-09-01T12:00:00Z" } } } });
  assert.equal(account.buckets.length, 2);
  assert.equal(account.buckets[0].limitId, "codex");
  assert.equal(account.buckets[0].usedPercent, 31);
  assert.equal(account.buckets[0].remainingPercent, 69);
  assert.equal(account.buckets[1].limitId, "codex:secondary");
  assert.equal(account.buckets[1].windowDurationMins, 10_080);
  assert.equal(account.displayWindows.main.limitId, "codex");
  assert.equal(account.displayWindows.weekly.limitId, "codex:secondary");
});

test("Pro 只有周窗口时不虚构主额度", () => {
  const windows = selectCodexQuotaWindows([
    { limitId: "codex_bengalfox", windowDurationMins: 300, usedPercent: 5 },
    { limitId: "codex_bengalfox:secondary", windowDurationMins: 10_080, usedPercent: 8 },
    { limitId: "codex", windowDurationMins: 10_080, usedPercent: 15 },
  ]);
  assert.equal(windows.main, null);
  assert.equal(windows.weekly.limitId, "codex");
  assert.equal(windows.weekly.usedPercent, 15);
});

test("周额度使用速度按已过窗口的均匀基准给出偏快与偏慢指标", () => {
  const resetAt = "2026-09-07T00:00:00.000Z";
  const dayOne = Date.parse("2026-09-01T00:00:00.000Z");
  const fast = weeklyUsagePace({ usedPercent: 30, windowDurationMins: 10_080, resetsAt: resetAt }, dayOne);
  const slow = weeklyUsagePace({ usedPercent: 8, windowDurationMins: 10_080, resetsAt: resetAt }, dayOne);
  assert.equal(fast.expectedUsedPercent, 14.3);
  assert.equal(fast.status, "fast");
  assert.equal(fast.paceMultiplier, 2.1);
  assert.equal(slow.status, "slow");
  assert.equal(slow.differencePercentPoints, -6.3);
});

test("项目账本只归因新增长的周额度，并在周窗口切换时归零", () => {
  const weekly = { limitId: "codex:secondary", usedPercent: 20, resetsAt: "2026-09-07T00:00:00.000Z" };
  let ledger = updateProjectUsage({ windowKey: "codex:secondary:2026-09-07T00:00:00.000Z", activeProject: "论文", projects: [] }, { ...weekly, usedPercent: 16 }, weekly, "2026-09-01T00:00:00.000Z");
  assert.deepEqual(ledger.projects, [{ name: "论文", usedPercent: 4, updatedAt: "2026-09-01T00:00:00.000Z" }]);
  ledger = updateProjectUsage(ledger, weekly, { ...weekly, usedPercent: 19 }, "2026-09-01T01:00:00.000Z");
  assert.equal(ledger.projects[0].usedPercent, 4, "下降或重复快照不得重复记账");
  ledger = updateProjectUsage(ledger, weekly, { ...weekly, usedPercent: 5, resetsAt: "2026-09-14T00:00:00.000Z" });
  assert.equal(ledger.projects.length, 0, "新周窗口不携带上周项目消耗");
});

test("App Server 的 Unix 秒级 resetsAt 会规范成 ISO 时间", () => {
  const account = normaliseAccount({ rateLimitsByLimitId: { codex: { primary: { usedPercent: 1, resetsAt: 1_800_000_000 } } } });
  assert.equal(account.buckets[0].resetsAt, "2027-01-15T08:00:00.000Z");
});

test("历史公告不会长期冒充正在宣布，活跃观察保持预测层级", () => {
  const healthy = { account: { health: { status: "ok", stale: false } }, public: { health: { status: "ok", stale: false }, latestReset: { occurredAt: "2026-08-01T00:00:00Z" } }, derived: {} };
  assert.equal(derivedStatus(healthy, Date.parse("2026-08-10T00:00:00Z")), "idle");
  healthy.public.activeWatch = { id: "watch" };
  assert.equal(derivedStatus(healthy, Date.parse("2026-08-10T00:00:00Z")), "forecast");
});
