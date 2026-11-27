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
var blocked: Dictionary = {}  # Vector2i -> true (바위 등 지나갈 수 없는 칸)
var terrain: Dictionary = {}  # Vector2i -> 지형 id (없으면 "plain")


func _init(p_cols: int, p_rows: int, p_size: float, p_origin: Vector2) -> void:
	cols = p_cols
	rows = p_rows
	size = p_size
	origin = p_origin


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func terrain_at(c: Vector2i) -> String:
	return str(terrain.get(c, "plain"))


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


## start에서 이동력 move 이내로 갈 수 있는 칸 -> 누적 이동 비용 (start 제외).
## cost_fn(칸) -> int 는 그 칸에 들어갈 때 드는 비용. (지형별로 다름)
## occupied에 있는 칸(다른 유닛)은 지나갈 수도, 멈출 수도 없다.
func reachable(start: Vector2i, move: int, occupied: Dictionary, cost_fn: Callable) -> Dictionary:
	var costs := {start: 0}
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		# 비용이 가장 낮은 칸부터 (맵이 작아 선형 탐색으로 충분한 다익스트라)
		var best_i := 0
		for i in range(1, open.size()):
			if int(costs[open[i]]) < int(costs[open[best_i]]):
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		var cost: int = costs[cur]
		for n in neighbors(cur):
			if not is_walkable(n) or occupied.has(n):
				continue
			var next_cost: int = cost + int(cost_fn.call(n))
			if next_cost > move:
				continue
			if not costs.has(n) or next_cost < int(costs[n]):
				costs[n] = next_cost
				if not open.has(n):
					open.append(n)
	costs.erase(start)
	return costs


func corners(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
