extends CanvasLayer
# All menus and HUD, built in code (RTL Arabic by default).

const Data = preload("res://scripts/data.gd")

const GREEN := Color("1c9a4d")
const GOLD := Color("f2c14e")
const RED := Color("ce1126")
const DARK := Color(0.06, 0.09, 0.11, 0.90)

var game
var root: Control
var font: Font
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

func _load_font() -> Font:
	if ResourceLoader.exists("res://fonts/arabic.ttf"):
		return load("res://fonts/arabic.ttf")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans Arabic", "Noto Naskh Arabic", "Droid Arabic Naskh", "Arial", "sans-serif"])
	return f

func _ar(s: String) -> String:
	var out := ""
	for ch in s:
		var i := "0123456789".find(ch)
		if i >= 0:
			out += "٠١٢٣٤٥٦٧٨٩"[i]
		else:
			out += ch
	return out

func _made_badge() -> Control:
	var pc := PanelContainer.new()
	var st := _style(Color("14663a"), 40, 4, GOLD)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 10
	st.content_margin_left = 44
	st.content_margin_right = 44
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", st)
	pc.add_child(_lbl("صنع في العراق", 52, Color.WHITE, 8))
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return pc


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
	l.text = _ar(text)
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
	b.text = _ar(text)
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

func _toast(text: String) -> void:
	toast_label.text = _ar(text)
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
	font = _load_font()
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
		daily_label.text = _ar("مكافأة الدخول اليومي\n+%d عملة\nالأيام المتتالية: %d" % [Save.daily_reward, int(Save.d["streak"])])
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
	var vg := ColorRect.new()
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shd := Shader.new()
	shd.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat v = smoothstep(0.30, 0.80, length(uv * vec2(1.0, 0.72)));\n\tfloat top = smoothstep(0.42, 0.0, UV.y) * 0.45;\n\tfloat bot = smoothstep(0.60, 1.0, UV.y) * 0.62;\n\tCOLOR = vec4(0.02, 0.05, 0.04, clamp(v * 0.45 + top + bot, 0.0, 0.88));\n}\n"
	var smat := ShaderMaterial.new()
	smat.shader = shd
	vg.material = smat
	s.add_child(vg)
	var sun := Sunburst.new()
	sun.center = Vector2(540, 300)
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
	logo.offset_top = 150
	logo.offset_bottom = 480
	logo.add_theme_constant_override("separation", 6)
	s.add_child(logo)
	var l1 := _lbl("بسام", 230, GOLD, 34)
	l1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l1.add_theme_constant_override("shadow_offset_x", 0)
	l1.add_theme_constant_override("shadow_offset_y", 12)
	l1.custom_minimum_size = Vector2(0, 250)
	l1.pivot_offset = Vector2(540, 125)
	logo.add_child(l1)
	var deco := HBoxContainer.new()
	deco.alignment = BoxContainer.ALIGNMENT_CENTER
	deco.add_theme_constant_override("separation", 18)
	logo.add_child(deco)
	var ln1 := ColorRect.new()
	ln1.color = GOLD
	ln1.custom_minimum_size = Vector2(190, 4)
	ln1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deco.add_child(ln1)
	var dia := Panel.new()
	dia.custom_minimum_size = Vector2(24, 24)
	dia.pivot_offset = Vector2(12, 12)
	dia.rotation = PI * 0.25
	dia.add_theme_stylebox_override("panel", _style(GOLD, 3, 0))
	deco.add_child(dia)
	var ln2 := ColorRect.new()
	ln2.color = GOLD
	ln2.custom_minimum_size = Vector2(190, 4)
	ln2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deco.add_child(ln2)
	var l3 := _lbl("ركضة عبر مدن لا تنتهي", 46, Color("fff4d6"), 8)
	logo.add_child(l3)
	var tw := create_tween().set_loops()
	tw.tween_property(l1, "scale", Vector2(1.04, 1.04), 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l1, "scale", Vector2(1.0, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(l1, "modulate", Color(1.0, 0.96, 0.8), 1.8).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(l1, "modulate", Color(1, 1, 1), 1.8).set_trans(Tween.TRANS_SINE)
	var tw3 := create_tween().set_loops()
	tw3.tween_property(dia, "rotation", TAU, 6.0).as_relative()

	var bottom := VBoxContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -600
	bottom.offset_bottom = -34
	bottom.add_theme_constant_override("separation", 26)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	s.add_child(bottom)
	var play := _btn("ابدأ الجري", Vector2(760, 176), GREEN, 82)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_start_run)
	bottom.add_child(play)
	var pt := create_tween().set_loops()
	pt.tween_property(play, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	var row := GridContainer.new()
	row.columns = 4
	row.add_theme_constant_override("h_separation", 14)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(row)
	var b1 := _btn("المتجر", Vector2(236, 128), Color("e08a1e"), 40)
	b1.pressed.connect(func(): show_screen("shop"))
	var b2 := _btn("الأزياء", Vector2(236, 128), Color("8e44ad"), 40)
	b2.pressed.connect(func(): show_screen("wardrobe"))
	var b3 := _btn("المهام", Vector2(236, 128), Color("2980b9"), 40)
	b3.pressed.connect(func(): show_screen("missions"))
	var b4 := _btn("الإعدادات", Vector2(236, 128), Color("5d6d7e"), 36)
	b4.pressed.connect(func(): show_screen("settings"))
	for b in [b1, b2, b3, b4]:
		row.add_child(b)
	var badge := _made_badge()
	bottom.add_child(badge)
	s.set_meta("pop", [play, b1, b2, b3, b4, badge, l3])

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
	hud_dist = _lbl("0 م", 40, Color("e8f5ec"), 8)
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
	v.add_child(_lbl("إيقاف مؤقت", 70, GOLD, 12))
	var r := _btn("متابعة", Vector2(560, 130), GREEN, 52)
	r.pressed.connect(_resume)
	v.add_child(r)
	var h := _btn("القائمة الرئيسية", Vector2(560, 130), RED, 46)
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
	go_title = _lbl("انتهت الجولة", 76, GOLD, 14)
	v.add_child(go_title)
	go_score = _lbl("0", 120, Color.WHITE, 16)
	v.add_child(go_score)
	go_info = _lbl("", 42, Color("e8f5ec"), 8)
	go_info.custom_minimum_size = Vector2(700, 0)
	v.add_child(go_info)
	go_revive = _btn("أكمل  (500 عملة)", Vector2(640, 125), Color("8e44ad"), 46)
	go_revive.pressed.connect(_revive)
	v.add_child(go_revive)
	var a := _btn("العب مجدداً", Vector2(640, 135), GREEN, 54)
	a.pressed.connect(_start_run)
	v.add_child(a)
	var h := _btn("القائمة الرئيسية", Vector2(640, 115), Color("5d6d7e"), 42)
	h.pressed.connect(_home_from_run)
	v.add_child(h)

func _process(_dt: float) -> void:
	if current == "menu":
		menu_coins.text = _ar(str(int(Save.d["coins"])))
		menu_best.text = _ar("%d" % int(Save.d["best"]))
	elif current == "hud":
		hud_score.text = _ar(str(game.get_score()))
		hud_dist.text = _ar("%d م" % int(game.distance))
		hud_coins.text = _ar(str(game.run_coins))
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
		_toast("لا تملك عملات كافية")

func _on_run_ended(r: Dictionary) -> void:
	go_score.text = _ar(str(r["score"]))
	go_title.text = "رقم قياسي جديد!" if r["new_best"] else "انتهت الجولة"
	go_info.text = _ar("المسافة: %d م\nالعملات: %d\nأفضل نتيجة: %d" % [r["distance"], r["coins"], r["best"]])
	go_revive.visible = r["can_revive"]
	show_screen("gameover")
	_pop([go_score, go_revive])

func _on_city(i: int) -> void:
	var c: Dictionary = Data.cities()[i]
	banner.text = "مرحباً بكم في " + c["name"]
	banner_sub.text = "أحسنت! واصل الركض"
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
	var back := _btn("رجوع", Vector2(200, 100), RED, 40)
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
	var v := _page("shop", "متجر القدرات")
	var cp := _pill(GOLD)
	shop_coins = cp[1]
	cp[0].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cp[0])
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 18)
	shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(shop_list)

func _refresh_shop() -> void:
	shop_coins.text = _ar(str(int(Save.d["coins"])))
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
		var st := _lbl("المستوى %d/%d  •  المدة %.1f ث" % [lvl, Data.MAX_LEVEL, Data.duration(id, lvl)], 30, GOLD, 4)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(st)
		var btn: Button
		if lvl >= Data.MAX_LEVEL:
			btn = _btn("الحد الأقصى", Vector2(250, 100), Color("5d6d7e"), 32)
			btn.disabled = true
		else:
			var cost := Data.upgrade_cost(lvl)
			btn = _btn("ترقية  %d" % cost, Vector2(250, 100), GREEN, 38)
			btn.pressed.connect(func(): _buy_upgrade(id, cost))
		h.add_child(btn)

func _buy_upgrade(id: String, cost: int) -> void:
	if int(Save.d["coins"]) < cost:
		Sfx.play("deny")
		_toast("لا تملك عملات كافية")
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
	var back := _btn("رجوع", Vector2(190, 96), RED, 38)
	back.pressed.connect(func(): show_screen("menu"))
	head.add_child(back)
	var ti := _lbl("الأزياء", 62, GOLD, 12)
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
	ward_coins.text = _ar(str(int(Save.d["coins"])))
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
			btn = _btn("مُرتدى", Vector2(260, 100), Color("5d6d7e"), 38)
			btn.disabled = true
		elif has:
			btn = _btn("ارتداء", Vector2(260, 100), GREEN, 40)
			btn.pressed.connect(func(): _equip(id))
		else:
			btn = _btn("شراء  %d" % int(o["price"]), Vector2(260, 100), Color("e08a1e"), 36)
			btn.pressed.connect(func(): _buy_outfit(id, int(o["price"])))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(btn)
		if id == "national":
			v.add_child(_lbl("مجاني", 34, GOLD, 6))

func _equip(id: String) -> void:
	Save.d["outfit"] = id
	Save.save()
	game.apply_outfit()
	Sfx.play("buy")
	_refresh_wardrobe()

func _buy_outfit(id: String, price: int) -> void:
	if int(Save.d["coins"]) < price:
		Sfx.play("deny")
		_toast("لا تملك عملات كافية")
		return
	Save.d["coins"] = int(Save.d["coins"]) - price
	Save.d["owned"].append(id)
	Save.save()
	_equip(id)

# ------------------------------------------------------------ missions

func _build_missions() -> void:
	var v := _page("missions", "المهام")
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
		h.add_child(_lbl("المكافأة: %d" % int(m["reward"]), 36, GOLD, 6))
		var b := _btn("استلام", Vector2(230, 90), GREEN if m["done"] else Color("5d6d7e"), 38)
		b.disabled = not m["done"]
		b.pressed.connect(func(): _claim(idx))
		h.add_child(b)

func _claim(i: int) -> void:
	Save.claim_mission(i)
	Sfx.play("buy")
	_refresh_missions()

# ------------------------------------------------------------ settings & daily

func _build_settings() -> void:
	var v := _page("settings", "الإعدادات")
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
		Save.d["quality"] = (int(Save.d["quality"]) + 1) % 3
		Save.save()
		game.apply_quality(true)
		_refresh_settings())
	v.add_child(quality_btn)
	var hint := _lbl("التحكم: اسحب يميناً/يساراً لتغيير المسار\nللأعلى للقفز • للأسفل للانزلاق", 36, Color("b8c4cc"), 6)
	v.add_child(hint)
	v.add_child(_made_badge())
	v.add_child(_lbl("تطوير: بلال النعيمي\nالإصدار 1.0.0", 38, Color.WHITE, 8))

func _refresh_settings() -> void:
	music_btn.text = "الموسيقى: " + ("تشغيل" if Save.d["music"] else "إيقاف")
	sfx_btn.text = "المؤثرات: " + ("تشغيل" if Save.d["sfx"] else "إيقاف")
	var qn := ["منخفضة (الأسرع)", "متوسطة", "عالية"]
	quality_btn.text = "الجودة: " + qn[clampi(int(Save.d["quality"]), 0, 2)]

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
	var b := _btn("استلام", Vector2(520, 130), GREEN, 56)
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
