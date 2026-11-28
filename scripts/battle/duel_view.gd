class_name DuelView
extends Control
## '전투 중' 연출 창 (원작처럼): 공격할 때마다 두 유닛을 작은 전장에 띄워 공격 → 피격 → 반격을 보여 준다.
## 화면을 누르면 남은 연출을 건너뛴다. '?' 도움말에서 연출 자체를 끌 수 있다 (flags.battle_anim).

const W := 680.0
const FIELD_H := 200.0

var skip := false
var _panel: PanelContainer
var _field: Control
var _sprites := [null, null]      # 0 = 왼쪽(공격), 1 = 오른쪽(방어)
var _bars := [null, null]
var _hp_labels := [null, null]
var _heads := [null, null]
var _home := [Vector2.ZERO, Vector2.ZERO]
var _max_hp := [1, 1]
var _mp_bars := [null, null]
var _mp_labels := [null, null]
var _max_mp := [1, 1]


static func open(parent: Control, left: Spirit, right: Spirit, bg: Texture2D, left_col: Color, right_col: Color) -> DuelView:
	var d := DuelView.new()
	parent.add_child(d)
	d._build(left, right, bg, left_col, right_col)
	return d


func _build(left: Spirit, right: Spirit, bg: Texture2D, left_col: Color, right_col: Color) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.11, 0.16, 0.97)
	st.border_color = UIKit.GOLD.darkened(0.2)
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", st)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(W, 0)
	_panel.position = Vector2((720.0 - W) * 0.5, 300.0)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)
	vb.add_child(UIKit.label("전투 중", 20, UIKit.GOLD))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	for i in 2:
		var l := UIKit.label("", 19, Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(l)
		_heads[i] = l
	_field = Control.new()
	_field.custom_minimum_size = Vector2(W - 20.0, FIELD_H)
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_field)
	var back := TextureRect.new() if bg != null else null
	if back != null:
		back.texture = bg
		back.stretch_mode = TextureRect.STRETCH_TILE
		back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.modulate = Color(0.85, 0.85, 0.85)
		_field.add_child(back)
	else:
		var cr := ColorRect.new()
		cr.color = Color(0.25, 0.4, 0.22)
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_field.add_child(cr)
	var spirits := [left, right]
	var cols := [left_col, right_col]
	for i in 2:
		var s: Spirit = spirits[i]
		var tr := TextureRect.new()
		tr.texture = GameData.sprite_for(s)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(112, 112)
		tr.pivot_offset = Vector2(56, 56)
		tr.flip_h = i == 1
		var home := Vector2(110.0 if i == 0 else W - 20.0 - 110.0 - 112.0, 30.0)
		tr.position = home
		_home[i] = home
		_field.add_child(tr)
		_sprites[i] = tr
		# HP 막대
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0, 0, 0, 0.7)
		bar_bg.size = Vector2(170, 14)
		bar_bg.position = Vector2(home.x - 29.0, FIELD_H - 44.0)
		_field.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = Color(0.4, 0.9, 0.45)
		bar.size = Vector2(170, 14)
		bar.position = bar_bg.position
		_field.add_child(bar)
		_bars[i] = bar
		var hl := _lbl("", 16, cols[i])
		hl.position = Vector2(home.x - 29.0, FIELD_H - 68.0)
		_field.add_child(hl)
		_hp_labels[i] = hl
		_max_hp[i] = maxi(1, s.max_hp())
		_set_hp(i, s.hp)
		# MP 막대 (스킬을 쓰면 줄어든다)
		var mbg := ColorRect.new()
		mbg.color = Color(0, 0, 0, 0.7)
		mbg.size = Vector2(170, 10)
		mbg.position = Vector2(home.x - 29.0, FIELD_H - 26.0)
		_field.add_child(mbg)
		var mbar := ColorRect.new()
		mbar.color = Color(0.45, 0.65, 1.0)
		mbar.size = Vector2(170, 10)
		mbar.position = mbg.position
		_field.add_child(mbar)
		_mp_bars[i] = mbar
		var ml := _lbl("", 14, Color(0.7, 0.8, 1.0))
		ml.position = Vector2(home.x + 146.0, FIELD_H - 32.0)
		_field.add_child(ml)
		_mp_labels[i] = ml
		_max_mp[i] = maxi(1, s.max_mp())
		_set_mp(i, s.mp)
	var tip := UIKit.label("화면을 누르면 넘김 · '?'에서 연출 끄기", 15, UIKit.MUTED)
	vb.add_child(tip)


static func _lbl(text: String, size: int, col: Color) -> Label:
	var l := UIKit.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func set_header(left_text: String, right_text: String) -> void:
	_heads[0].text = left_text
	_heads[1].text = right_text


func _set_hp(i: int, hp: int) -> void:
	var r := clampf(float(hp) / float(_max_hp[i]), 0.0, 1.0)
	(_bars[i] as ColorRect).size.x = 170.0 * r
	(_bars[i] as ColorRect).color = Color(0.4, 0.9, 0.45) if r > 0.5 else (Color(1.0, 0.8, 0.3) if r > 0.25 else Color(1.0, 0.35, 0.3))
	(_hp_labels[i] as Label).text = "HP %d/%d" % [maxi(0, hp), _max_hp[i]]


func _set_mp(i: int, mp: int) -> void:
	(_mp_bars[i] as ColorRect).size.x = 170.0 * clampf(float(mp) / float(_max_mp[i]), 0.0, 1.0)
	(_mp_labels[i] as Label).text = "MP %d" % maxi(0, mp)


## 스킬 MP 소비: 이전 값에서 줄어드는 모습 + "MP-5"
func spend_mp(side: int, before: int, after: int) -> void:
	_set_mp(side, before)
	if skip:
		_set_mp(side, after)
		return
	var bar: ColorRect = _mp_bars[side]
	var tw := create_tween()
	tw.tween_property(bar, "size:x", 170.0 * clampf(float(after) / float(_max_mp[side]), 0.0, 1.0), 0.3)
	_float(side, "MP-%d" % (before - after), Color(0.55, 0.75, 1.0), 24, 40.0)
	await _wait(0.3)
	_set_mp(side, after)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip = true
		accept_event()


func _wait(sec: float) -> void:
	if skip or not is_inside_tree():
		return
	await get_tree().create_timer(sec).timeout


## side(0/1)가 상대에게 공격: melee = 돌진, 아니면 투사체
func attack(side: int, melee: bool, col: Color) -> void:
	if skip:
		return
	var spr: TextureRect = _sprites[side]
	var other: TextureRect = _sprites[1 - side]
	var dir := 1.0 if side == 0 else -1.0
	if melee:
		var tw := create_tween()
		tw.tween_property(spr, "position", _home[side] + Vector2(-14.0 * dir, 0), 0.1)
		tw.tween_property(spr, "position", _home[1 - side] + Vector2(-70.0 * dir, 0), 0.16).set_ease(Tween.EASE_IN)
		await tw.finished
		_spark(other.position + Vector2(56, 56), col)
		var back := create_tween()
		back.tween_property(spr, "position", _home[side], 0.2)
	else:
		var hop := create_tween()
		hop.tween_property(spr, "position", _home[side] + Vector2(0, -18), 0.1)
		hop.tween_property(spr, "position", _home[side], 0.1)
		await hop.finished
		var orb := ColorRect.new()
		orb.color = col
		orb.size = Vector2(22, 22)
		orb.pivot_offset = Vector2(11, 11)
		orb.rotation = 0.785
		orb.position = spr.position + Vector2(45, 45)
		_field.add_child(orb)
		var fly := create_tween()
		fly.tween_property(orb, "position", other.position + Vector2(45, 45), 0.25)
		await fly.finished
		orb.queue_free()
		_spark(other.position + Vector2(56, 56), col)
	await _wait(0.05)


func _spark(at: Vector2, col: Color) -> void:
	for k in 6:
		var p := ColorRect.new()
		p.color = col.lightened(0.3)
		p.size = Vector2(10, 10)
		p.position = at - Vector2(5, 5)
		_field.add_child(p)
		var ang := TAU * k / 6.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", at + Vector2(cos(ang), sin(ang)) * 46.0, 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(p.queue_free)


func _float(side: int, text: String, col: Color, size: int = 34, dy: float = 0.0) -> void:
	var l := _lbl(text, size, col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.position = _home[side] + Vector2(20, -10 + dy)
	_field.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 30.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func show_hit(side: int, dmg: int, hp: int) -> void:
	var spr: TextureRect = _sprites[side]
	_set_hp(side, hp)
	if skip:
		return
	_float(side, str(dmg), Color(1.0, 0.95, 0.6))
	spr.modulate = Color(1.0, 0.4, 0.4)
	var sh := create_tween()
	sh.tween_property(spr, "position", _home[side] + Vector2(8, 0), 0.04)
	sh.tween_property(spr, "position", _home[side] + Vector2(-8, 0), 0.05)
	sh.tween_property(spr, "position", _home[side], 0.04)
	sh.parallel().tween_property(spr, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		sh.tween_property(spr, "modulate:a", 0.0, 0.35)
	await _wait(0.45)


func show_miss(side: int) -> void:
	if skip:
		return
	_float(side, "빗나감", Color(0.8, 0.85, 0.95), 28)
	var spr: TextureRect = _sprites[side]
	var dodge := create_tween()
	dodge.tween_property(spr, "position", _home[side] + Vector2(0 if side == 0 else 0, -26), 0.1)
	dodge.tween_property(spr, "position", _home[side], 0.12)
	await _wait(0.4)


func show_text(side: int, text: String, col: Color) -> void:
	if skip:
		return
	_float(side, text, col, 26)
	await _wait(0.3)


## 가운데 큰 글자 (반격! 등)
func banner(text: String, col: Color) -> void:
	if skip:
		return
	var l := _lbl(text, 46, col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.size = Vector2(W - 20.0, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, FIELD_H * 0.5 - 40.0)
	_field.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.08, 1.08), 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.tween_callback(l.queue_free)
	await _wait(0.5)


## 디스펠: side(0/1)에서 상대에게 금빛 실이 뻗는다
func thread(side: int) -> void:
	if skip:
		return
	var a: TextureRect = _sprites[side]
	var b: TextureRect = _sprites[1 - side]
	var from := a.position + Vector2(56, 50)
	var to := b.position + Vector2(56, 56)
	var hop := create_tween()
	hop.tween_property(a, "position", _home[side] + Vector2(0, -14), 0.1)
	hop.tween_property(a, "position", _home[side], 0.1)
	await hop.finished
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.85, 0.4)
	line.points = PackedVector2Array([from, from])
	_field.add_child(line)
	var steps := 10
	for k in steps:
		if skip:
			break
		var t := float(k + 1) / steps
		var p := from.lerp(to, t) + Vector2(0, sin(t * PI * 3.0) * 10.0 * (1.0 - t))
		line.add_point(p)
		await _wait(0.03)
	_thread_line = line
	await _wait(0.15)


var _thread_line: Line2D = null


## 디스펠 성공: 금빛 고리로 감싸며 사라지고 "GET!"
func seal(side: int) -> void:
	var spr: TextureRect = _sprites[side]
	if skip:
		spr.modulate.a = 0.0
		return
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = Color(1.0, 0.85, 0.4)
	var c := spr.position + Vector2(56, 60)
	var pts := PackedVector2Array()
	for k in 25:
		var ang := TAU * k / 24.0
		pts.append(c + Vector2(cos(ang) * 64.0, sin(ang) * 28.0))
	ring.points = pts
	_field.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(0.9, 0.9), 0.0)
	tw.parallel().tween_property(spr, "modulate", Color(1.0, 0.9, 0.5, 1.0), 0.2)
	tw.tween_property(spr, "scale", Vector2(0.2, 0.2), 0.35)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	if _thread_line != null:
		tw.parallel().tween_property(_thread_line, "modulate:a", 0.0, 0.3)
	await banner("GET!", Color(1.0, 0.88, 0.4))
	await _wait(0.2)


## 디스펠 실패: 실이 끊기고 "저항!"
func resist(side: int) -> void:
	if skip:
		return
	if _thread_line != null:
		var tw := create_tween()
		tw.tween_property(_thread_line, "modulate", Color(1, 1, 1, 0), 0.25)
	var spr: TextureRect = _sprites[side]
	var sh := create_tween()
	sh.tween_property(spr, "position", _home[side] + Vector2(10, 0), 0.05)
	sh.tween_property(spr, "position", _home[side] + Vector2(-10, 0), 0.06)
	sh.tween_property(spr, "position", _home[side], 0.05)
	await banner("저항!", Color(0.6, 0.9, 1.0))


func finish() -> void:
	await _wait(0.35)
	queue_free()
