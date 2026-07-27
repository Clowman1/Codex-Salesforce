import fs from "node:fs";
import path from "node:path";
import { BrowserPipeClient } from "./trainual-review/chrome-pipe-client.mjs";

const workspace = "C:\\Users\\ChristopherLowman\\Documents\\New project";
const sourceDir = path.join(workspace, "trainual-review", "doc-updates");

let updates = [
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
    name: "Condo & Property Intelligence",
    stepUrl: "https://app.trainual.com/8db2c10b-3bb3-4a6f-816f-439f7c14246f/steps/21392990/editor",
    file: "08-condo-property-intelligence.txt",
  },
].map((item) => ({
  ...item,
  content: fs.readFileSync(path.join(sourceDir, item.file), "utf8"),
}));

const singleArg = process.argv.slice(2).join(" ").trim().toLowerCase();
if (singleArg) {
  updates = updates.filter((item) =>
    item.name.toLowerCase().includes(singleArg) ||
    item.file.toLowerCase().includes(singleArg) ||
    item.stepUrl.includes(singleArg)
  );
  if (updates.length !== 1) {
    throw new Error(`Single-step argument matched ${updates.length} updates: ${singleArg}`);
  }
}

const client = new BrowserPipeClient();
let activeTabId = null;

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function cdp(tabId, method, commandParams = {}, timeoutMs = 30000) {
  try {
    return await client.request("executeCdp", {
      target: { tabId },
      method,
      commandParams,
      timeoutMs,
    }, timeoutMs + 5000);
  } catch (error) {
    if (!String(error.message || "").includes("Debugger is not attached")) throw error;
    await client.request("attach", { tabId });
    await client.request("executeCdp", {
      target: { tabId },
      method: "Page.enable",
      commandParams: {},
      timeoutMs: 10000,
    }, 15000).catch(() => null);
    await client.request("executeCdp", {
      target: { tabId },
      method: "Runtime.enable",
      commandParams: {},
      timeoutMs: 10000,
    }, 15000).catch(() => null);
    return await client.request("executeCdp", {
      target: { tabId },
      method,
      commandParams,
      timeoutMs,
    }, timeoutMs + 5000);
  }
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

async function getEditorState(tabId) {
  return await evaluate(tabId, `(() => {
    const editables = Array.from(document.querySelectorAll('[contenteditable="true"]'));
    return {
      href: location.href,
      title: document.title,
      editableCount: editables.length,
      editorText: editables.length === 1 ? editables[0].innerText : "",
      bodyText: document.body?.innerText?.slice(0, 4000) || "",
    };
  })()`);
}

async function waitForEditor(tabId, item) {
  for (let attempt = 1; attempt <= 90; attempt++) {
    const state = await getEditorState(tabId);
    if (state.editableCount === 1) return state;
    if (state.href.includes("sign_in") || state.href.includes("login")) {
      console.log(`Still on Trainual sign-in for "${item.name}"...`);
    }
    await wait(1000);
  }
  throw new Error(`No single editor found for ${item.name}`);
}

async function navigateTo(tabId, item) {
  await cdp(tabId, "Page.navigate", { url: item.stepUrl }, 60000);
  await wait(5000);
  activeTabId = tabId;
  const state = await waitForEditor(tabId, item);
  if (!state.editorText.includes(item.name)) {
    throw new Error(`Preflight failed for ${item.name}; editor did not contain expected title. URL: ${state.href}`);
  }
  return state;
}

async function replaceEditorText(tabId, text) {
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
  if (!selected) throw new Error("Unable to focus/select Trainual editor");
  await cdp(tabId, "Input.insertText", { text }, 120000);
  await wait(3500);
}

async function waitForSaved(tabId) {
  for (let attempt = 1; attempt <= 120; attempt++) {
    const saved = await evaluate(tabId, `document.body?.innerText?.includes("Saved") || false`);
    if (saved) return true;
    await wait(1000);
  }
  return false;
}

async function createControlledTab() {
  const created = await client.request("createTab", {});
  const tabId = Number(created.id ?? created.tabId ?? created.tab_id);
  activeTabId = tabId;
  await client.request("attach", { tabId });
  await cdp(tabId, "Page.enable", {});
  await cdp(tabId, "Runtime.enable", {});
  await cdp(tabId, "Input.setIgnoreInputEvents", { ignore: false }).catch(() => null);
  return tabId;
}

async function finalizeControlledTabs() {
  await client.request("finalizeTabs", { keep: [] }).catch(() => null);
}

try {
  if (singleArg) {
    const item = updates[0];
    console.log(`Updating one Trainual step: ${item.name}`);
    const tabId = await createControlledTab();
    try {
      await navigateTo(tabId, item);
      await replaceEditorText(tabId, item.content);
      const savedVisible = await waitForSaved(tabId);
      const state = await getEditorState(tabId);
      const result = {
        name: item.name,
        chars: item.content.length,
        url: state.href,
        hasTitle: state.editorText.slice(0, 500).includes(item.name),
        hasSourceHistory: state.editorText.includes("Source History"),
        hasNewSource: state.editorText.includes("2026-05-27") && state.editorText.includes("Byronte's Basics 5.27.26"),
        savedVisible,
      };
      result.ok = result.hasTitle && result.hasSourceHistory && result.hasNewSource && result.savedVisible;
      console.log("TRAINUAL_UPDATE_RESULTS_START");
      console.log(JSON.stringify([result], null, 2));
      console.log("TRAINUAL_UPDATE_RESULTS_END");
      if (!result.ok) throw new Error(`Verification failed for ${item.name}`);
    } finally {
      await finalizeControlledTabs();
    }
    process.exit(0);
  }

  console.log("Using new controlled Trainual tabs");
  console.log("Preflighting Trainual editors...");
  for (const item of updates) {
    const tabId = await createControlledTab();
    try {
      await navigateTo(tabId, item);
      console.log(`Preflight OK: ${item.name}`);
    } finally {
      await finalizeControlledTabs();
    }
  }

  const results = [];
  for (const item of updates) {
    console.log(`Updating: ${item.name}`);
    const tabId = await createControlledTab();
    try {
      await navigateTo(tabId, item);
      await replaceEditorText(tabId, item.content);
      const savedVisible = await waitForSaved(tabId);
      const state = await getEditorState(tabId);
      const result = {
        name: item.name,
        chars: item.content.length,
        url: state.href,
        hasTitle: state.editorText.slice(0, 500).includes(item.name),
        hasSourceHistory: state.editorText.includes("Source History"),
        hasNewSource: state.editorText.includes("2026-05-27") && state.editorText.includes("Byronte's Basics 5.27.26"),
        savedVisible,
      };
      result.ok = result.hasTitle && result.hasSourceHistory && result.hasNewSource && result.savedVisible;
      console.log(JSON.stringify(result));
      if (!result.ok) throw new Error(`Verification failed for ${item.name}`);
      results.push(result);
    } finally {
      await finalizeControlledTabs();
    }
  }

  console.log("TRAINUAL_UPDATE_RESULTS_START");
  console.log(JSON.stringify(results, null, 2));
  console.log("TRAINUAL_UPDATE_RESULTS_END");
} finally {
  await client.close();
}
