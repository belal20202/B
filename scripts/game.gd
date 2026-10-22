extends Node3D
# Core 3D runner: infinite city track, trains and obstacles, coins, power-ups, cities by distance.

const Data = preload("res://scripts/data.gd")
const CharacterScript = preload("res://scripts/character.gd")
const Decor = preload("res://scripts/decor.gd")

signal run_ended(result)
signal city_reached(index)

const LANES := [-2.2, 0.0, 2.2]
const SEG_LEN := 24.0
const SEG_COUNT := 11
const RECYCLE_Z := 82.0
const SPAWN_Z := -170.0
const GRAV := 38.0
const REVIVE_COST := 500

var mode := "menu"            # menu | run | dead
var menu_view := "home"       # home | wardrobe
var speed := 0.0
var distance := 0.0
var run_coins := 0
var px := 0.0
var py := 0.0
var vy := 0.0
var lane := 1
var prev_lane := 1
var rolling := 0.0
var grace := 0.0
var strikes := 0
var strike_timer := 0.0
var combo := 0
var revived := false
var since_spawn := 0.0
var gap := 20.0
var pickup_cd := 0.0
var city_cur := 0
var menu_t := 0.0
var shake := 0.0
var run_time := 0.0
var jumps := 0
var rolls := 0
var timers := {"magnet": 0.0, "jet": 0.0, "mult": 0.0, "boots": 0.0, "shield": 0.0}
var durations := {"magnet": 1.0, "jet": 1.0, "mult": 1.0, "boots": 1.0, "shield": 1.0}

var obstacles: Array = []
var coin_list: Array = []
var pickup_list: Array = []
var segments: Array = []

var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var ents: Node3D
var world: Node3D
var player_root: Node3D
var character: Node3D
var shield_node: MeshInstance3D
var jet_node: Node3D
var flame_nodes: Array = []
var spark: CPUParticles3D
var look_cur := Vector3(0, 0, 0)
var font: SystemFont
var _mats := {}
var _facade: ImageTexture
var coin_mesh: CylinderMesh
var cur_top: Color
var cur_hor: Color
var cur_fog: Color
var cur_sun: Color
var horn_cd := 6.0
var sun_pitch_cur := -42.0
var sun_energy_cur := 1.25
var amb_cur := 0.9
var night_cur := 0.0
var cam_roll := 0.0
var sky_fx: Node3D
var stars: MultiMeshInstance3D
var birds: Array = []
var clouds: Array = []
var dust: CPUParticles3D
var land_fx: CPUParticles3D
var fx_speed: CPUParticles3D
var _asphalt_mat: StandardMaterial3D
var _walk_tex: ImageTexture
var _facade_em: ImageTexture
var _facade_mats: Array = []
var _cloud_mat: StandardMaterial3D
var _star_mat: StandardMaterial3D
var _moon_mat: StandardMaterial3D

func _ready() -> void:
	randomize()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans Arabic", "Noto Naskh Arabic", "Droid Arabic Naskh", "Roboto", "Arial", "sans-serif"])
	font.font_weight = 700
	Decor.font = font
	Decor.quality = int(Save.d.get("quality", 1))
	_make_textures()
	_setup_environment()
	world = Node3D.new()
	add_child(world)
	ents = Node3D.new()
	add_child(ents)
	for i in SEG_COUNT:
		var s := Node3D.new()
		s.position = Vector3(0, 0, 70.0 - SEG_LEN * 0.5 - i * SEG_LEN)
		world.add_child(s)
		segments.append(s)
		_fill_segment(s, 0)
	_setup_player()
	_setup_particles()
	_setup_sky_fx()
	look_cur = Vector3(0, 0.1, 0)
	cam.position = Vector3(1.5, 1.4, -4.2)
	cam.look_at(look_cur, Vector3.UP)
	apply_outfit()
	apply_quality(false)

# ---------------------------------------------------------------- setup

func _setup_environment() -> void:
	var th: Dictionary = Data.cities()[0]
	cur_top = th["sky_top"]
	cur_hor = th["sky_hor"]
	cur_fog = th["fog"]
	cur_sun = th["sun"]
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cur_top
	sky_mat.sky_horizon_color = cur_hor
	sky_mat.ground_horizon_color = cur_hor
	sky_mat.ground_bottom_color = Color("6b5a40")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = cur_fog
	env.fog_density = 0.0085
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = cur_sun
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 66.0
	cam.far = 260.0
	cam.current = true
	add_child(cam)

func _setup_player() -> void:
	player_root = Node3D.new()
	add_child(player_root)
	character = CharacterScript.new()
	player_root.add_child(character)
	var sm := SphereMesh.new()
	sm.radius = 1.25
	sm.height = 2.5
	shield_node = MeshInstance3D.new()
	shield_node.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.75, 1.0, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.2, 0.6, 1.0)
	m.emission_energy_multiplier = 0.6
	shield_node.material_override = m
	shield_node.position = Vector3(0, 1.0, 0)
	shield_node.visible = false
	player_root.add_child(shield_node)

func apply_outfit() -> void:
	character.build(Save.outfit_data())
	_attach_jetpack()

func _attach_jetpack() -> void:
	jet_node = Node3D.new()
	jet_node.position = Vector3(0, 0.32, 0.2)
	character.torso.add_child(jet_node)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.42, 0.16)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(Color("5b6168"), 0.4, 0.6)
	jet_node.add_child(mi)
	flame_nodes.clear()
	for sx in [-0.08, 0.08]:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.065
		cm.bottom_radius = 0.0
		cm.height = 0.38
		var f := MeshInstance3D.new()
		f.mesh = cm
		f.material_override = _emat(Color("ff8a2a"), 3.0)
		f.position = Vector3(sx, -0.38, 0.0)
		jet_node.add_child(f)
		flame_nodes.append(f)
	jet_node.visible = false

func _setup_particles() -> void:
	spark = CPUParticles3D.new()
	spark.emitting = false
	spark.one_shot = true
	spark.amount = 10
	spark.lifetime = 0.45
	spark.explosiveness = 1.0
	spark.direction = Vector3(0, 1, 0)
	spark.spread = 180.0
	spark.initial_velocity_min = 2.0
	spark.initial_velocity_max = 4.5
	spark.gravity = Vector3(0, -7, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	spark.mesh = sm
	spark.material_override = _emat(Color("ffd84a"), 3.0)
	add_child(spark)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.85, 0.75, 0.6, 0.4)
	var dmesh := SphereMesh.new()
	dmesh.radius = 0.12
	dmesh.height = 0.24
	dmesh.radial_segments = 6
	dmesh.rings = 3
	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.amount = 14
	dust.lifetime = 0.5
	dust.local_coords = false
	dust.direction = Vector3(0, 0.3, 1)
	dust.spread = 25.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 8.0
	dust.gravity = Vector3(0, 0.6, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.5
	dust.mesh = dmesh
	dust.material_override = dm
	dust.position = Vector3(0, 0.1, 0.25)
	player_root.add_child(dust)
	land_fx = CPUParticles3D.new()
	land_fx.emitting = false
	land_fx.one_shot = true
	land_fx.amount = 12
	land_fx.lifetime = 0.5
	land_fx.explosiveness = 1.0
	land_fx.local_coords = false
	land_fx.direction = Vector3(0, 1, 0.3)
	land_fx.spread = 80.0
	land_fx.initial_velocity_min = 2.0
	land_fx.initial_velocity_max = 5.0
	land_fx.gravity = Vector3(0, -3, 0)
	land_fx.mesh = dmesh
	land_fx.material_override = dm
	land_fx.position = Vector3(0, 0.1, 0)
	player_root.add_child(land_fx)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.albedo_color = Color(1, 1, 1, 0.35)
	var lmesh := BoxMesh.new()
	lmesh.size = Vector3(0.02, 0.02, 1.8)
	fx_speed = CPUParticles3D.new()
	fx_speed.emitting = false
	fx_speed.amount = 26
	fx_speed.lifetime = 0.35
	fx_speed.local_coords = true
	fx_speed.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fx_speed.emission_box_extents = Vector3(5.0, 3.0, 1.0)
	fx_speed.direction = Vector3(0, 0, 1)
	fx_speed.spread = 0.0
	fx_speed.initial_velocity_min = 55.0
	fx_speed.initial_velocity_max = 60.0
	fx_speed.gravity = Vector3.ZERO
	fx_speed.mesh = lmesh
	fx_speed.material_override = lm
	fx_speed.position = Vector3(0, 0, -9)
	cam.add_child(fx_speed)

# ---------------------------------------------------------------- materials & helpers

func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "m%s_%s_%s" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m

func _emat(c: Color, energy: float) -> StandardMaterial3D:
	var key := "e%s_%s" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m

func _facade_mat(c: Color) -> StandardMaterial3D:
	var key := "f" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _facade
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.2, 0.2, 0.2)
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission_texture = _facade_em
	m.emission_energy_multiplier = night_cur * 1.8
	_mats[key] = m
	_facade_mats.append(m)
	return m

func _make_facade() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	var em := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	em.fill(Color(0, 0, 0, 1))
	for cx in [7, 37]:
		for cy in [8, 38]:
			var lit := randf() < 0.2
			var on_at_night := randf() < 0.6
			var col := Color(0.96, 0.82, 0.5) if lit else Color(0.15, 0.23, 0.33)
			var ecol := Color(1.0, 0.78, 0.4) if on_at_night else Color(0, 0, 0)
			for x in range(cx, cx + 20):
				for y in range(cy, cy + 18):
					img.set_pixel(x, y, col)
					em.set_pixel(x, y, ecol)
			for x in range(cx - 2, cx + 22):
				img.set_pixel(x, cy + 19, Color(0.72, 0.72, 0.72))
				img.set_pixel(x, cy + 20, Color(0.72, 0.72, 0.72))
	for x in 64:
		img.set_pixel(x, 31, Color(0.86, 0.86, 0.86))
		img.set_pixel(x, 63, Color(0.86, 0.86, 0.86))
	img.generate_mipmaps()
	em.generate_mipmaps()
	_facade_em = ImageTexture.create_from_image(em)
	return ImageTexture.create_from_image(img)

func _b(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, rt: float, rb: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _sph(parent: Node3D, r: float, mat: Material, pos: Vector3, hemi := false, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemi else r * 2.0
	m.is_hemisphere = hemi
	m.radial_segments = 16
	m.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- track segments

func _fill_segment(seg: Node3D, ci: int) -> void:
	for c in seg.get_children():
		c.queue_free()
	var th: Dictionary = Data.cities()[ci]
	var hq: bool = Decor.quality > 0
	_b(seg, Vector3(9.6, 0.2, SEG_LEN), _asphalt_mat, Vector3(0, -0.1, 0))
	_b(seg, Vector3(220.0, 0.2, SEG_LEN), _mat(th["ground"], 1.0), Vector3(0, -0.45, 0))
	var steel := _mat(Color("8d949c"), 0.35, 0.8)
	for lx in LANES:
		_b(seg, Vector3(0.09, 0.12, SEG_LEN), steel, Vector3(lx - 0.7, 0.05, 0))
		_b(seg, Vector3(0.09, 0.12, SEG_LEN), steel, Vector3(lx + 0.7, 0.05, 0))
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	var dmesh := BoxMesh.new()
	dmesh.size = Vector3(0.12, 0.02, 2.2)
	dm.mesh = dmesh
	dm.instance_count = 8
	var di := 0
	for bx in [-1.1, 1.1]:
		for k in 4:
			dm.set_instance_transform(di, Transform3D(Basis(), Vector3(bx, 0.01, -SEG_LEN * 0.5 + 3.0 + k * 6.0)))
			di += 1
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dm
	dmi.material_override = _mat(Color("e8e4d4"), 0.9)
	seg.add_child(dmi)
	var yellow := _mat(Color("e0b020"), 0.8)
	var curb_a := _mat(Color("c8372d"), 0.8)
	var curb_b := _mat(Color("f0f0f0"), 0.8)
	for side in [-1.0, 1.0]:
		_b(seg, Vector3(0.1, 0.02, SEG_LEN), yellow, Vector3(side * 4.55, 0.012, 0))
		for k in 4:
			_b(seg, Vector3(0.45, 0.28, 6.0), curb_a if k % 2 == 0 else curb_b, Vector3(side * 4.95, 0.04, -9.0 + k * 6.0))
		_b(seg, Vector3(3.6, 0.22, SEG_LEN), _walk_mat(th["walk"]), Vector3(side * 7.0, -0.02, 0))
	if hq:
		_road_details(seg)
	var water: bool = th.get("water", false)
	if water:
		_b(seg, Vector3(60.0, 0.1, SEG_LEN), _mat(Color("2c78a8"), 0.1, 0.3), Vector3(-40.0, -0.2, 0))
		_b(seg, Vector3(0.12, 0.9, SEG_LEN), _mat(Color("e8e4d4")), Vector3(-8.7, 0.5, 0))
		if hq and randf() < 0.55:
			Decor.boat(seg, Vector3(-randf_range(14.0, 30.0), -0.1, randf_range(-4.0, 4.0)))
	# buildings
	var bcols: Array = th["bld"]
	var awn := [Color("b8452f"), Color("2f6f8f"), Color("d9a21b"), Color("4a7c59")]
	var shops: Array = th["shops"]
	for side in [-1.0, 1.0]:
		if water and side < 0.0:
			continue
		for k in 3:
			var w := randf_range(5.0, 10.0)
			var h := randf_range(float(th["hmin"]), float(th["hmax"]))
			var d := 7.2
			var cx: float = side * (9.4 + w * 0.5)
			var cz := -8.0 + k * 8.0
			var bc: Color = bcols[randi() % bcols.size()]
			_b(seg, Vector3(w, h, d), _facade_mat(bc), Vector3(cx, h * 0.5, cz))
			_b(seg, Vector3(w + 0.3, 0.5, d + 0.3), _mat(bc.darkened(0.25)), Vector3(cx, h + 0.25, cz))
			_b(seg, Vector3(0.9, 0.12, d - 1.0), _mat(awn[randi() % 4], 0.8), Vector3(side * 8.9, 3.0, cz), Vector3(0, 0, side * 0.25))
			if ci in [0, 3, 4] and randf() < 0.6:
				_b(seg, Vector3(0.9, 2.0, 2.6), _mat(Color("7a4b26"), 0.7), Vector3(side * 8.9, 6.5, cz))
			if randf() < 0.4:
				_cyl(seg, 0.9, 0.9, 1.6, _mat(Color("8a8a8a"), 0.6, 0.4), Vector3(cx, h + 1.2, cz), Vector3.ZERO, 10)
			if hq:
				Decor.building_extras(seg, side, cx, cz, w, h)
				if randf() < 0.55:
					Decor.sign_board(seg, shops[randi() % shops.size()], Vector3(side * 9.36, 2.3, cz + randf_range(-1.5, 1.5)), side, awn[randi() % 4])
	if hq:
		for side in [-1.0, 1.0]:
			if water and side < 0.0:
				continue
			for k in 2:
				var fw := randf_range(8.0, 16.0)
				var fh := randf_range(20.0, 46.0) if ci == 2 else randf_range(14.0, 30.0)
				var fc: Color = bcols[randi() % bcols.size()]
				_b(seg, Vector3(fw, fh, 10.0), _facade_mat(fc.darkened(0.12)), Vector3(side * randf_range(34.0, 55.0), fh * 0.5, -6.0 + k * 12.0))
	# trees, lamps, wires, flags
	var has_bridge := hq and randf() < 0.14
	var tn := int(th["tree_n"])
	if not hq:
		tn = maxi(1, tn / 2)
	for side in [-1.0, 1.0]:
		if not has_bridge:
			for k in tn:
				var tz := randf_range(-11.0, 11.0)
				var tx: float = side * randf_range(6.6, 7.6)
				if th["trees"] == "palm":
					Decor.palm(seg, Vector3(tx, 0, tz))
				else:
					Decor.pine(seg, Vector3(tx, 0, tz))
		for lz in [-6.0, 6.0]:
			_cyl(seg, 0.07, 0.09, 4.6, _mat(Color("3a3f45"), 0.5, 0.6), Vector3(side * 5.5, 2.3, lz), Vector3.ZERO, 8)
			_b(seg, Vector3(0.9, 0.08, 0.08), _mat(Color("3a3f45")), Vector3(side * 5.1, 4.6, lz))
			_sph(seg, 0.18, _emat(Color("ffe3a3"), 3.5), Vector3(side * 4.7, 4.5, lz))
		if hq:
			Decor.wires(seg, side)
			if th.get("flags", false) and randf() < 0.5:
				Decor.flag(seg, Vector3(side * 6.4, 0, randf_range(-9.0, 9.0)))
			for k in randi_range(1, 2):
				Decor.person(seg, side * randf_range(6.0, 8.2), 10.0, -10.0)
	if hq and th.get("bunting", false) and randf() < 0.3 and not has_bridge:
		Decor.bunting(seg, 6.2, 9.3)
	if has_bridge:
		Decor.overpass(seg)
	if randf() < 0.6:
		var s := -1.0 if randf() < 0.5 else 1.0
		if not (water and s < 0.0):
			_landmark(seg, th["lm"], Vector3(s * randf_range(24.0, 34.0), 0, randf_range(-6.0, 6.0)))
		elif water:
			_landmark(seg, th["lm"], Vector3(30.0, 0, randf_range(-6.0, 6.0)))

func _landmark(parent: Node3D, kind: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var gold := _mat(Color("e2b033"), 0.25, 0.9)
	var cream := _mat(Color("eadfc4"), 0.9)
	var turq := _mat(Color("2aa6b5"), 0.4, 0.2)
	match kind:
		"mosque", "mosque_gold":
			var big := kind == "mosque_gold"
			_b(n, Vector3(14, 7, 14), cream, Vector3(0, 3.5, 0))
			_cyl(n, 5.0, 5.0, 2.0, cream, Vector3(0, 8.0, 0), Vector3.ZERO, 20)
			_sph(n, 5.4 if big else 4.6, gold if big else turq, Vector3(0, 9.0, 0), true)
			_cyl(n, 0.1, 0.1, 3.0, gold, Vector3(0, 14.4 if big else 13.4, 0), Vector3.ZERO, 6)
			for sx in [-8.0, 8.0]:
				_cyl(n, 0.55, 0.75, 24.0, cream, Vector3(sx, 12.0, 8.0), Vector3.ZERO, 12)
				_cyl(n, 1.0, 1.0, 0.4, gold, Vector3(sx, 20.0, 8.0), Vector3.ZERO, 12)
				_sph(n, 0.8, gold, Vector3(sx, 24.0, 8.0), true)
		"crane":
			var orange := _mat(Color("e8742a"), 0.6)
			_b(n, Vector3(1.2, 28, 1.2), orange, Vector3(-4, 14, 0))
			_b(n, Vector3(1.2, 28, 1.2), orange, Vector3(4, 14, 0))
			_b(n, Vector3(30, 1.4, 1.4), orange, Vector3(2, 28.5, 0))
			_b(n, Vector3(0.1, 8, 0.1), _mat(Color("222222")), Vector3(12, 24, 0))
			_b(n, Vector3(10, 4, 4), _mat(Color("2c3e50"), 0.7), Vector3(-6, 2, 8))
		"citadel":
			_cyl(n, 13.0, 19.0, 7.0, _mat(Color("b69f74"), 1.0), Vector3(0, 3.5, 0), Vector3.ZERO, 24)
			_cyl(n, 12.5, 12.5, 4.5, _mat(Color("cdb88c"), 0.95), Vector3(0, 9.0, 0), Vector3.ZERO, 24)
			for i in 12:
				var a := i * TAU / 12.0
				_b(n, Vector3(2.2, 1.2, 2.2), cream, Vector3(cos(a) * 12.5, 11.7, sin(a) * 12.5))
		"hadba":
			var sand := _mat(Color("c9b48a"), 0.95)
			var t := Node3D.new()
			t.rotation.z = 0.07
			n.add_child(t)
			_cyl(t, 1.1, 1.8, 30.0, sand, Vector3(0, 15, 0), Vector3.ZERO, 14)
			for hy in [8.0, 16.0, 24.0]:
				_cyl(t, 1.5, 1.5, 0.4, cream, Vector3(0, hy, 0), Vector3.ZERO, 14)
			_sph(t, 1.2, sand, Vector3(0, 30.0, 0), true)
			_b(n, Vector3(12, 5, 12), sand, Vector3(-8, 2.5, 6))
		"mountain":
			var rock := _mat(Color("7c8a74"), 1.0)
			_cyl(n, 0.0, 22.0, 30.0, rock, Vector3(0, 15, 0), Vector3.ZERO, 8)
			_cyl(n, 0.0, 7.0, 9.0, _mat(Color("f4f6f8"), 0.9), Vector3(0, 25.5, 0), Vector3.ZERO, 8)
			_cyl(n, 0.0, 16.0, 20.0, rock, Vector3(-18, 10, -6), Vector3.ZERO, 8)

# ---------------------------------------------------------------- obstacles & collectibles

func _make_obstacle(kind: String, length: float) -> Node3D:
	var n := Node3D.new()
	var bodyn := Node3D.new()
	n.add_child(bodyn)
	var wheels: Array = []
	var blink: Array = []
	var dark := _mat(Color("151515"), 0.6)
	n.set_meta("ph", randf() * 6.28)
	match kind:
		"train":
			var cols := [Color("2b5ea8"), Color("b83a3a"), Color("2e8b57"), Color("d9a21b")]
			var bc: Color = cols[randi() % 4]
			_b(bodyn, Vector3(2.0, 2.9, length), _mat(bc, 0.45, 0.3), Vector3(0, 1.75, 0))
			_b(bodyn, Vector3(2.03, 0.3, length), _mat(Color("eeeeee"), 0.6), Vector3(0, 1.15, 0))
			_b(bodyn, Vector3(2.03, 0.8, length * 0.92), _mat(Color("18222f"), 0.2, 0.5), Vector3(0, 2.55, 0))
			_b(bodyn, Vector3(1.9, 0.35, length), _mat(Color("2e3238"), 0.7), Vector3(0, 0.3, 0))
			_b(bodyn, Vector3(1.7, 0.18, length), _mat(Color("c9ced4"), 0.5, 0.4), Vector3(0, 3.28, 0))
			for k in int(length / 3.5):
				_b(bodyn, Vector3(2.05, 2.5, 0.06), _mat(bc.darkened(0.4), 0.6), Vector3(0, 1.75, -length * 0.5 + 1.7 + k * 3.5))
			_b(bodyn, Vector3(0.7, 0.3, 1.0), _mat(Color("9aa1a8"), 0.5, 0.5), Vector3(-0.4, 3.5, -length * 0.25))
			_b(bodyn, Vector3(0.7, 0.3, 1.0), _mat(Color("9aa1a8"), 0.5, 0.5), Vector3(0.4, 3.5, length * 0.2))
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("ff3b30")
			bm.emission_enabled = true
			bm.emission = Color("ff3b30")
			bm.emission_energy_multiplier = 2.0
			blink.append(bm)
			for zz in [-1.0, 1.0]:
				_sph(bodyn, 0.14, bm, Vector3(0, 3.5, zz * (length * 0.5 - 0.4)))
				for sx in [-0.62, 0.62]:
					_b(bodyn, Vector3(0.3, 0.3, 0.1), _emat(Color("fff1b0"), 2.8), Vector3(sx, 0.95, zz * (length * 0.5 + 0.02)))
				_b(bodyn, Vector3(1.4, 0.7, 0.08), _mat(Color("18222f"), 0.2, 0.5), Vector3(0, 2.4, zz * (length * 0.5 + 0.02)))
			var dest := Label3D.new()
			dest.text = Data.cities()[randi() % 6]["name"]
			dest.font = font
			dest.font_size = 64
			dest.pixel_size = 0.0052
			dest.modulate = Color("ffb52e")
			dest.outline_size = 0
			dest.position = Vector3(0, 3.0, length * 0.5 + 0.06)
			bodyn.add_child(dest)
			for zz in [-length * 0.32, length * 0.32]:
				for sx in [-0.95, 0.95]:
					var w := Node3D.new()
					w.position = Vector3(sx, 0.34, zz)
					n.add_child(w)
					wheels.append(w)
					_cyl(w, 0.34, 0.34, 0.16, dark, Vector3.ZERO, Vector3(0, 0, PI * 0.5), 12)
					_b(w, Vector3(0.18, 0.1, 0.5), _mat(Color("8d949c"), 0.4, 0.8), Vector3.ZERO)
		"taxi":
			_b(bodyn, Vector3(1.75, 0.75, length), _mat(Color("f2a900"), 0.4, 0.3), Vector3(0, 0.7, 0))
			_b(bodyn, Vector3(1.55, 0.6, length * 0.5), _mat(Color("f4f1ea"), 0.4, 0.2), Vector3(0, 1.35, 0.1))
			_b(bodyn, Vector3(1.57, 0.4, length * 0.46), _mat(Color("18222f"), 0.1, 0.6), Vector3(0, 1.38, 0.1))
			_b(bodyn, Vector3(0.5, 0.18, 0.22), _emat(Color("fff1b0"), 1.8), Vector3(0, 1.72, 0.1))
			for sx in [-0.6, 0.6]:
				_b(bodyn, Vector3(0.3, 0.2, 0.06), _emat(Color("fff1b0"), 3.0), Vector3(sx, 0.78, length * 0.5 + 0.02))
				_b(bodyn, Vector3(0.3, 0.2, 0.06), _emat(Color("ff3b30"), 2.0), Vector3(sx, 0.78, -length * 0.5 - 0.02))
			for wx in [-0.9, 0.9]:
				for wz in [-1.1, 1.1]:
					var w := Node3D.new()
					w.position = Vector3(wx, 0.34, wz)
					n.add_child(w)
					wheels.append(w)
					_cyl(w, 0.34, 0.34, 0.22, dark, Vector3.ZERO, Vector3(0, 0, PI * 0.5), 12)
					_b(w, Vector3(0.24, 0.08, 0.4), _mat(Color("b0b6bc"), 0.4, 0.8), Vector3.ZERO)
		"block":
			_b(bodyn, Vector3(1.8, 0.9, length), _mat(Color("d8d4c8"), 0.9), Vector3(0, 0.45, 0))
			_b(bodyn, Vector3(1.82, 0.22, length + 0.02), _mat(Color("c8372d")), Vector3(0, 0.3, 0))
			_b(bodyn, Vector3(1.82, 0.22, length + 0.02), _mat(Color("c8372d")), Vector3(0, 0.74, 0))
			var am := StandardMaterial3D.new()
			am.albedo_color = Color("ffb52e")
			am.emission_enabled = true
			am.emission = Color("ffb52e")
			am.emission_energy_multiplier = 2.0
			blink.append(am)
			_sph(bodyn, 0.13, am, Vector3(0, 1.02, 0))
		"stall":
			_b(bodyn, Vector3(1.7, 0.7, length), _mat(Color("8a5a30"), 0.8), Vector3(0, 0.35, 0))
			_b(bodyn, Vector3(1.8, 0.1, length + 0.1), _mat(Color("c8372d")), Vector3(0, 0.72, 0))
			var fr := [Color("d63a2b"), Color("f08a24"), Color("7fb83a"), Color("f2d13c")]
			for i in 6:
				_sph(bodyn, 0.13, _mat(fr[i % 4], 0.5), Vector3(-0.55 + (i % 3) * 0.55, 0.9, -0.25 + (i / 3) * 0.5))
			var cloth := Node3D.new()
			cloth.position = Vector3(0, 0.95, length * 0.5)
			bodyn.add_child(cloth)
			_b(cloth, Vector3(1.8, 0.35, 0.03), _mat(Color("1c9a4d"), 0.9), Vector3(0, -0.17, 0))
			n.set_meta("sway", cloth)
		"bar":
			var yel := _mat(Color("f2c200"), 0.6)
			var blk := _mat(Color("1d1d1d"), 0.7)
			for sx in [-0.98, 0.98]:
				_b(bodyn, Vector3(0.14, 1.8, 0.14), _mat(Color("5b6168"), 0.4, 0.6), Vector3(sx, 0.9, 0))
			for i in 6:
				_b(bodyn, Vector3(0.34, 0.55, 0.26), yel if i % 2 == 0 else blk, Vector3(-0.85 + i * 0.34, 1.55, 0))
			var rm := StandardMaterial3D.new()
			rm.albedo_color = Color("ff3b30")
			rm.emission_enabled = true
			rm.emission = Color("ff3b30")
			rm.emission_energy_multiplier = 2.0
			blink.append(rm)
			for sx in [-0.98, 0.98]:
				_sph(bodyn, 0.1, rm, Vector3(sx, 1.9, 0))
	n.set_meta("wheels", wheels)
	n.set_meta("blink", blink)
	n.set_meta("body", bodyn)
	return n

func _obstacle_spec(kind: String) -> Dictionary:
	match kind:
		"train":
			return {"len": randf_range(8.0, 14.0), "hw": 0.95, "y0": 0.0, "y1": 3.3}
		"taxi":
			return {"len": 3.6, "hw": 0.88, "y0": 0.0, "y1": 1.55}
		"block":
			return {"len": 1.0, "hw": 0.9, "y0": 0.0, "y1": 0.9}
		"stall":
			return {"len": 1.2, "hw": 0.88, "y0": 0.0, "y1": 0.98}
	return {"len": 0.5, "hw": 1.05, "y0": 1.25, "y1": 1.85}

func _place_obstacle(kind: String, ln: int, z: float, vx := 0.0) -> float:
	var sp := _obstacle_spec(kind)
	var node := _make_obstacle(kind, sp["len"])
	node.position = Vector3(LANES[ln], 0, z)
	ents.add_child(node)
	obstacles.append({"node": node, "kind": kind, "len": sp["len"], "hw": sp["hw"], "y0": sp["y0"], "y1": sp["y1"], "vx": vx})
	return sp["len"]

func _place_coin(x: float, y: float, z: float) -> void:
	if coin_mesh == null:
		coin_mesh = CylinderMesh.new()
		coin_mesh.top_radius = 0.3
		coin_mesh.bottom_radius = 0.3
		coin_mesh.height = 0.07
		coin_mesh.radial_segments = 14
	var holder := Node3D.new()
	holder.position = Vector3(x, y, z)
	holder.set_meta("by", y)
	var mi := MeshInstance3D.new()
	mi.mesh = coin_mesh
	mi.material_override = _coin_mat()
	mi.rotation.x = PI * 0.5
	holder.add_child(mi)
	ents.add_child(holder)
	coin_list.append(holder)

func _coin_mat() -> StandardMaterial3D:
	var key := "coin"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f6c21a")
	m.metallic = 0.9
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color("c98a00")
	m.emission_energy_multiplier = 0.6
	_mats[key] = m
	return m

func _make_pickup(id: String) -> Node3D:
	var n := Node3D.new()
	var col := Color("ffffff")
	var label := ""
	for u in Data.upgrades():
		if u["id"] == id:
			col = u["color"]
			label = u["name"]
	var core := _sph(n, 0.34, _emat(col, 1.8), Vector3.ZERO)
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.52
	var ring := MeshInstance3D.new()
	ring.mesh = t
	ring.material_override = _emat(Color("ffffff"), 1.2)
	n.add_child(ring)
	var ring2 := MeshInstance3D.new()
	ring2.mesh = t
	ring2.material_override = _emat(col, 1.5)
	ring2.rotation.x = PI * 0.5
	n.add_child(ring2)
	var l := Label3D.new()
	l.text = label
	l.font = font
	l.font_size = 64
	l.pixel_size = 0.0065
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color("ffffff")
	l.outline_size = 14
	l.position = Vector3(0, 0.95, 0)
	n.add_child(l)
	n.set_meta("ring", ring)
	n.set_meta("ring2", ring2)
	n.set_meta("core", core)
	return n

# ---------------------------------------------------------------- public controls

func start_run() -> void:
	_clear_entities()
	mode = "run"
	speed = 4.0
	distance = 0.0
	run_coins = 0
	px = 0.0
	py = 0.0
	vy = 0.0
	lane = 1
	prev_lane = 1
	rolling = 0.0
	grace = 1.0
	strikes = 0
	combo = 0
	revived = false
	since_spawn = 0.0
	gap = 16.0
	pickup_cd = 4.0
	run_time = 0.0
	jumps = 0
	rolls = 0
	horn_cd = 6.0
	city_cur = 0
	for k in timers.keys():
		timers[k] = 0.0
	shield_node.visible = false
	jet_node.visible = false
	player_root.visible = true
	Sfx.play_music("game")

func go_menu() -> void:
	_clear_entities()
	mode = "menu"
	distance = 0.0
	speed = 0.0
	px = 0.0
	py = 0.0
	player_root.visible = true
	shield_node.visible = false
	jet_node.visible = false
	for s in segments:
		_fill_segment(s, 0)
	Sfx.play_music("menu")

func revive() -> bool:
	if mode != "dead" or revived or int(Save.d["coins"]) < REVIVE_COST:
		return false
	Save.d["coins"] = int(Save.d["coins"]) - REVIVE_COST
	Save.save()
	revived = true
	mode = "run"
	speed = 10.0
	py = 0.0
	vy = 0.0
	rolling = 0.0
	grace = 2.5
	strikes = 0
	for o in obstacles.duplicate():
		if o["node"].position.z + o["len"] * 0.5 > -60.0:
			o["node"].queue_free()
			obstacles.erase(o)
	Sfx.play("power")
	return true

func move_left() -> void:
	if mode != "run" or lane <= 0:
		return
	prev_lane = lane
	lane -= 1
	Sfx.play("swipe")

func move_right() -> void:
	if mode != "run" or lane >= 2:
		return
	prev_lane = lane
	lane += 1
	Sfx.play("swipe")

func do_jump() -> void:
	if mode != "run" or timers["jet"] > 0.0:
		return
	if py <= 0.05:
		var v := sqrt(2.0 * GRAV * (4.2 if timers["boots"] > 0.0 else 2.3))
		vy = v
		rolling = 0.0
		jumps += 1
		Save.add_progress("jumps", 1)
		Sfx.play("jump")

func do_roll() -> void:
	if mode != "run" or timers["jet"] > 0.0 or rolling > 0.0:
		return
	rolling = 0.7
	rolls += 1
	Save.add_progress("rolls", 1)
	if py > 0.05:
		vy = -30.0
	Sfx.play("roll")

func get_score() -> int:
	return int(distance) + run_coins * 5

func _clear_entities() -> void:
	for c in ents.get_children():
		c.queue_free()
	obstacles.clear()
	coin_list.clear()
	pickup_list.clear()

# ---------------------------------------------------------------- main loop

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_update_theme(dt)
	match mode:
		"menu":
			_tick_menu(dt)
		"run":
			_tick_run(dt)
		"dead":
			_tick_dead(dt)

func _update_theme(dt: float) -> void:
	var idx := 0
	if mode != "menu":
		idx = Data.city_at(distance + 90.0)
	var th: Dictionary = Data.cities()[idx]
	var k := 1.0 - exp(-dt * 1.3)
	cur_top = cur_top.lerp(th["sky_top"], k)
	cur_hor = cur_hor.lerp(th["sky_hor"], k)
	cur_fog = cur_fog.lerp(th["fog"], k)
	cur_sun = cur_sun.lerp(th["sun"], k)
	sun_pitch_cur = lerpf(sun_pitch_cur, float(th["sun_pitch"]), k)
	sun_energy_cur = lerpf(sun_energy_cur, float(th["sun_energy"]), k)
	amb_cur = lerpf(amb_cur, float(th["amb"]), k)
	night_cur = lerpf(night_cur, float(th["night"]), k)
	sky_mat.sky_top_color = cur_top
	sky_mat.sky_horizon_color = cur_hor
	sky_mat.ground_horizon_color = cur_hor
	env.fog_light_color = cur_fog
	env.ambient_light_energy = amb_cur
	sun.light_color = cur_sun
	sun.light_energy = sun_energy_cur
	sun.rotation_degrees = Vector3(sun_pitch_cur, -35.0, 0.0)
	for m in _facade_mats:
		m.emission_energy_multiplier = night_cur * 1.8
	var dark := 1.0 - night_cur * 0.85
	var cc := Color.WHITE.lerp(cur_hor, 0.35)
	_cloud_mat.albedo_color = Color(cc.r * dark, cc.g * dark, cc.b * dark, 1.0)
	stars.visible = night_cur > 0.05
	stars.global_position = cam.global_position
	_star_mat.albedo_color = Color(1, 1, 1, clampf(night_cur * 1.1, 0.0, 1.0))
	_moon_mat.albedo_color = Color(1.0, 0.96, 0.8, clampf(night_cur * 1.2 - 0.1, 0.0, 1.0))
	# sky life: birds and clouds
	for b in birds:
		b["t"] += dt
		var bn: Node3D = b["n"]
		bn.position += Vector3(float(b["vx"]), 0.0, float(b["vz"]) + speed * 0.2) * dt
		var fl := sin(float(b["t"]) * 12.0) * 0.8
		b["wl"].rotation.z = fl
		b["wr"].rotation.z = -fl
		if bn.position.z > 20.0 or absf(bn.position.x) > 80.0:
			bn.position = Vector3(randf_range(-45, 45), randf_range(12, 28), randf_range(-150, -110))
		bn.visible = night_cur < 0.6
	for c in clouds:
		c.position.x += 1.6 * dt
		c.position.z += speed * 0.02 * dt
		if c.position.x > 130.0:
			c.position.x = -130.0

func _scroll(dz: float) -> void:
	var lowest := 0.0
	for s in segments:
		s.position.z += dz
		lowest = minf(lowest, s.position.z)
	for s in segments:
		if s.position.z > RECYCLE_Z + SEG_LEN * 0.5:
			lowest -= SEG_LEN
			s.position.z = lowest
			var ci := 0
			if mode != "menu":
				ci = Data.city_at(distance + 190.0)
			_fill_segment(s, ci)

func _tick_menu(dt: float) -> void:
	menu_t += dt
	var home := menu_view == "home"
	_scroll(7.0 * dt if home else 0.0)
	player_root.position = Vector3(0, 0, 0)
	character.air_vel = 0.0
	character.set_height(0.0)
	character.animate("run" if home else "hero", dt, 8.0)
	dust.emitting = false
	fx_speed.emitting = false
	var ang := sin(menu_t * 0.4) * 0.55 + 0.4
	var dist := 4.6 if home else 3.4
	var target := Vector3(sin(ang) * dist, 1.45 if home else 1.15, -cos(ang) * dist)
	cam.position = cam.position.lerp(target, 1.0 - exp(-dt * 3.0))
	var look := Vector3(0, -0.15 if home else -0.55, 0)
	look_cur = look_cur.lerp(look, 1.0 - exp(-dt * 3.0))
	cam.look_at(look_cur, Vector3.UP)
	cam.fov = lerpf(cam.fov, 62.0, dt * 3.0)

func _tick_dead(dt: float) -> void:
	character.air_vel = 0.0
	character.set_height(py)
	character.animate("dead", dt, 0.0)
	dust.emitting = false
	fx_speed.emitting = false
	shake = maxf(0.0, shake - dt * 2.0)
	_cam_follow(dt)

func _tick_run(dt: float) -> void:
	run_time += dt
	var target_speed := minf(36.0, 15.0 + distance * 0.0042)
	speed = move_toward(speed, target_speed, 9.0 * dt)
	var dz := speed * dt
	distance += dz
	_scroll(dz)
	var ci := Data.city_at(distance)
	if ci != city_cur:
		city_cur = ci
		emit_signal("city_reached", ci)
		Sfx.play("city")
	for k in timers.keys():
		if timers[k] > 0.0:
			timers[k] = maxf(0.0, timers[k] - dt)
			if timers[k] == 0.0:
				_on_expire(k)
	grace = maxf(0.0, grace - dt)
	strike_timer = maxf(0.0, strike_timer - dt)
	if strike_timer == 0.0:
		strikes = 0
	horn_cd -= dt
	if horn_cd <= 0.0:
		horn_cd = randf_range(9.0, 16.0)
		Sfx.play("horn", 1.0, -8.0)
	since_spawn += dz
	if since_spawn >= gap:
		since_spawn = 0.0
		_spawn_row()
	px = move_toward(px, LANES[lane], 15.0 * dt)
	character.lean_target = -(LANES[lane] - px) * 0.22
	if timers["jet"] > 0.0:
		py = lerpf(py, 4.6, 1.0 - exp(-dt * 4.0))
		vy = 0.0
	else:
		var was_air := py > 0.05
		vy -= GRAV * dt
		py += vy * dt
		if py <= 0.0:
			py = 0.0
			vy = 0.0
			if was_air:
				Sfx.play("land", 1.0, -6.0)
				character.land()
				land_fx.restart()
				land_fx.emitting = true
	if rolling > 0.0:
		rolling = maxf(0.0, rolling - dt)
	player_root.position = Vector3(px, py, 0)
	if grace > 0.0 and mode == "run":
		player_root.visible = int(Time.get_ticks_msec() / 90) % 2 == 0
	else:
		player_root.visible = true
	var state := "run"
	if timers["jet"] > 0.0:
		state = "fly"
	elif rolling > 0.0:
		state = "roll"
	elif py > 0.05:
		state = "jump"
	character.air_vel = vy
	character.set_height(py)
	character.animate(state, dt, speed, 1.0 - rolling / 0.7)
	dust.emitting = state == "run"
	dust.initial_velocity_min = speed * 0.5
	dust.initial_velocity_max = speed * 0.8
	fx_speed.emitting = speed > 22.0
	jet_node.visible = timers["jet"] > 0.0
	for f in flame_nodes:
		f.scale = Vector3(1.0, randf_range(0.7, 1.4), 1.0)
	shield_node.visible = timers["shield"] > 0.0
	shield_node.rotation.y += dt * 2.0
	shield_node.scale = Vector3.ONE * (1.0 + sin(run_time * 6.0) * 0.03)
	_update_entities(dt)
	if mode == "run":
		_check_collisions()
	shake = maxf(0.0, shake - dt * 2.5)
	_cam_follow(dt)

func _cam_follow(dt: float) -> void:
	var jet: bool = timers["jet"] > 0.0
	var tp := Vector3(px * 0.55, 3.9 + py * 0.3, 7.4)
	if jet:
		tp.y += 0.6
	if shake > 0.0:
		tp += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.35
	cam.position = cam.position.lerp(tp, 1.0 - exp(-dt * 6.0))
	var look := Vector3(px * 0.35, 1.3 + py * 0.35, -9.0)
	look_cur = look_cur.lerp(look, 1.0 - exp(-dt * 6.0))
	cam.look_at(look_cur, Vector3.UP)
	var roll_t := 0.0
	if mode == "run":
		roll_t = -(LANES[lane] - px) * 0.025
	cam_roll = lerpf(cam_roll, roll_t, minf(1.0, 8.0 * dt))
	cam.rotate_object_local(Vector3(0, 0, 1), cam_roll)
	var fov_t := 66.0 + (speed - 15.0) * 0.35
	cam.fov = lerpf(cam.fov, fov_t, dt * 2.0)

func _on_expire(id: String) -> void:
	if id == "jet":
		grace = 1.8
		vy = 0.0
	if id == "shield":
		pass

func _spawn_row() -> void:
	var d := clampf(distance / 5000.0, 0.0, 1.0)
	var z := SPAWN_Z
	var free := randi() % 3
	var max_len := 3.0
	var roll := randf()
	var jump_row := roll < 0.14
	var roll_row := roll >= 0.14 and roll < 0.24
	if jump_row:
		free = -1
		for ln in 3:
			max_len = maxf(max_len, _place_obstacle("block" if randf() < 0.6 else "stall", ln, z))
		for k in 7:
			_place_coin(LANES[1], 0.9 + sin(float(k) / 6.0 * PI) * 1.7, z + 6.0 - k * 1.9)
	elif roll_row:
		free = -1
		for ln in 3:
			_place_obstacle("bar", ln, z)
		for k in 6:
			_place_coin(LANES[1], 0.6, z + 5.0 - k * 1.8)
	else:
		var dens := 0.5 + 0.4 * d
		for ln in 3:
			if ln == free or randf() > dens:
				continue
			var kind := _pick_kind(d)
			var vx := 0.0
			if kind == "train" and d > 0.12 and randf() < 0.4:
				vx = randf_range(6.0, 9.0)
			max_len = maxf(max_len, _place_obstacle(kind, ln, z, vx))
		var cl := free
		for k in 8:
			_place_coin(LANES[cl], 0.7, z + 7.0 - k * 1.8)
	if timers["jet"] > 0.0:
		for k in 10:
			for ln in 3:
				if randf() < 0.5:
					_place_coin(LANES[ln], 4.4, z - 14.0 - k * 1.8)
	pickup_cd -= 1.0
	if pickup_cd <= 0.0 and free >= 0 and randf() < 0.22:
		pickup_cd = 6.0
		var ids := ["magnet", "jet", "mult", "boots", "shield"]
		var id: String = ids[randi() % 5]
		var p := _make_pickup(id)
		p.position = Vector3(LANES[free], 1.1, z - 12.0)
		ents.add_child(p)
		pickup_list.append({"node": p, "id": id})
	gap = max_len + randf_range(13.0, 17.0) + speed * 0.25

func _pick_kind(d: float) -> String:
	var r := randf()
	if d < 0.15:
		if r < 0.34:
			return "block"
		if r < 0.58:
			return "stall"
		if r < 0.78:
			return "taxi"
		if r < 0.88:
			return "bar"
		return "train"
	if r < 0.18:
		return "block"
	if r < 0.3:
		return "stall"
	if r < 0.48:
		return "taxi"
	if r < 0.6:
		return "bar"
	return "train"

func _update_entities(dt: float) -> void:
	var dz := speed * dt
	var t := run_time
	for o in obstacles.duplicate():
		var n: Node3D = o["node"]
		var vx: float = o["vx"]
		var rel: float = speed + vx
		n.position.z += dz + vx * dt
		if n.position.z - float(o["len"]) * 0.5 > 10.0:
			n.queue_free()
			obstacles.erase(o)
			continue
		var ph: float = n.get_meta("ph", 0.0)
		for w in n.get_meta("wheels", []):
			w.rotation.x += rel * dt / 0.34
		for bm in n.get_meta("blink", []):
			bm.emission_energy_multiplier = 0.6 + 3.2 * maxf(0.0, sin(t * 8.0 + ph))
		var bodyn = n.get_meta("body", null)
		if bodyn != null:
			if o["kind"] == "train":
				bodyn.rotation.z = sin(t * 7.0 + ph) * 0.006
				bodyn.position.y = sin(t * 15.0 + ph) * 0.012
			elif o["kind"] == "taxi":
				bodyn.position.y = absf(sin(t * 9.0 + ph)) * 0.035
				bodyn.rotation.z = sin(t * 6.0 + ph) * 0.01
		var sway = n.get_meta("sway", null)
		if sway != null:
			sway.rotation.x = sin(t * 3.0 + ph) * 0.1
	var target := Vector3(px, py + 1.0, 0.0)
	var magnet: bool = timers["magnet"] > 0.0
	for c in coin_list.duplicate():
		c.position.z += dz
		c.rotation.y += dt * 5.0
		var pulled: bool = c.get_meta("pulled", false)
		if magnet and c.position.z > -16.0 and c.position.z < 3.0 and absf(c.position.x - px) < 8.0:
			c.position = c.position.move_toward(target, 30.0 * dt)
			c.set_meta("pulled", true)
		elif not pulled:
			c.position.y = float(c.get_meta("by", 0.7)) + sin(t * 4.0 + c.position.x * 2.0 + c.position.z * 0.3) * 0.08
		var dzp: float = absf(c.position.z)
		if dzp < 0.9 and absf(c.position.x - px) < 1.0 and c.position.y > py - 0.3 and c.position.y < py + 2.1:
			_collect_coin(c)
		elif c.position.z > 8.0:
			c.queue_free()
			coin_list.erase(c)
	for p in pickup_list.duplicate():
		var n: Node3D = p["node"]
		n.position.z += dz
		n.rotation.y += dt * 2.5
		var ring: Node3D = n.get_meta("ring")
		ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 6.0))
		var ring2: Node3D = n.get_meta("ring2")
		ring2.rotation.y += dt * 3.0
		var core: Node3D = n.get_meta("core")
		core.position.y = sin(t * 3.0) * 0.1
		if absf(n.position.z) < 1.1 and absf(n.position.x - px) < 1.2 and absf(n.position.y - (py + 1.0)) < 1.6:
			_activate(p["id"])
			n.queue_free()
			pickup_list.erase(p)
		elif n.position.z > 8.0:
			n.queue_free()
			pickup_list.erase(p)

func _collect_coin(c: Node3D) -> void:
	var value: int = 2 if timers["mult"] > 0.0 else 1
	run_coins += value
	combo += 1
	Save.add_progress("coins", value)
	Sfx.play("coin", minf(1.0 + combo * 0.02, 1.5), -4.0)
	spark.position = c.position
	spark.restart()
	spark.emitting = true
	coin_list.erase(c)
	c.queue_free()

func _activate(id: String) -> void:
	var lvl := int(Save.d["upg"][id])
	var dur := Data.duration(id, lvl)
	timers[id] = dur
	durations[id] = dur
	Save.add_progress("powerups", 1)
	Sfx.play("power")
	if id == "jet":
		vy = 0.0

func _check_collisions() -> void:
	if grace > 0.0 or timers["jet"] > 0.0:
		return
	var p0 := py
	var p1 := py + (0.95 if rolling > 0.0 else 1.9)
	for o in obstacles:
		var n: Node3D = o["node"]
		var oz := n.position.z
		var half: float = o["len"] * 0.5
		if oz - half > 0.35 or oz + half < -0.35:
			continue
		if absf(n.position.x - px) > float(o["hw"]) + 0.3:
			continue
		if p1 <= float(o["y0"]) + 0.05 or p0 >= float(o["y1"]) - 0.05:
			continue
		_hit(oz + half)
		return

func _hit(face: float) -> void:
	if timers["shield"] > 0.0:
		timers["shield"] = 0.0
		grace = 1.3
		shake = 0.6
		Sfx.play("shield_break")
		return
	if face > 1.2 and strikes == 0:
		strikes = 1
		strike_timer = 3.0
		lane = prev_lane
		grace = 0.4
		speed *= 0.85
		shake = 0.5
		Sfx.play("bump")
		Input.vibrate_handheld(40)
		return
	_crash()

func _crash() -> void:
	mode = "dead"
	speed = 0.0
	shake = 1.0
	player_root.visible = true
	Sfx.play("crash")
	Input.vibrate_handheld(220)
	var new_best := get_score() > int(Save.d["best"])
	if new_best:
		Save.d["best"] = get_score()
	Save.d["coins"] = int(Save.d["coins"]) + run_coins
	Save.d["total_coins"] = int(Save.d["total_coins"]) + run_coins
	Save.d["runs"] = int(Save.d["runs"]) + 1
	Save.add_progress("distance", distance)
	Save.add_progress("runs", 1)
	Save.save()
	var result := {
		"score": get_score(), "distance": int(distance), "coins": run_coins,
		"best": int(Save.d["best"]), "new_best": new_best,
		"can_revive": (not revived) and int(Save.d["coins"]) >= REVIVE_COST,
	}
	await get_tree().create_timer(1.1).timeout
	if mode == "dead":
		emit_signal("run_ended", result)

func apply_quality(refill := true) -> void:
	Decor.quality = int(Save.d.get("quality", 1))
	sun.shadow_enabled = Decor.quality > 0
	if refill:
		for s in segments:
			_fill_segment(s, 0 if mode == "menu" else Data.city_at(distance + 120.0))

func _make_textures() -> void:
	_facade = _make_facade()
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var v := 0.5 + randf_range(-0.07, 0.07)
			if randf() < 0.05:
				v += 0.15
			img.set_pixel(x, y, Color(v, v, v * 1.04))
	img.generate_mipmaps()
	_asphalt_mat = StandardMaterial3D.new()
	_asphalt_mat.albedo_color = Color(0.5, 0.5, 0.52)
	_asphalt_mat.albedo_texture = ImageTexture.create_from_image(img)
	_asphalt_mat.uv1_triplanar = true
	_asphalt_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	_asphalt_mat.roughness = 0.92
	var wi := Image.create(32, 32, true, Image.FORMAT_RGB8)
	for x in 32:
		for y in 32:
			var v := 0.9 + randf_range(-0.03, 0.03)
			if x % 16 < 1 or y % 16 < 1:
				v = 0.62
			wi.set_pixel(x, y, Color(v, v, v))
	wi.generate_mipmaps()
	_walk_tex = ImageTexture.create_from_image(wi)

func _walk_mat(c: Color) -> StandardMaterial3D:
	var key := "w" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _walk_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.roughness = 0.9
	_mats[key] = m
	return m

func _setup_sky_fx() -> void:
	sky_fx = Node3D.new()
	add_child(sky_fx)
	var bm := Decor.mat(Color("22262b"), 0.8)
	for i in 8:
		var b := Node3D.new()
		sky_fx.add_child(b)
		Decor.sph(b, 0.18, bm, Vector3.ZERO, false, Vector3(0.7, 0.6, 1.6))
		var wl := Node3D.new()
		wl.position = Vector3(-0.1, 0, 0)
		b.add_child(wl)
		Decor.box(wl, Vector3(0.9, 0.03, 0.32), bm, Vector3(-0.45, 0, 0))
		var wr := Node3D.new()
		wr.position = Vector3(0.1, 0, 0)
		b.add_child(wr)
		Decor.box(wr, Vector3(0.9, 0.03, 0.32), bm, Vector3(0.45, 0, 0))
		b.position = Vector3(randf_range(-45, 45), randf_range(12, 28), randf_range(-140, -30))
		birds.append({"n": b, "wl": wl, "wr": wr, "t": randf() * 6.0, "vx": randf_range(-4.0, 4.0), "vz": randf_range(-6.0, -2.0)})
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.albedo_color = Color.WHITE
	_cloud_mat.disable_fog = true
	for i in 7:
		var c := Node3D.new()
		sky_fx.add_child(c)
		for j in 4:
			Decor.sph(c, randf_range(5.0, 9.0), _cloud_mat, Vector3(j * 7.0 - 10.0, randf_range(-1.0, 1.0), randf_range(-3.0, 3.0)), false, Vector3(1.4, 0.55, 1.0))
		c.position = Vector3(randf_range(-110, 110), randf_range(55, 80), randf_range(-190, -60))
		clouds.append(c)
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	sm.radial_segments = 4
	sm.rings = 2
	smm.mesh = sm
	smm.instance_count = 110
	for i in 110:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.12, 1.0), randf_range(-1, 1)).normalized()
		var sc := randf_range(0.6, 1.6)
		smm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), dir * 200.0))
	stars = MultiMeshInstance3D.new()
	stars.multimesh = smm
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.albedo_color = Color(1, 1, 1, 0)
	_star_mat.disable_fog = true
	stars.material_override = _star_mat
	stars.visible = false
	add_child(stars)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 9.0
	mm.height = 18.0
	moon.mesh = mm
	_moon_mat = StandardMaterial3D.new()
	_moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_moon_mat.albedo_color = Color(1.0, 0.96, 0.8, 0)
	_moon_mat.disable_fog = true
	moon.material_override = _moon_mat
	moon.position = Vector3(-90, 100, -160)
	stars.add_child(moon)

func _road_details(seg: Node3D) -> void:
	var white := _mat(Color("e8e4d4"), 0.9)
	if randf() < 0.14:
		var zc := randf_range(-8.0, 8.0)
		for i in 9:
			_b(seg, Vector3(0.5, 0.025, 3.2), white, Vector3(-4.0 + i * 1.0, 0.012, zc))
	for k in randi_range(1, 2):
		_cyl(seg, 0.42, 0.42, 0.03, _mat(Color("1b1c1e"), 0.6, 0.6), Vector3(LANES[randi() % 3] + randf_range(-0.5, 0.5), 0.015, randf_range(-10.0, 10.0)), Vector3.ZERO, 14)
	var patch := _mat(Color("2b2c30"), 1.0)
	for k in 3:
		_b(seg, Vector3(randf_range(0.8, 1.6), 0.02, randf_range(1.5, 3.0)), patch, Vector3(randf_range(-4.0, 4.0), 0.011, randf_range(-10.0, 10.0)), Vector3(0, randf_range(-0.2, 0.2), 0))
	var crack := _mat(Color("131416"), 1.0)
	for k in 3:
		_b(seg, Vector3(0.035, 0.014, randf_range(1.2, 2.6)), crack, Vector3(randf_range(-4.0, 4.0), 0.013, randf_range(-10.0, 10.0)), Vector3(0, randf_range(-0.5, 0.5), 0))
	var tire := _mat(Color("202125"), 1.0)
	for k in 2:
		_b(seg, Vector3(0.3, 0.012, randf_range(5.0, 9.0)), tire, Vector3(LANES[randi() % 3] + randf_range(-0.6, 0.6), 0.012, randf_range(-6.0, 6.0)))
