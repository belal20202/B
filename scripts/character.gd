
extends Node3D
# Procedural humanoid v2: detailed face (blinking eyes, lips, mustache, stubble), layered hair,
# jointed limbs with hands and shoes, outfit details, secondary motion (hair, cloth), squash & stretch.

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
var skin := Color("c68c60")
var hair_col := Color("151110")
var _cache := {}

func _mat(c: Color, rough := 0.75, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
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

func _cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m

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
	m.radial_segments = 16
	return m

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func build(o: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	tails.clear()
	lids.clear()
	var shirt: Color = o["shirt"]
	var acc: Color = o["acc"]
	var pants: Color = o["pants"]
	var shoes: Color = o["shoes"]
	var long_robe: bool = o["long"]
	var shorts: bool = o["shorts"]
	var long_sleeve: bool = o["sleeve"] == "long"
	var sm := _mat(skin, 0.62)
	var shm := _mat(shirt, 0.8)
	var pm := _mat(pants, 0.85)
	var accm := _mat(acc, 0.65)
	var gold := _mat(Color("e2b033"), 0.25, 0.9)

	# soft contact shadow (does not rotate with the body)
	var sh := _mat(Color(0, 0, 0, 0.38), 1.0)
	sh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow = _mi(self, _cyl(0.5, 0.5, 0.01), sh, Vector3(0, 0.02, 0))

	pivot = _node(self, Vector3(0, 0.9, 0))
	body = _node(pivot, Vector3(0, -0.9, 0))
	hips = _node(body, Vector3(0, 1.0, 0))
	_mi(hips, _cap(0.16, 0.36), pm, Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 1, 0.82))
	if not long_robe:
		_mi(hips, _box(Vector3(0.4, 0.07, 0.27)), _mat(Color("2a2420"), 0.5), Vector3(0, 0.12, 0))
		_mi(hips, _box(Vector3(0.07, 0.06, 0.02)), gold, Vector3(0, 0.12, -0.14))

	# torso
	torso = _node(hips, Vector3(0, 0.05, 0))
	_mi(torso, _cap(0.17, 0.66), shm, Vector3(0, 0.31, 0), Vector3.ZERO, Vector3(1.2, 1, 0.75))
	_mi(torso, _sph(0.2), shm, Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.18, 0.55, 0.78))
	_mi(torso, _cyl(0.055, 0.068, 0.12), sm, Vector3(0, 0.66, 0))
	_mi(torso, _box(Vector3(0.12, 0.06, 0.03)), sm, Vector3(0, 0.62, -0.1))
	_mi(torso, _box(Vector3(0.2, 0.035, 0.12)), accm, Vector3(0, 0.62, 0.0))
	_mi(torso, _box(Vector3(0.36, 0.05, 0.02)), accm, Vector3(0, 0.44, -0.133))
	if long_robe:
		for k in 3:
			_mi(torso, _sph(0.016), gold, Vector3(0, 0.34 - k * 0.1, -0.138))
	elif o["id"] == "sport":
		_mi(torso, _box(Vector3(0.018, 0.5, 0.012)), accm, Vector3(0, 0.3, -0.135))
	elif o["id"] == "national":
		var num := Label3D.new()
		num.text = "9"
		num.font_size = 140
		num.pixel_size = 0.0032
		num.modulate = acc
		num.outline_size = 0
		num.position = Vector3(0, 0.36, 0.137)
		torso.add_child(num)

	# head & face
	head = _node(torso, Vector3(0, 0.69, 0))
	_mi(head, _sph(0.115), sm, Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(0.92, 1.12, 1.0))
	_mi(head, _sph(0.07), sm, Vector3(0, 0.055, -0.045), Vector3.ZERO, Vector3(1.05, 0.85, 0.95))
	var white := _mat(Color("f6f6f4"), 0.35)
	var iris := _mat(Color("3a2414"), 0.3)
	var dark := _mat(hair_col, 0.55)
	for sx in [-1.0, 1.0]:
		_mi(head, _sph(0.03), sm, Vector3(0.106 * sx, 0.12, 0.0), Vector3.ZERO, Vector3(0.55, 1.2, 0.9))
		_mi(head, _sph(0.021), white, Vector3(0.041 * sx, 0.15, -0.1), Vector3.ZERO, Vector3(1.15, 0.8, 0.6))
		_mi(head, _sph(0.0125), iris, Vector3(0.041 * sx, 0.15, -0.111))
		_mi(head, _sph(0.006), _mat(Color("050505"), 0.2), Vector3(0.041 * sx, 0.15, -0.121))
		_mi(head, _box(Vector3(0.056, 0.012, 0.014)), dark, Vector3(0.041 * sx, 0.186, -0.104), Vector3(0, 0, -0.16 * sx))
		var lid := _mi(head, _box(Vector3(0.056, 0.05, 0.012)), sm, Vector3(0.041 * sx, 0.15, -0.113))
		lid.scale.y = 0.02
		lids.append(lid)
		_mi(head, _box(Vector3(0.036, 0.013, 0.015)), dark, Vector3(0.019 * sx, 0.083, -0.112), Vector3(0, 0, 0.22 * sx))
		_mi(head, _sph(0.02), sm, Vector3(0.062 * sx, 0.09, -0.088), Vector3.ZERO, Vector3(1, 0.9, 0.7))
	_mi(head, _box(Vector3(0.022, 0.05, 0.026)), sm, Vector3(0, 0.13, -0.108))
	_mi(head, _sph(0.023), sm, Vector3(0, 0.108, -0.118), Vector3.ZERO, Vector3(1.0, 0.9, 1.3))
	_mi(head, _box(Vector3(0.05, 0.011, 0.014)), _mat(Color("7a3a34"), 0.5), Vector3(0, 0.068, -0.108))
	_mi(head, _box(Vector3(0.04, 0.012, 0.014)), _mat(Color("8d4a40"), 0.5), Vector3(0, 0.055, -0.107))
	var stub := _mat(Color(0.05, 0.04, 0.03, 0.42), 1.0)
	stub.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mi(head, _sph(0.108), stub, Vector3(0, 0.05, -0.008), Vector3.ZERO, Vector3(0.9, 0.55, 0.92))

	# hair
	hair = _node(head, Vector3.ZERO)
	var htype: String = o["head"]
	_mi(hair, _sph(0.113), dark, Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3(0.96, 1.0, 0.95))
	for sx in [-1.0, 1.0]:
		_mi(hair, _box(Vector3(0.02, 0.075, 0.035)), dark, Vector3(0.101 * sx, 0.115, -0.035))
	if htype in ["none", "sidara", "headband", "crown"]:
		_mi(hair, _sph(0.119), dark, Vector3(0, 0.186, 0.012), Vector3.ZERO, Vector3(1.0, 0.8, 1.04))
		_mi(hair, _sph(0.06), dark, Vector3(0, 0.236, -0.058), Vector3.ZERO, Vector3(1.45, 0.55, 1.0))
		_mi(hair, _sph(0.05), dark, Vector3(0.05, 0.25, -0.01), Vector3.ZERO, Vector3(1.0, 0.7, 1.2))
		_mi(hair, _sph(0.05), dark, Vector3(-0.05, 0.25, -0.01), Vector3.ZERO, Vector3(1.0, 0.7, 1.2))
	_head_gear(htype, o["headc"], accm)

	# arms
	for side in [-1.0, 1.0]:
		var arm := _node(torso, Vector3(0.265 * side, 0.54, 0))
		_mi(arm, _sph(0.07), shm)
		_mi(arm, _cap(0.058, 0.4), shm, Vector3(0, -0.16, 0))
		if not long_sleeve:
			_mi(arm, _cyl(0.062, 0.062, 0.035), accm, Vector3(0, -0.27, 0))
		var fore := _node(arm, Vector3(0, -0.32, 0))
		var fm: Material = shm if long_sleeve else sm
		_mi(fore, _sph(0.053), fm)
		_mi(fore, _cap(0.05, 0.36), fm, Vector3(0, -0.15, 0))
		if long_sleeve:
			_mi(fore, _cyl(0.054, 0.054, 0.03), accm, Vector3(0, -0.28, 0))
		var hand := _node(fore, Vector3(0, -0.33, 0))
		_mi(hand, _box(Vector3(0.075, 0.1, 0.038)), sm, Vector3(0, -0.04, 0))
		_mi(hand, _box(Vector3(0.07, 0.06, 0.03)), sm, Vector3(0, -0.105, 0))
		_mi(hand, _cap(0.016, 0.07), sm, Vector3(0.045 * side * -1.0, -0.03, -0.02), Vector3(0, 0, 0.35 * side))
		if side < 0.0:
			arm_l = arm
			fore_l = fore
		else:
			arm_r = arm
			fore_r = fore

	# legs
	var shin_mat: Material = sm if shorts else pm
	for side in [-1.0, 1.0]:
		var leg := _node(hips, Vector3(0.12 * side, -0.02, 0))
		_mi(leg, _cap(0.09, 0.58), pm, Vector3(0, -0.25, 0))
		var shin := _node(leg, Vector3(0, -0.48, 0))
		_mi(shin, _sph(0.075), pm if not shorts else sm)
		_mi(shin, _cap(0.068, 0.56), shin_mat, Vector3(0, -0.22, 0))
		if shorts:
			_mi(shin, _cyl(0.073, 0.073, 0.17), accm, Vector3(0, -0.33, 0))
		var foot := _node(shin, Vector3(0, -0.46, 0))
		_mi(foot, _cap(0.058, 0.3), _mat(shoes, 0.55), Vector3(0, -0.015, -0.06), Vector3(PI * 0.5, 0, 0), Vector3(1.15, 1, 0.8))
		_mi(foot, _box(Vector3(0.13, 0.026, 0.31)), _mat(Color("f2f2f2"), 0.7), Vector3(0, -0.058, -0.06))
		_mi(foot, _box(Vector3(0.07, 0.012, 0.1)), accm, Vector3(0, 0.03, -0.1))
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
		robe = _mi(hips, _cyl(0.2, 0.31, 0.92), shm, Vector3(0, -0.46, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.88))
		_mi(robe, _cyl(0.312, 0.312, 0.07), accm, Vector3(0, -0.43, 0))
		_mi(robe, _box(Vector3(0.07, 0.62, 0.02)), accm, Vector3(0, -0.05, -0.285))

func _head_gear(kind: String, c: Color, accm: Material) -> void:
	match kind:
		"cap":
			var cm := _mat(c, 0.7)
			_mi(head, _sph(0.126), cm, Vector3(0, 0.17, 0.012), Vector3.ZERO, Vector3(1.0, 0.72, 1.05))
			_mi(head, _box(Vector3(0.17, 0.014, 0.1)), cm, Vector3(0, 0.162, -0.13), Vector3(0.08, 0, 0))
			_mi(head, _sph(0.014), accm, Vector3(0, 0.262, 0.012))
			_mi(head, _sph(0.02), accm, Vector3(0, 0.2, -0.122), Vector3.ZERO, Vector3(1.2, 0.8, 0.4))
		"ghutra":
			var white := _mat(Color("f4f1ea"), 0.9)
			var chk := _mat(c, 0.9)
			_mi(head, _sph(0.133), white, Vector3(0, 0.17, 0.02), Vector3.ZERO, Vector3(1.0, 0.92, 1.1))
			_mi(head, _box(Vector3(0.05, 0.2, 0.2)), chk, Vector3(-0.135, 0.12, 0.03))
			_mi(head, _box(Vector3(0.05, 0.2, 0.2)), chk, Vector3(0.135, 0.12, 0.03))
			var t := TorusMesh.new()
			t.inner_radius = 0.118
			t.outer_radius = 0.137
			_mi(head, t, _mat(Color("151515"), 0.5), Vector3(0, 0.205, 0.015), Vector3.ZERO, Vector3(1.0, 1.0, 1.08))
			for sx in [-0.07, 0.0, 0.07]:
				var tail := _node(head, Vector3(sx, 0.14, 0.1))
				_mi(tail, _box(Vector3(0.1, 0.34, 0.025)), white if sx != 0.0 else chk, Vector3(0, -0.17, 0.02))
				tails.append(tail)
		"sidara":
			_mi(head, _cyl(0.085, 0.118, 0.15), _mat(c, 0.85), Vector3(0, 0.27, 0.0))
			_mi(head, _cyl(0.088, 0.088, 0.02), _mat(Color("5c4a2a"), 0.6), Vector3(0, 0.345, 0.0))
			_mi(head, _cyl(0.119, 0.119, 0.025), accm, Vector3(0, 0.205, 0.0))
		"beanie":
			var bm := _mat(c, 0.9)
			_mi(head, _sph(0.127), bm, Vector3(0, 0.17, 0.012), Vector3.ZERO, Vector3(1.0, 0.85, 1.05))
			_mi(head, _cyl(0.123, 0.123, 0.04), accm, Vector3(0, 0.15, 0.01))
			_mi(head, _sph(0.04), accm, Vector3(0, 0.285, 0.01))
		"headband":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.112
			t2.outer_radius = 0.126
			_mi(head, t2, _mat(c, 0.8), Vector3(0, 0.19, 0.005), Vector3.ZERO, Vector3(1.0, 1.0, 1.05))
			_mi(head, _box(Vector3(0.04, 0.06, 0.02)), _mat(c, 0.8), Vector3(0.03, 0.17, 0.125), Vector3(0, 0, 0.5))
			_mi(head, _box(Vector3(0.04, 0.06, 0.02)), _mat(c, 0.8), Vector3(-0.03, 0.16, 0.13), Vector3(0, 0, -0.5))
		"hat":
			var hm := _mat(c, 0.85)
			_mi(head, _cyl(0.2, 0.2, 0.02), hm, Vector3(0, 0.2, 0.0))
			_mi(head, _cyl(0.1, 0.12, 0.13), hm, Vector3(0, 0.27, 0.0))
			_mi(head, _cyl(0.121, 0.121, 0.03), accm, Vector3(0, 0.225, 0.0))
		"helmet":
			_mi(head, _sph(0.14), _mat(c, 0.25, 0.8), Vector3(0, 0.15, 0.02), Vector3.ZERO, Vector3(1.0, 1.0, 1.05))
			_mi(head, _box(Vector3(0.17, 0.07, 0.03)), _mat(Color("101820"), 0.1, 0.6), Vector3(0, 0.15, -0.125))
			_mi(head, _box(Vector3(0.03, 0.2, 0.2)), accm, Vector3(0, 0.27, 0.01))
		"crown":
			var gm := _mat(Color("e2b033"), 0.25, 0.9)
			_mi(head, _cyl(0.118, 0.118, 0.05), gm, Vector3(0, 0.255, 0.0))
			for i in 5:
				var a := i * TAU / 5.0
				_mi(head, _cyl(0.0, 0.025, 0.07), gm, Vector3(cos(a) * 0.105, 0.31, sin(a) * 0.105))
				_mi(head, _sph(0.014), _mat(c, 0.3, 0.2), Vector3(cos(a) * 0.118, 0.255, sin(a) * 0.118))
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
