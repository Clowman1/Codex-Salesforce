import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire("C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\");
const { chromium } = require("playwright");

const workspace = "C:\\Users\\ChristopherLowman\\Documents\\New project";
const sourceDir = path.join(workspace, "trainual-review", "doc-updates");
const profileDir = path.join(workspace, ".trainual-playwright-profile");

const updates = [
  {
    name: "Latest Byronte Updates",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21404370/editor",
    file: "01-latest-byronte-updates.txt",
  },
  {
    name: "AUS Discipline & Findings Management",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392979/editor",
    file: "02-aus-discipline-findings-management.txt",
  },
  {
    name: "Income Calculation & Trending Rules",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392981/editor",
    file: "03-income-calculation-trending-rules.txt",
  },
  {
    name: "Credit & Non-Traditional Credit",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392984/editor",
    file: "05-credit-non-traditional-credit.txt",
  },
  {
    name: "Loan Structuring Intelligence",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392986/editor",
    file: "07-loan-structuring-intelligence.txt",
  },
  {
    name: "Non-QM & Specialty Products",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392996/editor",
    file: "11-non-qm-specialty-products.txt",
  },
].map((item) => ({
  ...item,
  content: fs.readFileSync(path.join(sourceDir, item.file), "utf8"),
}));

async function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForEditor(page, item) {
  for (let attempt = 1; attempt <= 60; attempt++) {
    const editable = page.locator('[contenteditable="true"]');
    if ((await editable.count().catch(() => 0)) === 1) return editable;

    const url = page.url();
    if (url.includes("/accounts/") || url.includes("login") || url.includes("sign_in")) {
      console.log(`Waiting for Trainual login before updating "${item.name}"...`);
      await wait(10000);
      await page.goto(item.stepUrl, { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => null);
      continue;
    }

    await wait(1000);
  }
  throw new Error(`No single Trainual editor found for ${item.name} at ${page.url()}`);
}

async function updateDoc(page, item) {
  console.log(`Opening: ${item.name}`);
  await page.goto(item.stepUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => null);

  const editable = await waitForEditor(page, item);
  await editable.click({ timeout: 15000 });
  await page.keyboard.press("Control+A");
  await page.keyboard.insertText(item.content);
  await wait(3500);

  const saved = page.getByText("Saved", { exact: true });
  await saved.waitFor({ state: "visible", timeout: 120000 }).catch(() => null);

  const text = await editable.innerText({ timeout: 15000 });
  const result = {
    name: item.name,
    chars: item.content.length,
    url: page.url(),
    hasTitle: text.slice(0, 500).includes(item.name),
    hasSourceHistory: text.includes("Source History"),
    hasNewSource: text.includes("2026-05-13") && text.includes("Byronte's Basics 5.13.26"),
    savedVisible: await saved.count().catch(() => 0),
  };
  result.ok = result.hasTitle && result.hasSourceHistory && result.hasNewSource && result.savedVisible > 0;
  console.log(JSON.stringify(result));
  if (!result.ok) throw new Error(`Verification failed for ${item.name}`);
  return result;
}

const context = await chromium.launchPersistentContext(profileDir, {
  headless: false,
  executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  acceptDownloads: true,
  viewport: { width: 1365, height: 900 },
});

const page = context.pages()[0] ?? await context.newPage();
const results = [];
try {
  for (const item of updates) {
    results.push(await updateDoc(page, item));
  }
  console.log("TRAINUAL_UPDATE_RESULTS_START");
  console.log(JSON.stringify(results, null, 2));
  console.log("TRAINUAL_UPDATE_RESULTS_END");
} finally {
  await context.close();
}
