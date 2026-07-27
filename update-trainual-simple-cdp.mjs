import fs from "node:fs";
import path from "node:path";
import { BrowserPipeClient } from "./trainual-review/chrome-pipe-client.mjs";

const workspace = "C:\\Users\\ChristopherLowman\\Documents\\New project";
const sourceDir = path.join(workspace, "trainual-review", "doc-updates");

const items = [
  {
    key: "loan",
    name: "Loan Structuring Intelligence",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392986/editor",
    file: "07-loan-structuring-intelligence.txt",
  },
  {
    key: "condo",
    name: "Condo & Property Intelligence",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392990/editor",
    file: "08-condo-property-intelligence.txt",
  },
];

const key = (process.argv[2] || "").toLowerCase();
const item = items.find((candidate) => candidate.key === key || candidate.name.toLowerCase().includes(key));
if (!item) throw new Error(`Unknown item key: ${key}`);
item.content = fs.readFileSync(path.join(sourceDir, item.file), "utf8");

const client = new BrowserPipeClient();

async function wait(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function cdp(tabId, method, commandParams = {}, timeoutMs = 30000) {
  return await client.request("executeCdp", {
    target: { tabId },
    method,
    commandParams,
    timeoutMs,
  }, timeoutMs + 5000);
}

async function evaluate(tabId, expression, timeoutMs = 30000) {
  const result = await cdp(tabId, "Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  }, timeoutMs);
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text || "Runtime.evaluate failed");
  return result.result?.value;
}

try {
  const created = await client.request("createTab", {});
  const tabId = Number(created.id);
  await client.request("attach", { tabId });
  await cdp(tabId, "Page.enable", {});
  await cdp(tabId, "Runtime.enable", {});
  await cdp(tabId, "Page.navigate", { url: item.stepUrl }, 60000);
  let before = null;
  for (let attempt = 0; attempt < 60; attempt++) {
    await wait(1000);
    before = await evaluate(tabId, `(() => {
      const el = document.querySelector('[contenteditable="true"]');
      return { href: location.href, title: document.title, text: el?.innerText || "", editorCount: document.querySelectorAll('[contenteditable="true"]').length, bodyText: document.body?.innerText?.slice(0, 800) || "" };
    })()`);
    if (before.editorCount === 1 && before.text.includes(item.name)) break;
  }
  if (!before.text.includes(item.name)) {
    throw new Error(`Preflight failed: ${JSON.stringify({ item: item.name, before: { ...before, text: before.text.slice(0, 500) } })}`);
  }

  const selected = await evaluate(tabId, `(() => {
    const el = document.querySelector('[contenteditable="true"]');
    if (!el) return false;
    el.focus();
    const range = document.createRange();
    range.selectNodeContents(el);
    const selection = getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    return true;
  })()`);
  if (!selected) throw new Error("Could not select editor");
  await cdp(tabId, "Input.insertText", { text: item.content }, 120000);
  await wait(5000);

  let savedVisible = false;
  for (let attempt = 0; attempt < 90; attempt++) {
    savedVisible = await evaluate(tabId, `document.body?.innerText?.includes("Saved") || false`);
    if (savedVisible) break;
    await wait(1000);
  }
  const after = await evaluate(tabId, `(() => {
    const el = document.querySelector('[contenteditable="true"]');
    return { href: location.href, title: document.title, text: el?.innerText || "" };
  })()`);
  const result = {
    name: item.name,
    chars: item.content.length,
    url: after.href,
    hasTitle: after.text.slice(0, 500).includes(item.name),
    hasSourceHistory: after.text.includes("Source History"),
    hasNewSource: after.text.includes("2026-05-27") && after.text.includes("Byronte's Basics 5.27.26"),
    savedVisible,
  };
  result.ok = result.hasTitle && result.hasSourceHistory && result.hasNewSource && result.savedVisible;
  console.log("TRAINUAL_UPDATE_RESULTS_START");
  console.log(JSON.stringify([result], null, 2));
  console.log("TRAINUAL_UPDATE_RESULTS_END");
  if (!result.ok) throw new Error(`Verification failed for ${item.name}`);
  await client.request("finalizeTabs", { keep: [] }).catch(() => null);
} finally {
  await client.close();
}
