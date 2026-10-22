extends CanvasLayer
# All menus and HUD, built in code (RTL Arabic by default).

const Data = preload("res://scripts/data.gd")

const GREEN := Color("1c9a4d")
const GOLD := Color("f2c14e")
const RED := Color("ce1126")
const DARK := Color(0.06, 0.09, 0.11, 0.90)

var game
var root: Control
var font: SystemFont
var theme_res: Theme
var screens := {}
var current := ""

var hud_score: Label
var hud_dist: Label
var hud_coins: Label
var pu_rows := {}
var banner: Label
var banner_sub: Label
var menu_coins: Label
var menu_best: Label
var go_title: Label
var go_score: Label
var go_info: Label
var go_revive: Button
var shop_list: VBoxContainer
var shop_coins: Label
var ward_list: HBoxContainer
var ward_coins: Label
var miss_list: VBoxContainer
var daily_label: Label
var music_btn: Button
var sfx_btn: Button
var quality_btn: Button
var toast_label: Label

# ------------------------------------------------------------ decorative controls

class Sunburst extends Control:
	var t := 0.0
	var center := Vector2(540, 380)
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		t += dt
		queue_redraw()
	func _draw() -> void:
		for i in 14:
			var a0 := t * 0.12 + i * TAU / 14.0
			var a1 := a0 + TAU / 28.0
			var pts := PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * 1500.0, center + Vector2(cos(a1), sin(a1)) * 1500.0])
			draw_colored_polygon(pts, Color(1, 0.93, 0.6, 0.07))
		for r in [250.0, 300.0, 345.0]:
			draw_arc(center, r, 0.0, TAU, 72, Color(0.95, 0.8, 0.35, 0.18), 3.0)
		var star := PackedVector2Array()
		for i in 16:
			var rr := 290.0 if i % 2 == 0 else 225.0
			var a := -t * 0.2 + i * TAU / 16.0
			star.append(center + Vector2(cos(a), sin(a)) * rr)
		star.append(star[0])
		draw_polyline(star, Color(0.97, 0.82, 0.35, 0.4), 4.0)

class Sparkles extends Control:
	var ps: Array = []
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 30:
			ps.append({"p": Vector2(randf() * 1080.0, randf() * 1920.0), "v": randf_range(20.0, 70.0), "r": randf_range(3.0, 8.0), "a": randf_range(0.2, 0.7)})
	func _process(dt: float) -> void:
		for p in ps:
			var pos: Vector2 = p["p"]
			pos.y -= float(p["v"]) * dt
			pos.x += sin(pos.y * 0.01) * 12.0 * dt
			if pos.y < -20.0:
				pos = Vector2(randf() * 1080.0, 1940.0)
			p["p"] = pos
		queue_redraw()
	func _draw() -> void:
		for p in ps:
			draw_circle(p["p"], p["r"], Color(1.0, 0.85, 0.3, p["a"]))
			draw_circle(p["p"], p["r"] * 2.2, Color(1.0, 0.85, 0.3, p["a"] * 0.18))

# ------------------------------------------------------------ helpers

func _style(col: Color, radius := 24, bw := 0, bcol := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_width_left = bw
	s.border_width_right = bw
	s.border_width_top = bw
	s.border_width_bottom = bw
	s.border_color = bcol
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

func _lbl(text: String, size := 40, col := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _btn(text: String, size: Vector2, col: Color, fsize := 44) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.pivot_offset = size * 0.5
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	b.add_theme_constant_override("outline_size", 8)
	var n := _style(col, 30, 0)
	n.border_width_bottom = 9
	n.border_color = col.darkened(0.45)
	var h := _style(col.lightened(0.12), 30, 0)
	h.border_width_bottom = 9
	h.border_color = col.darkened(0.45)
	var p := _style(col.darkened(0.08), 30, 0)
	p.border_width_bottom = 3
	p.border_color = col.darkened(0.45)
	var d := _style(Color(0.35, 0.37, 0.4), 30, 0)
	d.border_width_bottom = 9
	d.border_color = Color(0.2, 0.22, 0.24)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_down.connect(func(): _tween_scale(b, 0.94))
	b.button_up.connect(func(): _tween_scale(b, 1.0))
	b.pressed.connect(func(): Sfx.play("click"))
	return b

func _tween_scale(c: Control, s: float) -> void:
	var t := create_tween()
	t.tween_property(c, "scale", Vector2(s, s), 0.08)

func _panel(col := DARK, radius := 36) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(col, radius, 3, Color(1, 1, 1, 0.12)))
	return p

func _screen(name: String, block := true) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	screens[name] = c
	return c

func _dim(parent: Control, a := 0.6) -> void:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, a)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _dot(col: Color, size := 46) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", _style(col, size / 2, 4, col.darkened(0.35)))
	return p

func _pill(col: Color) -> Array:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.45), 40, 2, Color(1, 1, 1, 0.2)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pc.add_child(h)
	h.add_child(_dot(col))
	var l := _lbl("0", 44, Color.WHITE)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	return [pc, l]

func _flag() -> Control:
	var f := VBoxContainer.new()
	f.add_theme_constant_override("separation", 0)
	f.custom_minimum_size = Vector2(120, 78)
	var cols := [RED, Color.WHITE, Color("111111")]
	for i in 3:
		var r := ColorRect.new()
		r.color = cols[i]
		r.custom_minimum_size = Vector2(120, 26)
		f.add_child(r)
		if i == 1:
			var t := Label.new()
			t.text = "丕賱賱賴 兀賰亘乇"
			t.add_theme_font_size_override("font_size", 17)
			t.add_theme_color_override("font_color", GREEN)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			r.add_child(t)
	return f

func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	toast_label.scale = Vector2(0.8, 0.8)
	var t := create_tween()
	t.tween_property(toast_label, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK)
	t.tween_interval(1.2)
	t.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func _pop(nodes: Array) -> void:
	var i := 0
	for n in nodes:
		if not is_instance_valid(n):
			continue
		n.modulate.a = 0.0
		var base: Vector2 = n.scale
		n.scale = base * 0.7
		var t := create_tween()
		t.tween_interval(0.06 * i)
		t.tween_property(n, "modulate:a", 1.0, 0.2)
		t.parallel().tween_property(n, "scale", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

func _section_title(parent: Control, text: String) -> Label:
	var l := _lbl(text, 64, GOLD, 12)
	parent.add_child(l)
	return l

# ------------------------------------------------------------ setup

func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(g) -> void:
	game = g
	get_tree().quit_on_go_back = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans Arabic", "Noto Naskh Arabic", "Droid Arabic Naskh", "Roboto", "Arial", "sans-serif"])
	font.font_weight = 700
	theme_res = Theme.new()
	theme_res.default_font = font
	theme_res.default_font_size = 40
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme_res
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_menu()
	_build_hud()
	_build_pause()
	_build_gameover()
	_build_shop()
	_build_wardrobe()
	_build_missions()
	_build_settings()
	_build_daily()
	toast_label = _lbl("", 44, Color.WHITE, 10)
	toast_label.anchor_left = 0.0
	toast_label.anchor_right = 1.0
	toast_label.anchor_top = 1.0
	toast_label.anchor_bottom = 1.0
	toast_label.offset_left = 0
	toast_label.offset_right = 0
	toast_label.offset_top = -420
	toast_label.offset_bottom = -340
	toast_label.pivot_offset = Vector2(540, 40)
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)
	game.run_ended.connect(_on_run_ended)
	game.city_reached.connect(_on_city)
	Sfx.play_music("menu")
	show_screen("menu")
	if Save.daily_reward > 0:
		daily_label.text = "賲賰丕賮兀丞 丕賱丿禺賵賱 丕賱賷賵賲賷\n+%d 毓賲賱丞\n丕賱兀賷丕賲 丕賱賲鬲鬲丕賱賷丞: %d" % [Save.daily_reward, int(Save.d["streak"])]
		show_screen("daily")

func show_screen(name: String) -> void:
	for k in screens.keys():
		screens[k].visible = false
	current = name
	var s: Control = screens[name]
	s.visible = true
	game.menu_view = "wardrobe" if name == "wardrobe" else "home"
	match name:
		"menu":
			_pop(s.get_meta("pop"))
		"shop":
			_refresh_shop()
		"wardrobe":
			_refresh_wardrobe()
		"missions":
			_refresh_missions()
		"settings":
			_refresh_settings()

# ------------------------------------------------------------ menu

func _build_menu() -> void:
	var s := _screen("menu", false)
	var sun := Sunburst.new()
	sun.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(sun)
	var sp := Sparkles.new()
	sp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(sp)

	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 40
	top.offset_bottom = 130
	s.add_child(top)
	var cp := _pill(GOLD)
	menu_coins = cp[1]
	top.add_child(cp[0])
	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp1)
	var bp := _pill(GREEN)
	menu_best = bp[1]
	top.add_child(bp[0])

	var logo := VBoxContainer.new()
	logo.anchor_right = 1.0
	logo.offset_top = 190
	logo.offset_bottom = 560
	logo.add_theme_constant_override("separation", -10)
	s.add_child(logo)
	var l1 := _lbl("BASSAM", 190, GOLD, 26)
	l1.pivot_offset = Vector2(540, 100)
	logo.add_child(l1)
	var l2 := _lbl("亘爻丕賲", 120, Color.WHITE, 20)
	l2.pivot_offset = Vector2(540, 70)
	logo.add_child(l2)
	var l3 := _lbl("乇賰囟丞 毓亘乇 賲丿賳 丕賱毓乇丕賯", 40, Color("e8f5ec"), 8)
	logo.add_child(l3)
	var tw := create_tween().set_loops()
	tw.tween_property(l1, "scale", Vector2(1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l1, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(l1, "modulate", Color(1.0, 0.95, 0.75), 1.6).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(l1, "modulate", Color(1, 1, 1), 1.6).set_trans(Tween.TRANS_SINE)
	var tw3 := create_tween().set_loops()
	tw3.tween_property(l2, "rotation", 0.03, 1.5).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(l2, "rotation", -0.03, 1.5).set_trans(Tween.TRANS_SINE)

	var bottom := VBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -620
	bottom.offset_bottom = -28
	bottom.add_theme_constant_override("separation", 22)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	s.add_child(bottom)
	var play := _btn("丕賱毓亘 丕賱丌賳", Vector2(640, 170), GREEN, 72)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_start_run)
	bottom.add_child(play)
	var pt := create_tween().set_loops()
	pt.tween_property(play, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)
	var b1 := _btn("丕賱賲鬲噩乇", Vector2(236, 130), Color("e08a1e"), 38)
	b1.pressed.connect(func(): show_screen("shop"))
	var b2 := _btn("丕賱兀夭賷丕亍", Vector2(236, 130), Color("8e44ad"), 38)
	b2.pressed.connect(func(): show_screen("wardrobe"))
	var b3 := _btn("丕賱賲賴丕賲", Vector2(236, 130), Color("2980b9"), 38)
	b3.pressed.connect(func(): show_screen("missions"))
	var b4 := _btn("丕賱廿毓丿丕丿丕鬲", Vector2(236, 130), Color("5d6d7e"), 34)
	b4.pressed.connect(func(): show_screen("settings"))
	for b in [b1, b2, b3, b4]:
		row.add_child(b)
	var badge := HBoxContainer.new()
	badge.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_theme_constant_override("separation", 20)
	bottom.add_child(badge)
	badge.add_child(_flag())
	var bl := VBoxContainer.new()
	bl.add_theme_constant_override("separation", -6)
	badge.add_child(bl)
	bl.add_child(_lbl("氐賳毓 賮賷 丕賱毓乇丕賯", 52, Color.WHITE, 10))
	bl.add_child(_lbl("MADE IN IRAQ", 28, GOLD, 6))
	s.set_meta("pop", [play, b1, b2, b3, b4, badge])

# ------------------------------------------------------------ HUD / pause / game over

func _build_hud() -> void:
	var s := _screen("hud", false)
	var tl := VBoxContainer.new()
	tl.offset_left = 36
	tl.offset_top = 40
	tl.add_theme_constant_override("separation", -4)
	s.add_child(tl)
	hud_score = _lbl("0", 84, Color.WHITE, 14)
	hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl.add_child(hud_score)
	hud_dist = _lbl("0 賲", 40, Color("e8f5ec"), 8)
	hud_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl.add_child(hud_dist)
	var pu := VBoxContainer.new()
	pu.offset_left = 36
	pu.offset_top = 250
	pu.add_theme_constant_override("separation", 10)
	s.add_child(pu)
	for u in Data.upgrades():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.add_child(_dot(u["color"], 34))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(240, 26)
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.45), 13))
		pb.add_theme_stylebox_override("fill", _style(u["color"], 13))
		h.add_child(pb)
		h.visible = false
		pu.add_child(h)
		pu_rows[u["id"]] = {"row": h, "bar": pb}
	var tr := VBoxContainer.new()
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -330
	tr.offset_right = -30
	tr.offset_top = 40
	tr.add_theme_constant_override("separation", 14)
	s.add_child(tr)
	var cp := _pill(GOLD)
	hud_coins = cp[1]
	tr.add_child(cp[0])
	var pb2 := _btn("II", Vector2(110, 110), Color(0.15, 0.17, 0.2, 0.9), 54)
	pb2.size_flags_horizontal = Control.SIZE_SHRINK_END
	pb2.pressed.connect(_pause)
	tr.add_child(pb2)
	banner = _lbl("", 76, GOLD, 16)
	banner.anchor_right = 1.0
	banner.offset_top = 520
	banner.offset_bottom = 640
	banner.pivot_offset = Vector2(540, 60)
	banner.modulate.a = 0.0
	s.add_child(banner)
	banner_sub = _lbl("", 44, Color.WHITE, 10)
	banner_sub.anchor_right = 1.0
	banner_sub.offset_top = 630
	banner_sub.offset_bottom = 700
	banner_sub.modulate.a = 0.0
	s.add_child(banner_sub)

func _build_pause() -> void:
	var s := _screen("pause")
	_dim(s, 0.65)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(c)
	var p := _panel()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	p.add_child(v)
	v.add_child(_lbl("廿賷賯丕賮 賲丐賯鬲", 70, GOLD, 12))
	var r := _btn("賲鬲丕亘毓丞", Vector2(560, 130), GREEN, 52)
	r.pressed.connect(_resume)
	v.add_child(r)
	var h := _btn("丕賱賯丕卅賲丞 丕賱乇卅賷爻賷丞", Vector2(560, 130), RED, 46)
	h.pressed.connect(_home_from_run)
	v.add_child(h)

func _build_gameover() -> void:
	var s := _screen("gameover")
	_dim(s, 0.7)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(c)
	var p := _panel()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	p.add_child(v)
	go_title = _lbl("丕賳鬲賴鬲 丕賱噩賵賱丞", 76, GOLD, 14)
	v.add_child(go_title)
	go_score = _lbl("0", 120, Color.WHITE, 16)
	v.add_child(go_score)
	go_info = _lbl("", 42, Color("e8f5ec"), 8)
	go_info.custom_minimum_size = Vector2(700, 0)
	v.add_child(go_info)
	go_revive = _btn("兀賰賲賱  (500 毓賲賱丞)", Vector2(640, 125), Color("8e44ad"), 46)
	go_revive.pressed.connect(_revive)
	v.add_child(go_revive)
	var a := _btn("丕賱毓亘 賲噩丿丿丕賸", Vector2(640, 135), GREEN, 54)
	a.pressed.connect(_start_run)
	v.add_child(a)
	var h := _btn("丕賱賯丕卅賲丞 丕賱乇卅賷爻賷丞", Vector2(640, 115), Color("5d6d7e"), 42)
	h.pressed.connect(_home_from_run)
	v.add_child(h)

func _process(_dt: float) -> void:
	if current == "menu":
		menu_coins.text = str(int(Save.d["coins"]))
		menu_best.text = "%d" % int(Save.d["best"])
	elif current == "hud":
		hud_score.text = str(game.get_score())
		hud_dist.text = "%d 賲" % int(game.distance)
		hud_coins.text = str(game.run_coins)
		for id in pu_rows.keys():
			var t: float = game.timers[id]
			var row = pu_rows[id]
			row["row"].visible = t > 0.0
			if t > 0.0:
				row["bar"].value = t / maxf(game.durations[id], 0.1)

func _start_run() -> void:
	get_tree().paused = false
	game.start_run()
	show_screen("hud")

func _pause() -> void:
	if game.mode != "run":
		return
	get_tree().paused = true
	show_screen("pause")

func _resume() -> void:
	get_tree().paused = false
	show_screen("hud")

func _home_from_run() -> void:
	get_tree().paused = false
	game.go_menu()
	show_screen("menu")

func _revive() -> void:
	if game.revive():
		show_screen("hud")
	else:
		Sfx.play("deny")
		_toast("賱丕 鬲賲賱賰 毓賲賱丕鬲 賰丕賮賷丞")

func _on_run_ended(r: Dictionary) -> void:
	go_score.text = str(r["score"])
	go_title.text = "乇賯賲 賯賷丕爻賷 噩丿賷丿!" if r["new_best"] else "丕賳鬲賴鬲 丕賱噩賵賱丞"
	go_info.text = "丕賱賲爻丕賮丞: %d 賲\n丕賱毓賲賱丕鬲: %d\n兀賮囟賱 賳鬲賷噩丞: %d" % [r["distance"], r["coins"], r["best"]]
	go_revive.visible = r["can_revive"]
	show_screen("gameover")
	_pop([go_score, go_revive])

func _on_city(i: int) -> void:
	var c: Dictionary = Data.cities()[i]
	banner.text = "賲乇丨亘丕賸 亘賰賲 賮賷 " + c["name"]
	banner_sub.text = c["en"].to_upper()
	for l in [banner, banner_sub]:
		l.modulate.a = 0.0
	banner.scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(banner, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(banner, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(banner_sub, "modulate:a", 1.0, 0.4)
	t.tween_interval(2.0)
	t.tween_property(banner, "modulate:a", 0.0, 0.6)
	t.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.6)

# ------------------------------------------------------------ shop (power-up upgrades)

func _page(name: String, title: String) -> VBoxContainer:
	var s := _screen(name)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.08, 0.1, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 36
	v.offset_right = -36
	v.offset_top = 40
	v.offset_bottom = -40
	v.add_theme_constant_override("separation", 20)
	s.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := _btn("乇噩賵毓", Vector2(200, 100), RED, 40)
	back.pressed.connect(func(): show_screen("menu"))
	head.add_child(back)
	var ti := _lbl(title, 66, GOLD, 12)
	ti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ti)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(200, 0)
	head.add_child(spacer)
	return v

func _build_shop() -> void:
	var v := _page("shop", "賲鬲噩乇 丕賱賯丿乇丕鬲")
	var cp := _pill(GOLD)
	shop_coins = cp[1]
	cp[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cp[0])
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 18)
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(shop_list)

func _refresh_shop() -> void:
	shop_coins.text = str(int(Save.d["coins"]))
	for c in shop_list.get_children():
		c.queue_free()
	for u in Data.upgrades():
		var id: String = u["id"]
		var lvl := int(Save.d["upg"][id])
		var p := _panel(Color(0.1, 0.14, 0.17, 0.95), 30)
		shop_list.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		p.add_child(h)
		h.add_child(_dot(u["color"], 78))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -2)
		h.add_child(col)
		var nm := _lbl(u["name"], 44, Color.WHITE, 8)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(nm)
		var ds := _lbl(u["desc"], 30, Color("b8c4cc"), 4)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(ds)
		var st := _lbl("丕賱賲爻鬲賵賶 %d/%d  鈥�  丕賱賲丿丞 %.1f 孬" % [lvl, Data.MAX_LEVEL, Data.duration(id, lvl)], 30, GOLD, 4)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(st)
		var btn: Button
		if lvl >= Data.MAX_LEVEL:
			btn = _btn("丕賱丨丿 丕賱兀賯氐賶", Vector2(250, 100), Color("5d6d7e"), 32)
			btn.disabled = true
		else:
			var cost := Data.upgrade_cost(lvl)
			btn = _btn("鬲乇賯賷丞  %d" % cost, Vector2(250, 100), GREEN, 38)
			btn.pressed.connect(func(): _buy_upgrade(id, cost))
		h.add_child(btn)

func _buy_upgrade(id: String, cost: int) -> void:
	if int(Save.d["coins"]) < cost:
		Sfx.play("deny")
		_toast("賱丕 鬲賲賱賰 毓賲賱丕鬲 賰丕賮賷丞")
		return
	Save.d["coins"] = int(Save.d["coins"]) - cost
	Save.d["upg"][id] = int(Save.d["upg"][id]) + 1
	Save.save()
	Sfx.play("buy")
	_refresh_shop()

# ------------------------------------------------------------ wardrobe

func _build_wardrobe() -> void:
	var s := _screen("wardrobe", false)
	var panel := _panel(Color(0.04, 0.08, 0.1, 0.94), 44)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = -900
	panel.offset_bottom = -20
	s.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var back := _btn("乇噩賵毓", Vector2(190, 96), RED, 38)
	back.pressed.connect(func(): show_screen("menu"))
	head.add_child(back)
	var ti := _lbl("丕賱兀夭賷丕亍", 62, GOLD, 12)
	ti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ti)
	var cp := _pill(GOLD)
	ward_coins = cp[1]
	ward_coins.custom_minimum_size = Vector2(100, 0)
	head.add_child(cp[0])
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	ward_list = HBoxContainer.new()
	ward_list.add_theme_constant_override("separation", 18)
	sc.add_child(ward_list)

func _refresh_wardrobe() -> void:
	ward_coins.text = str(int(Save.d["coins"]))
	for c in ward_list.get_children():
		c.queue_free()
	var owned: Array = Save.d["owned"]
	for o in Data.outfits():
		var id: String = o["id"]
		var card := _panel(Color(0.12, 0.17, 0.2, 1.0), 30)
		card.custom_minimum_size = Vector2(310, 640)
		ward_list.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		card.add_child(v)
		var nm := _lbl(o["name"], 42, Color.WHITE, 8)
		nm.custom_minimum_size = Vector2(260, 0)
		v.add_child(nm)
		var sw := HBoxContainer.new()
		sw.alignment = BoxContainer.ALIGNMENT_CENTER
		sw.add_theme_constant_override("separation", 10)
		v.add_child(sw)
		for key in ["shirt", "pants", "shoes", "acc"]:
			sw.add_child(_dot(o[key], 52))
		var big := _dot(o["shirt"], 190)
		big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(big)
		var pr: Label
		var has := owned.has(id)
		var equipped: bool = Save.d["outfit"] == id
		var btn: Button
		if equipped:
			btn = _btn("賲購乇鬲丿賶", Vector2(260, 100), Color("5d6d7e"), 38)
			btn.disabled = true
		elif has:
			btn = _btn("丕乇鬲丿丕亍", Vector2(260, 100), GREEN, 40)
			btn.pressed.connect(func(): _equip(id))
		else:
			btn = _btn("卮乇丕亍  %d" % int(o["price"]), Vector2(260, 100), Color("e08a1e"), 36)
			btn.pressed.connect(func(): _buy_outfit(id, int(o["price"])))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(btn)
		if id == "national":
			v.add_child(_lbl("賲噩丕賳賷", 34, GOLD, 6))

func _equip(id: String) -> void:
	Save.d["outfit"] = id
	Save.save()
	game.apply_outfit()
	Sfx.play("buy")
	_refresh_wardrobe()

func _buy_outfit(id: String, price: int) -> void:
	if int(Save.d["coins"]) < price:
		Sfx.play("deny")
		_toast("賱丕 鬲賲賱賰 毓賲賱丕鬲 賰丕賮賷丞")
		return
	Save.d["coins"] = int(Save.d["coins"]) - price
	Save.d["owned"].append(id)
	Save.save()
	_equip(id)

# ------------------------------------------------------------ missions

func _build_missions() -> void:
	var v := _page("missions", "丕賱賲賴丕賲")
	miss_list = VBoxContainer.new()
	miss_list.add_theme_constant_override("separation", 22)
	miss_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(miss_list)

func _refresh_missions() -> void:
	for c in miss_list.get_children():
		c.queue_free()
	var tpl := Data.mission_templates()
	var i := 0
	for m in Save.d["missions"]:
		var idx := i
		i += 1
		var p := _panel(Color(0.1, 0.14, 0.17, 0.95), 30)
		miss_list.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		p.add_child(v)
		var t: String = tpl[m["type"]]["text"] % int(m["target"])
		v.add_child(_lbl(t, 44, Color.WHITE, 8))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 30)
		pb.show_percentage = false
		pb.max_value = float(m["target"])
		pb.value = float(m["progress"])
		pb.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 15))
		pb.add_theme_stylebox_override("fill", _style(GREEN, 15))
		v.add_child(pb)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 24)
		v.add_child(h)
		h.add_child(_lbl("%d / %d" % [int(m["progress"]), int(m["target"])], 34, Color("b8c4cc"), 4))
		h.add_child(_lbl("丕賱賲賰丕賮兀丞: %d" % int(m["reward"]), 36, GOLD, 6))
		var b := _btn("丕爻鬲賱丕賲", Vector2(230, 90), GREEN if m["done"] else Color("5d6d7e"), 38)
		b.disabled = not m["done"]
		b.pressed.connect(func(): _claim(idx))
		h.add_child(b)

func _claim(i: int) -> void:
	Save.claim_mission(i)
	Sfx.play("buy")
	_refresh_missions()

# ------------------------------------------------------------ settings & daily

func _build_settings() -> void:
	var v := _page("settings", "丕賱廿毓丿丕丿丕鬲")
	music_btn = _btn("", Vector2(700, 120), GREEN, 46)
	music_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	music_btn.pressed.connect(func():
		Sfx.set_music(not Save.d["music"])
		_refresh_settings())
	v.add_child(music_btn)
	sfx_btn = _btn("", Vector2(700, 120), GREEN, 46)
	sfx_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sfx_btn.pressed.connect(func():
		Sfx.set_sfx(not Save.d["sfx"])
		_refresh_settings())
	v.add_child(sfx_btn)
	quality_btn = _btn("", Vector2(700, 120), Color("2980b9"), 46)
	quality_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quality_btn.pressed.connect(func():
		Save.d["quality"] = 0 if int(Save.d["quality"]) > 0 else 1
		Save.save()
		game.apply_quality(true)
		_refresh_settings())
	v.add_child(quality_btn)
	var hint := _lbl("丕賱鬲丨賰賲: 丕爻丨亘 賷賲賷賳丕賸/賷爻丕乇丕賸 賱鬲睾賷賷乇 丕賱賲爻丕乇\n賱賱兀毓賱賶 賱賱賯賮夭 鈥� 賱賱兀爻賮賱 賱賱丕賳夭賱丕賯", 36, Color("b8c4cc"), 6)
	v.add_child(hint)
	var fl := HBoxContainer.new()
	fl.alignment = BoxContainer.ALIGNMENT_CENTER
	fl.add_theme_constant_override("separation", 20)
	fl.add_child(_flag())
	fl.add_child(_lbl("氐賳毓 賮賷 丕賱毓乇丕賯", 56, GOLD, 10))
	v.add_child(fl)
	v.add_child(_lbl("鬲胤賵賷乇: 亘賱丕賱 丕賱賳毓賷賲賷\nBassam v1.0.0", 38, Color.WHITE, 8))

func _refresh_settings() -> void:
	music_btn.text = "丕賱賲賵爻賷賯賶: " + ("鬲卮睾賷賱" if Save.d["music"] else "廿賷賯丕賮")
	sfx_btn.text = "丕賱賲丐孬乇丕鬲: " + ("鬲卮睾賷賱" if Save.d["sfx"] else "廿賷賯丕賮")
	quality_btn.text = "丕賱噩賵丿丞: " + ("毓丕賱賷丞" if int(Save.d["quality"]) > 0 else "賲賳禺賮囟丞 (兀爻乇毓)")

func _build_daily() -> void:
	var s := _screen("daily")
	_dim(s, 0.7)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(c)
	var p := _panel()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	p.add_child(v)
	v.add_child(_dot(GOLD, 150))
	v.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	daily_label = _lbl("", 54, Color.WHITE, 10)
	daily_label.custom_minimum_size = Vector2(700, 0)
	v.add_child(daily_label)
	var b := _btn("丕爻鬲賱丕賲", Vector2(520, 130), GREEN, 56)
	b.pressed.connect(func():
		Save.claim_daily()
		Sfx.play("buy")
		show_screen("menu"))
	v.add_child(b)

# ------------------------------------------------------------ Android back button

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and game != null:
		match current:
			"hud":
				_pause()
			"pause":
				_resume()
			"shop", "wardrobe", "missions", "settings":
				show_screen("menu")
			"gameover":
				_home_from_run()
			"menu":
				get_tree().quit()
