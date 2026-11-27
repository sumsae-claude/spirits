# 32x32 도트 정령 시안 → 외곽선 자동 → x10 확대
from PIL import Image, ImageDraw
import sys
OUT = sys.argv[1]
N = 32
OUTLINE = (40, 30, 45, 255)

def base():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))

def outline(img):
    px = img.load(); out = img.copy(); po = out.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][3] == 0:
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < N and 0 <= ny < N and px[nx, ny][3] > 0 and px[nx, ny] != OUTLINE:
                        po[x, y] = OUTLINE; break
    return out

def face(d, cx, cy, eye_gap=4, blush=(255, 150, 160, 255)):
    for ex in (cx - eye_gap, cx + eye_gap - 1):
        d.rectangle([ex, cy, ex + 1, cy + 2], fill=(35, 25, 40, 255))
        d.point((ex, cy), fill=(255, 255, 255, 255))
    d.point((cx - 1, cy + 4), fill=(35, 25, 40, 255)); d.point((cx, cy + 4), fill=(35, 25, 40, 255))
    d.point((cx - 2, cy + 3), fill=(35, 25, 40, 255)); d.point((cx + 1, cy + 3), fill=(35, 25, 40, 255))
    d.rectangle([cx - eye_gap - 2, cy + 3, cx - eye_gap - 1, cy + 3], fill=blush)
    d.rectangle([cx + eye_gap, cy + 3, cx + eye_gap + 1, cy + 3], fill=blush)

def emberbean():  # 불씨콩: 콩 몸통 + 머리 불꽃
    img = base(); d = ImageDraw.Draw(img)
    d.ellipse([8, 12, 24, 28], fill=(232, 96, 60, 255))
    d.ellipse([10, 14, 18, 20], fill=(250, 140, 90, 255))       # 하이라이트
    d.ellipse([9, 22, 23, 28], fill=(200, 70, 50, 255))          # 아랫면 그림자
    d.polygon([(16, 3), (20, 9), (19, 13), (13, 13), (12, 9)], fill=(255, 170, 40, 255))
    d.polygon([(16, 6), (18, 10), (17, 12), (15, 12), (14, 10)], fill=(255, 235, 120, 255))
    d.rectangle([11, 28, 13, 29], fill=(170, 60, 45, 255)); d.rectangle([19, 28, 21, 29], fill=(170, 60, 45, 255))
    face(d, 16, 18)
    return outline(img)

def dewdrop():  # 물방울이: 물방울 모양 젤리
    img = base(); d = ImageDraw.Draw(img)
    d.polygon([(16, 4), (22, 13), (9, 13)], fill=(80, 150, 240, 255))
    d.ellipse([7, 10, 25, 28], fill=(80, 150, 240, 255))
    d.ellipse([9, 22, 23, 28], fill=(55, 115, 210, 255))
    d.ellipse([10, 12, 14, 17], fill=(200, 230, 255, 255))      # 반짝임
    d.point((15, 8), fill=(200, 230, 255, 255))
    face(d, 16, 18, blush=(255, 160, 190, 255))
    for bx, by in ((4, 8), (27, 12), (26, 5)):
        d.ellipse([bx, by, bx + 2, by + 2], outline=(140, 200, 255, 255))
    return outline(img)

def sprout():  # 새싹이: 동그란 몸 + 새싹 두 장
    img = base(); d = ImageDraw.Draw(img)
    d.ellipse([7, 12, 25, 28], fill=(140, 205, 90, 255))
    d.ellipse([9, 14, 16, 19], fill=(185, 230, 130, 255))
    d.ellipse([8, 22, 24, 28], fill=(105, 170, 70, 255))
    d.line([(16, 12), (16, 7)], fill=(90, 150, 60, 255), width=1)
    d.ellipse([9, 4, 16, 8], fill=(80, 190, 80, 255))
    d.ellipse([16, 2, 23, 7], fill=(80, 190, 80, 255))
    d.point((12, 6), fill=(150, 235, 140, 255)); d.point((19, 4), fill=(150, 235, 140, 255))
    d.rectangle([10, 28, 13, 29], fill=(80, 150, 60, 255)); d.rectangle([19, 28, 22, 29], fill=(80, 150, 60, 255))
    face(d, 16, 18)
    return outline(img)

def breezebird():  # 산들새: 동그란 새 + 바람 머리깃
    img = base(); d = ImageDraw.Draw(img)
    d.ellipse([7, 10, 25, 27], fill=(205, 238, 245, 255))
    d.ellipse([9, 12, 16, 17], fill=(240, 252, 255, 255))
    d.ellipse([10, 20, 22, 27], fill=(255, 255, 255, 255))     # 배
    d.ellipse([3, 15, 10, 21], fill=(150, 210, 225, 255))     # 날개
    d.ellipse([22, 15, 29, 21], fill=(150, 210, 225, 255))
    d.arc([12, 3, 20, 11], 180, 360, fill=(120, 200, 220, 255))   # 머리깃 회오리
    d.arc([15, 5, 21, 11], 200, 380, fill=(120, 200, 220, 255))
    d.polygon([(15, 19), (17, 19), (16, 21)], fill=(255, 170, 60, 255))  # 부리
    for ex in (12, 19):
        d.rectangle([ex, 15, ex + 1, 17], fill=(35, 25, 40, 255)); d.point((ex, 15), fill=(255, 255, 255, 255))
    d.rectangle([10, 18, 11, 18], fill=(255, 160, 170, 255)); d.rectangle([21, 18, 22, 18], fill=(255, 160, 170, 255))
    d.rectangle([13, 27, 14, 28], fill=(255, 170, 60, 255)); d.rectangle([18, 27, 19, 28], fill=(255, 170, 60, 255))
    return outline(img)

for name, fn in (("breezebird", breezebird), ("emberbean", emberbean), ("sprout", sprout), ("dewdrop", dewdrop)):
    im = fn()
    im.save(f"{OUT}/pixel_{name}_32.png")
    im.resize((N * 10, N * 10), Image.NEAREST).save(f"{OUT}/pixel_{name}.png")
print("pixel done")
