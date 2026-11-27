"""전투 배경(지역별) + 지형 헥스 타일 도트 생성기.
사용: python3 tools/art/battle_bg.py <프로젝트 루트>
출력: assets/battle/bg_<속성>.png (360x640, 게임에서 x2 확대)
      assets/battle/tile_<지형>.png (40x46 헥스, 게임에서 x2 확대)
모두 절차 생성한 오리지널 도트.
"""
import sys, math, random, os
from PIL import Image, ImageDraw

ROOT = sys.argv[1]
OUT = os.path.join(ROOT, "assets", "battle")
os.makedirs(OUT, exist_ok=True)

W, H = 360, 640
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def value_noise(w, h, cell, seed):
    rnd = random.Random(seed)
    gw, gh = w // cell + 2, h // cell + 2
    g = [[rnd.random() for _ in range(gw)] for _ in range(gh)]

    def at(x, y):
        fx, fy = x / cell, y / cell
        ix, iy = int(fx), int(fy)
        tx, ty = fx - ix, fy - iy
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[iy][ix] * (1 - tx) + g[iy][ix + 1] * tx
        b = g[iy + 1][ix] * (1 - tx) + g[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty
    return at


def dither_fill(img, cols, seed, cells=(48, 16), mask=None):
    """cols: 어두운→밝은 색 목록. 두 겹 노이즈 + 4x4 베이어 디더."""
    px = img.load()
    n1 = value_noise(img.width, img.height, cells[0], seed)
    n2 = value_noise(img.width, img.height, cells[1], seed + 1)
    k = len(cols) - 1
    for y in range(img.height):
        for x in range(img.width):
            if mask is not None and mask[x, y][3] == 0:
                continue
            v = n1(x, y) * 0.7 + n2(x, y) * 0.3
            v = v * k + (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.9
            i = max(0, min(k, int(round(v))))
            px[x, y] = cols[i]


REGIONS = {
    # 바람의 고원: 연둣빛 풀밭, 흰 꽃, 회색 자갈
    "wind": dict(ground=[(104, 140, 84), (128, 166, 98), (152, 190, 112), (178, 210, 132)],
                 details=[("flower", (245, 245, 235)), ("flower", (190, 225, 245)), ("pebble", (150, 150, 145)), ("tuft", (98, 132, 78))]),
    # 불꽃 골짜기: 붉은 흙, 갈라진 틈, 불씨
    "fire": dict(ground=[(104, 58, 44), (128, 74, 52), (152, 92, 62), (176, 112, 74)],
                 details=[("crack", (74, 38, 32)), ("ember", (255, 150, 60)), ("pebble", (90, 70, 64)), ("crack", (74, 38, 32))]),
    # 초록숲 마을: 짙은 풀, 분홍·노랑 꽃, 클로버
    "grass": dict(ground=[(56, 112, 60), (72, 136, 70), (92, 160, 80), (118, 184, 96)],
                  details=[("flower", (255, 150, 180)), ("flower", (255, 225, 110)), ("tuft", (48, 96, 52)), ("clover", (120, 200, 100))]),
    # 물안개 호숫가: 청록 풀, 모래, 웅덩이
    "water": dict(ground=[(62, 112, 104), (78, 136, 120), (98, 158, 136), (126, 182, 154)],
                  details=[("sand", (196, 186, 140)), ("puddle", (110, 170, 220)), ("tuft", (58, 104, 96)), ("flower", (235, 240, 255))]),
}


def draw_detail(d, kind, col, x, y, rnd):
    dark = tuple(max(0, c - 40) for c in col)
    if kind == "flower":
        d.point([(x, y - 1), (x - 1, y), (x + 1, y), (x, y + 1)], fill=col)
        d.point((x, y), fill=(255, 220, 90))
    elif kind == "pebble":
        d.rectangle([x, y, x + 2, y + 1], fill=col)
        d.point((x, y), fill=tuple(min(255, c + 40) for c in col))
        d.line([(x, y + 2), (x + 2, y + 2)], fill=dark)
    elif kind == "tuft":
        d.point([(x, y), (x - 1, y - 1), (x + 1, y - 1), (x, y - 2)], fill=col)
    elif kind == "clover":
        d.point([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], fill=col)
    elif kind == "crack":
        px, py = x, y
        for _ in range(rnd.randint(4, 9)):
            nx, ny = px + rnd.choice((-1, 0, 1)), py + 1
            d.line([(px, py), (nx, ny)], fill=col)
            px, py = nx, ny
    elif kind == "ember":
        d.point((x, y), fill=col)
        d.point((x, y - 1), fill=(255, 220, 120))
    elif kind == "sand":
        d.ellipse([x - 6, y - 3, x + 6, y + 3], fill=col)
        d.point([(x - 3, y), (x + 2, y - 1), (x + 4, y + 1)], fill=dark)
    elif kind == "puddle":
        d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=col)
        d.line([(x - 2, y - 1), (x, y - 1)], fill=(200, 230, 255))


def make_bg(el, spec, seed):
    img = Image.new("RGBA", (W, H))
    dither_fill(img, [c + (255,) for c in spec["ground"]], seed)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed + 7)
    for _ in range(380):
        kind, col = rnd.choice(spec["details"])
        draw_detail(d, kind, col + (255,) if len(col) == 3 else col, rnd.randrange(4, W - 4), rnd.randrange(4, H - 4), rnd)
    # 위·아래 가장자리 어둡게 (HUD와 하단 패널 쪽)
    px = img.load()
    for y in range(H):
        t = 0.0
        if y < 60:
            t = (60 - y) / 60.0 * 0.55
        elif y > H - 150:
            t = (y - (H - 150)) / 150.0 * 0.6
        for x in range(W):
            edge = max(0.0, (abs(x - W / 2) - W / 2 + 18) / 18.0) * 0.35
            k = min(0.75, t + edge)
            if k > 0:
                r, g, b, a = px[x, y]
                # 단계적으로 어둡게 (도트 느낌 유지)
                k = round(k * 6) / 6
                px[x, y] = (int(r * (1 - k)), int(g * (1 - k)), int(b * (1 - k)), a)
    img.save(os.path.join(OUT, f"bg_{el}.png"))
    return img


# ---------------------------------------------------------------- 지형 헥스 타일
TW, TH = 40, 46
OUTL = (36, 30, 40, 255)


def hex_mask():
    m = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    cx, cy, r = TW / 2 - 0.5, TH / 2 - 0.5, TH / 2 - 0.5
    pts = [(cx + math.cos(math.radians(60 * i - 30)) * r * 0.997, cy + math.sin(math.radians(60 * i - 30)) * r) for i in range(6)]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return m


MASK = hex_mask()


def tile_base(cols, seed, cells=(10, 5)):
    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    dither_fill(img, [c + (255,) for c in cols], seed, cells, mask=MASK.load())
    return img


def clip(img):
    out = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    out.paste(img, (0, 0), MASK)
    return out


def tree(d, x, y, s=1.0):
    r = int(6 * s)
    d.rectangle([x - 1, y, x + 1, y + 4], fill=(96, 62, 40, 255))
    d.ellipse([x - r, y - 2 * r + 1, x + r, y + 1], fill=(38, 96, 52, 255), outline=OUTL)
    d.ellipse([x - r + 2, y - 2 * r + 3, x + 1, y - r + 1], fill=(70, 140, 70, 255))
    d.point((x - r + 3, y - 2 * r + 4), fill=(130, 200, 110, 255))


def t_forest():
    img = tile_base([(34, 78, 44), (44, 94, 52), (54, 110, 60)], 11)
    d = ImageDraw.Draw(img)
    for x, y, s in ((12, 18, 1.0), (28, 16, 0.9), (20, 34, 1.15), (32, 34, 0.75), (8, 32, 0.7)):
        tree(d, x, y, s)
    return clip(img)


def t_water():
    img = tile_base([(40, 90, 160), (52, 110, 186), (66, 132, 206)], 12)
    d = ImageDraw.Draw(img)
    for x, y in ((8, 12), (22, 9), (14, 24), (28, 22), (10, 35), (24, 36)):
        d.line([(x, y), (x + 5, y)], fill=(150, 200, 240, 255))
        d.point((x + 6, y - 1), fill=(220, 240, 255, 255))
    return clip(img)


def t_hill():
    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 14, 38, 44], fill=(120, 100, 60, 255), outline=OUTL)
    d.ellipse([5, 15, 33, 37], fill=(150, 128, 76, 255))
    d.ellipse([9, 16, 25, 28], fill=(178, 156, 96, 255))
    d.ellipse([20, 6, 36, 24], fill=(132, 112, 68, 255), outline=OUTL)
    d.ellipse([22, 7, 32, 17], fill=(170, 148, 90, 255))
    for x, y in ((8, 30), (16, 38), (28, 32), (30, 14)):
        d.point([(x, y), (x - 1, y - 1), (x + 1, y - 1)], fill=(110, 150, 70, 255))
    return clip(img)


def t_lava():
    img = tile_base([(48, 30, 30), (64, 38, 34), (80, 46, 38)], 14)
    d = ImageDraw.Draw(img)
    rnd = random.Random(5)
    for _ in range(5):
        x, y = rnd.randrange(6, 34), rnd.randrange(6, 40)
        for _ in range(rnd.randint(5, 10)):
            nx, ny = x + rnd.choice((-1, 0, 1)), y + rnd.choice((0, 1))
            d.line([(x, y), (nx, ny)], fill=(255, 120, 40, 255))
            x, y = nx, ny
    for x, y in ((12, 14), (26, 30), (16, 34)):
        d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=(255, 140, 40, 255))
        d.point((x - 1, y - 1), fill=(255, 230, 120, 255))
    return clip(img)


def t_circle():
    img = tile_base([(46, 36, 72), (58, 46, 90), (70, 56, 106)], 15)
    d = ImageDraw.Draw(img)
    cx, cy = 19.5, 22.5
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], outline=(190, 160, 255, 255))
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], outline=(150, 120, 230, 255))
    pts = [(cx + math.cos(math.radians(-90 + 144 * k)) * 12, cy + math.sin(math.radians(-90 + 144 * k)) * 12) for k in range(6)]
    d.line(pts, fill=(210, 190, 255, 255))
    for a in range(0, 360, 45):
        d.point((cx + math.cos(math.radians(a)) * 16, cy + math.sin(math.radians(a)) * 16), fill=(240, 230, 255, 255))
    return clip(img)


def t_rock():
    img = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 34, 36, 44], fill=(0, 0, 0, 70))
    d.polygon([(6, 38), (4, 24), (12, 10), (26, 8), (36, 20), (36, 36), (24, 42), (12, 42)], fill=(104, 100, 98, 255), outline=OUTL)
    d.polygon([(10, 22), (14, 12), (26, 10), (30, 18), (20, 22)], fill=(144, 140, 134, 255))
    d.polygon([(8, 36), (20, 30), (34, 34), (24, 40), (12, 40)], fill=(78, 74, 74, 255))
    d.line([(20, 22), (24, 30)], fill=OUTL)
    d.point([(16, 14), (17, 14)], fill=(190, 186, 180, 255))
    return clip(img)


TILES = {"forest": t_forest, "water": t_water, "hill": t_hill, "lava": t_lava, "circle": t_circle, "rock": t_rock}

if __name__ == "__main__":
    for i, (el, spec) in enumerate(REGIONS.items()):
        make_bg(el, spec, 100 + i * 17)
    for name, fn in TILES.items():
        fn().save(os.path.join(OUT, f"tile_{name}.png"))
    print("battle art:", len(REGIONS), "bg,", len(TILES), "tiles")
