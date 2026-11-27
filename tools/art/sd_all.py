"""나머지 정령 + 정령사 2D SD 일러스트(SVG) 생성. 사용: python3 tools/art/sd_all.py <출력폴더>"""
import sys, math
OUT = sys.argv[1]

def eyes(cx, cy, gap=58, r=30, brows=False):
    s = ""
    for x in (cx - gap, cx + gap):
        s += f'<ellipse cx="{x}" cy="{cy}" rx="{r*0.8}" ry="{r}" fill="#2a1f33"/><ellipse cx="{x-8}" cy="{cy-12}" rx="{r*0.3}" ry="{r*0.34}" fill="#fff"/><circle cx="{x+9}" cy="{cy+12}" r="{r*0.14}" fill="#fff" opacity="0.85"/>'
    if brows:
        s += f'<path d="M{cx-gap-26},{cy-44} L{cx-gap+18},{cy-34}" stroke="#2a1f33" stroke-width="9" stroke-linecap="round"/><path d="M{cx+gap+26},{cy-44} L{cx+gap-18},{cy-34}" stroke="#2a1f33" stroke-width="9" stroke-linecap="round"/>'
    return s
def blush(cx, cy, gap=96):
    return "".join(f'<ellipse cx="{x}" cy="{cy}" rx="26" ry="14" fill="#ff8fa3" opacity="0.55"/>' for x in (cx-gap, cx+gap))
def mouth(cx, cy):
    return f'<path d="M{cx-14},{cy} Q{cx-7},{cy+12} {cx},{cy} Q{cx+7},{cy+12} {cx+14},{cy}" stroke="#2a1f33" stroke-width="6" fill="none" stroke-linecap="round"/>'
def face(cx, cy, gap=58, brows=False):
    return eyes(cx, cy, gap, brows=brows) + blush(cx, cy + 40, gap + 38) + mouth(cx, cy + 52)
def grad(i, c0, c1, c2):
    return f'<radialGradient id="{i}" cx="40%" cy="35%" r="72%"><stop offset="0" stop-color="{c0}"/><stop offset="0.55" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>'
def shine(x, y):
    return f'<ellipse cx="{x}" cy="{y}" rx="44" ry="24" fill="#fff" opacity="0.33" transform="rotate(-25 {x} {y})"/>'
def crown(cx, top):
    return f'<path d="M{cx-60},{top+50} L{cx-60},{top} L{cx-30},{top+28} L{cx},{top-14} L{cx+30},{top+28} L{cx+60},{top} L{cx+60},{top+50} Z" fill="#ffcf3d" stroke="#9a6a10" stroke-width="7" stroke-linejoin="round"/><circle cx="{cx}" cy="{top+30}" r="9" fill="#ff5f8a"/>'
def svg(defs, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs>{defs}</defs><ellipse cx="256" cy="468" rx="150" ry="22" fill="#000" opacity="0.18"/>{body}</svg>'
def feet(c, o, y=452, xs=(196, 316)):
    return "".join(f'<ellipse cx="{x}" cy="{y}" rx="36" ry="17" fill="{c}" stroke="{o}" stroke-width="6"/>' for x in xs)

A = {}
# ---------------- 바람
A["stormhawk"] = svg(grad("b", "#eaf7fc", "#9fcfe6", "#5f97bd"),
    '<path d="M40,250 C30,170 110,150 160,210 C140,290 90,320 40,250Z" fill="#6aa3c7" stroke="#2f5f85" stroke-width="8"/><path d="M472,250 C482,170 402,150 352,210 C372,290 422,320 472,250Z" fill="#6aa3c7" stroke="#2f5f85" stroke-width="8"/>'
    '<path d="M200,110 L216,40 L240,105 L256,25 L272,105 L296,40 L312,110Z" fill="#6aa3c7" stroke="#2f5f85" stroke-width="7" stroke-linejoin="round"/>'
    '<ellipse cx="256" cy="300" rx="155" ry="160" fill="url(#b)" stroke="#2f5f85" stroke-width="8"/><ellipse cx="256" cy="370" rx="95" ry="80" fill="#fff"/>'
    '<path d="M236,344 L276,344 L256,374Z" fill="#ffab3d" stroke="#b5671a" stroke-width="5" stroke-linejoin="round"/>'
    '<path d="M210,458 l-12,18 M226,460 l0,20 M302,458 l12,18 M286,460 l0,20" stroke="#ffab3d" stroke-width="10" stroke-linecap="round"/>'
    + shine(196, 222) + eyes(256, 286, 62, brows=True) + blush(256, 330, 104))
def mouse(body, light, line, ears_pointy, evolved):
    ears = ('<path d="M120,190 L150,60 L220,170Z" fill="{b}" stroke="{l}" stroke-width="8" stroke-linejoin="round"/><path d="M392,190 L362,60 L292,170Z" fill="{b}" stroke="{l}" stroke-width="8" stroke-linejoin="round"/><path d="M148,165 L158,100 L195,160Z" fill="#ffb3c6"/><path d="M364,165 L354,100 L317,160Z" fill="#ffb3c6"/>'
            if ears_pointy else
            '<circle cx="140" cy="150" r="70" fill="{b}" stroke="{l}" stroke-width="8"/><circle cx="372" cy="150" r="70" fill="{b}" stroke="{l}" stroke-width="8"/><circle cx="140" cy="150" r="40" fill="#ffb3c6"/><circle cx="372" cy="150" r="40" fill="#ffb3c6"/>').format(b=body, l=line)
    tail = f'<path d="M380,400 C470,400 480,300 420,290 C380,285 380,340 420,335" stroke="{line}" stroke-width="12" fill="none" stroke-linecap="round"/>'
    streak = '<path d="M40,250 h60 M30,290 h70 M50,330 h50" stroke="#a6dced" stroke-width="9" stroke-linecap="round"/>' if evolved else ""
    return svg(grad("b", "#ffffff", light, body), streak + tail + ears + f'<ellipse cx="256" cy="320" rx="150" ry="140" fill="url(#b)" stroke="{line}" stroke-width="8"/><ellipse cx="256" cy="390" rx="85" ry="62" fill="#fff"/><ellipse cx="256" cy="352" rx="10" ry="8" fill="#ff8fa3"/>'
               + shine(198, 250) + face(256, 300, 58, brows=evolved) + feet(body, line))
A["whirlmouse"] = mouse("#a9dcec", "#d8f0f8", "#3f8aa3", False, False)
A["galemouse"] = mouse("#7fc0dc", "#c3e6f4", "#2f6f8f", True, True)
# ---------------- 불
A["blazebean"] = svg(grad("b", "#ffb08a", "#f0643c", "#c2412a") + '<linearGradient id="f" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#ff7a1a"/><stop offset="0.6" stop-color="#ffb02e"/><stop offset="1" stop-color="#ffe680"/></linearGradient>',
    '<path d="M256,10 C320,70 360,110 345,175 C335,205 300,222 256,224 C212,222 177,205 167,175 C152,110 192,70 256,10Z" fill="url(#f)" stroke="#8a3a1c" stroke-width="7"/>'
    '<path d="M160,90 C140,130 150,160 175,170 M352,90 C372,130 362,160 337,170" stroke="#ffb02e" stroke-width="18" stroke-linecap="round" fill="none"/>'
    '<path d="M256,70 C282,110 294,145 282,175 C274,190 238,190 230,175 C218,145 230,110 256,70Z" fill="#fff4b0"/>'
    '<ellipse cx="78" cy="330" rx="40" ry="34" fill="#e0552f" stroke="#7a2a1c" stroke-width="7"/><ellipse cx="434" cy="330" rx="40" ry="34" fill="#e0552f" stroke="#7a2a1c" stroke-width="7"/>'
    '<ellipse cx="256" cy="330" rx="165" ry="150" fill="url(#b)" stroke="#7a2a1c" stroke-width="8"/>' + feet("#c2412a", "#7a2a1c") + shine(196, 258) + face(256, 318, 60, brows=True))
def fox(fur, light, line, tails, evolved):
    t = ""
    for (dx, rot) in tails:
        t += f'<path d="M330,380 C420,{340+dx} 470,{250+dx} 430,{200+dx} C400,{250+dx} 360,{300+dx} 330,330Z" fill="#ffb02e" stroke="{line}" stroke-width="7" transform="rotate({rot} 330 370)"/>'
    tip = "#ffcf3d" if evolved else "#4a3d40"
    return svg(grad("b", light, fur, fur),
        t + f'<path d="M110,220 L140,70 L230,180Z" fill="{fur}" stroke="{line}" stroke-width="8" stroke-linejoin="round"/><path d="M402,220 L372,70 L282,180Z" fill="{fur}" stroke="{line}" stroke-width="8" stroke-linejoin="round"/>'
        f'<path d="M140,70 L152,120 L178,128Z" fill="{tip}"/><path d="M372,70 L360,120 L334,128Z" fill="{tip}"/>'
        f'<ellipse cx="256" cy="320" rx="150" ry="140" fill="url(#b)" stroke="{line}" stroke-width="8"/><ellipse cx="256" cy="380" rx="90" ry="70" fill="#fff3e6"/><ellipse cx="256" cy="355" rx="12" ry="9" fill="#2a1f33"/>'
        + shine(198, 250) + eyes(256, 300, 60, brows=evolved) + blush(256, 340, 98) + feet(fur, line))
A["ashfox"] = fox("#ec7c3c", "#ffc79a", "#7a3a1c", [(0, 0)], False)
A["crimsonfox"] = fox("#d23c3c", "#ff9a8a", "#6a1c1c", [(-40, -20), (0, 0), (40, 20)], True)
# ---------------- 풀
A["boulder"] = svg(grad("b", "#cdeea0", "#6fb24a", "#3e7d2c") + '<linearGradient id="l" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8be07a"/><stop offset="1" stop-color="#3fa84a"/></linearGradient>',
    '<ellipse cx="70" cy="320" rx="50" ry="70" fill="#5c9c3c" stroke="#2f5f20" stroke-width="7"/><ellipse cx="442" cy="320" rx="50" ry="70" fill="#5c9c3c" stroke="#2f5f20" stroke-width="7"/>'
    '<rect x="96" y="120" width="320" height="340" rx="120" fill="url(#b)" stroke="#2f5f20" stroke-width="8"/>'
    '<path d="M110,330 C200,300 312,360 402,320 M110,390 C200,360 312,420 402,380" stroke="#3a6e28" stroke-width="10" fill="none"/>'
    '<path d="M256,125 C220,60 150,60 130,95 C170,135 230,140 256,125Z" fill="url(#l)" stroke="#2f6b26" stroke-width="7"/><path d="M262,118 C290,50 370,40 395,72 C360,118 300,128 262,118Z" fill="url(#l)" stroke="#2f6b26" stroke-width="7"/>'
    '<circle cx="372" cy="190" r="26" fill="#ff8fb8" stroke="#a04070" stroke-width="5"/><circle cx="372" cy="190" r="9" fill="#ffcf3d"/>'
    + shine(186, 200) + face(256, 260, 62, brows=True))
def turtle(evolved):
    tree = ('<rect x="240" y="40" width="32" height="90" fill="#8a5a33" stroke="#4a2a14" stroke-width="6"/><circle cx="256" cy="50" r="70" fill="#4fa84a" stroke="#2f6b26" stroke-width="7"/><circle cx="226" cy="35" r="24" fill="#7fd06a"/>' if evolved else "")
    return svg(grad("s", "#b6d07a", "#7f9c48", "#566c2c") + grad("h", "#f0f7c8", "#c8df8e", "#97b45a"),
        tree + '<ellipse cx="256" cy="230" rx="200" ry="130" fill="url(#s)" stroke="#3e4e1c" stroke-width="8"/>'
        '<path d="M190,170 l30,-25 l40,0 l30,25 l-15,40 l-70,0Z M120,230 l35,-20 l30,30 l-20,35 l-40,-5Z M392,230 l-35,-20 l-30,30 l20,35 l40,-5Z" fill="#6c8a38" stroke="#3e4e1c" stroke-width="5"/>'
        '<ellipse cx="150" cy="180" rx="40" ry="24" fill="#7fd06a"/><ellipse cx="370" cy="170" rx="36" ry="22" fill="#7fd06a"/>'
        '<rect x="80" y="380" width="70" height="80" rx="30" fill="#a9c46e" stroke="#3e4e1c" stroke-width="7"/><rect x="362" y="380" width="70" height="80" rx="30" fill="#a9c46e" stroke="#3e4e1c" stroke-width="7"/>'
        '<ellipse cx="256" cy="350" rx="110" ry="100" fill="url(#h)" stroke="#4e6624" stroke-width="8"/>' + face(256, 332, 46, brows=evolved))
A["mossturtle"] = turtle(False)
A["oaktortoise"] = turtle(True)
# ---------------- 물
A["tidesprite"] = svg(grad("w", "#d9efff", "#5aa0f0", "#2558c4"),
    '<path d="M60,300 C90,250 140,250 160,290 C130,320 90,330 60,300Z M452,300 C422,250 372,250 352,290 C382,320 422,330 452,300Z" fill="#8fc4ff" stroke="#1f4c9e" stroke-width="7"/>'
    '<path d="M256,50 C300,130 400,215 400,320 C400,405 336,462 256,462 C176,462 112,405 112,320 C112,215 212,130 256,50Z" fill="url(#w)" stroke="#1f4c9e" stroke-width="8"/>'
    '<path d="M180,90 q20,-30 40,0 q20,-30 40,0 q20,-30 40,0 q20,-30 40,0" stroke="#fff" stroke-width="10" fill="none" stroke-linecap="round"/>'
    '<path d="M200,180 C180,220 172,250 170,290" stroke="#fff" stroke-width="18" stroke-linecap="round" opacity="0.6" fill="none"/>' + face(256, 320, 56, brows=True))
def whale(body, light, belly, line, glow, crown_on):
    dots = "".join(f'<circle cx="{x}" cy="{y}" r="8" fill="#ffe680"/>' for x, y in ((330, 260), (370, 320), (300, 380), (390, 380))) if glow else ""
    c = crown(200, 90) if crown_on else ""
    return svg(grad("b", light, body, body),
        f'<path d="M380,250 C430,200 480,150 470,240 C490,300 440,310 410,300Z" fill="{body}" stroke="{line}" stroke-width="8"/>'
        f'<ellipse cx="236" cy="320" rx="200" ry="150" fill="url(#b)" stroke="{line}" stroke-width="8"/><ellipse cx="226" cy="400" rx="140" ry="62" fill="{belly}"/>'
        '<path d="M200,165 C200,130 180,110 170,100 M200,165 C200,130 220,110 230,100" stroke="#9fd0ff" stroke-width="10" fill="none" stroke-linecap="round"/>'
        + c + dots + shine(140, 250) + face(196, 300, 50))
A["mistwhale"] = whale("#7aa6d8", "#cfe2f7", "#eef6ff", "#2f5a8e", False, False)
A["abysswhale"] = whale("#2e4590", "#5a78c8", "#5d79c4", "#141f4a", True, False)
# ---------------- 수호 정령
A["guardian_wind"] = svg(grad("k", "#ffffff", "#d4f1f8", "#9fd6e6"),
    '<path d="M30,200 C50,120 140,130 170,220 C140,300 70,300 30,200Z M482,200 C462,120 372,130 342,220 C372,300 442,300 482,200Z" fill="#eefaff" stroke="#3f8aa3" stroke-width="7"/>'
    '<path d="M60,200 C90,190 120,200 150,225 M452,200 C422,190 392,200 362,225" stroke="#9fd6e6" stroke-width="7" fill="none"/>'
    '<ellipse cx="256" cy="300" rx="150" ry="150" fill="url(#k)" stroke="#3f8aa3" stroke-width="8"/>'
    '<path d="M120,440 C200,480 312,480 392,440" stroke="#6cc0d8" stroke-width="12" fill="none" stroke-linecap="round"/>' + crown(256, 100) + shine(200, 232) + face(256, 296))
petals = "".join(f'<ellipse cx="{256+math.cos(math.radians(a))*150:.0f}" cy="{300+math.sin(math.radians(a))*150:.0f}" rx="60" ry="40" fill="{c}" stroke="#7a2a1c" stroke-width="6" transform="rotate({a} {256+math.cos(math.radians(a))*150:.0f} {300+math.sin(math.radians(a))*150:.0f})"/>' for a, c in [(i*45, "#f0643c" if i % 2 else "#ffb02e") for i in range(8)])
A["guardian_fire"] = svg(grad("b", "#fff0c0", "#ffc25a", "#e8902a"),
    petals + '<circle cx="150" cy="170" r="36" fill="#ffc25a" stroke="#7a3a1c" stroke-width="6"/><circle cx="362" cy="170" r="36" fill="#ffc25a" stroke="#7a3a1c" stroke-width="6"/>'
    '<ellipse cx="256" cy="300" rx="130" ry="125" fill="url(#b)" stroke="#7a3a1c" stroke-width="8"/><ellipse cx="256" cy="360" rx="70" ry="50" fill="#fff3e0"/><ellipse cx="256" cy="345" rx="12" ry="9" fill="#2a1f33"/>'
    + crown(256, 40) + eyes(256, 292, 52) + blush(256, 330, 88))
A["guardian_grass"] = svg(grad("b", "#fbe8c8", "#d8a868", "#a8743a"),
    '<path d="M200,150 C180,90 150,70 130,40 M180,110 C150,110 120,95 100,80 M312,150 C332,90 362,70 382,40 M332,110 C362,110 392,95 412,80" stroke="#7a5030" stroke-width="12" fill="none" stroke-linecap="round"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="22" fill="#ff9ec4" stroke="#a04070" stroke-width="5"/><circle cx="{x}" cy="{y}" r="7" fill="#ffcf3d"/>' for x, y in ((130, 40), (100, 80), (382, 40), (412, 80)))
    + '<ellipse cx="110" cy="230" rx="55" ry="28" fill="#d8a868" stroke="#6a4020" stroke-width="6" transform="rotate(-20 110 230)"/><ellipse cx="402" cy="230" rx="55" ry="28" fill="#d8a868" stroke="#6a4020" stroke-width="6" transform="rotate(20 402 230)"/>'
    '<ellipse cx="256" cy="300" rx="140" ry="150" fill="url(#b)" stroke="#6a4020" stroke-width="8"/><ellipse cx="256" cy="380" rx="80" ry="60" fill="#fff4e4"/><ellipse cx="256" cy="362" rx="12" ry="9" fill="#2a1f33"/>'
    '<path d="M150,150 Q256,120 362,150" stroke="#ffcf3d" stroke-width="10" fill="none"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="9" fill="#fff" opacity="0.8"/>' for x, y in ((170, 230), (340, 240), (190, 280))) + eyes(256, 296, 56) + blush(256, 336, 92))
A["guardian_water"] = whale("#8ec6f7", "#e2f2ff", "#f4faff", "#2f6aa8", False, True)

# ---------------- 정령사 (속성별 로브)
def summoner(robe, trim, orb):
    return svg(grad("r", trim, robe, robe),
        f'<line x1="430" y1="120" x2="430" y2="470" stroke="#8a5a33" stroke-width="16" stroke-linecap="round"/><circle cx="430" cy="100" r="40" fill="{orb}" stroke="#3a2a40" stroke-width="7"/><circle cx="418" cy="88" r="12" fill="#fff" opacity="0.8"/>'
        f'<path d="M150,300 L362,300 L410,470 L102,470Z" fill="url(#r)" stroke="#3a2a40" stroke-width="8" stroke-linejoin="round"/><path d="M256,305 L256,465" stroke="{trim}" stroke-width="10"/>'
        f'<ellipse cx="256" cy="190" rx="165" ry="160" fill="url(#r)" stroke="#3a2a40" stroke-width="8"/>'
        '<ellipse cx="256" cy="220" rx="120" ry="115" fill="#ffe0c8" stroke="#3a2a40" stroke-width="6"/>'
        '<path d="M140,190 C160,120 352,120 372,190 C330,160 300,175 256,160 C212,175 182,160 140,190Z" fill="#5a3a30"/>'
        '<ellipse cx="415" cy="320" rx="30" ry="26" fill="#ffe0c8" stroke="#3a2a40" stroke-width="6"/>'
        + eyes(256, 226, 48, 26) + blush(256, 262, 80) + mouth(256, 276))
A["summoner_wind"] = summoner("#6fb6d0", "#e8f8ff", "#bfe9f3")
A["summoner_fire"] = summoner("#d4503a", "#ffc4a0", "#ffb02e")
A["summoner_grass"] = summoner("#5aa040", "#d4f0b0", "#8be07a")
A["summoner_water"] = summoner("#3a74d0", "#c8e2ff", "#6fb3ff")

for k, v in A.items():
    open(f"{OUT}/{k}.svg", "w").write(v)
print(len(A))
