// art/portraits_src/*.svg → assets/portraits/*.png (512px)
const { chromium } = require('playwright'); const fs = require('fs');
const [src, dst] = [process.argv[2], process.argv[3]];
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 512, height: 512 } });
  for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg'))) {
    await p.setContent(`<html><body style="margin:0;background:transparent">${fs.readFileSync(src + '/' + f, 'utf8')}</body></html>`);
    await p.locator('svg').screenshot({ path: `${dst}/${f.replace('.svg', '.png')}`, omitBackground: true });
  }
  await b.close(); console.log('rendered');
})();
