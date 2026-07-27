import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import path from "node:path";

const require = createRequire("C:\\Users\\ChristopherLowman\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules\\");
const { chromium } = require("playwright");

const sf = "C:\\Program Files\\sf\\bin\\sf.cmd";
const cwd = "C:\\Users\\ChristopherLowman\\Documents\\Codex\\2026-05-11\\what-all-are-you-able-to-2\\salesforce-work";
const outputDir = "C:\\Users\\ChristopherLowman\\Desktop\\Nickley Reports";
const reports = [
  ["Contracts From Nickley (This Month)", "00OQi000000wTsrMAE", "Contracts From Nickley (This Month).xlsx"],
  ["Nickley Leads This Month", "00OQi000004m3u9MAA", "Nickley Leads This Month.xlsx"],
  ["Nickley Realtor Lookback Last Week", "00OQi000002w0CzMAI", "Nickley Realtor Lookback Last Week.xlsx"],
  ["Nickley Pre-Approvals This Month", "00OQi000005ZLrVMAW", "Nickley Pre-Approvals This Month.xlsx"],
];

const org = JSON.parse(execFileSync("cmd.exe", ["/c", sf, "org", "display", "--target-org", "my-org", "--verbose", "--json"], { cwd, encoding: "utf8" })).result;
const browser = await chromium.launch({
  headless: true,
  executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
});
const context = await browser.newContext({ acceptDownloads: true, viewport: { width: 1280, height: 720 } });
const page = await context.newPage();

const results = [];
for (const [name, reportId, fileName] of reports) {
  const retUrl = `/lightning/r/Report/${reportId}/view`;
  const frontdoor = `${org.instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(org.accessToken)}&retURL=${encodeURIComponent(retUrl)}`;
  await page.goto(frontdoor, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForTimeout(35000);

  await page.mouse.click(1226, 141);
  await page.waitForTimeout(1000);
  await page.mouse.click(1152, 282);
  await page.waitForTimeout(3000);

  const exportButton = page.locator('button[title="Export"]');
  await exportButton.waitFor({ state: "visible", timeout: 30000 });
  const [download] = await Promise.all([
    page.waitForEvent("download", { timeout: 120000 }),
    exportButton.click(),
  ]);
  const outputPath = path.join(outputDir, fileName);
  await download.saveAs(outputPath);
  results.push({ name, path: outputPath, suggestedFilename: download.suggestedFilename() });
}

await browser.close();
console.log(JSON.stringify(results, null, 2));
