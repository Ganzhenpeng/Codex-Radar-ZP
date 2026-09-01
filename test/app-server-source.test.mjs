import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../server.mjs", import.meta.url), "utf8");

test("额度读取每次使用新 App Server 会话，并记录可执行文件来源", () => {
  assert.match(source, /resolveCodexExecutable/);
  assert.match(source, /app_server_executable/, "应只记录可执行文件来源，不记录路径或认证信息");
  assert.match(source, /async readRateLimits\(\)[\s\S]*?try \{[\s\S]*?account\/rateLimits\/read[\s\S]*?finally \{[\s\S]*?this\.close\(\)/);
});
