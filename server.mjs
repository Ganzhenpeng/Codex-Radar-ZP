import http from "node:http";
import path from "node:path";
import fs from "node:fs/promises";
import { createWriteStream } from "node:fs";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import {
  derivedStatus, detectAccountChange, nextEligibleCheck, normaliseAccount, normaliseHistory,
  normalisePublicStatus, schedulerDecision, shouldCheckPublic, shortHash, updateProjectUsage,
} from "./lib/radar-core.mjs";
import { resolveCodexExecutable } from "./lib/codex-executable.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(ROOT, "data");
const PUBLIC_DIR = path.join(ROOT, "public");
const STATE_PATH = path.join(DATA_DIR, "state.json");
const LOG_PATH = path.join(DATA_DIR, "radar.log");
const PID_PATH = path.join(DATA_DIR, "server.pid");
const PORT = Number(process.env.RADAR_PORT ?? 43721);
const STARTED_AT = new Date().toISOString();
const VERSION = "1.0.0";
const MAX_LOG_BYTES = 512 * 1024;
const PUBLIC_STATUS_URL = "https://codex-resets.com/api/v1/status";
const PUBLIC_HISTORY_URL = "https://codex-resets.com/api/v1/resets?limit=100&order=desc";
const ALLOWED_ORIGINS = new Set([`http://127.0.0.1:${PORT}`, `http://localhost:${PORT}`]);

let state;
let refreshPromise = null;
let appServer = null;

function initialState() {
  return {
    version: 1, createdAt: STARTED_AT, updatedAt: null,
    account: { buckets: [], resetCredits: { availableCount: 0, entries: [] }, usagePace: null, health: { status: "unavailable", stale: true, lastSuccessAt: null, lastError: "尚未读取" }, lastSnapshot: null },
    public: { latestReset: null, activeWatch: null, stats: null, historyEtag: null, statusEtag: null, health: { status: "unavailable", stale: true, lastSuccessAt: null, lastError: "尚未读取" }, retryAfterAt: null, lastAttemptAt: null },
    history: [], notifications: {}, derived: { status: "unavailable", lastAccountChange: null }, scheduler: {},
    projectUsage: { version: 1, windowKey: null, activeProject: "未归类", projects: [], updatedAt: null },
  };
}

async function atomicWrite(file, value) {
  const temporary = `${file}.${process.pid}.${Date.now()}.tmp`;
  await fs.writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  await fs.rename(temporary, file);
}

async function log(event, detail = {}) {
  const safe = JSON.stringify({ at: new Date().toISOString(), event, ...detail }).replace(/[\r\n]/g, " ");
  try {
    const stat = await fs.stat(LOG_PATH).catch(() => null);
    if (stat?.size > MAX_LOG_BYTES) await fs.rename(LOG_PATH, `${LOG_PATH}.1`).catch(() => {});
    await fs.appendFile(LOG_PATH, `${safe}\n`, "utf8");
  } catch { /* Logging must not stop the radar. */ }
}

async function save() {
  state.updatedAt = new Date().toISOString();
  state.derived.status = derivedStatus(state);
  state.scheduler = schedulerState();
  await atomicWrite(STATE_PATH, state);
}

async function loadState() {
  await fs.mkdir(DATA_DIR, { recursive: true });
  try {
    const parsed = JSON.parse(await fs.readFile(STATE_PATH, "utf8"));
    const cachedPublic = { ...initialState().public, ...parsed.public };
    // Persisted state is intentionally a normalised, privacy-minimal cache. Re-run
    // that normalisation on startup so a new derived display field still appears
    // when the Tracker correctly answers the next network check with 304 Not Modified.
    const rehydrated = normalisePublicStatus({ data: {
      latest_reset: cachedPublic.latestReset ? {
        id: cachedPublic.latestReset.id, reset_type: cachedPublic.latestReset.type,
        text: cachedPublic.latestReset.text, announced_at: cachedPublic.latestReset.occurredAt,
        source: { author: cachedPublic.latestReset.source?.author, url: cachedPublic.latestReset.source?.url },
      } : null,
      active_watch: cachedPublic.activeWatch ? {
        id: cachedPublic.activeWatch.id, level: cachedPublic.activeWatch.level,
        reset_chance_percent: cachedPublic.activeWatch.probability, forecast_window: cachedPublic.activeWatch.forecastWindow,
        observed_at: cachedPublic.activeWatch.observedAt, expires_at: cachedPublic.activeWatch.expiresAt,
        text: cachedPublic.activeWatch.text,
        source: { author: cachedPublic.activeWatch.source?.author, url: cachedPublic.activeWatch.source?.url },
      } : null,
      stats: cachedPublic.stats,
    } });
    return {
      ...initialState(), ...parsed,
      account: { ...initialState().account, ...parsed.account },
      public: { ...cachedPublic, ...rehydrated },
      projectUsage: { ...initialState().projectUsage, ...parsed.projectUsage },
    };
  } catch (error) {
    if (error.code !== "ENOENT") await log("state_cache_invalid", { category: "invalid_json" });
    return initialState();
  }
}

function schedulerState(now = new Date()) {
  const decision = schedulerDecision(now);
  return {
    account: { mode: "continuous_local_read", intervalSeconds: 300, active: true },
    public: { timeZones: { beijing: "Asia/Shanghai", sanFrancisco: "America/Los_Angeles" }, allowedNow: decision.allowedNow, pauseReason: decision.pauseReason, nextAllowedCheckAt: nextEligibleCheck(now) },
    // Keep these fields during the transition so older local pages can still render the public-source schedule.
    timeZones: { beijing: "Asia/Shanghai", sanFrancisco: "America/Los_Angeles" }, allowedNow: decision.allowedNow, pauseReason: decision.pauseReason, nextAllowedCheckAt: nextEligibleCheck(now),
  };
}

function publicState() {
  const clone = structuredClone(state);
  delete clone.notifications;
  delete clone.account.lastSnapshot;
  clone.scheduler = schedulerState();
  clone.derived.status = derivedStatus(clone);
  return clone;
}

function projectName(value) {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, 60);
}

async function readJsonBody(request, limit = 2048) {
  let body = "";
  for await (const chunk of request) {
    body += chunk;
    if (body.length > limit) throw new Error("body_too_large");
  }
  try { return JSON.parse(body || "{}"); } catch { throw new Error("invalid_json"); }
}

function allowedHost(request) {
  const host = String(request.headers.host ?? "").toLowerCase();
  return host === `127.0.0.1:${PORT}` || host === `localhost:${PORT}`;
}

function send(response, statusCode, body, headers = {}) {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff", ...headers });
  response.end(JSON.stringify(body));
}

function setSecurityHeaders(response, contentType) {
  response.setHeader("content-type", contentType);
  response.setHeader("x-content-type-options", "nosniff");
  response.setHeader("referrer-policy", "no-referrer");
  response.setHeader("content-security-policy", "default-src 'self'; connect-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; base-uri 'none'");
}

class AppServerClient {
  constructor() { this.child = null; this.pending = new Map(); this.sequence = 0; this.initialized = false; this.buffer = ""; }
  async connect() {
    if (this.child && !this.child.killed && this.initialized) return;
    this.close();
    const target = await resolveCodexExecutable();
    await log("app_server_executable", { source: target.source });
    this.child = spawn(target.executable, ["app-server"], { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
    this.child.stdout.setEncoding("utf8");
    this.child.stdout.on("data", (chunk) => this.onData(chunk));
    this.child.stderr.on("data", () => {});
    this.child.on("error", (error) => this.rejectAll(error));
    this.child.on("exit", () => { this.initialized = false; this.rejectAll(new Error("app_server_exited")); });
    await this.request("initialize", { clientInfo: { name: "codex-reset-radar", title: "Codex Reset Radar", version: VERSION } }, 20_000);
    this.notify("initialized", {});
    this.initialized = true;
  }
  onData(chunk) {
    this.buffer += chunk;
    const lines = this.buffer.split("\n"); this.buffer = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const message = JSON.parse(line);
        if (message.id !== undefined && this.pending.has(message.id)) {
          const entry = this.pending.get(message.id); this.pending.delete(message.id); clearTimeout(entry.timer);
          if (message.error) entry.reject(new Error(message.error.message ?? "app_server_error")); else entry.resolve(message.result);
        }
      } catch { log("app_server_protocol", { category: "invalid_json" }); }
    }
  }
  write(message) { this.child.stdin.write(`${JSON.stringify(message)}\n`); }
  notify(method, params) { this.write({ method, params }); }
  request(method, params, timeoutMs = 15_000) {
    return new Promise((resolve, reject) => {
      const id = ++this.sequence;
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`${method}_timeout`)); }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      try { this.write({ method, id, params }); } catch (error) { clearTimeout(timer); this.pending.delete(id); reject(error); }
    });
  }
  rejectAll(error) { for (const item of this.pending.values()) { clearTimeout(item.timer); item.reject(error); } this.pending.clear(); }
  close() { if (this.child) { this.child.kill(); this.child = null; } this.initialized = false; }
  async readRateLimits() {
    await this.connect();
    try {
      return await this.request("account/rateLimits/read", {}, 20_000);
    } finally {
      // The desktop App Server can invalidate a reused stdio session after a
      // successful request. This radar reads only once per interval, so a fresh
      // short-lived client is more reliable than holding a stale connection.
      this.close();
    }
  }
}

async function fetchPublic() {
  state.public.lastAttemptAt = new Date().toISOString();
  if (state.public.retryAfterAt && Date.parse(state.public.retryAfterAt) > Date.now()) return { skipped: "retry_after" };
  const headers = { accept: "application/json", "user-agent": `Codex-Reset-Radar/${VERSION} (local-only)` };
  if (state.public.statusEtag) headers["if-none-match"] = state.public.statusEtag;
  let response;
  try { response = await fetch(PUBLIC_STATUS_URL, { headers, signal: AbortSignal.timeout(15_000) }); }
  catch (error) { throw new Error("public_network_timeout"); }
  if (response.status === 304) {
    state.public.health = { status: "ok", stale: false, lastSuccessAt: new Date().toISOString(), lastError: null };
    await log("public_status", { status: 304 }); return { unchanged: true };
  }
  if (response.status === 429) {
    const seconds = Math.max(60, Number(response.headers.get("retry-after") ?? 60));
    state.public.retryAfterAt = new Date(Date.now() + seconds * 1000).toISOString();
    throw new Error("public_rate_limited");
  }
  if (!response.ok) throw new Error(`public_http_${response.status}`);
  const payload = await response.json();
  const next = normalisePublicStatus(payload);
  const previousLatestId = state.public.latestReset?.id ?? null;
  const isChanged = previousLatestId !== (next.latestReset?.id ?? null);
  state.public = { ...state.public, ...next, statusEtag: response.headers.get("etag") ?? state.public.statusEtag, retryAfterAt: null, health: { status: "ok", stale: false, lastSuccessAt: new Date().toISOString(), lastError: null } };
  const noHistoryYet = state.history.length === 0;
  if (isChanged || noHistoryYet) await fetchHistory();
  await log("public_status", { status: 200, latestEventId: next.latestReset?.id ?? null });
  return { changed: isChanged };
}

async function fetchHistory() {
  const headers = { accept: "application/json", "user-agent": `Codex-Reset-Radar/${VERSION} (local-only)` };
  if (state.public.historyEtag) headers["if-none-match"] = state.public.historyEtag;
  const response = await fetch(PUBLIC_HISTORY_URL, { headers, signal: AbortSignal.timeout(15_000) });
  if (response.status === 304) return;
  if (!response.ok) throw new Error(`public_history_http_${response.status}`);
  state.history = normaliseHistory(await response.json()).slice(0, 100);
  state.public.historyEtag = response.headers.get("etag") ?? state.public.historyEtag;
}

async function fetchAccount() {
  try {
    appServer ??= new AppServerClient();
    const response = await appServer.readRateLimits();
    const current = normaliseAccount(response);
    const previous = state.account.lastSnapshot;
    const changes = detectAccountChange(previous, current);
    state.projectUsage = updateProjectUsage(state.projectUsage, previous?.displayWindows?.weekly, current.displayWindows?.weekly);
    state.account = { ...state.account, ...current, health: { status: "ok", stale: false, lastSuccessAt: new Date().toISOString(), lastError: null }, lastSnapshot: current };
    delete state.account.usageSamples;
    delete state.account.recentTwoHourPace;
    if (changes.length) state.derived.lastAccountChange = { ...changes[0], at: new Date().toISOString() };
    await log("account_rate_limits", { status: "ok", bucketCount: current.buckets.length });
    return changes;
  } catch (error) {
    state.account.health = { ...state.account.health, status: "unavailable", stale: Boolean(state.account.health.lastSuccessAt), lastError: "个人额度暂不可读" };
    await log("account_rate_limits", { status: "error", category: String(error.message).replace(/[^a-z0-9_]/gi, "_").slice(0, 60) });
    return [];
  }
}

async function toast(title, body) {
  const title64 = Buffer.from(String(title), "utf8").toString("base64");
  const body64 = Buffer.from(String(body), "utf8").toString("base64");
  const command = `[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] > $null; $title=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${title64}')); $body=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${body64}')); $xml=[Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); $text=$xml.GetElementsByTagName('text'); $null=$text.Item(0).AppendChild($xml.CreateTextNode($title)); $null=$text.Item(1).AppendChild($xml.CreateTextNode($body)); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Codex Reset Radar').Show([Windows.UI.Notifications.ToastNotification]::new($xml))`;
  const encoded = Buffer.from(command, "utf16le").toString("base64");
  const windowsPowerShell = process.env.SystemRoot ? path.join(process.env.SystemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe") : "powershell.exe";
  spawn(windowsPowerShell, ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded], { windowsHide: true, stdio: "ignore" });
}

async function notifyOnce(key, title, body) {
  if (state.notifications[key]) return;
  state.notifications[key] = new Date().toISOString();
  await toast(title, body);
  await log("notification", { key: key.slice(0, 80) });
}

async function applyNotifications(previousLatest, changes, hadPublicBaseline) {
  if (hadPublicBaseline && state.public.activeWatch) await notifyOnce(`watch:${state.public.activeWatch.id}`, "Codex 重置雷达：第三方预测", "检测到 Tibo 相关观察信号；这是第三方预测，不是 OpenAI 承诺。");
  const latest = state.public.latestReset;
  if (hadPublicBaseline && latest && previousLatest?.id !== latest.id) {
    const title = latest.type === "banked_reset" ? "Codex 重置雷达：公开重置卡公告" : "Codex 重置雷达：公开全量重置公告";
    await notifyOnce(`public:${latest.id}`, title, "Tracker 分类的公开公告，个人账户额度仍需单独确认。");
  }
  for (const change of changes) {
    if (change.kind === "early_recovery") await notifyOnce(`account:${shortHash(change)}`, "Codex 重置雷达：个人额度疑似提前恢复", "这是个人额度快照变化；与公开事件仅做时间关联，未证明因果关系。");
    if (change.kind === "natural_recovery") await notifyOnce(`account:${shortHash(change)}`, "Codex 重置雷达：个人额度自然窗口恢复", "个人账户快照接近原定恢复时间，属于自然窗口恢复判断。");
    if (change.kind === "credit_increase") await notifyOnce(`credit:${change.after}`, "Codex 重置雷达：个人账户已收到重置卡", `可用重置卡数量从 ${change.before} 变为 ${change.after}。仅显示，不会自动兑换。`);
  }
}

async function refresh({ reason = "manual", includePublic = true, includeAccount = true } = {}) {
  if (refreshPromise) return refreshPromise;
  refreshPromise = (async () => {
    const hadPublicBaseline = includePublic && Boolean(state.public.health.lastSuccessAt);
    const previousLatest = includePublic ? state.public.latestReset : null;
    let publicResult = null;
    if (includePublic) {
      try { publicResult = await fetchPublic(); }
      catch (error) {
        state.public.health = { ...state.public.health, status: "unavailable", stale: Boolean(state.public.health.lastSuccessAt), lastError: error.message.startsWith("public_http_") ? "公共 Tracker 暂不可读" : "公共 Tracker 网络异常" };
        await log("public_status", { status: "error", category: error.message });
      }
    }
    const changes = includeAccount ? await fetchAccount() : [];
    if (previousLatest && state.public.latestReset?.id === previousLatest.id && changes.some((change) => change.kind === "early_recovery" || change.kind === "natural_recovery")) {
      state.derived.lastAccountChange = { kind: "public_confirmed", at: new Date().toISOString(), relation: "时间关联，非因果证明" };
    }
    if (includePublic || changes.length) await applyNotifications(previousLatest, changes, hadPublicBaseline);
    await save();
    return { publicResult, changes };
  })().finally(() => { refreshPromise = null; });
  return refreshPromise;
}

async function serveStatic(request, response, pathname) {
  const requested = pathname === "/" ? "/index.html" : pathname;
  const target = path.resolve(PUBLIC_DIR, `.${requested}`);
  if (!target.startsWith(`${PUBLIC_DIR}${path.sep}`)) return send(response, 403, { error: "forbidden" });
  const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml" };
  try {
    const body = await fs.readFile(target);
    setSecurityHeaders(response, types[path.extname(target)] ?? "application/octet-stream");
    response.end(body);
  } catch { send(response, 404, { error: "not_found" }); }
}

async function main() {
  state = await loadState();
  await fs.writeFile(PID_PATH, `${process.pid}\n`, "utf8");
  const server = http.createServer(async (request, response) => {
    if (!allowedHost(request)) return send(response, 403, { error: "local_host_only" });
    const url = new URL(request.url, `http://127.0.0.1:${PORT}`);
    if (request.method === "GET" && url.pathname === "/healthz") return send(response, 200, { version: VERSION, startedAt: STARTED_AT, account: state.account.health, public: state.public.health });
    if (request.method === "GET" && url.pathname === "/api/state") return send(response, 200, publicState());
    if (request.method === "POST" && url.pathname === "/api/refresh") {
      const origin = request.headers.origin;
      if (origin && !ALLOWED_ORIGINS.has(origin)) return send(response, 403, { error: "same_origin_required" });
      const coalesced = Boolean(refreshPromise);
      try { const result = await refresh({ reason: "manual", includePublic: true, includeAccount: true }); return send(response, 200, { ok: true, coalesced, result, state: publicState() }); }
      catch { return send(response, 503, { ok: false, error: "refresh_failed", state: publicState() }); }
    }
    if (request.method === "POST" && url.pathname === "/api/project") {
      const origin = request.headers.origin;
      if (origin && !ALLOWED_ORIGINS.has(origin)) return send(response, 403, { error: "same_origin_required" });
      try {
        const body = await readJsonBody(request);
        const name = projectName(body?.name);
        if (!name) return send(response, 400, { error: "project_name_required" });
        // Settle the previous active project with one read-only snapshot before
        // switching labels, so the prior five-minute interval is not charged
        // to the newly selected project.
        await fetchAccount();
        state.projectUsage = { ...state.projectUsage, activeProject: name, updatedAt: new Date().toISOString() };
        await save();
        await log("project_usage_active", { nameLength: name.length });
        return send(response, 200, { ok: true, state: publicState() });
      } catch (error) {
        return send(response, error.message === "body_too_large" ? 413 : 400, { error: "invalid_project_request" });
      }
    }
    if (request.method === "GET") return serveStatic(request, response, decodeURIComponent(url.pathname));
    return send(response, 405, { error: "method_not_allowed" });
  });
  server.listen(PORT, "127.0.0.1", async () => {
    await log("server_started", { port: PORT });
    console.log(`Codex Reset Radar listening on http://127.0.0.1:${PORT}`);
    const scheduledRefresh = () => {
      // Account data is a local, read-only App Server query and must not inherit
      // the public Tibo source's overnight/public-network pause.
      const publicAllowed = shouldCheckPublic(new Date(), state.public.lastAttemptAt);
      refresh({ reason: "scheduled", includePublic: publicAllowed, includeAccount: true }).catch(() => {});
    };
    const interval = setInterval(scheduledRefresh, 5 * 60_000);
    interval.unref();
    scheduledRefresh();
  });
  const shutdown = async () => { appServer?.close(); await fs.rm(PID_PATH, { force: true }); server.close(() => process.exit(0)); setTimeout(() => process.exit(0), 2_000).unref(); };
  process.once("SIGINT", shutdown); process.once("SIGTERM", shutdown);
}

main().catch((error) => { console.error("Radar failed to start:", error.message); process.exitCode = 1; });
