const { chromium } = require('playwright'); const fs=require('fs');
const root=process.argv[2];
const sp=JSON.parse(fs.readFileSync(root+'/data/spirits.json','utf8'));
const elk={wind:'바람',fire:'불',grass:'풀',water:'물'}, elc={wind:'#bfe9f3',fire:'#f0643c',grass:'#93d35a',water:'#6fb3ff'};
const groups={wind:[],fire:[],grass:[],water:[]};
for (const [k,v] of Object.entries(sp)) groups[v.element].push([k,v]);
const b64=f=>'data:image/png;base64,'+fs.readFileSync(f).toString('base64');
let html=`<html><head><style>body{margin:0;background:#1c2030;color:#fff;font-family:'Noto Sans CJK KR',sans-serif;padding:28px}
h1{color:#ffd973;font-size:34px;margin:0 0 4px}p{color:#9aa3b5;margin:0 0 18px;font-size:18px}
.row{display:flex;gap:12px;margin-bottom:14px;align-items:flex-end}.lab{width:70px;font-size:22px;font-weight:700}
.c{background:#262b3e;border-radius:12px;padding:8px;width:120px;text-align:center}
img{width:96px;height:96px;image-rendering:pixelated}.n{font-size:16px}.s{font-size:12px;color:#9aa3b5}</style></head><body>
<h1>전투용 도트 스프라이트 v1</h1><p>정령 20종 + 정령사 4종 · 32×32 원본 (전투에서 60px로 표시)</p>`;
for (const el of ['wind','fire','grass','water']) {
  html+=`<div class="row"><div class="lab" style="color:${elc[el]}">${elk[el]}</div>`;
  for (const [k,v] of groups[el]) html+=`<div class="c"><img src="${b64(root+'/assets/sprites/spirits/'+k+'.png')}"><div class="n">${v.name}</div><div class="s">${v.guardian?'수호 정령':(v.wild?'1단계':'진화')}</div></div>`;
  html+=`<div class="c"><img src="${b64(root+'/assets/sprites/summoner_'+el+'.png')}"><div class="n">정령사</div><div class="s">${elk[el]}</div></div></div>`;
}
html+='</body></html>';
(async()=>{const br=await chromium.launch();const pg=await br.newPage({viewport:{width:1000,height:700}});
await pg.setContent(html);await pg.screenshot({path:root+'/art/sprites_sheet.png',fullPage:true});await br.close();console.log('ok')})();
