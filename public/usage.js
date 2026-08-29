const $ = (id) => document.getElementById(id);
const bj = new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Shanghai" });
const safe = (value) => String(value ?? "").replace(/[&<>"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[ch]));
const fmt = (value) => value ? bj.format(new Date(value)) : "未提供";
const number = (value) => value !== null && value !== undefined && String(value).trim() !== "" && Number.isFinite(Number(value)) ? Number(value) : null;

function remaining(value) {
  const target = Date.parse(value ?? "");
  if (!Number.isFinite(target)) return "恢复时间未提供";
  const ms = target - Date.now();
  if (ms <= 0) return "等待接口更新";
  const minutes = Math.ceil(ms / 60_000);
  const days = Math.floor(minutes / 1440), hours = Math.floor((minutes % 1440) / 60), mins = minutes % 60;
  return days ? `约 ${days} 天 ${hours} 小时` : hours ? `约 ${hours} 小时 ${mins} 分` : `约 ${mins} 分`;
}

function health(node, source) {
  const okay = source?.status === "ok" && !source?.stale;
  node.textContent = okay ? "本机数据正常" : source?.stale ? "缓存可能过期" : "暂不可读";
  node.className = `source-state ${okay ? "ok" : "warn"}`;
}

function chooseWindows(account) {
  const generic = (account.buckets ?? []).filter((bucket) => bucket.limitId === "codex" || bucket.limitId === "codex:secondary");
  const duration = (bucket) => number(bucket?.windowDurationMins);
  return {
    main: account.displayWindows?.main ?? generic.filter((bucket) => duration(bucket) > 0 && duration(bucket) <= 1440).sort((a, b) => duration(a) - duration(b))[0] ?? null,
    weekly: account.displayWindows?.weekly ?? generic.filter((bucket) => duration(bucket) >= 8640).sort((a, b) => duration(b) - duration(a))[0] ?? null,
  };
}

function paceLabel(pace) {
  if (!pace) return "使用速度暂不可计算";
  if (pace.status === "warming_up") return "使用速度：刚进入本周窗口";
  const label = pace.status === "fast" ? "偏快" : pace.status === "slow" ? "偏慢" : "均匀";
  return `使用速度：${label}${pace.paceMultiplier === null ? "" : ` ${pace.paceMultiplier}×`}`;
}

function paceDetail(pace) {
  if (!pace) return "需同时具备周窗口、已用比例和自然恢复时间。";
  const totalDays = Math.round((pace.totalMins ?? 0) / 1440);
  const elapsedDays = ((pace.elapsedMins ?? 0) / 1440).toFixed(1);
  if (pace.status === "warming_up") return `本周窗口刚开始；已过 ${elapsedDays}/${totalDays} 天，稍后会形成稳定节奏指标。`;
  const delta = Math.abs(pace.differencePercentPoints ?? 0).toFixed(1);
  const comparison = pace.differencePercentPoints > 2 ? `高出 ${delta} 个百分点` : pace.differencePercentPoints < -2 ? `低于 ${delta} 个百分点` : `相差 ${delta} 个百分点`;
  return `已过 ${elapsedDays}/${totalDays} 天 · 当前已用 ${pace.usedPercent}% · 均匀基准约 ${pace.expectedUsedPercent}% · ${comparison}`;
}

function pacePosition(pace) {
  if (pace?.paceMultiplier === null || pace?.paceMultiplier === undefined) return 50;
  return Math.max(5, Math.min(95, 50 + (Number(pace.paceMultiplier) - 1) * 30));
}

function balanceBar(pace) {
  if (!pace || pace.status === "warming_up") return "";
  const position = pacePosition(pace).toFixed(1);
  const marker = '<i style=\'left:' + position + '%\'></i>';
  return '<div class=\'pace-balance\'>' + marker + '</div><div class=\'pace-balance-labels\'><span>偏慢</span><span>正好</span><span>偏快</span></div>';
}

// Kept as adapters for the existing compact window markup: they now receive
// the current cumulative weekly pace, not a two-hour sample.
function twoHourPaceLabel(pace) { return paceLabel(pace); }
function twoHourPaceDetail(pace) { return paceDetail(pace); }

function appendPaceBalance(pace) {
  const target = document.querySelector(".quota-window.weekly .usage-pace");
  if (!target || !pace || pace.status === "warming_up") return;
  target.insertAdjacentHTML("beforeend", balanceBar(pace));
}

function windowCard(label, bucket, tone, pace = null, twoHourPace = null) {
  if (!bucket || number(bucket.usedPercent) === null) return `<article class="quota-window ${tone} unavailable"><div><strong>${label}</strong><span>当前账户未返回此窗口</span></div><p>不显示为 0%，也不会由其他模型额度替代。</p></article>`;
  const used = number(bucket.usedPercent), left = number(bucket.remainingPercent);
  const paceHtml = tone === "weekly" ? `<div class="usage-pace ${safe(twoHourPace?.status ?? "collecting")}"><strong>${safe(twoHourPaceLabel(twoHourPace))}</strong><span>${safe(twoHourPaceDetail(twoHourPace))}</span></div><div class="weekly-progress ${safe(pace?.status ?? "unavailable")}"><strong>本周总体节奏：${safe(paceLabel(pace))}</strong><span>${safe(paceDetail(pace))}</span></div>` : "";
  return `<article class="quota-window ${tone}"><div class="quota-window-head"><strong>${label}</strong><span>${safe(bucket.displayName)}</span></div><div class="quota-window-main"><b>${left ?? "—"}%</b><span>剩余</span><em>${used ?? "—"}% 已用</em></div><div class="meter ${tone}"><i style="width:${Math.max(0, Math.min(100, used ?? 0))}%"></i></div><div class="quota-window-meta"><span>${bucket.windowDurationMins ? `${safe(bucket.windowDurationMins)} 分钟窗口` : "窗口长度未提供"}</span><span>${safe(remaining(bucket.resetsAt))}</span></div><p>自然恢复：<b>${safe(fmt(bucket.resetsAt))}</b></p>${paceHtml}</article>`;
}

function renderSummary(account) {
  const { main, weekly } = chooseWindows(account);
  const primary = main ?? weekly;
  if (!primary || number(primary.remainingPercent) === null) { $("summary-content").innerHTML = `<p class="empty">个人额度暂不可读。请确认 Codex 已登录后点击立即刷新。</p>`; return; }
  const status = number(primary.remainingPercent) >= 50 ? "充足" : number(primary.remainingPercent) >= 20 ? "注意用量" : "接近窗口上限";
  $("summary-content").innerHTML = `<div class="summary-number">${safe(primary.remainingPercent)}<small>%</small></div><div class="summary-side"><strong>${status}</strong><span>当前查看：${main ? "主额度" : "周额度"}</span><small>${safe(remaining(primary.resetsAt))} 后自然恢复</small></div>`;
}

function renderWindows(account) {
  const { main, weekly } = chooseWindows(account);
  account.recentTwoHourPace = account.usagePace;
  $("quota-windows").innerHTML = `${windowCard("主额度", main, "main")}${windowCard("周额度", weekly, "weekly", account.usagePace, account.recentTwoHourPace)}`;
}

function projectMeter(percent, tone = "") {
  const width = Math.max(0, Math.min(100, Number(percent) || 0));
  return `<div class="project-meter ${tone}"><i style="width:${width}%"></i></div>`;
}

function renderProjectUsage(state) {
  const account = state.account ?? {};
  const { weekly } = chooseWindows(account);
  const ledger = state.projectUsage ?? {};
  const field = $("project-name");
  if (document.activeElement !== field) field.value = ledger.activeProject ?? "未归类";
  if (!weekly || number(weekly.usedPercent) === null) {
    $("project-total").textContent = "周额度暂不可读";
    $("project-usage").innerHTML = `<p class="empty">需先读取到本账号的通用周额度，项目账本才会开始统计。</p>`;
    return;
  }
  const weeklyUsed = number(weekly.usedPercent) ?? 0;
  const projects = (Array.isArray(ledger.projects) ? ledger.projects : [])
    .map((project) => ({ name: String(project?.name ?? "未归类"), usedPercent: Math.max(0, number(project?.usedPercent) ?? 0) }))
    .filter((project) => project.usedPercent > 0)
    .sort((a, b) => b.usedPercent - a.usedPercent);
  const tracked = projects.reduce((total, project) => total + project.usedPercent, 0);
  const untracked = Math.max(0, weeklyUsed - tracked);
  $("project-total").textContent = `本周已用 ${weeklyUsed}%`;
  const rows = projects.map((project) => `<article class="project-row"><div><strong>${safe(project.name)}</strong><span>${safe(project.usedPercent)}% / 周额度 100</span></div>${projectMeter(project.usedPercent)}<b>${safe(project.usedPercent)}%</b></article>`);
  if (untracked > 0.01) rows.push(`<article class="project-row untracked"><div><strong>未追踪历史</strong><span>雷达开始项目归因前已消耗，无法可靠分配</span></div>${projectMeter(untracked, "untracked")}<b>${safe(Math.round(untracked * 100) / 100)}%</b></article>`);
  if (!rows.length) rows.push(`<p class="empty">当前本周没有可归因的消耗。选择项目后，后续新增用量会自动记入此处。</p>`);
  $("project-usage").innerHTML = `<p class="project-ledger-meta">当前归因：<b>${safe(ledger.activeProject ?? "未归类")}</b> · 已归因 ${safe(Math.round(tracked * 100) / 100)}%</p>${rows.join("")}`;
}

function renderModelBuckets(account) {
  const buckets = (account.buckets ?? []).filter((bucket) => bucket.limitId !== "codex" && bucket.limitId !== "codex:secondary");
  $("model-buckets").innerHTML = buckets.length ? buckets.map((bucket) => `<article class="compact-bucket"><div><strong>${safe(bucket.displayName)}</strong><span>${bucket.windowDurationMins ? `${safe(bucket.windowDurationMins)} 分钟` : "窗口未提供"}</span></div><div class="meter model"><i style="width:${Math.max(0, Math.min(100, number(bucket.usedPercent) ?? 0))}%"></i></div><p>已用 <b>${safe(bucket.usedPercent ?? "—")}%</b> · 剩余 <b>${safe(bucket.remainingPercent ?? "—")}%</b> · ${safe(remaining(bucket.resetsAt))}</p></article>`).join("") : `<p class="empty">当前没有独立模型额度桶。</p>`;
}

function renderCreditsHealth(account) {
  const credits = account.resetCredits ?? {}, entries = Array.isArray(credits.entries) ? credits.entries : [];
  const source = account.health ?? {};
  $("credits-health").innerHTML = `<div class="credits summary-credits"><strong>可用重置卡</strong><span>${safe(credits.availableCount ?? "—")} 张</span><small>${entries.length ? entries.map((entry) => entry.expiresAt ? `有效期至 ${fmt(entry.expiresAt)}` : "有效期未提供").join(" · ") : "只读显示，不提供兑换按钮"}</small></div><ul class="health-list"><li><span>个人额度来源</span><b>${source.status === "ok" ? (source.stale ? "缓存可能过期" : "正常") : "暂不可读"}</b><small>${source.lastSuccessAt ? `最近成功：${fmt(source.lastSuccessAt)}` : safe(source.lastError ?? "尚未读取")}</small></li></ul>`;
}

function render(state) {
  const account = state.account ?? {};
  health($("account-health"), account.health);
  const pill = $("health-pill"); health(pill, account.health); pill.className = `pill ${account.health?.status === "ok" && !account.health?.stale ? "announced" : "warn"}`;
  renderSummary(account); renderWindows(account); appendPaceBalance(account.usagePace); renderProjectUsage(state); renderModelBuckets(account); renderCreditsHealth(account);
  $("updated-at").textContent = state.updatedAt ? ` 本地缓存更新：${fmt(state.updatedAt)}` : " 尚无本地缓存";
}

async function load() {
  const response = await fetch("/api/state", { cache: "no-store" });
  if (!response.ok) throw new Error("state_unavailable");
  render(await response.json());
}

async function manualRefresh() {
  const button = $("refresh"), notice = $("notice"); button.disabled = true; button.textContent = "刷新中…";
  try {
    const response = await fetch("/api/refresh", { method: "POST", headers: { "content-type": "application/json" } });
    const body = await response.json(); render(body.state); notice.hidden = false;
    notice.textContent = body.ok ? "已完成一次只读刷新。窗口只按账户当前返回的额度桶显示。" : "刷新未完全成功，已保留最近可用缓存。";
  } catch { notice.hidden = false; notice.textContent = "本地服务暂不可用。"; }
  finally { button.disabled = false; button.textContent = "立即刷新"; }
}

$("refresh").addEventListener("click", manualRefresh);
$("project-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const field = $("project-name"), button = event.currentTarget.querySelector("button"), notice = $("notice");
  const name = field.value.trim();
  if (!name) { notice.hidden = false; notice.textContent = "请输入项目名称。"; return; }
  button.disabled = true;
  try {
    const response = await fetch("/api/project", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ name }) });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error ?? "project_save_failed");
    render(body.state); notice.hidden = false; notice.textContent = `已切换到“${name}”；切换前的用量已按旧项目结算，之后新增周额度会归入此项目。`;
  } catch { notice.hidden = false; notice.textContent = "项目设置保存失败，本机服务可能暂不可用。"; }
  finally { button.disabled = false; }
});
load().catch(() => { $("notice").hidden = false; $("notice").textContent = "无法连接本地雷达服务。"; });
setInterval(() => load().catch(() => {}), 60_000);
