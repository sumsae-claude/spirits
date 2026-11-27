"""전투용 도트 스프라이트 생성기 (32x32, 자동 외곽선).
사용: python3 tools/art/sprites.py <프로젝트 루트>
출력: assets/sprites/spirits/<종족id>.png, assets/sprites/summoner_<속성>.png
"""
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1]
N = 32
OUT_COL = (40, 30, 45, 255)
EYE = (35, 25, 40, 255)
WHITE = (255, 255, 255, 255)
BLUSH = (255, 150, 160, 255)
GOLD = (255, 205, 60, 255)
GOLD_L = (255, 240, 150, 255)

PAL = {
    "fire": dict(base=(232, 96, 60, 255), light=(250, 140, 90, 255), dark=(200, 70, 50, 255), acc=(255, 170, 40, 255), acc2=(255, 235, 120, 255)),
    "water": dict(base=(80, 150, 240, 255), light=(200, 230, 255, 255), dark=(55, 115, 210, 255), acc=(140, 200, 255, 255), acc2=(230, 245, 255, 255)),
    "grass": dict(base=(140, 205, 90, 255), light=(185, 230, 130, 255), dark=(105, 170, 70, 255), acc=(80, 190, 80, 255), acc2=(150, 235, 140, 255)),
    "wind": dict(base=(205, 238, 245, 255), light=(240, 252, 255, 255), dark=(150, 210, 225, 255), acc=(120, 200, 220, 255), acc2=(255, 255, 255, 255)),
}


def canvas():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def outline(img):
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < N and 0 <= ny < N and px[nx, ny][3] > 0 and px[nx, ny] != OUT_COL:
                        po[x, y] = OUT_COL
                        break
    return out


def eyes(d, cx, cy, gap=4, brows=False):
    for ex in (cx - gap, cx + gap - 1):
        d.rectangle([ex, cy, ex + 1, cy + 2], fill=EYE)
        d.point((ex, cy), fill=WHITE)
    if brows:
        d.line([(cx - gap - 1, cy - 2), (cx - gap + 1, cy - 1)], fill=EYE)
        d.line([(cx + gap - 2, cy - 1), (cx + gap, cy - 2)], fill=EYE)


def mouth(d, cx, cy):
    d.point((cx - 1, cy), fill=EYE)
    d.point((cx, cy), fill=EYE)
    d.point((cx - 2, cy - 1), fill=EYE)
    d.point((cx + 1, cy - 1), fill=EYE)


def blush(d, cx, cy, gap=6):
    d.rectangle([cx - gap, cy, cx - gap + 1, cy], fill=BLUSH)
    d.rectangle([cx + gap - 2, cy, cx + gap - 1, cy], fill=BLUSH)


def face(d, cx, cy, gap=4, brows=False):
    eyes(d, cx, cy, gap, brows)
    mouth(d, cx, cy + 4)
    blush(d, cx, cy + 3, gap + 2)


def crown(d, cx, top):
    d.polygon([(cx - 5, top + 4), (cx - 5, top), (cx - 3, top + 2), (cx, top - 1), (cx + 3, top + 2), (cx + 5, top), (cx + 5, top + 4)], fill=GOLD)
    d.point((cx, top + 2), fill=(255, 80, 120, 255))
    d.point((cx - 4, top + 3), fill=GOLD_L)


# ------------------------------------------------------------------ 바람
def breezebird(evolved=False):
    img, d = canvas()
    p = PAL["wind"]
    if not evolved:
        d.ellipse([7, 10, 25, 27], fill=p["base"]); d.ellipse([9, 12, 16, 17], fill=p["light"])
        d.ellipse([10, 20, 22, 27], fill=WHITE)
        d.ellipse([3, 15, 10, 21], fill=p["dark"]); d.ellipse([22, 15, 29, 21], fill=p["dark"])
        d.arc([12, 3, 20, 11], 180, 360, fill=p["acc"]); d.arc([15, 5, 21, 11], 200, 380, fill=p["acc"])
        d.polygon([(15, 19), (17, 19), (16, 21)], fill=(255, 170, 60, 255))
        eyes(d, 16, 15, 4); blush(d, 16, 18, 6)
        d.rectangle([13, 27, 14, 28], fill=(255, 170, 60, 255)); d.rectangle([18, 27, 19, 28], fill=(255, 170, 60, 255))
    else:  # 폭풍매
        body, wing = (150, 195, 220, 255), (90, 150, 190, 255)
        d.polygon([(0, 10), (8, 13), (9, 22), (2, 19)], fill=wing); d.polygon([(31, 10), (23, 13), (22, 22), (29, 19)], fill=wing)
        d.ellipse([6, 8, 26, 28], fill=body); d.ellipse([10, 18, 22, 28], fill=(235, 248, 252, 255))
        d.ellipse([8, 10, 15, 15], fill=(190, 225, 240, 255))
        for x0 in (11, 15, 19):
            d.polygon([(x0, 9), (x0 + 2, 2), (x0 + 3, 9)], fill=wing)
        d.polygon([(14, 18), (18, 18), (16, 21)], fill=(255, 170, 60, 255))
        eyes(d, 16, 14, 4, brows=True); blush(d, 16, 17, 6)
        d.rectangle([12, 28, 13, 29], fill=(255, 170, 60, 255)); d.rectangle([19, 28, 20, 29], fill=(255, 170, 60, 255))
    return outline(img)


def whirlmouse(evolved=False):
    img, d = canvas()
    p = PAL["wind"]
    body = (190, 230, 240, 255) if not evolved else (150, 205, 230, 255)
    # 꼬리 회오리
    d.arc([21, 16, 31, 26], 90, 400, fill=p["acc"], width=2)
    if evolved:
        d.arc([23, 10, 31, 18], 0, 300, fill=p["acc"], width=1)
        d.polygon([(7, 5), (11, 13), (5, 13)], fill=body); d.polygon([(25, 5), (27, 13), (21, 13)], fill=body)
        d.polygon([(7, 8), (9, 12), (6, 12)], fill=(255, 180, 200, 255)); d.polygon([(25, 8), (26, 12), (23, 12)], fill=(255, 180, 200, 255))
    else:
        d.ellipse([5, 7, 13, 15], fill=body); d.ellipse([19, 7, 27, 15], fill=body)
        d.ellipse([7, 9, 11, 13], fill=(255, 180, 200, 255)); d.ellipse([21, 9, 25, 13], fill=(255, 180, 200, 255))
    d.ellipse([8, 12, 24, 28], fill=body); d.ellipse([10, 14, 15, 18], fill=p["light"])
    d.ellipse([11, 21, 21, 28], fill=WHITE)
    d.point((16, 21), fill=(255, 130, 150, 255))
    face(d, 16, 17, 4, brows=evolved)
    if evolved:  # 질풍 줄무늬
        for y in (14, 16):
            d.line([(2, y), (6, y)], fill=p["acc"])
    return outline(img)


# ------------------------------------------------------------------ 불
def emberbean(evolved=False):
    img, d = canvas()
    p = PAL["fire"]
    if not evolved:
        d.ellipse([8, 12, 24, 28], fill=p["base"]); d.ellipse([10, 14, 18, 20], fill=p["light"]); d.ellipse([9, 22, 23, 28], fill=p["dark"])
        d.polygon([(16, 3), (20, 9), (19, 13), (13, 13), (12, 9)], fill=p["acc"]); d.polygon([(16, 6), (18, 10), (17, 12), (15, 12), (14, 10)], fill=p["acc2"])
        d.rectangle([11, 28, 13, 29], fill=(170, 60, 45, 255)); d.rectangle([19, 28, 21, 29], fill=(170, 60, 45, 255))
        face(d, 16, 18)
    else:  # 화염콩
        d.polygon([(16, 0), (23, 8), (22, 12), (10, 12), (9, 8)], fill=p["acc"]); d.polygon([(11, 3), (14, 8), (10, 10)], fill=p["acc"]); d.polygon([(21, 3), (22, 10), (18, 8)], fill=p["acc"])
        d.polygon([(16, 4), (19, 9), (18, 12), (14, 12), (13, 9)], fill=p["acc2"])
        d.ellipse([3, 18, 8, 23], fill=p["base"]); d.ellipse([24, 18, 29, 23], fill=p["base"])
        d.ellipse([6, 10, 26, 29], fill=p["base"]); d.ellipse([9, 12, 18, 19], fill=p["light"]); d.ellipse([7, 23, 25, 29], fill=p["dark"])
        face(d, 16, 17, 4, brows=True)
        for e in ((4, 9), (27, 12), (26, 5)):
            d.point(e, fill=p["acc2"])
    return outline(img)


def ashfox(evolved=False):
    img, d = canvas()
    p = PAL["fire"]
    fur = (235, 120, 60, 255) if not evolved else (205, 55, 55, 255)
    tip = (90, 80, 85, 255) if not evolved else GOLD
    # 꼬리
    if not evolved:
        d.ellipse([21, 15, 31, 25], fill=(150, 140, 140, 255)); d.polygon([(26, 12), (31, 16), (28, 18)], fill=p["acc"])
    else:
        for (x0, y0) in ((22, 8), (24, 14), (21, 19)):
            d.polygon([(x0, y0 + 5), (x0 + 5, y0), (x0 + 9, y0 + 2), (x0 + 4, y0 + 8)], fill=p["acc"])
            d.point((x0 + 5, y0 + 2), fill=p["acc2"])
    d.polygon([(8, 6), (13, 13), (7, 14)], fill=fur); d.polygon([(24, 6), (25, 14), (19, 13)], fill=fur)
    d.polygon([(8, 6), (10, 9), (8, 10)], fill=tip); d.polygon([(24, 6), (24, 10), (22, 9)], fill=tip)
    d.ellipse([7, 11, 25, 28], fill=fur)
    d.ellipse([11, 18, 21, 27], fill=(255, 235, 215, 255))
    d.point((16, 20), fill=EYE)
    eyes(d, 16, 16, 4, brows=evolved); blush(d, 16, 19, 6)
    if evolved:
        d.line([(9, 13), (11, 15)], fill=GOLD); d.line([(23, 13), (21, 15)], fill=GOLD)
    return outline(img)


# ------------------------------------------------------------------ 풀
def sprout(evolved=False):
    img, d = canvas()
    p = PAL["grass"]
    if not evolved:
        d.ellipse([7, 12, 25, 28], fill=p["base"]); d.ellipse([9, 14, 16, 19], fill=p["light"]); d.ellipse([8, 22, 24, 28], fill=p["dark"])
        d.line([(16, 12), (16, 7)], fill=(90, 150, 60, 255))
        d.ellipse([9, 4, 16, 8], fill=p["acc"]); d.ellipse([16, 2, 23, 7], fill=p["acc"])
        d.point((12, 6), fill=p["acc2"]); d.point((19, 4), fill=p["acc2"])
        d.rectangle([10, 28, 13, 29], fill=(80, 150, 60, 255)); d.rectangle([19, 28, 22, 29], fill=(80, 150, 60, 255))
        face(d, 16, 18)
    else:  # 덩굴거인
        body = (95, 165, 75, 255)
        d.ellipse([1, 14, 8, 24], fill=body); d.ellipse([24, 14, 31, 24], fill=body)
        d.rounded_rectangle([6, 8, 26, 29], radius=7, fill=body)
        d.ellipse([8, 10, 16, 16], fill=(140, 200, 110, 255))
        for y in (20, 24):
            d.arc([6, y - 3, 26, y + 3], 0, 180, fill=(60, 120, 50, 255))
        d.ellipse([8, 3, 15, 9], fill=p["acc"]); d.ellipse([17, 1, 25, 8], fill=p["acc"]); d.ellipse([13, 0, 19, 6], fill=p["acc"])
        d.ellipse([20, 9, 24, 13], fill=(255, 140, 180, 255)); d.point((22, 11), fill=GOLD)
        face(d, 16, 15, 4, brows=True)
    return outline(img)


def turtle(evolved=False):
    img, d = canvas()
    p = PAL["grass"]
    shell = (115, 150, 70, 255)
    if evolved:
        d.rectangle([15, 3, 17, 10], fill=(130, 90, 55, 255))
        d.ellipse([9, 0, 23, 8], fill=(70, 160, 70, 255)); d.ellipse([11, 1, 16, 4], fill=(120, 205, 110, 255))
    d.ellipse([4, 8 if evolved else 10, 28, 24], fill=shell)
    for (x, y) in ((10, 14), (16, 12), (22, 14), (13, 18), (19, 18)):
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(85, 120, 55, 255))
    d.ellipse([6, 11, 12, 15], fill=p["acc"]); d.ellipse([19, 10, 25, 14], fill=p["acc"])  # 이끼
    d.ellipse([10, 16, 22, 27], fill=(175, 205, 120, 255))
    d.rectangle([5, 23, 9, 28], fill=(150, 180, 100, 255)); d.rectangle([23, 23, 27, 28], fill=(150, 180, 100, 255))
    face(d, 16, 20, 3, brows=evolved)
    return outline(img)


# ------------------------------------------------------------------ 물
def dewdrop(evolved=False):
    img, d = canvas()
    p = PAL["water"]
    base = p["base"] if not evolved else (60, 120, 230, 255)
    if evolved:
        d.polygon([(2, 16), (8, 13), (8, 21)], fill=p["acc"]); d.polygon([(30, 16), (24, 13), (24, 21)], fill=p["acc"])
    d.polygon([(16, 4), (22, 13), (9, 13)], fill=base); d.ellipse([7, 10, 25, 28], fill=base)
    d.ellipse([9, 22, 23, 28], fill=p["dark"]); d.ellipse([10, 12, 14, 17], fill=p["light"]); d.point((15, 8), fill=p["light"])
    if evolved:  # 파도 왕관
        for x0 in (10, 15, 20):
            d.arc([x0 - 2, 1, x0 + 3, 6], 180, 360, fill=WHITE)
    else:
        for bx, by in ((4, 8), (27, 12), (26, 5)):
            d.ellipse([bx, by, bx + 2, by + 2], outline=p["acc"])
    face(d, 16, 18, 4, brows=evolved)
    return outline(img)


def whale(evolved=False):
    img, d = canvas()
    body = (110, 150, 205, 255) if not evolved else (45, 65, 140, 255)
    belly = (225, 238, 250, 255) if not evolved else (90, 120, 190, 255)
    d.polygon([(24, 12), (31, 7), (30, 14), (27, 17)], fill=body)  # 꼬리
    d.ellipse([3, 11, 28, 28], fill=body)
    d.ellipse([7, 20, 24, 28], fill=belly)
    d.ellipse([6, 13, 12, 17], fill=(160, 195, 235, 255) if not evolved else (80, 105, 180, 255))
    # 물 뿜기
    d.line([(12, 10), (12, 5)], fill=(140, 200, 255, 255)); d.point((10, 4), fill=(140, 200, 255, 255)); d.point((14, 4), fill=(140, 200, 255, 255))
    eyes(d, 12, 17, 3, brows=evolved); mouth(d, 12, 22); blush(d, 12, 20, 5)
    if evolved:
        for pt in ((20, 15), (23, 19), (18, 24), (25, 23)):
            d.point(pt, fill=(255, 240, 120, 255))
    return outline(img)


# ------------------------------------------------------------------ 수호 정령
def guardian_wind():
    img, d = canvas()
    p = PAL["wind"]
    d.polygon([(1, 8), (9, 14), (8, 22), (2, 18)], fill=(225, 245, 250, 255)); d.polygon([(31, 8), (23, 14), (24, 22), (30, 18)], fill=(225, 245, 250, 255))
    d.line([(3, 11), (8, 15)], fill=p["dark"]); d.line([(29, 11), (24, 15)], fill=p["dark"])
    d.ellipse([8, 9, 24, 27], fill=p["base"]); d.ellipse([10, 11, 16, 16], fill=WHITE)
    d.arc([5, 22, 27, 31], 200, 340, fill=p["acc"], width=2)
    crown(d, 16, 4)
    face(d, 16, 17)
    return outline(img)


def guardian_fire():
    img, d = canvas()
    p = PAL["fire"]
    for k in range(8):  # 연꽃 갈기
        import math
        a = math.radians(k * 45)
        cx, cy = 16 + math.cos(a) * 10, 18 + math.sin(a) * 10
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(230, 70, 60, 255) if k % 2 else p["acc"])
    d.ellipse([9, 11, 23, 25], fill=(250, 190, 90, 255)); d.ellipse([12, 18, 20, 24], fill=(255, 235, 200, 255))
    d.ellipse([9, 9, 12, 12], fill=(250, 190, 90, 255)); d.ellipse([20, 9, 23, 12], fill=(250, 190, 90, 255))
    d.point((16, 19), fill=EYE)
    eyes(d, 16, 15); blush(d, 16, 18, 6)
    crown(d, 16, 2)
    return outline(img)


def guardian_grass():
    img, d = canvas()
    ant = (140, 100, 60, 255)
    for sx in (-1, 1):  # 뿔과 꽃
        x0 = 16 + sx * 4
        d.line([(x0, 10), (x0 + sx * 4, 3)], fill=ant); d.line([(x0 + sx * 2, 6), (x0 + sx * 6, 6)], fill=ant)
        d.ellipse([x0 + sx * 4 - 2, 1, x0 + sx * 4 + 2, 5], fill=(255, 150, 190, 255)); d.point((x0 + sx * 4, 3), fill=GOLD)
    d.ellipse([5, 12, 11, 16], fill=(205, 165, 115, 255)); d.ellipse([21, 12, 27, 16], fill=(205, 165, 115, 255))
    d.ellipse([9, 9, 23, 26], fill=(215, 175, 120, 255))
    d.ellipse([12, 18, 20, 26], fill=(250, 235, 210, 255))
    for pt in ((11, 13), (21, 13), (12, 16)):
        d.point(pt, fill=WHITE)
    d.rectangle([11, 26, 13, 29], fill=(170, 130, 90, 255)); d.rectangle([19, 26, 21, 29], fill=(170, 130, 90, 255))
    d.line([(10, 9), (22, 9)], fill=GOLD)
    d.point((16, 20), fill=EYE)
    eyes(d, 16, 15); blush(d, 16, 18, 6)
    return outline(img)


def guardian_water():
    img, d = canvas()
    body = (130, 190, 245, 255)
    d.polygon([(24, 14), (31, 9), (30, 16), (27, 19)], fill=body)
    d.ellipse([3, 12, 28, 29], fill=body); d.ellipse([7, 21, 24, 29], fill=(235, 245, 255, 255))
    d.ellipse([6, 14, 12, 18], fill=(200, 230, 255, 255))
    crown(d, 13, 6)
    d.polygon([(13, 2), (15, 5), (11, 5)], fill=(90, 170, 255, 255))
    eyes(d, 13, 18, 3); mouth(d, 13, 23); blush(d, 13, 21, 5)
    return outline(img)


# ------------------------------------------------------------------ 정령사
def summoner(el):
    img, d = canvas()
    p = PAL[el]
    robe = p["dark"] if el != "wind" else (110, 175, 200, 255)
    trim = p["light"] if el != "wind" else WHITE
    # 지팡이
    d.line([(26, 9), (26, 30)], fill=(140, 100, 60, 255))
    d.ellipse([23, 4, 29, 10], fill=p["acc"]); d.point((25, 6), fill=WHITE)
    # 로브
    d.polygon([(10, 17), (22, 17), (25, 30), (7, 30)], fill=robe)
    d.line([(16, 18), (16, 29)], fill=trim)
    d.rectangle([7, 28, 25, 30], fill=trim)
    # 두건 + 얼굴
    d.ellipse([7, 3, 25, 20], fill=robe)
    d.ellipse([10, 7, 22, 19], fill=(255, 222, 196, 255))
    d.rectangle([10, 7, 22, 10], fill=(80, 55, 50, 255))   # 앞머리
    d.point((16, 3), fill=trim)
    eyes(d, 16, 12, 3); mouth(d, 16, 17); blush(d, 16, 15, 5)
    # 손
    d.ellipse([23, 18, 27, 22], fill=(255, 222, 196, 255))
    return outline(img)


SPRITES = {
    "breezebird": lambda: breezebird(False), "stormhawk": lambda: breezebird(True),
    "whirlmouse": lambda: whirlmouse(False), "galemouse": lambda: whirlmouse(True),
    "emberbean": lambda: emberbean(False), "blazebean": lambda: emberbean(True),
    "ashfox": lambda: ashfox(False), "crimsonfox": lambda: ashfox(True),
    "pebble": lambda: sprout(False), "boulder": lambda: sprout(True),
    "mossturtle": lambda: turtle(False), "oaktortoise": lambda: turtle(True),
    "dewdrop": lambda: dewdrop(False), "tidesprite": lambda: dewdrop(True),
    "mistwhale": lambda: whale(False), "abysswhale": lambda: whale(True),
    "guardian_wind": guardian_wind, "guardian_fire": guardian_fire,
    "guardian_grass": guardian_grass, "guardian_water": guardian_water,
}

if __name__ == "__main__":
    for sid, fn in SPRITES.items():
        fn().save(f"{ROOT}/assets/sprites/spirits/{sid}.png")
    for el in PAL:
        summoner(el).save(f"{ROOT}/assets/sprites/summoner_{el}.png")
    print(f"{len(SPRITES)} spirits + {len(PAL)} summoners")
