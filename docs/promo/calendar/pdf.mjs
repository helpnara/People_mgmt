// shorts-calendar.html → shorts-calendar.pdf (A4 가로) · 미리 보기 PNG 는 --png
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const require = createRequire(import.meta.url);
let pw; try { pw = require("playwright"); } catch { pw = require("/opt/node22/lib/node_modules/playwright"); }
const here = path.dirname(fileURLToPath(import.meta.url));
const b = await pw.chromium.launch();
const p = await b.newPage({ viewport: { width: 1123, height: 794 }, deviceScaleFactor: 2 });
await p.goto(pathToFileURL(path.join(here, "shorts-calendar.html")).href);
await p.evaluate(() => document.fonts.ready);
await p.pdf({ path: path.join(here, "shorts-calendar.pdf"), width: "297mm", height: "210mm", printBackground: true, preferCSSPageSize: true });
if (process.argv.includes("--png")) {
  const pages = await p.$$("section.page");
  for (let i = 0; i < pages.length; i++) await pages[i].screenshot({ path: path.join(process.argv[process.argv.indexOf("--png") + 1], `page-${i + 1}.png`) });
}
await b.close();
console.log("PDF:", path.join(here, "shorts-calendar.pdf"));
