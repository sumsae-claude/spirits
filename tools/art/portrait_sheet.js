const { chromium } = require('playwright'); const fs = require('fs');
const root = process.argv[2];
const sp = JSON.parse(fs.readFileSync(root + '/data/spirits.json', 'utf8'));
const elk = { wind: '바람', fire: '불', grass: '풀', water: '물' }, elc = { wind: '#bfe9f3', fire: '#f0643c', grass: '#93d35a', water: '#6fb3ff' };
const b64 = f => 'data:image/png;base64,' + fs.readFileSync(f).toString('base64');
let html = `<html><head><style>body{margin:0;background:#1c2030;color:#fff;font-family:'Noto Sans CJK KR',sans-serif;padding:24px}
h1{color:#ffd973;font-size:32px;margin:0 0 14px}.row{display:flex;gap:10px;margin-bottom:12px;align-items:center}.lab{width:56px;font-size:22px;font-weight:700}
.c{background:#262b3e;border-radius:12px;padding:6px;width:140px;text-align:center}img{width:130px;height:130px}.n{font-size:16px}</style></head><body><h1>2D SD 초상화 (정령 20종 + 정령사 4종)</h1>`;
for (const el of ['wind', 'fire', 'grass', 'water']) {
  html += `<div class="row"><div class="lab" style="color:${elc[el]}">${elk[el]}</div>`;
  for (const [k, v] of Object.entries(sp)) if (v.element === el) html += `<div class="c"><img src="${b64(root + '/assets/portraits/' + k + '.png')}"><div class="n">${v.name}</div></div>`;
  html += `<div class="c"><img src="${b64(root + '/assets/portraits/summoner_' + el + '.png')}"><div class="n">정령사</div></div></div>`;
}
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1100, height: 700 } });
  await p.setContent(html + '</body></html>'); await p.screenshot({ path: root + '/art/portraits_sheet.png', fullPage: true }); await b.close(); console.log('ok'); })();
