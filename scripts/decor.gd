extends RefCounted
# Animated scenery builders: palms, pedestrians, flags, bunting, wires, bridges, boats, shop signs.
# Every builder must be called with a parent that is already inside the scene tree (tweens need it).

static var font: Font
static var quality := 1
static var _m := {}

static func mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "m%s_%s_%s" % [c.to_html(), rough, metal]
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_m[key] = m
	return m

static func emat(c: Color, energy: float) -> StandardMaterial3D:
	var key := "e%s_%s" % [c.to_html(), energy]
	if _m.has(key):
		return _m[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_m[key] = m
	return m

static func node(parent: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

static func box(parent: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, rt: float, rb: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func sph(parent: Node3D, r: float, m: Material, pos: Vector3, hemi := false, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 12
	s.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func cap(parent: Node3D, r: float, h: float, m: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func swing(n: Node3D, prop: String, a: float, b: float, dur: float) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, prop, a, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, prop, b, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ------------------------------------------------------------------ trees

static func palm(parent: Node3D, pos: Vector3) -> void:
	var root := node(parent, pos)
	root.rotation.z = randf_range(-0.08, 0.08)
	var th := randf_range(4.2, 6.2)
	cyl(root, 0.1, 0.17, th, mat(Color("7b5a38"), 0.9), Vector3(0, th * 0.5, 0), Vector3.ZERO, 8)
	for k in 3:
		cyl(root, 0.15, 0.15, 0.08, mat(Color("5e4327"), 0.9), Vector3(0, 0.8 + k * th * 0.25, 0), Vector3.ZERO, 8)
	var crown := node(root, Vector3(0, th, 0))
	var leaf := mat(Color("2f7d32"), 0.8)
	var n_leaf := 7 if quality > 1 else 5
	for i in n_leaf:
		var p := node(crown)
		p.rotation.y = i * TAU / n_leaf
		var dr := node(p)
		dr.rotation.x = -0.45
		box(dr, Vector3(0.45, 0.05, 2.6), leaf, Vector3(0, 0, -1.3))
	sph(crown, 0.15, mat(Color("5a3a1e")), Vector3(0.12, -0.15, 0.0))
	sph(crown, 0.12, mat(Color("d9822b"), 0.6), Vector3(-0.14, -0.25, 0.05))
	if quality > 1:
		swing(crown, "rotation:z", 0.05, -0.05, randf_range(1.6, 2.6))

static func pine(parent: Node3D, pos: Vector3) -> void:
	var root := node(parent, pos)
	var h := randf_range(3.5, 5.5)
	cyl(root, 0.12, 0.16, 1.4, mat(Color("6b4a2c")), Vector3(0, 0.7, 0), Vector3.ZERO, 8)
	var g := mat(Color("2d6a3a"), 0.9)
	var top := node(root, Vector3(0, 0, 0))
	cyl(top, 0.0, 1.5, h * 0.6, g, Vector3(0, 1.4 + h * 0.3, 0), Vector3.ZERO, 10)
	cyl(top, 0.0, 1.1, h * 0.5, g, Vector3(0, 1.4 + h * 0.62, 0), Vector3.ZERO, 10)
	if quality > 1:
		swing(top, "rotation:z", 0.025, -0.025, randf_range(1.8, 2.8))

# ------------------------------------------------------------------ people

static func person(parent: Node3D, x: float, z_a: float, z_b: float) -> void:
	var root := node(parent, Vector3(x, 0, z_a))
	var shirts := [Color("c0392b"), Color("2980b9"), Color("f4f1ea"), Color("27ae60"), Color("8e6b3e"), Color("34495e"), Color("e0a81c")]
	var skin_cols := [Color("c68c60"), Color("b57a50"), Color("d79c70")]
	var sm := mat(shirts[randi() % shirts.size()], 0.85)
	var skin := mat(skin_cols[randi() % 3], 0.7)
	var pm := mat(Color("34383f") if randf() < 0.5 else Color("cdbf9d"), 0.85)
	var hips := node(root, Vector3(0, 0.95, 0))
	cap(hips, 0.17, 0.62, sm, Vector3(0, 0.3, 0), Vector3(1.1, 1.0, 0.7))
	sph(hips, 0.115, skin, Vector3(0, 0.82, 0), false, Vector3(0.92, 1.1, 1.0))
	sph(hips, 0.12, mat(Color("181210"), 0.6), Vector3(0, 0.88, 0.02), false, Vector3(0.95, 0.85, 1.0))
	var legs := []
	for sx in [-1.0, 1.0]:
		var leg := node(hips, Vector3(0.1 * sx, 0.0, 0))
		cap(leg, 0.075, 0.9, pm, Vector3(0, -0.45, 0))
		legs.append(leg)
		var arm := node(hips, Vector3(0.23 * sx, 0.54, 0))
		cap(arm, 0.05, 0.62, sm, Vector3(0, -0.28, 0))
		if sx < 0.0:
			swing(arm, "rotation:x", 0.5, -0.5, 0.42)
		else:
			swing(arm, "rotation:x", -0.5, 0.5, 0.42)
	swing(legs[0], "rotation:x", -0.55, 0.55, 0.42)
	swing(legs[1], "rotation:x", 0.55, -0.55, 0.42)
	var t := absf(z_b - z_a) / 1.5
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "position:z", z_b, t)
	tw.tween_property(root, "rotation:y", PI, 0.25)
	tw.tween_property(root, "position:z", z_a, t)
	tw.tween_property(root, "rotation:y", 0.0, 0.25)

# ------------------------------------------------------------------ flags, bunting, wires

static func flag(parent: Node3D, pos: Vector3) -> void:
	var n := node(parent, pos)
	cyl(n, 0.04, 0.06, 6.5, mat(Color("c9ced4"), 0.4, 0.8), Vector3(0, 3.25, 0), Vector3.ZERO, 8)
	sph(n, 0.09, mat(Color("e2b033"), 0.3, 0.9), Vector3(0, 6.55, 0))
	var cloth := node(n, Vector3(0, 6.0, 0))
	var cols := [Color("c0392b"), Color("f2c14e"), Color("1f4fa8")]
	for i in 3:
		box(cloth, Vector3(0.02, 0.24, 1.3), mat(cols[i], 0.9), Vector3(0, -i * 0.24, 0.65))
	swing(cloth, "rotation:y", 0.4, -0.25, randf_range(0.45, 0.7))

static func bunting(parent: Node3D, y: float, half_w: float) -> void:
	var n := node(parent, Vector3(0, y, randf_range(-8.0, 8.0)))
	box(n, Vector3(half_w * 2.0, 0.03, 0.03), mat(Color("444444")), Vector3.ZERO)
	var flags := node(n)
	var cols := [Color("e0a81c"), Color("2980b9"), Color("c0392b"), Color("27ae60"), Color("f4f4f4")]
	for i in 13:
		var x := -half_w + 0.6 + i * (half_w * 2.0 - 1.2) / 12.0
		box(flags, Vector3(0.3, 0.42, 0.04), mat(cols[i % 5], 0.8), Vector3(x, -0.24, 0), Vector3(0, 0, PI * 0.25))
	swing(flags, "rotation:x", 0.14, -0.14, randf_range(0.8, 1.2))

static func wires(parent: Node3D, side: float) -> void:
	var wm := mat(Color("1c1c1c"), 0.6)
	for k in 3:
		box(parent, Vector3(0.03, 0.03, 24.0), wm, Vector3(side * 5.25, 4.75 - k * 0.14, 6.0))

# ------------------------------------------------------------------ structures

static func overpass(parent: Node3D) -> void:
	var conc := mat(Color("b8b3a6"), 0.9)
	var n := node(parent)
	box(n, Vector3(19.2, 0.9, 7.0), conc, Vector3(0, 9.0, 0))
	box(n, Vector3(19.2, 0.9, 0.35), conc, Vector3(0, 9.95, 3.4))
	box(n, Vector3(19.2, 0.9, 0.35), conc, Vector3(0, 9.95, -3.4))
	box(n, Vector3(19.3, 0.22, 7.1), mat(Color("1c9a4d"), 0.6), Vector3(0, 8.62, 0))
	box(n, Vector3(16, 0.08, 0.25), emat(Color("fff1b0"), 2.2), Vector3(0, 8.5, 0))
	for sx in [-7.6, 7.6]:
		box(n, Vector3(1.6, 8.6, 5.0), conc, Vector3(sx, 4.3, 0))
	var car := node(n, Vector3(-9.5, 9.7, 1.4))
	var cols := [Color("d9a21b"), Color("c0392b"), Color("2980b9"), Color("f4f1ea")]
	box(car, Vector3(3.6, 0.8, 1.7), mat(cols[randi() % 4], 0.4, 0.3), Vector3(0, 0.0, 0))
	box(car, Vector3(1.9, 0.6, 1.5), mat(Color("18222f"), 0.2, 0.5), Vector3(-0.2, 0.65, 0))
	box(car, Vector3(0.1, 0.25, 0.25), emat(Color("fff1b0"), 3.0), Vector3(1.8, 0.0, -0.5))
	box(car, Vector3(0.1, 0.25, 0.25), emat(Color("fff1b0"), 3.0), Vector3(1.8, 0.0, 0.5))
	var tw := car.create_tween().set_loops()
	tw.tween_property(car, "position:x", 9.5, randf_range(2.6, 4.0))
	tw.tween_callback(func(): car.position.x = -9.5)

static func boat(parent: Node3D, pos: Vector3) -> void:
	var n := node(parent, pos)
	var wood := mat(Color("7a4b26"), 0.8)
	box(n, Vector3(2.2, 0.8, 6.5), wood, Vector3(0, 0.1, 0))
	box(n, Vector3(1.4, 0.8, 2.0), wood, Vector3(0, 0.1, -3.7), Vector3(0.0, 0.6, 0.0))
	box(n, Vector3(1.7, 1.0, 1.9), mat(Color("f0ece0"), 0.7), Vector3(0, 1.0, 1.2))
	box(n, Vector3(1.75, 0.3, 1.95), mat(Color("1c9a4d"), 0.7), Vector3(0, 1.6, 1.2))
	cyl(n, 0.07, 0.09, 5.0, wood, Vector3(0, 3.0, -0.8), Vector3.ZERO, 8)
	box(n, Vector3(0.04, 3.4, 2.4), mat(Color("f2e9d0"), 0.9), Vector3(0, 3.2, -1.9), Vector3(0, 0, 0.0))
	swing(n, "rotation:z", 0.045, -0.045, randf_range(1.1, 1.6))
	swing(n, "position:y", pos.y + 0.12, pos.y - 0.08, randf_range(0.9, 1.3))
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "position:z", pos.z - 9.0, 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:z", pos.z + 9.0, 5.0).set_trans(Tween.TRANS_SINE)

static func sign_board(parent: Node3D, text: String, pos: Vector3, side: float, col: Color) -> void:
	box(parent, Vector3(0.1, 0.95, 2.8), mat(col, 0.6), pos)
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 64
	l.pixel_size = 0.012
	l.modulate = Color("ffffff")
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos + Vector3(-side * 0.09, 0, 0)
	l.rotation.y = -side * PI * 0.5
	parent.add_child(l)

static func building_extras(parent: Node3D, side: float, cx: float, cz: float, w: float, h: float) -> void:
	if quality <= 1:
		return
	var white := mat(Color("e8e8e8"), 0.6)
	for k in randi_range(1, 2):
		box(parent, Vector3(0.55, 0.45, 0.75), white, Vector3(side * 9.15, randf_range(4.0, maxf(h - 2.0, 4.5)), cz + randf_range(-2.5, 2.5)))
	if randf() < 0.5:
		var y := randf_range(5.0, maxf(h - 2.5, 5.5))
		box(parent, Vector3(0.9, 0.12, 2.2), mat(Color("9a8f7c"), 0.8), Vector3(side * 9.0, y, cz))
		box(parent, Vector3(0.06, 0.7, 2.2), mat(Color("3a3f45"), 0.5, 0.5), Vector3(side * 8.58, y + 0.4, cz))
	if randf() < 0.5:
		sph(parent, 0.45, mat(Color("d0d0d0"), 0.5, 0.4), Vector3(cx + randf_range(-w * 0.3, w * 0.3), h + 0.7, cz), true)
	if randf() < 0.4:
		cyl(parent, 0.03, 0.03, 3.0, mat(Color("3a3f45")), Vector3(cx, h + 2.0, cz + 1.0), Vector3.ZERO, 6)
