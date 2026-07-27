import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);
const Module = require("node:module");
process.env.NODE_PATH = [
  "C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules",
  "C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\.pnpm\\playwright-core@1.60.0\\node_modules",
  process.env.NODE_PATH || "",
].filter(Boolean).join(path.delimiter);
Module._initPaths();
const { chromium } = require("playwright");

const profileDir = "C:\\Users\\ChristopherLowman\\Documents\\New project\\.trainual-playwright-profile";
const stepUrl = process.argv[2];

if (!stepUrl) {
  console.error("Usage: node inspect-trainual-step.mjs <step-editor-url>");
  process.exit(2);
}

const context = await chromium.launchPersistentContext(profileDir, {
  headless: false,
  executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  viewport: { width: 1365, height: 900 },
});

const page = context.pages()[0] ?? await context.newPage();

try {
  await page.goto(stepUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => null);
  const editable = page.locator('[contenteditable="true"]');
  const count = await editable.count().catch(() => 0);
  const text = count === 1 ? await editable.innerText({ timeout: 15000 }) : "";
  console.log(JSON.stringify({
    url: page.url(),
    title: await page.title(),
    editableCount: count,
    textStart: text.slice(0, 500),
  }, null, 2));
} finally {
  await context.close();
}
