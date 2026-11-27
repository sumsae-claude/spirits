import sys
OUT = sys.argv[1]
# 공통: 큰 눈 + 하이라이트 + 볼터치 + 입
def eyes(cx, cy, gap=58, r=30):
    s = ""
    for x in (cx - gap, cx + gap):
        s += f'<ellipse cx="{x}" cy="{cy}" rx="{r*0.8}" ry="{r}" fill="#2a1f33"/>'
        s += f'<ellipse cx="{x-8}" cy="{cy-12}" rx="{r*0.3}" ry="{r*0.34}" fill="#fff"/>'
        s += f'<circle cx="{x+9}" cy="{cy+12}" r="{r*0.14}" fill="#fff" opacity="0.85"/>'
    return s
def blush(cx, cy, gap=96):
    return "".join(f'<ellipse cx="{x}" cy="{cy}" rx="26" ry="14" fill="#ff8fa3" opacity="0.55"/>' for x in (cx-gap, cx+gap))
def mouth(cx, cy):
    return f'<path d="M{cx-14},{cy} Q{cx-7},{cy+12} {cx},{cy} Q{cx+7},{cy+12} {cx+14},{cy}" stroke="#2a1f33" stroke-width="6" fill="none" stroke-linecap="round"/>'
def shadow():
    return '<ellipse cx="256" cy="468" rx="150" ry="22" fill="#000" opacity="0.18"/>'
def wrap(defs, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>{defs}</defs>{shadow()}{body}</svg>'

ember = wrap('''
<radialGradient id="b" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#ffb08a"/><stop offset="0.55" stop-color="#f0643c"/><stop offset="1" stop-color="#c2412a"/></radialGradient>
<linearGradient id="f" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#ff7a1a"/><stop offset="0.6" stop-color="#ffb02e"/><stop offset="1" stop-color="#ffe680"/></linearGradient>''',
'''<path d="M256,40 C300,90 330,120 318,170 C312,195 290,210 256,212 C222,210 200,195 194,170 C182,120 222,95 256,40Z" fill="url(#f)" stroke="#8a3a1c" stroke-width="7"/>
<path d="M256,95 C276,125 286,150 276,175 C270,188 242,188 236,175 C228,150 240,125 256,95Z" fill="#fff4b0"/>
<ellipse cx="256" cy="330" rx="150" ry="140" fill="url(#b)" stroke="#7a2a1c" stroke-width="8"/>
<ellipse cx="196" cy="452" rx="34" ry="18" fill="#c2412a" stroke="#7a2a1c" stroke-width="6"/><ellipse cx="316" cy="452" rx="34" ry="18" fill="#c2412a" stroke="#7a2a1c" stroke-width="6"/>
<ellipse cx="200" cy="262" rx="46" ry="26" fill="#fff" opacity="0.35" transform="rotate(-25 200 262)"/>''' + eyes(256, 320) + blush(256, 360) + mouth(256, 372))

drop = wrap('''
<radialGradient id="w" cx="38%" cy="40%" r="75%"><stop offset="0" stop-color="#d9efff"/><stop offset="0.45" stop-color="#6fb3ff"/><stop offset="1" stop-color="#2f6fd8"/></radialGradient>''',
'''<path d="M256,40 C300,120 400,210 400,320 C400,405 336,462 256,462 C176,462 112,405 112,320 C112,210 212,120 256,40Z" fill="url(#w)" stroke="#1f4c9e" stroke-width="8" opacity="0.97"/>
<path d="M200,170 C180,210 170,240 168,280" stroke="#fff" stroke-width="18" stroke-linecap="round" opacity="0.6" fill="none"/>
<circle cx="214" cy="140" r="10" fill="#fff" opacity="0.7"/>
<circle cx="84" cy="150" r="16" fill="none" stroke="#9fd0ff" stroke-width="6"/><circle cx="430" cy="190" r="12" fill="none" stroke="#9fd0ff" stroke-width="5"/><circle cx="420" cy="100" r="8" fill="none" stroke="#9fd0ff" stroke-width="4"/>''' + eyes(256, 330, 56) + blush(256, 372, 92) + mouth(256, 384))

sprout = wrap('''
<radialGradient id="g" cx="40%" cy="35%" r="72%"><stop offset="0" stop-color="#e6f7a8"/><stop offset="0.5" stop-color="#93d35a"/><stop offset="1" stop-color="#5a9c34"/></radialGradient>
<linearGradient id="l" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8be07a"/><stop offset="1" stop-color="#3fa84a"/></linearGradient>''',
'''<path d="M256,200 C254,160 258,130 262,105" stroke="#3e7d2c" stroke-width="12" fill="none" stroke-linecap="round"/>
<path d="M258,118 C220,70 150,70 130,100 C170,140 230,140 258,118Z" fill="url(#l)" stroke="#2f6b26" stroke-width="7"/>
<path d="M264,108 C290,50 370,40 395,72 C360,118 300,128 264,108Z" fill="url(#l)" stroke="#2f6b26" stroke-width="7"/>
<path d="M145,100 C185,108 220,112 250,116" stroke="#c8f5b8" stroke-width="5" fill="none" opacity="0.8"/>
<ellipse cx="256" cy="330" rx="152" ry="138" fill="url(#g)" stroke="#3e6e26" stroke-width="8"/>
<ellipse cx="196" cy="452" rx="36" ry="17" fill="#5a9c34" stroke="#3e6e26" stroke-width="6"/><ellipse cx="316" cy="452" rx="36" ry="17" fill="#5a9c34" stroke="#3e6e26" stroke-width="6"/>
<ellipse cx="198" cy="262" rx="46" ry="26" fill="#fff" opacity="0.35" transform="rotate(-25 198 262)"/>''' + eyes(256, 322) + blush(256, 362) + mouth(256, 374))

bird = wrap('''
<radialGradient id="k" cx="40%" cy="32%" r="75%"><stop offset="0" stop-color="#ffffff"/><stop offset="0.6" stop-color="#d4f1f8"/><stop offset="1" stop-color="#9fd6e6"/></radialGradient>
<linearGradient id="wi" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#bfe9f3"/><stop offset="1" stop-color="#7cc3da"/></linearGradient>''',
'''<path d="M210,120 C200,60 270,40 300,80 C320,108 290,135 266,118 C250,106 262,88 276,96" stroke="#6cc0d8" stroke-width="14" fill="none" stroke-linecap="round"/>
<path d="M60,280 C70,230 120,220 150,250 C135,300 100,320 60,280Z" fill="url(#wi)" stroke="#3f8aa3" stroke-width="7"/>
<path d="M452,280 C442,230 392,220 362,250 C377,300 412,320 452,280Z" fill="url(#wi)" stroke="#3f8aa3" stroke-width="7"/>
<ellipse cx="256" cy="315" rx="150" ry="145" fill="url(#k)" stroke="#3f8aa3" stroke-width="8"/>
<ellipse cx="256" cy="380" rx="92" ry="72" fill="#fff"/>
<path d="M240,352 L272,352 L256,378Z" fill="#ffab3d" stroke="#b5671a" stroke-width="5" stroke-linejoin="round"/>
<path d="M212,458 l-10,16 M224,458 l0,18 M300,458 l10,16 M288,458 l0,18" stroke="#ffab3d" stroke-width="9" stroke-linecap="round"/>
<path d="M392,140 C420,130 440,150 425,165 M404,112 C440,100 470,122 452,145" stroke="#a6dced" stroke-width="7" fill="none" stroke-linecap="round" opacity="0.8"/>''' + eyes(256, 300, 60) + blush(256, 342, 100))

for name, svg in (("breezebird", bird), ("emberbean", ember), ("sprout", sprout), ("dewdrop", drop)):
    open(f"{OUT}/sd_{name}.svg", "w").write(svg)
print("svg done")
