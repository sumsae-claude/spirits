"""UI 아이콘 도트 생성기. 사용: python3 tools/art/ui_icons.py <프로젝트 루트>
출력: assets/ui/coin.png (16x16, 게임에서 확대해 씀)"""
import sys, os
from PIL import Image, ImageDraw
OUT = os.path.join(sys.argv[1], "assets", "ui")
os.makedirs(OUT, exist_ok=True)
OL = (90, 52, 20, 255)
img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.ellipse([1, 1, 14, 14], fill=(232, 168, 40, 255), outline=OL)       # 테두리·몸
d.ellipse([3, 3, 12, 12], fill=(255, 205, 70, 255))                  # 안쪽
d.ellipse([4, 4, 11, 11], outline=(214, 140, 30, 255))               # 안쪽 고리
d.rectangle([7, 5, 8, 10], fill=(214, 140, 30, 255))                 # 가운데 무늬 (정령의 실 매듭)
d.point([(6, 6), (9, 6), (6, 9), (9, 9)], fill=(214, 140, 30, 255))
d.point([(4, 5), (5, 4)], fill=(255, 245, 190, 255))                 # 반짝임
d.point([(5, 5)], fill=(255, 255, 230, 255))
img.save(os.path.join(OUT, "coin.png"))
print("coin")
