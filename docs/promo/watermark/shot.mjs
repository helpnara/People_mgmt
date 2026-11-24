// 워터마크 후보 찍기 — node shot.mjs → wm-a.png … wm-e.png (600×600, 투명 바탕)
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const here = path.dirname(fileURLToPath(import.meta.url));
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 600, height: 3000 } });
await p.goto(pathToFileURL(path.join(here, "watermark.html")).href);
await p.evaluate(() => document.fonts.ready);
for (const id of ["a", "b", "c", "d", "e"]) {
  await p.locator("#" + id).screenshot({ path: path.join(here, `wm-${id}.png`), omitBackground: true });
}
await b.close();
