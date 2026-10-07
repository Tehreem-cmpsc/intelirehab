import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

// scripts/README.md is the run order for the hand-run SQL scripts. A script added without a line there would
// be easy to forget (or to run too early), so this keeps the two in step.
const scriptsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "scripts");
const sqlFiles = readdirSync(scriptsDir).filter((f) => /^supabase_.*\.sql$/.test(f));
const readme = readFileSync(join(scriptsDir, "README.md"), "utf8");

describe("scripts/README.md run order", () => {
  it("lists every supabase_*.sql script", () => {
    const missing = sqlFiles.filter((f) => !readme.includes(`\`${f}\``));
    expect(missing).toEqual([]);
  });

  it("does not list a script that no longer exists", () => {
    const listed = [...readme.matchAll(/`(supabase_[a-z0-9_]+\.sql)`/g)].map((m) => m[1]);
    expect(listed.filter((f) => !sqlFiles.includes(f))).toEqual([]);
  });

  it("numbers the table in order, starting from 0", () => {
    const numbers = [...readme.matchAll(/^\| (\d+) \| `supabase_/gm)].map((m) => Number(m[1]));
    expect(numbers).toEqual(numbers.map((_, i) => i));
  });
});
