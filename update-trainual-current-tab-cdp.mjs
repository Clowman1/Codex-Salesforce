import fs from "node:fs";
import path from "node:path";
import { BrowserPipeClient } from "./trainual-review/chrome-pipe-client.mjs";

const workspace = "C:\\Users\\ChristopherLowman\\Documents\\New project";
const sourceDir = path.join(workspace, "trainual-review", "doc-updates");

const updates = [
  {
    name: "Loan Structuring Intelligence",
    urlPart: "/steps/21392986/editor",
    file: "07-loan-structuring-intelligence.txt",
  },
  {
    name: "Condo & Property Intelligence",
    urlPart: "/steps/21392990/editor",
    file: "08-condo-property-intelligence.txt",
  },
].map((item) => ({
  ...item,
  content: fs.readFileSync(path.join(sourceDir, item.file), "utf8"),
}));

const match = process.argv.slice(2).join(" ").trim().toLowerCase();
const item = updates.find((candidate) =>
  candidate.name.toLowerCase().includes(match) ||
  candidate.file.toLowerCase().includes(match) ||
  candidate.urlPart.includes(match)
);
if (!item) throw new Error(`No matching update for ${match}`);

const client = new BrowserPipeClient();

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.text || result.exceptionDetails.exception?.description || "Runtime.evaluate failed");
  }
  return result.result?.value;
}

async function state(tabId) {
  return await evaluate(tabId, `(() => {
    const el = document.querySelector('[contenteditable="true"]');
    return {
      href: location.href,
      title: document.title,
      editorText: el?.innerText || "",
      bodyText: document.body?.innerText || "",
    };
  })()`);
}

try {
  const tabs = await client.request("getTabs", {});
  const tab = tabs.find((candidate) => (candidate.url || "").includes(item.urlPart));
  if (!tab) throw new Error(`No controlled tab found for ${item.name}`);
  const tabId = Number(tab.id);
  await client.request("attach", { tabId });
  await cdp(tabId, "Page.enable", {}).catch(() => null);
  await cdp(tabId, "Runtime.enable", {}).catch(() => null);
  await wait(1000);

  const before = await state(tabId);
  if (!before.href.includes(item.urlPart) || !before.editorText.includes(item.name)) {
    throw new Error(`Tab preflight failed for ${item.name}: ${JSON.stringify({ href: before.href, title: before.title, textStart: before.editorText.slice(0, 200) })}`);
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
  await wait(3500);

  let savedVisible = false;
  for (let attempt = 0; attempt < 90; attempt++) {
    savedVisible = await evaluate(tabId, `document.body?.innerText?.includes("Saved") || false`);
    if (savedVisible) break;
    await wait(1000);
  }

  const after = await state(tabId);
  const result = {
    name: item.name,
    chars: item.content.length,
    url: after.href,
    hasTitle: after.editorText.slice(0, 500).includes(item.name),
    hasSourceHistory: after.editorText.includes("Source History"),
    hasNewSource: after.editorText.includes("2026-05-27") && after.editorText.includes("Byronte's Basics 5.27.26"),
    savedVisible,
  };
  result.ok = result.hasTitle && result.hasSourceHistory && result.hasNewSource && result.savedVisible;
  console.log("TRAINUAL_UPDATE_RESULTS_START");
  console.log(JSON.stringify([result], null, 2));
  console.log("TRAINUAL_UPDATE_RESULTS_END");
  if (!result.ok) throw new Error(`Verification failed for ${item.name}`);
} finally {
  await client.close();
}
