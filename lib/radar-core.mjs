import crypto from "node:crypto";

export const BJ_TIME_ZONE = "Asia/Shanghai";
export const TIBO_TIME_ZONE = "America/Los_Angeles";

function zonedParts(instant, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone, hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(new Date(instant));
  return Object.fromEntries(parts.filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
}

export function localMinuteOfDay(instant, timeZone) {
  const parts = zonedParts(instant, timeZone);
  return Number(parts.hour) * 60 + Number(parts.minute);
}

export function schedulerDecision(instant = new Date()) {
  const bjMinute = localMinuteOfDay(instant, BJ_TIME_ZONE);
  const laMinute = localMinuteOfDay(instant, TIBO_TIME_ZONE);
  const bjAllowed = bjMinute >= 8 * 60 || bjMinute <= 2 * 60;
  const laResting = laMinute >= 30 && laMinute < 8 * 60 + 30;
  const onHour = new Date(instant).getUTCMinutes() === 0 && new Date(instant).getUTCSeconds() === 0;
  let pauseReason = null;
  if (!bjAllowed) pauseReason = "北京时间 02:00 后至 08:00 前暂停";
  else if (laResting) pauseReason = "旧金山 00:30–08:30 休息时段暂停";
  return { eligible: bjAllowed && !laResting && onHour, allowedNow: bjAllowed && !laResting, bjMinute, laMinute, pauseReason };
}

export function nextEligibleCheck(from = new Date()) {
  const next = new Date(from);
  next.setUTCMinutes(0, 0, 0);
  if (next <= from) next.setUTCHours(next.getUTCHours() + 1);
  for (let i = 0; i < 96; i += 1) {
    if (schedulerDecision(next).eligible) return next.toISOString();
    next.setUTCHours(next.getUTCHours() + 1);
  }
  return null;
}

export function shouldCheckPublic(instant = new Date(), lastAttemptAt = null) {
  const now = new Date(instant);
  if (!schedulerDecision(now).allowedNow) return false;
  const previous = Date.parse(lastAttemptAt ?? "");
  return !Number.isFinite(previous) || now.getTime() - previous >= 60 * 60 * 1000;
}

export function signalType(value) {
  if (value === "regular" || value === "full_reset") return "full_reset";
  if (value === "banked" || value === "banked_reset") return "banked_reset";
  if (value === "active_watch") return "watch";
  return "other";
}

export function shortHash(value) {
  return crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex").slice(0, 20);
}

export function normalisePublicStatus(payload) {
  const data = payload?.data ?? payload ?? {};
  const latest = data.latest_reset;
  const watch = data.active_watch;
  return {
    latestReset: latest ? {
      id: String(latest.id ?? shortHash(latest)), type: signalType(latest.reset_type), text: String(latest.text ?? ""),
      occurredAt: latest.announced_at ?? latest.occurred_at ?? null,
      source: { kind: "tracker_transcript", author: latest.source?.author ?? "thsottiaux", url: latest.source?.url ?? null },
      evidence: "第三方 Tracker 分类 / 原帖链接",
    } : null,
    activeWatch: watch ? {
      id: String(watch.id ?? shortHash(watch)), level: watch.level ?? "观察", probability: Number(watch.reset_chance_percent ?? 0) || null,
      forecastWindow: watch.forecast_window ?? null, observedAt: watch.observed_at ?? null, expiresAt: watch.expires_at ?? null,
      text: String(watch.text ?? ""), source: { kind: "tracker_transcript", author: watch.source?.author ?? "thsottiaux", url: watch.source?.url ?? null },
      evidence: "第三方预测（非 OpenAI 承诺）",
    } : null,
    stats: data.stats ?? null,
  };
}

export function normaliseHistory(payload) {
  const rows = payload?.data?.items ?? payload?.data ?? payload?.items ?? [];
  if (!Array.isArray(rows)) return [];
  return rows.map((row) => ({
    id: String(row.id ?? shortHash(row)), type: signalType(row.reset_type ?? row.type),
    occurredAt: row.announced_at ?? row.occurred_at ?? null, summary: String(row.text ?? ""),
    source: { kind: "tracker_transcript", author: row.source?.author ?? "thsottiaux", url: row.source?.url ?? null },
    evidence: "第三方 Tracker 分类 / 原帖链接",
  })).filter((row) => row.type !== "other");
}

function safeNumber(value, fallback = null) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function normaliseTimestamp(value) {
  if (value === null || value === undefined || value === "") return null;
  const numeric = safeNumber(value);
  if (numeric !== null && String(value).trim() !== "") {
    const milliseconds = Math.abs(numeric) < 100_000_000_000 ? numeric * 1_000 : numeric;
    const date = new Date(milliseconds);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function normaliseAccount(response) {
  const limits = response?.rateLimitsByLimitId ?? response?.rate_limits_by_limit_id ?? {};
  const normaliseWindow = (limitId, bucket, window, suffix = "") => {
    const used = safeNumber(window?.usedPercent ?? window?.used_percent);
    const name = bucket?.displayName ?? bucket?.display_name ?? bucket?.limitName ?? bucket?.limit_name ?? (limitId === "codex" ? "Codex" : limitId);
    return {
      limitId: suffix ? `${limitId}:${suffix}` : limitId,
      displayName: suffix ? `${String(name)} · ${suffix === "secondary" ? "次级窗口" : suffix}` : String(name),
      usedPercent: used === null ? null : Math.max(0, Math.min(100, used)),
      remainingPercent: used === null ? null : Math.max(0, Math.min(100, 100 - used)),
      windowDurationMins: safeNumber(window?.windowDurationMins ?? window?.window_duration_mins),
      resetsAt: normaliseTimestamp(window?.resetsAt ?? window?.resets_at),
      planType: bucket?.planType ?? bucket?.plan_type ?? response?.planType ?? null,
    };
  };
  const buckets = Object.entries(limits).flatMap(([limitId, bucket]) => {
    const primary = bucket?.primary ?? bucket;
    const result = [normaliseWindow(limitId, bucket, primary)];
    if (bucket?.secondary) result.push(normaliseWindow(limitId, bucket, bucket.secondary, "secondary"));
    return result;
  });
  const creditsRaw = response?.rateLimitResetCredits ?? response?.rate_limit_reset_credits ?? {};
  const credits = Array.isArray(creditsRaw) ? creditsRaw : (creditsRaw?.credits ?? []);
  const available = safeNumber(creditsRaw?.availableCount ?? creditsRaw?.available_count, Array.isArray(credits) ? credits.length : 0);
  const displayWindows = selectCodexQuotaWindows(buckets);
  return {
    buckets,
    displayWindows,
    usagePace: weeklyUsagePace(displayWindows.weekly),
    resetCredits: {
      availableCount: available ?? 0,
      entries: (Array.isArray(credits) ? credits : []).map((credit) => ({
        status: credit?.status ?? "available", expiresAt: credit?.expiresAt ?? credit?.expires_at ?? null,
        grantedAt: credit?.grantedAt ?? credit?.granted_at ?? null,
      })),
    },
  };
}

export function selectCodexQuotaWindows(buckets = []) {
  const generic = (Array.isArray(buckets) ? buckets : []).filter((bucket) =>
    bucket?.limitId === "codex" || bucket?.limitId === "codex:secondary");
  const duration = (bucket) => safeNumber(bucket?.windowDurationMins);
  const main = generic
    .filter((bucket) => duration(bucket) !== null && duration(bucket) > 0 && duration(bucket) <= 24 * 60)
    .sort((left, right) => duration(left) - duration(right))[0] ?? null;
  const weekly = generic
    .filter((bucket) => duration(bucket) !== null && duration(bucket) >= 6 * 24 * 60)
    .sort((left, right) => duration(right) - duration(left))[0] ?? null;
  return { main, weekly };
}

/**
 * Compares a weekly window's actual consumption with a uniform 7-day pace.
 * It is deliberately percentage-based: the App Server does not expose an
 * absolute eToken allowance, so the radar must not invent one.
 */
export function weeklyUsagePace(bucket, now = Date.now()) {
  const usedPercent = safeNumber(bucket?.usedPercent);
  const windowDurationMins = safeNumber(bucket?.windowDurationMins);
  const resetsAt = Date.parse(bucket?.resetsAt ?? "");
  if (usedPercent === null || windowDurationMins === null || windowDurationMins < 6 * 24 * 60 || !Number.isFinite(resetsAt)) return null;

  const totalMs = windowDurationMins * 60_000;
  const elapsedMs = Math.max(0, Math.min(totalMs, now - (resetsAt - totalMs)));
  const elapsedPercent = (elapsedMs / totalMs) * 100;
  const expectedUsedPercent = elapsedPercent;
  const differencePercentPoints = usedPercent - expectedUsedPercent;
  const paceMultiplier = expectedUsedPercent < 1 ? null : usedPercent / expectedUsedPercent;
  // A two-percentage-point band avoids labelling small timing/rounding noise as a pace problem.
  const status = expectedUsedPercent < 1 ? "warming_up" : differencePercentPoints > 2 ? "fast" : differencePercentPoints < -2 ? "slow" : "on_track";
  const rounded = (value, digits = 1) => Math.round(value * (10 ** digits)) / (10 ** digits);
  return {
    status,
    usedPercent: rounded(usedPercent),
    expectedUsedPercent: rounded(expectedUsedPercent),
    differencePercentPoints: rounded(differencePercentPoints),
    elapsedPercent: rounded(elapsedPercent),
    elapsedMins: Math.round(elapsedMs / 60_000),
    totalMins: windowDurationMins,
    paceMultiplier: paceMultiplier === null ? null : rounded(paceMultiplier, 2),
  };
}

/**
 * Maintains a local-only project attribution ledger for the generic weekly
 * allowance. The App Server supplies one account-level percentage, not a
 * project-level bill, so only newly observed positive deltas can be assigned.
 */
export function updateProjectUsage(previousLedger, previousWeekly, currentWeekly, observedAt = new Date().toISOString()) {
  const normaliseName = (value) => String(value ?? "").replace(/\s+/g, " ").trim().slice(0, 60) || "未归类";
  const round = (value) => Math.round(Number(value) * 100) / 100;
  const activeProject = normaliseName(previousLedger?.activeProject);
  const currentUsed = safeNumber(currentWeekly?.usedPercent);
  const windowKey = currentWeekly?.limitId && currentWeekly?.resetsAt
    ? `${currentWeekly.limitId}:${currentWeekly.resetsAt}`
    : null;
  const existing = Array.isArray(previousLedger?.projects) ? previousLedger.projects
    .map((project) => ({ name: normaliseName(project?.name), usedPercent: Math.max(0, round(safeNumber(project?.usedPercent, 0))), updatedAt: project?.updatedAt ?? null }))
    : [];
  const base = { version: 1, windowKey, activeProject, projects: existing, updatedAt: previousLedger?.updatedAt ?? null };
  if (currentUsed === null || !windowKey) return base;
  if (previousLedger?.windowKey !== windowKey) return { ...base, projects: [], updatedAt: observedAt };
  const previousUsed = safeNumber(previousWeekly?.usedPercent);
  if (previousUsed === null || currentUsed <= previousUsed) return { ...base, updatedAt: observedAt };
  const delta = round(currentUsed - previousUsed);
  const projects = [...existing];
  const index = projects.findIndex((project) => project.name === activeProject);
  if (index >= 0) projects[index] = { ...projects[index], usedPercent: round(projects[index].usedPercent + delta), updatedAt: observedAt };
  else projects.push({ name: activeProject, usedPercent: delta, updatedAt: observedAt });
  return { ...base, projects, updatedAt: observedAt };
}

export function detectAccountChange(previous, current, observedAt = new Date().toISOString()) {
  const changes = [];
  for (const now of current?.buckets ?? []) {
    const before = previous?.buckets?.find((bucket) => bucket.limitId === now.limitId);
    if (before?.usedPercent === null || before?.usedPercent === undefined || now.usedPercent === null) continue;
    if (before.usedPercent - now.usedPercent >= 10) {
      const resetAt = Date.parse(before.resetsAt ?? "");
      const observed = Date.parse(observedAt);
      const early = Number.isFinite(resetAt) && Number.isFinite(observed) && observed < resetAt - 5 * 60 * 1000;
      changes.push({ kind: early ? "early_recovery" : "natural_recovery", limitId: now.limitId, before: before.usedPercent, after: now.usedPercent });
    }
  }
  if ((current?.resetCredits?.availableCount ?? 0) > (previous?.resetCredits?.availableCount ?? 0)) {
    changes.push({ kind: "credit_increase", before: previous?.resetCredits?.availableCount ?? 0, after: current.resetCredits.availableCount });
  }
  return changes;
}

export function derivedStatus(state, now = Date.now()) {
  if (state.account?.health?.status === "unavailable" && state.public?.health?.status === "unavailable") return "unavailable";
  if (state.account?.health?.stale || state.public?.health?.stale) return "stale";
  if (state.derived?.lastAccountChange?.kind === "public_confirmed") return "account_confirmed";
  if (state.derived?.lastAccountChange?.kind === "early_recovery") return "propagating";
  if (state.public?.activeWatch) return "forecast";
  const announcedAt = Date.parse(state.public?.latestReset?.occurredAt ?? "");
  if (Number.isFinite(announcedAt) && now - announcedAt >= 0 && now - announcedAt < 48 * 60 * 60 * 1000) return "announced";
  return "idle";
}
