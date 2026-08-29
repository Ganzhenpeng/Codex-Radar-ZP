const $ = (id) => document.getElementById(id);
let currentState = null;

const dt = new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Shanghai" });
const la = new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short", timeZone: "America/Los_Angeles" });
const bjShort = new Intl.DateTimeFormat("zh-CN", { weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: "Asia/Shanghai" });
const fmt = (value, formatter = dt) => value ? formatter.format(new Date(value)) : "未提供";
const fmtBjShort = (value) => value ? bjShort.format(new Date(value)).replace(/\s+/g, "") : null;
const safe = (value) => String(value ?? "").replace(/[&<>\"']/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[ch]));

function health(node, health) {
  const text = health?.status === "ok" ? (health.stale ? "缓存可能过期" : "正常") : "暂不可读";
  node.textContent = text; node.className = `source-state ${health?.status === "ok" && !health.stale ? "ok" : "warn"}`;
}

function badge(value) { return `<span class="pill ${safe(value)}">${safe(value)}</span>`; }

function renderAccount(account) {
  health($("account-health"), account.health);
  if (!account.buckets?.length) { $("account-content").innerHTML = `<p class="empty">个人额度暂不可读。${safe(account.health?.lastError ?? "请确认 Codex 已登录后点击立即刷新。")}</p>`; return; }
  $("account-content").innerHTML = `<div class="buckets">${account.buckets.map((bucket) => `<div class="bucket"><div class="bucket-name"><strong>${safe(bucket.displayName)}</strong><span>${safe(bucket.limitId)}</span></div><div class="meter"><i style="width:${Number(bucket.usedPercent ?? 0)}%"></i></div><div class="bucket-meta"><span>已用 <b>${bucket.usedPercent ?? "—"}%</b></span><span>剩余 <b>${bucket.remainingPercent ?? "—"}%</b></span></div><dl><div><dt>窗口</dt><dd>${bucket.windowDurationMins ? `${bucket.windowDurationMins} 分钟` : "未提供"}</dd></div><div><dt>自然恢复</dt><dd>${fmt(bucket.resetsAt)}</dd></div>${bucket.planType ? `<div><dt>计划</dt><dd>${safe(bucket.planType)}</dd></div>` : ""}</dl></div>`).join("")}</div><div class="credits"><strong>可用重置卡</strong><span>${account.resetCredits?.availableCount ?? "—"} 张</span><small>${account.resetCredits?.entries?.map((entry) => entry.expiresAt ? `有效期至 ${fmt(entry.expiresAt)}` : "有效期未提供").join(" · ") || "只读显示，不提供兑换按钮"}</small></div>`;
}

function renderPublic(publicData) {
  health($("public-health"), publicData.health);
  const latest = publicData.latestReset, watch = publicData.activeWatch;
  const block = (label, title, body, source) => `<div class="signal"><div class="signal-label">${label}</div><h3>${safe(title)}</h3><p>${safe(body || "无正文")}</p>${source?.url ? `<a href="${safe(source.url)}" target="_blank" rel="noreferrer">打开原帖链接 ↗</a>` : ""}</div>`;
  const latestBlock = latest ? block(latest.type === "banked_reset" ? "公开重置卡公告" : "公开全量重置公告", `北京时间：${fmt(latest.occurredAt)} · 旧金山：${fmt(latest.occurredAt, la)}`, latest.text, latest.source) : `<p class="empty">尚无可用公开重置公告。</p>`;
  const watchTiming = watch ? `Tibo（${fmtBjShort(watch.observedAt) ?? "发帖时间未提供"}）：${watch.expiresAt ? `预计 ${fmtBjShort(watch.expiresAt)} 前（北京时间）` : "预计时间未提供"}` : "";
  const watchBlock = watch ? block(`第三方预测 · ${watch.probability ?? "—"}%`, `${watchTiming}${watch.forecastWindow ? ` · 原始窗口：${safe(watch.forecastWindow)}` : ""}`, watch.text, watch.source) : `<p class="watch-empty">当前没有活跃的第三方观察信号。</p>`;
  $("public-content").innerHTML = `${latestBlock}${watchBlock}`;
}

function renderDerived(state) {
  const change = state.derived?.lastAccountChange; const status = state.derived?.status ?? "unavailable";
  const map = { idle: ["等待新信号", "当前没有公开重置信号或个人额度恢复事件。"], forecast: ["第三方预测", "Tracker 观察到相关信号；这不是 OpenAI 官方承诺。"], announced: ["公开已宣布，个人账户待确认", "公开 Tracker 已记录公告；请以本账号额度窗口变化为准。"], propagating: ["额度提前恢复，疑似额外重置", "这是个人额度快照变化；没有接口原因字段，因此不擅自断言因果。"], account_confirmed: ["公开公告后，个人额度随后得到确认", "按时间关联显示；仍不代表已证明公开事件与账户变化的因果。"], stale: ["数据可能过期", "至少一个数据源读取失败，正在保留最近成功的缓存。"], unavailable: ["暂不可用", "两个数据源都尚未得到可用数据。"] };
  const [title, body] = map[status] ?? map.unavailable;
  $("derived-content").innerHTML = `<div class="derived ${safe(status)}"><strong>${safe(title)}</strong><p>${safe(body)}</p>${change ? `<small>最近账户变化：${safe(change.kind)} · ${fmt(change.at)}</small>` : ""}</div>`;
  const pill = $("status-pill"); pill.textContent = title; pill.className = `pill ${status}`;
}

function renderScheduler(state) {
  const scheduler = state.scheduler ?? {}, sourceLine = (name, health) => `<li><span>${name}</span><b>${health?.status === "ok" ? (health.stale ? "缓存可能过期" : "正常") : "暂不可读"}</b><small>${health?.lastSuccessAt ? `最近成功：${fmt(health.lastSuccessAt)}` : safe(health?.lastError ?? "尚未检查")}</small></li>`;
  const publicSchedule = scheduler.public ?? scheduler;
  const accountSchedule = scheduler.account ?? { mode: "continuous_local_read", intervalSeconds: 300, active: true };
  const accountLine = accountSchedule.active
    ? `个人额度：服务运行期间每 ${Math.round((accountSchedule.intervalSeconds ?? 300) / 60)} 分钟通过本机 App Server 只读刷新。`
    : "个人额度：当前未启用持续读取。";
  $("scheduler-content").innerHTML = `<div class="schedule-state">${badge("个人额度持续读取")}<p>${safe(accountLine)}</p>${badge(publicSchedule.allowedNow ? "Tibo 公共源允许检查" : "Tibo 公共源暂停")}<p>${safe(publicSchedule.pauseReason ?? "当前时段可在整点检查")}</p><p>Tibo 下次允许整点：<b>${fmt(publicSchedule.nextAllowedCheckAt)}</b></p></div><ul class="health-list">${sourceLine("个人额度源", state.account.health)}${sourceLine("公共 Tracker", state.public.health)}</ul>`;
}

function renderHistory(history) {
  const filter = $("history-filter").value;
  const rows = (history ?? []).filter((row) => filter === "all" || row.type === filter);
  $("history-content").innerHTML = rows.length ? rows.map((row) => `<article class="history-item"><time>${fmt(row.occurredAt)}</time><div><strong>${row.type === "banked_reset" ? "重置卡" : row.type === "full_reset" ? "全量重置" : "预告/观察"}</strong><p>${safe(row.summary)}</p><small>${safe(row.evidence)}</small>${row.source?.url ? ` <a href="${safe(row.source.url)}" target="_blank" rel="noreferrer">原帖 ↗</a>` : ""}</div></article>`).join("") : `<p class="empty">当前筛选没有记录。</p>`;
}

function render(state) { currentState = state; renderAccount(state.account); renderPublic(state.public); renderDerived(state); renderScheduler(state); renderHistory(state.history); $("updated-at").textContent = state.updatedAt ? `本地缓存更新：${fmt(state.updatedAt)}` : "尚无本地缓存"; }

async function load() { const response = await fetch("/api/state", { cache: "no-store" }); if (!response.ok) throw new Error("state_unavailable"); render(await response.json()); }
async function manualRefresh() { const button = $("refresh"), notice = $("notice"); button.disabled = true; button.textContent = "刷新中…"; try { const response = await fetch("/api/refresh", { method: "POST", headers: { "content-type": "application/json" } }); const body = await response.json(); render(body.state); notice.hidden = false; notice.textContent = body.ok ? "已完成一次只读刷新。个人账户与公开 Tracker 的证据仍分开显示。" : "刷新未完全成功，已保留最近可用缓存。"; } catch { notice.hidden = false; notice.textContent = "本地服务暂不可用。"; } finally { button.disabled = false; button.textContent = "立即刷新"; } }

$("refresh").addEventListener("click", manualRefresh);
$("history-filter").addEventListener("change", () => renderHistory(currentState?.history));
load().catch(() => { $("notice").hidden = false; $("notice").textContent = "无法连接本地雷达服务。请先运行 npm start。"; });
setInterval(() => load().catch(() => {}), 60_000);
