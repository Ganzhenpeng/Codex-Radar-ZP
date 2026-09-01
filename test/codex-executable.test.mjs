import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { resolveCodexExecutable } from "../lib/codex-executable.mjs";

test("失效的 CODEX_BIN 不会阻塞当前 Codex 安装目录发现", async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "codex-radar-bin-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const oldBin = path.join(root, "OpenAI", "Codex", "bin", "older", "codex.exe");
  const currentBin = path.join(root, "OpenAI", "Codex", "bin", "current", "codex.exe");
  await fs.mkdir(path.dirname(oldBin), { recursive: true });
  await fs.mkdir(path.dirname(currentBin), { recursive: true });
  await fs.writeFile(oldBin, "old");
  await new Promise((resolve) => setTimeout(resolve, 15));
  await fs.writeFile(currentBin, "current");

  const resolved = await resolveCodexExecutable({ environment: { LOCALAPPDATA: root, CODEX_BIN: path.join(root, "removed", "codex.exe") } });
  assert.deepEqual(resolved, { executable: currentBin, source: "installed_current" });
});

test("存在的 CODEX_BIN 优先于扫描结果，缺少安装目录时回退 PATH", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "codex-radar-override-"));
  try {
    const override = path.join(root, "custom-codex.exe");
    await fs.writeFile(override, "custom");
    assert.deepEqual(await resolveCodexExecutable({ environment: { CODEX_BIN: override } }), { executable: override, source: "existing_override" });
    assert.deepEqual(await resolveCodexExecutable({ environment: {}, fallback: "codex-on-path" }), { executable: "codex-on-path", source: "path_fallback" });
  } finally { await fs.rm(root, { recursive: true, force: true }); }
});
