const { chromium } = require('playwright');
const fs = require('fs');
const dir = process.argv[2];
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: 1 });
  for (const n of ['breezebird', 'emberbean', 'sprout', 'dewdrop']) {
    const svg = fs.readFileSync(`${dir}/sd_${n}.svg`, 'utf8');
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
    await page.locator('svg').screenshot({ path: `${dir}/sd_${n}.png`, omitBackground: true });
  }
  await browser.close();
  console.log('rendered');
})();
