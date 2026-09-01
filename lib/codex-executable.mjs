import fs from "node:fs/promises";
import path from "node:path";

async function executableFile(candidate, fsApi) {
  if (!candidate) return null;
  try {
    const stat = await fsApi.stat(candidate);
    return stat.isFile() ? { path: candidate, modifiedAt: stat.mtimeMs } : null;
  } catch { return null; }
}

// Codex desktop updates use versioned bin directories. A previously exported
// CODEX_BIN can therefore point at a removed version; only trust it if it still
// exists, then discover the newest installed executable before falling back to PATH.
export async function resolveCodexExecutable({ environment = process.env, fsApi = fs, fallback = "codex" } = {}) {
  const override = await executableFile(environment.CODEX_BIN, fsApi);
  if (override) return { executable: override.path, source: "existing_override" };

  const localAppData = environment.LOCALAPPDATA;
  if (localAppData) {
    const binRoot = path.join(localAppData, "OpenAI", "Codex", "bin");
    try {
      const entries = await fsApi.readdir(binRoot, { withFileTypes: true });
      const candidates = await Promise.all(entries.filter((entry) => entry.isDirectory()).map(async (entry) => executableFile(path.join(binRoot, entry.name, "codex.exe"), fsApi)));
      const latest = candidates.filter(Boolean).sort((left, right) => right.modifiedAt - left.modifiedAt)[0];
      if (latest) return { executable: latest.path, source: "installed_current" };
    } catch { /* Codex may be installed through PATH instead. */ }
  }
  return { executable: fallback, source: "path_fallback" };
}
