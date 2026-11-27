const { chromium } = require('playwright');
const dir = process.argv[2];
const spirits = [
  ['breezebird', '산들새', '바람', '#bfe9f3'], ['emberbean', '불씨콩', '불', '#f0643c'],
  ['sprout', '새싹이', '풀', '#93d35a'], ['dewdrop', '물방울이', '물', '#6fb3ff'],
];
const cell = (img, name, el, col, pixel) => `
  <div class="cell"><img src="data:image/png;base64,${require("fs").readFileSync(dir + "/" + img).toString("base64")}" class="${pixel ? 'px' : ''}">
  <div class="nm">${name}</div><div class="el" style="color:${col}">${el} 속성</div></div>`;
const html = `<html><head><style>
 body{margin:0;background:#1c2030;color:#fff;font-family:'Noto Sans CJK KR','Noto Sans KR',sans-serif;padding:36px}
 h1{font-size:40px;margin:0 0 6px;color:#ffd973} p{color:#9aa3b5;margin:0 0 26px;font-size:20px}
 h2{font-size:28px;margin:26px 0 12px} .row{display:flex;gap:22px}
 .cell{background:#262b3e;border-radius:18px;padding:18px;width:260px;text-align:center}
 img{width:240px;height:240px} .px{image-rendering:pixelated}
 .nm{font-size:26px;font-weight:700;margin-top:6px} .el{font-size:19px}
 .note{color:#c9cfdc;font-size:19px;margin-top:10px}
</style></head><body>
 <h1>정령계약자 · 대표 정령 시안</h1>
 <p>속성별 첫 정령 4종 — A안 도트 / B안 2D SD 일러스트 (시안이므로 최종 아트가 아님)</p>
 <h2>A안 · 도트 (32×32 원본, 확대 표시)</h2>
 <div class="row">${spirits.map(s => cell(`pixel_${s[0]}.png`, s[1], s[2], s[3], true)).join('')}</div>
 <div class="note">전투 맵·월드맵용. 다수의 정령을 적은 비용으로 일관되게 제작 가능, 레트로 감성.</div>
 <h2>B안 · 2D SD 일러스트</h2>
 <div class="row">${spirits.map(s => cell(`sd_${s[0]}.png`, s[1], s[2], s[3], false)).join('')}</div>
 <div class="note">도감 카드·대화 초상화·스토어 이미지용. 눈에 잘 띄지만 제작 비용이 큼 → 추천: 전투는 A안, 도감/연출은 B안 혼합.</div>
</body></html>`;
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1250, height: 900 }, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'load' });
  await page.screenshot({ path: `${dir}/concept_sheet.png`, fullPage: true });
  await browser.close();
  console.log('sheet done');
})();
