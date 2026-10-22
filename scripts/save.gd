
extends Node
# Persistent save data (JSON in user://)

const Data = preload("res://scripts/data.gd")
const PATH := "user://bassam_save.json"

var d: Dictionary = {}
var daily_reward := 0

func _ready() -> void:
	load_data()
	_check_daily()
	_ensure_missions()

func defaults() -> Dictionary:
	return {
		"coins": 250, "best": 0, "total_coins": 0, "runs": 0,
		"upg": {"magnet": 0, "jet": 0, "mult": 0, "boots": 0, "shield": 0},
		"owned": ["national"], "outfit": "national",
		"missions": [], "mission_level": 0,
		"music": true, "sfx": true, "quality": 1,
		"last_day": "", "streak": 0,
	}

func load_data() -> void:
	d = defaults()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					d[k] = parsed[k]
	for k in defaults()["upg"].keys():
		if not d["upg"].has(k):
			d["upg"][k] = 0

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _check_daily() -> void:
	var today := Time.get_date_string_from_system(true)
	if d["last_day"] == today:
		return
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	if d["last_day"] == yesterday:
		d["streak"] = int(d["streak"]) + 1
	else:
		d["streak"] = 1
	d["last_day"] = today
	daily_reward = 100 * mini(int(d["streak"]), 7)
	save()

func claim_daily() -> int:
	var r := daily_reward
	d["coins"] = int(d["coins"]) + r
	daily_reward = 0
	save()
	return r

func _new_mission(exclude: Array) -> Dictionary:
	var tpl := Data.mission_templates()
	var keys: Array = tpl.keys()
	keys.shuffle()
	var type := ""
	for k in keys:
		if not exclude.has(k):
			type = k
			break
	if type == "":
		type = keys[0]
	var lvl := mini(int(d["mission_level"]), 4)
	var target: int = tpl[type]["targets"][lvl]
	var reward := int(round(float(target) * float(tpl[type]["reward"]) / 10.0)) * 10
	return {"type": type, "target": target, "progress": 0, "reward": maxi(reward, 50), "done": false}

func _ensure_missions() -> void:
	var m: Array = d["missions"]
	while m.size() < 3:
		var ex: Array = []
		for x in m:
			ex.append(x["type"])
		m.append(_new_mission(ex))
	d["missions"] = m

func add_progress(type: String, amount: float) -> void:
	for m in d["missions"]:
		if m["type"] == type and not m["done"]:
			m["progress"] = float(m["progress"]) + amount
			if float(m["progress"]) >= float(m["target"]):
				m["progress"] = m["target"]
				m["done"] = true

func claim_mission(i: int) -> void:
	var m = d["missions"][i]
	if not m["done"]:
		return
	d["coins"] = int(d["coins"]) + int(m["reward"])
	var ex: Array = []
	for x in d["missions"]:
		ex.append(x["type"])
	d["missions"][i] = _new_mission(ex)
	d["mission_level"] = int(d["mission_level"]) + 1
	save()

func outfit_data() -> Dictionary:
	for o in Data.outfits():
		if o["id"] == d["outfit"]:
			return o
	return Data.outfits()[0]
