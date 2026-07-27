import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import fs from "node:fs/promises";

const require = createRequire("C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\");
const { chromium } = require("playwright");
const sf = "C:\\Program Files\\sf\\bin\\sf.cmd";
const cwd = "C:\\Users\\ChristopherLowman\\Documents\\Codex\\2026-05-11\\what-all-are-you-able-to-2\\salesforce-work";
const reportId = "00OQi000000wTsrMAE";
const org = JSON.parse(execFileSync("cmd.exe", ["/c", sf, "org", "display", "--target-org", "my-org", "--verbose", "--json"], { cwd, encoding: "utf8" })).result;
const browser = await chromium.launch({
  headless: true,
  executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
});
const context = await browser.newContext({ acceptDownloads: true });
const page = await context.newPage();
const reportUrl = `${org.instanceUrl}/lightning/r/Report/${reportId}/view`;
const frontdoor = `${org.instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(org.accessToken)}&retURL=${encodeURIComponent(`/lightning/r/Report/${reportId}/view`)}`;
await page.goto(frontdoor, { waitUntil: "domcontentloaded", timeout: 60000 });
await page.waitForTimeout(10000);
await page.goto(reportUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(25000);
const title = await page.title();
const url = page.url();
const buttons = await page.locator("button, a").evaluateAll((nodes) => nodes.slice(0, 200).map((node) => ({
  text: (node.innerText || node.textContent || "").trim(),
  title: node.getAttribute("title"),
  aria: node.getAttribute("aria-label"),
  href: node.getAttribute("href"),
})));
await page.screenshot({ path: "salesforce-report-ui.png", fullPage: true });
await fs.writeFile("salesforce-report-ui.json", JSON.stringify({ title, url, buttons }, null, 2));
console.log(JSON.stringify({ title, url, buttons: buttons.filter((b) => `${b.text} ${b.title} ${b.aria}`.match(/export|download|more|action|run/i)).slice(0, 50) }, null, 2));
await browser.close();
