class_name HexGrid
extends RefCounted
## 위쪽이 뾰족한(pointy-top) 육각 그리드. 칸 좌표는 odd-r 오프셋(Vector2i(열, 행)).
## 홀수 행이 반 칸 오른쪽으로 밀려 있다. 거리 계산은 axial 좌표로 변환해서 한다.

const SQRT3 := 1.7320508075688772
const EVEN_DIRS := [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const ODD_DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]

var cols: int
var rows: int
var size: float       # 육각형 중심~꼭짓점 거리
var origin: Vector2   # (0, 0) 칸의 중심 픽셀 좌표
var blocked: Dictionary = {}  # Vector2i -> true (바위 등 장애물)


func _init(p_cols: int, p_rows: int, p_size: float, p_origin: Vector2) -> void:
	cols = p_cols
	rows = p_rows
	size = p_size
	origin = p_origin


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not blocked.has(c)


func to_pixel(c: Vector2i) -> Vector2:
	var x := origin.x + SQRT3 * size * (float(c.x) + 0.5 * float(c.y & 1))
	var y := origin.y + 1.5 * size * float(c.y)
	return Vector2(x, y)


func from_pixel(p: Vector2) -> Vector2i:
	var local := p - origin
	var fq := (SQRT3 / 3.0 * local.x - local.y / 3.0) / size
	var fr := (2.0 / 3.0 * local.y) / size
	return axial_to_offset(_axial_round(fq, fr))


static func offset_to_axial(c: Vector2i) -> Vector2i:
	return Vector2i(c.x - ((c.y - (c.y & 1)) >> 1), c.y)


static func axial_to_offset(a: Vector2i) -> Vector2i:
	return Vector2i(a.x + ((a.y - (a.y & 1)) >> 1), a.y)


static func _axial_round(fq: float, fr: float) -> Vector2i:
	var fs := -fq - fr
	var q := roundf(fq)
	var r := roundf(fr)
	var s := roundf(fs)
	var dq := absf(q - fq)
	var dr := absf(r - fr)
	var ds := absf(s - fs)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))


func distance(a: Vector2i, b: Vector2i) -> int:
	var aa := offset_to_axial(a)
	var bb := offset_to_axial(b)
	var dq := aa.x - bb.x
	var dr := aa.y - bb.y
	return int((absi(dq) + absi(dr) + absi(dq + dr)) / 2.0)


func neighbors(c: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array = ODD_DIRS if (c.y & 1) == 1 else EVEN_DIRS
	for d in dirs:
		var n: Vector2i = c + d
		if in_bounds(n):
			result.append(n)
	return result


## start에서 move 칸 이내로 갈 수 있는 칸 -> 이동 비용 (start 제외).
## occupied에 있는 칸(다른 유닛)은 지나갈 수도, 멈출 수도 없다.
func reachable(start: Vector2i, move: int, occupied: Dictionary) -> Dictionary:
	var costs := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var cost: int = costs[cur]
		if cost >= move:
			continue
		for n in neighbors(cur):
			if costs.has(n) or not is_walkable(n) or occupied.has(n):
				continue
			costs[n] = cost + 1
			frontier.append(n)
	costs.erase(start)
	return costs


func corners(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
