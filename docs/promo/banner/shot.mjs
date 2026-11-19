import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
let pw; try { pw = require("playwright"); } catch { pw = require("/opt/node22/lib/node_modules/playwright"); }
const b = await pw.chromium.launch();
const p = await b.newPage({ viewport: { width: 2560, height: 1440 }, deviceScaleFactor: 1 });
await p.goto("file://" + process.argv[2]); await p.evaluate(() => document.fonts.ready);
await p.screenshot({ path: process.argv[3] }); await b.close();
