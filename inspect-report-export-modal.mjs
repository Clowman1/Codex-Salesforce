import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";

const require = createRequire("C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\");
const { chromium } = require("playwright");

const sf = "C:\\Program Files\\sf\\bin\\sf.cmd";
const cwd = "C:\\Users\\ChristopherLowman\\Documents\\Codex\\2026-05-11\\what-all-are-you-able-to-2\\salesforce-work";
const reportId = "00OQi000000wTsrMAE";
const org = JSON.parse(execFileSync("cmd.exe", ["/c", sf, "org", "display", "--target-org", "my-org", "--verbose", "--json"], { cwd, encoding: "utf8" })).result;
const browser = await chromium.launch({ headless: true, executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" });
const context = await browser.newContext({ acceptDownloads: true, viewport: { width: 1280, height: 720 } });
const page = await context.newPage();
const frontdoor = `${org.instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(org.accessToken)}&retURL=${encodeURIComponent(`/lightning/r/Report/${reportId}/view`)}`;
await page.goto(frontdoor, { waitUntil: "domcontentloaded", timeout: 60000 });
await page.waitForTimeout(35000);
await page.mouse.click(1226, 141);
await page.waitForTimeout(1000);
await page.mouse.click(1152, 282);
await page.waitForTimeout(3000);
await page.screenshot({ path: "salesforce-report-export-modal.png", fullPage: true });
const items = await page.locator("button, a, input, label, span, select, option").evaluateAll((nodes) => nodes.map((node) => ({
  text: (node.innerText || node.textContent || "").trim(),
  title: node.getAttribute("title"),
  aria: node.getAttribute("aria-label"),
  role: node.getAttribute("role"),
  type: node.getAttribute("type"),
  value: node.getAttribute("value"),
  checked: node.checked,
  tag: node.tagName,
})).filter((item) => `${item.text} ${item.title} ${item.aria} ${item.value}`.match(/export|format|xlsx|xls|csv|details|formatted|cancel|encoding|excel/i)));
console.log(JSON.stringify(items, null, 2));
await browser.close();
