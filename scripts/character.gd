extends Node3D
# Procedural humanoid v3: lofted (smooth) body meshes with realistic proportions, face (eyes, nose, lips,
# ears), layered hair, real hands with fingers, shoes, outfits, and secondary motion.

const Decor = preload("res://scripts/decor.gd")

var pivot: Node3D
var body: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var hair: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var robe: MeshInstance3D
var shadow: MeshInstance3D
var tails: Array = []
var lids: Array = []
var phase := 0.0
var t_all := 0.0
var lean_target := 0.0
var air_vel := 0.0
var squash := 0.0
var blink_t := 2.5
var blink_ph := -1.0
var skin := Color("c99a6b")
var hair_col := Color("14100e")
var _cache := {}

func _mat(c: Color, rough := 0.75, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m

func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 18
	return m

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

# ---- lofted meshes: a profile is a list of [y, radius_x, radius_z, center_x, center_z] sections ----

func _pt(y: float, rx: float, rz: float, cx := 0.0, cz := 0.0) -> Array:
	return [y, rx, rz, cx, cz]

func _grow(pts: Array, d: float) -> Array:
	var out: Array = []
	for p in pts:
		out.append([p[0], float(p[1]) + d, float(p[2]) + d, p[3], p[4]])
	return out

func _add_loft(st: SurfaceTool, pts: Array, seg := 16, xf := Transform3D.IDENTITY) -> void:
	var rings: Array = []
	for p in pts:
		var ring: Array = []
		for j in seg:
			var a := TAU * float(j) / float(seg)
			ring.append(xf * Vector3(float(p[3]) + cos(a) * float(p[1]), float(p[0]), float(p[4]) + sin(a) * float(p[2])))
		rings.append(ring)
	for i in pts.size() - 1:
		for j in seg:
			var j2 := (j + 1) % seg
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j]
			var d: Vector3 = rings[i + 1][j2]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)
			st.add_vertex(c)
	st.set_smooth_group(-1)
	var first: Array = pts[0]
	var last: Array = pts[pts.size() - 1]
	var c0 := xf * Vector3(float(first[3]), float(first[0]), float(first[4]))
	var c1 := xf * Vector3(float(last[3]), float(last[0]), float(last[4]))
	for j in seg:
		var j2 := (j + 1) % seg
		st.add_vertex(c1)
		st.add_vertex(rings[pts.size() - 1][j])
		st.add_vertex(rings[pts.size() - 1][j2])
		st.add_vertex(c0)
		st.add_vertex(rings[0][j2])
		st.add_vertex(rings[0][j])
	st.set_smooth_group(0)

func _loft(pts: Array, seg := 16, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_loft(st, pts, seg, xf)
	st.generate_normals()
	return st.commit()

# ---- build ----

func build(o: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	tails.clear()
	lids.clear()
	scale = Vector3.ONE * 0.85
	var shirt: Color = o["shirt"]
	var acc: Color = o["acc"]
	var pants: Color = o["pants"]
	var shoes: Color = o["shoes"]
	var long_robe: bool = o["long"]
	var shorts: bool = o["shorts"]
	var long_sleeve: bool = o["sleeve"] == "long"
	var sm := _mat(skin, 0.58)
	var shm := _mat(shirt, 0.82)
	var pm := _mat(pants, 0.85)
	var accm := _mat(acc, 0.65)
	var gold := _mat(Color("e2b033"), 0.25, 0.9)
	var hm := _mat(hair_col, 0.5)
	var lipm := _mat(Color("9a5448"), 0.5)

	var sh := _mat(Color(0, 0, 0, 0.38), 1.0)
	sh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shc := CylinderMesh.new()
	shc.top_radius = 0.5
	shc.bottom_radius = 0.5
	shc.height = 0.01
	shadow = _mi(self, shc, sh, Vector3(0, 0.02, 0))

	pivot = _node(self, Vector3(0, 0.9, 0))
	body = _node(pivot, Vector3(0, -0.9, 0))
	hips = _node(body, Vector3(0, 0.95, 0))

	# pelvis + belt
	if not long_robe:
		_mi(hips, _loft([_pt(-0.14, 0.15, 0.105), _pt(-0.06, 0.168, 0.114), _pt(0.03, 0.166, 0.112)], 20), pm)
		_mi(hips, _loft([_pt(0.0, 0.1665, 0.1125), _pt(0.04, 0.1665, 0.1125)], 20), _mat(Color("2a2420"), 0.5))
		_mi(hips, _box(Vector3(0.05, 0.035, 0.012)), gold, Vector3(0, 0.02, -0.116))

	# torso (shirt), neck (skin), collar
	torso = _node(hips, Vector3.ZERO)
	var torso_pts := [_pt(0.03, 0.163, 0.108), _pt(0.12, 0.152, 0.102), _pt(0.24, 0.158, 0.106), _pt(0.36, 0.182, 0.118, 0, -0.008),
		_pt(0.46, 0.198, 0.12, 0, -0.008), _pt(0.52, 0.185, 0.105), _pt(0.565, 0.1, 0.072), _pt(0.585, 0.062, 0.056)]
	_mi(torso, _loft(torso_pts, 22), shm)
	_mi(torso, _loft([_pt(0.55, 0.062, 0.06), _pt(0.62, 0.05, 0.05, 0, -0.004), _pt(0.69, 0.047, 0.048, 0, -0.01)], 14), sm)
	_mi(torso, _loft([_pt(0.575, 0.072, 0.068), _pt(0.602, 0.057, 0.055)], 16), accm)
	if long_robe:
		for k in 3:
			_mi(torso, _sph(0.014), gold, Vector3(0, 0.38 - k * 0.1, -0.12))
	elif o["id"] == "sport":
		_mi(torso, _box(Vector3(0.016, 0.45, 0.01)), accm, Vector3(0, 0.3, -0.112))
	if o["id"] == "national" or o["id"] == "legend":
		var num := Label3D.new()
		num.text = "٩"
		num.font = Decor.font
		num.font_size = 140
		num.pixel_size = 0.0032
		num.modulate = acc
		num.outline_size = 0
		num.position = Vector3(0, 0.33, 0.123)
		torso.add_child(num)
	_mi(torso, _box(Vector3(0.3, 0.035, 0.012)), accm, Vector3(0, 0.44, -0.121))

	# head
	head = _node(torso, Vector3(0, 0.665, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_loft(st, [_pt(-0.01, 0.028, 0.035, 0, -0.045), _pt(0.025, 0.058, 0.07, 0, -0.035), _pt(0.07, 0.073, 0.092, 0, -0.015),
		_pt(0.12, 0.079, 0.1, 0, 0.0), _pt(0.17, 0.08, 0.104, 0, 0.004), _pt(0.21, 0.072, 0.098, 0, 0.006),
		_pt(0.24, 0.045, 0.07, 0, 0.004), _pt(0.255, 0.015, 0.025)], 26)
	_add_loft(st, [_pt(0.135, 0.008, 0.008, 0, -0.099), _pt(0.11, 0.011, 0.012, 0, -0.106), _pt(0.088, 0.014, 0.016, 0, -0.111), _pt(0.074, 0.02, 0.016, 0, -0.108)], 10)
	for sx in [-1.0, 1.0]:
		_add_loft(st, [_pt(0.03, 0.004, 0.011), _pt(0.0, 0.007, 0.017), _pt(-0.03, 0.005, 0.011)], 8, Transform3D(Basis(), Vector3(0.079 * sx, 0.115, 0.012)))
		_add_loft(st, [_pt(0.01, 0.006, 0.007), _pt(-0.005, 0.009, 0.009), _pt(-0.016, 0.006, 0.007)], 8, Transform3D(Basis(), Vector3(0.017 * sx, 0.077, -0.105)))
	st.generate_normals()
	_mi(head, st.commit(), sm)
	var white := _mat(Color("f6f6f4"), 0.3)
	var iris := _mat(Color("3a2414"), 0.3)
	for sx in [-1.0, 1.0]:
		_mi(head, _sph(0.0125), white, Vector3(0.036 * sx, 0.135, -0.094), Vector3.ZERO, Vector3(1.15, 0.8, 0.6))
		_mi(head, _sph(0.0072), iris, Vector3(0.036 * sx, 0.135, -0.0985), Vector3.ZERO, Vector3(1, 1, 0.5))
		_mi(head, _sph(0.0035), _mat(Color("050505"), 0.2), Vector3(0.036 * sx, 0.135, -0.1008), Vector3.ZERO, Vector3(1, 1, 0.5))
		_mi(head, _box(Vector3(0.034, 0.004, 0.006)), hm, Vector3(0.036 * sx, 0.1475, -0.1015))
		_mi(head, _box(Vector3(0.042, 0.0075, 0.01)), hm, Vector3(0.037 * sx, 0.158, -0.1), Vector3(0, 0, 0.12 * sx))
		var lid := _mi(head, _box(Vector3(0.032, 0.026, 0.008)), sm, Vector3(0.036 * sx, 0.138, -0.1035))
		lid.scale.y = 0.02
		lids.append(lid)
		_mi(head, _sph(0.012), hm, Vector3(0.0125 * sx, 0.0585, -0.1065), Vector3(0, 0, -0.25 * sx), Vector3(1.5, 0.5, 0.6))
		_mi(head, _sph(0.006), lipm, Vector3(0.019 * sx, 0.0445, -0.1015))
	_mi(head, _sph(0.02), lipm, Vector3(0, 0.047, -0.1055), Vector3.ZERO, Vector3(1.0, 0.3, 0.5))
	_mi(head, _sph(0.018), lipm, Vector3(0, 0.037, -0.105), Vector3.ZERO, Vector3(1.0, 0.34, 0.5))
	_mi(head, _box(Vector3(0.034, 0.0025, 0.006)), _mat(Color("3a1a16"), 0.4), Vector3(0, 0.0425, -0.1068))
	var stub := _mat(Color(0.05, 0.04, 0.03, 0.4), 1.0)
	stub.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mi(head, _sph(0.082), stub, Vector3(0, 0.045, -0.012), Vector3.ZERO, Vector3(0.95, 0.5, 1.1))

	# hair (smooth shell that leaves the forehead visible)
	hair = _node(head, Vector3.ZERO)
	var htype: String = o["head"]
	_mi(hair, _loft([_pt(0.09, 0.086, 0.112, 0, 0.03), _pt(0.14, 0.09, 0.116, 0, 0.022), _pt(0.19, 0.088, 0.114, 0, 0.008),
		_pt(0.23, 0.07, 0.095, 0, 0.004), _pt(0.255, 0.036, 0.06), _pt(0.268, 0.01, 0.02)], 24), hm)
	for sx in [-1.0, 1.0]:
		_mi(hair, _box(Vector3(0.012, 0.07, 0.03)), hm, Vector3(0.082 * sx, 0.13, -0.04))
	if htype in ["none", "sidara", "headband", "crown"]:
		_mi(hair, _sph(0.045), hm, Vector3(0, 0.245, -0.05), Vector3.ZERO, Vector3(1.4, 0.5, 1.0))
	_head_gear(htype, o["headc"], accm)

	# arms
	for side in [-1.0, 1.0]:
		var arm := _node(torso, Vector3(0.215 * side, 0.5, 0))
		var up_pts := [_pt(0.0, 0.05, 0.05), _pt(-0.05, 0.048, 0.049), _pt(-0.15, 0.043, 0.045), _pt(-0.29, 0.036, 0.038), _pt(-0.31, 0.034, 0.036)]
		_mi(arm, _sph(0.058), shm)
		_mi(arm, _loft(up_pts, 14), sm)
		if long_sleeve:
			_mi(arm, _loft(_grow(up_pts, 0.007), 14), shm)
		else:
			_mi(arm, _loft(_grow([_pt(0.01, 0.05, 0.05), _pt(-0.05, 0.048, 0.049), _pt(-0.15, 0.043, 0.045), _pt(-0.19, 0.041, 0.043)], 0.008), 14), shm)
			_mi(arm, _loft([_pt(-0.17, 0.0505, 0.0525), _pt(-0.2, 0.0505, 0.0525)], 14), accm)
		var fore := _node(arm, Vector3(0, -0.31, 0))
		var fo_pts := [_pt(0.01, 0.037, 0.039), _pt(-0.06, 0.041, 0.041), _pt(-0.17, 0.032, 0.033), _pt(-0.26, 0.025, 0.027)]
		_mi(fore, _sph(0.04), shm if long_sleeve else sm)
		_mi(fore, _loft(fo_pts, 14), sm)
		if long_sleeve:
			_mi(fore, _loft(_grow([_pt(0.01, 0.037, 0.039), _pt(-0.06, 0.041, 0.041), _pt(-0.17, 0.032, 0.033), _pt(-0.235, 0.027, 0.029)], 0.007), 14), shm)
			_mi(fore, _loft([_pt(-0.22, 0.036, 0.038), _pt(-0.245, 0.036, 0.038)], 14), accm)
		var hand := _node(fore, Vector3(0, -0.265, 0))
		var hs := SurfaceTool.new()
		hs.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_loft(hs, [_pt(0.0, 0.026, 0.015), _pt(-0.04, 0.036, 0.017), _pt(-0.085, 0.035, 0.015)], 14)
		var lens := [0.056, 0.066, 0.06, 0.048]
		for k in 4:
			var fx := -0.0255 + k * 0.017
			var fl: float = lens[k]
			_add_loft(hs, [_pt(-0.083, 0.0085, 0.0085, fx, 0), _pt(-0.083 - fl * 0.5, 0.0078, 0.0078, fx, -0.004), _pt(-0.083 - fl, 0.0065, 0.0065, fx, -0.011)], 8)
		_add_loft(hs, [_pt(0.0, 0.011, 0.011), _pt(-0.028, 0.01, 0.01), _pt(-0.052, 0.0075, 0.0075)], 8,
			Transform3D(Basis(Vector3(0, 0, 1), -0.55 * side).rotated(Vector3(1, 0, 0), 0.4), Vector3(-0.03 * side, -0.02, -0.012)))
		hs.generate_normals()
		_mi(hand, hs.commit(), sm)
		if side < 0.0:
			arm_l = arm
			fore_l = fore
		else:
			arm_r = arm
			fore_r = fore

	# legs
	for side in [-1.0, 1.0]:
		var leg := _node(hips, Vector3(0.092 * side, -0.03, 0))
		var th_pts := [_pt(0.04, 0.092, 0.1), _pt(-0.1, 0.088, 0.098), _pt(-0.25, 0.07, 0.078), _pt(-0.44, 0.052, 0.058), _pt(-0.46, 0.05, 0.056)]
		var sh_pts := [_pt(0.0, 0.052, 0.058), _pt(-0.07, 0.058, 0.066, 0, 0.012), _pt(-0.2, 0.045, 0.05, 0, 0.006), _pt(-0.34, 0.033, 0.036, 0, 0.002), _pt(-0.39, 0.034, 0.036)]
		var shin := _node(leg, Vector3(0, -0.45, 0))
		if shorts:
			_mi(leg, _loft(th_pts, 16), sm)
			_mi(leg, _loft(_grow([_pt(0.04, 0.092, 0.1), _pt(-0.1, 0.088, 0.098), _pt(-0.2, 0.074, 0.082), _pt(-0.27, 0.068, 0.076)], 0.011), 16), pm)
			_mi(shin, _sph(0.052), sm)
			_mi(shin, _loft(sh_pts, 14), sm)
			_mi(shin, _loft([_pt(-0.27, 0.0365, 0.0395), _pt(-0.35, 0.0365, 0.0395)], 14), accm)
		else:
			_mi(leg, _loft(_grow(th_pts, 0.007), 16), pm)
			_mi(shin, _sph(0.054), pm)
			_mi(shin, _loft(_grow(sh_pts, 0.007), 14), pm)
		var foot := _node(shin, Vector3(0, -0.39, 0))
		var shoe_pts := [_pt(0.0, 0.04, 0.045), _pt(0.06, 0.043, 0.05, 0, 0.004), _pt(0.14, 0.047, 0.045), _pt(0.22, 0.042, 0.032, 0, -0.005), _pt(0.27, 0.025, 0.02, 0, -0.01)]
		_mi(foot, _loft(shoe_pts, 14), _mat(shoes, 0.55), Vector3(0, -0.045, 0.065), Vector3(-PI * 0.5, 0, 0))
		_mi(foot, _box(Vector3(0.095, 0.02, 0.275)), _mat(Color("f2f2f2"), 0.7), Vector3(0, -0.082, -0.07))
		_mi(foot, _box(Vector3(0.05, 0.01, 0.09)), accm, Vector3(0, 0.0, -0.09))
		if side < 0.0:
			leg_l = leg
			shin_l = shin
			foot_l = foot
		else:
			leg_r = leg
			shin_r = shin
			foot_r = foot

	robe = null
	if long_robe:
		robe = _mi(hips, _loft([_pt(0.1, 0.17, 0.115), _pt(0.0, 0.19, 0.13), _pt(-0.35, 0.215, 0.15), _pt(-0.7, 0.25, 0.17), _pt(-0.86, 0.27, 0.18)], 24), shm)
		_mi(robe, _loft([_pt(-0.82, 0.273, 0.183), _pt(-0.875, 0.275, 0.185)], 24), accm)
		_mi(robe, _box(Vector3(0.06, 0.62, 0.012)), accm, Vector3(0, -0.4, -0.172))

func _head_gear(kind: String, c: Color, accm: Material) -> void:
	match kind:
		"cap":
			var cm := _mat(c, 0.7)
			_mi(head, _sph(0.1), cm, Vector3(0, 0.185, 0.006), Vector3.ZERO, Vector3(0.93, 0.82, 1.18))
			_mi(head, _box(Vector3(0.15, 0.012, 0.1)), cm, Vector3(0, 0.172, -0.118), Vector3(0.08, 0, 0))
			_mi(head, _sph(0.011), accm, Vector3(0, 0.262, 0.006))
		"ghutra":
			var white := _mat(Color("f4f1ea"), 0.9)
			var chk := _mat(c, 0.9)
			_mi(head, _sph(0.1), white, Vector3(0, 0.18, 0.015), Vector3.ZERO, Vector3(0.98, 0.95, 1.2))
			_mi(head, _box(Vector3(0.04, 0.15, 0.17)), chk, Vector3(-0.095, 0.12, 0.02))
			_mi(head, _box(Vector3(0.04, 0.15, 0.17)), chk, Vector3(0.095, 0.12, 0.02))
			var t := TorusMesh.new()
			t.inner_radius = 0.095
			t.outer_radius = 0.108
			_mi(head, t, _mat(Color("151515"), 0.5), Vector3(0, 0.215, 0.012), Vector3.ZERO, Vector3(0.93, 1.0, 1.14))
			for sx in [-0.06, 0.0, 0.06]:
				var tail := _node(head, Vector3(sx, 0.14, 0.098))
				_mi(tail, _box(Vector3(0.09, 0.3, 0.02)), white if sx != 0.0 else chk, Vector3(0, -0.15, 0.015))
				tails.append(tail)
		"sidara":
			_mi(head, _cyl(0.07, 0.092, 0.13), _mat(c, 0.85), Vector3(0, 0.275, 0.0))
			_mi(head, _cyl(0.073, 0.073, 0.018), _mat(Color("5c4a2a"), 0.6), Vector3(0, 0.34, 0.0))
			_mi(head, _cyl(0.094, 0.094, 0.02), accm, Vector3(0, 0.215, 0.0))
		"beanie":
			var bm := _mat(c, 0.9)
			_mi(head, _sph(0.098), bm, Vector3(0, 0.185, 0.008), Vector3.ZERO, Vector3(0.96, 0.9, 1.16))
			_mi(head, _cyl(0.094, 0.094, 0.035), accm, Vector3(0, 0.16, 0.008))
			_mi(head, _sph(0.033), accm, Vector3(0, 0.285, 0.008))
		"headband":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.086
			t2.outer_radius = 0.098
			_mi(head, t2, _mat(c, 0.8), Vector3(0, 0.195, 0.004), Vector3.ZERO, Vector3(0.95, 1.0, 1.17))
			_mi(head, _box(Vector3(0.035, 0.055, 0.015)), _mat(c, 0.8), Vector3(0.025, 0.18, 0.12), Vector3(0, 0, 0.5))
			_mi(head, _box(Vector3(0.035, 0.055, 0.015)), _mat(c, 0.8), Vector3(-0.025, 0.175, 0.124), Vector3(0, 0, -0.5))
		"hat":
			var hm2 := _mat(c, 0.85)
			_mi(head, _cyl(0.17, 0.17, 0.014), hm2, Vector3(0, 0.205, 0.0))
			_mi(head, _cyl(0.075, 0.09, 0.11), hm2, Vector3(0, 0.26, 0.0))
			_mi(head, _cyl(0.092, 0.092, 0.024), accm, Vector3(0, 0.218, 0.0))
		"helmet":
			_mi(head, _sph(0.115), _mat(c, 0.25, 0.8), Vector3(0, 0.17, 0.012), Vector3.ZERO, Vector3(0.9, 0.95, 1.1))
			_mi(head, _box(Vector3(0.13, 0.05, 0.03)), _mat(Color("101820"), 0.1, 0.6), Vector3(0, 0.15, -0.108))
			_mi(head, _box(Vector3(0.025, 0.05, 0.16)), accm, Vector3(0, 0.275, 0.01))
		"crown":
			var gm := _mat(Color("e2b033"), 0.25, 0.9)
			_mi(head, _cyl(0.088, 0.088, 0.045), gm, Vector3(0, 0.255, 0.0))
			for i in 5:
				var a := i * TAU / 5.0
				_mi(head, _cyl(0.0, 0.022, 0.065), gm, Vector3(cos(a) * 0.084, 0.31, sin(a) * 0.084))
				_mi(head, _sph(0.012), _mat(c, 0.3, 0.2), Vector3(cos(a) * 0.09, 0.255, sin(a) * 0.09))
		_:
			pass

func land() -> void:
	squash = 1.0

func animate(state: String, dt: float, speed: float, roll_t := 0.0) -> void:
	if pivot == null:
		return
	t_all += dt
	var k := minf(1.0, 24.0 * dt)
	pivot.rotation.z = lerpf(pivot.rotation.z, lean_target, minf(1.0, 12.0 * dt))
	# joint targets
	var ll := 0.0
	var lr := 0.0
	var sl := 0.0
	var sr := 0.0
	var fl_ := 0.0
	var fr_ := 0.0
	var al := 0.0
	var ar := 0.0
	var fol := 0.2
	var for_ := 0.2
	var alz := 0.0
	var arz := 0.0
	var tx := 0.0
	var ty := 0.0
	var hy := 0.0
	var hx := 0.0
	var bob := -0.9
	var hz := 0.0
	var hyaw := 0.0
	var px_target := 0.0
	var fore_rz := 0.0
	match state:
		"run":
			phase += dt * (7.5 + speed * 0.32)
			var s := sin(phase)
			var c := cos(phase)
			var stride := 0.85 + speed * 0.009
			ll = s * stride
			lr = -s * stride
			sl = -maxf(0.0, c) * 1.5
			sr = -maxf(0.0, -c) * 1.5
			fl_ = -s * 0.3
			fr_ = s * 0.3
			al = -s * 0.95
			ar = s * 0.95
			fol = 1.2 + maxf(0.0, s) * 0.25
			for_ = 1.2 + maxf(0.0, -s) * 0.25
			alz = 0.08
			arz = -0.08
			tx = -0.17
			ty = -s * 0.15
			hy = s * 0.08
			hx = 0.12
			hyaw = s * 0.1
			hz = c * 0.035
			bob = -0.9 + absf(c) * 0.055 - 0.02
		"hero":
			phase += dt * 1.5
			ll = 0.04
			lr = -0.03
			alz = 0.1
			arz = -0.1
			al = sin(t_all * 1.2) * 0.05
			fol = 0.25
			for_ = 0.25
			ar = 0.05
			var w := fmod(t_all, 7.0)
			if w < 2.4:
				ar = 2.75
				arz = -0.3
				for_ = 0.5
				fore_rz = sin(w * 11.0) * 0.55
			hy = sin(t_all * 0.9) * 0.3
			hx = 0.04
			tx = 0.02
			ty = sin(t_all * 0.9) * 0.1
			bob = -0.9
		"jump":
			var rising := air_vel > 0.0
			ll = 1.1 if rising else 0.7
			sl = -1.3 if rising else -0.7
			lr = -0.6 if rising else -0.2
			sr = -0.6 if rising else -0.3
			al = 2.4 if rising else 1.7
			ar = 2.4 if rising else 1.7
			alz = 0.35
			arz = -0.35
			fol = 0.3
			for_ = 0.3
			tx = -0.08 if rising else -0.22
			hx = -0.05
			bob = -0.9
			fl_ = 0.4
			fr_ = 0.6
		"roll":
			px_target = -roll_t * TAU
			ll = 1.7
			lr = 1.7
			sl = -2.1
			sr = -2.1
			al = 1.0
			ar = 1.0
			fol = 1.7
			for_ = 1.7
			tx = -0.55
			hx = 0.3
			bob = -0.9
		"fly":
			phase += dt * 6.0
			px_target = -1.15
			ll = -0.35 + sin(phase * 2.0) * 0.12
			lr = -0.25 - sin(phase * 2.0) * 0.12
			sl = -0.3
			sr = -0.3
			al = 2.9
			ar = 2.9
			fol = 0.1
			for_ = 0.1
			hx = 0.5
			bob = -0.9
		"dead":
			px_target = 1.45
			ll = 0.4
			lr = -0.2
			al = 2.2
			ar = 1.7
			alz = 0.6
			arz = -0.6
			hx = -0.3
			bob = -0.9
	leg_l.rotation.x = lerpf(leg_l.rotation.x, ll, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lr, k)
	shin_l.rotation.x = lerpf(shin_l.rotation.x, sl, k)
	shin_r.rotation.x = lerpf(shin_r.rotation.x, sr, k)
	foot_l.rotation.x = lerpf(foot_l.rotation.x, fl_, k)
	foot_r.rotation.x = lerpf(foot_r.rotation.x, fr_, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, al, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ar, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, alz, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, arz, k)
	fore_l.rotation.x = lerpf(fore_l.rotation.x, fol, k)
	fore_r.rotation.x = lerpf(fore_r.rotation.x, for_, k)
	fore_r.rotation.z = lerpf(fore_r.rotation.z, fore_rz, k)
	torso.rotation.x = lerpf(torso.rotation.x, tx, k)
	torso.rotation.y = lerpf(torso.rotation.y, ty, k)
	head.rotation.y = lerpf(head.rotation.y, hy, k)
	head.rotation.x = lerpf(head.rotation.x, hx, k)
	hips.rotation.y = lerpf(hips.rotation.y, hyaw, k)
	hips.rotation.z = lerpf(hips.rotation.z, hz, k)
	body.position.y = lerpf(body.position.y, bob, k)
	if state == "roll":
		pivot.rotation.x = px_target
	else:
		if pivot.rotation.x < -PI:
			pivot.rotation.x += TAU
		pivot.rotation.x = lerpf(pivot.rotation.x, px_target, minf(1.0, 9.0 * dt))
	# squash & stretch
	squash = maxf(0.0, squash - dt * 5.0)
	var stretch := 0.0
	if state == "jump" and air_vel > 4.0:
		stretch = 0.06
	body.scale = Vector3(1.0 + squash * 0.18 - stretch * 0.5, 1.0 - squash * 0.22 + stretch, 1.0 + squash * 0.18 - stretch * 0.5)
	torso.scale = Vector3.ONE * (1.0 + sin(t_all * 2.3) * 0.012)
	# secondary motion
	var hair_t := 0.1
	if state == "run":
		hair_t = 0.1 + absf(cos(phase)) * 0.12
	elif state == "jump":
		hair_t = clampf(-air_vel * 0.02, -0.25, 0.25)
	hair.rotation.x = lerpf(hair.rotation.x, hair_t, minf(1.0, 10.0 * dt))
	var flutter := 0.25 + minf(speed, 36.0) * 0.012
	for i in tails.size():
		tails[i].rotation.x = flutter + sin(t_all * 11.0 + i * 1.3) * 0.18 * minf(1.0, 0.3 + speed * 0.03)
		tails[i].rotation.z = sin(t_all * 7.0 + i) * 0.06
	if robe != null:
		var rf := -0.05
		if state == "run":
			rf = -0.05 - absf(sin(phase)) * 0.09
		robe.rotation.x = lerpf(robe.rotation.x, rf, k)
	# blinking
	blink_t -= dt
	if blink_t <= 0.0 and blink_ph < 0.0:
		blink_ph = 0.0
	if blink_ph >= 0.0:
		blink_ph += dt
		var closed := 1.0 if blink_ph < 0.12 else 0.02
		for l in lids:
			l.scale.y = closed
		if blink_ph > 0.14:
			blink_ph = -1.0
			blink_t = randf_range(2.0, 5.0)
			for l in lids:
				l.scale.y = 0.02

func set_height(py: float) -> void:
	if shadow == null:
		return
	var s := clampf(1.0 - py * 0.14, 0.3, 1.0)
	shadow.scale = Vector3(s, 1.0, s)
	shadow.position.y = 0.02 - py
