class_name GameData
extends RefCounted

## Читает TSV/JSON из assets/data/. Править таблицы, не код.

const ENEMIES_PATH := "res://assets/data/enemies.tsv"
const ECONOMY_PATH := "res://assets/data/economy.tsv"
const UNITS_PATH := "res://assets/data/units.json"

static var _enemies: Dictionary = {}
static var _economy: Dictionary = {}
static var _units: Dictionary = {}  # type -> { level_str -> stats }
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {}
	_economy = {}
	_load_enemies()
	_load_economy()
	_load_units()


static func reload() -> void:
	_loaded = false
	_ensure()


static func _load_enemies() -> void:
	if not FileAccess.file_exists(ENEMIES_PATH):
		push_error("GameData: нет " + ENEMIES_PATH)
		return
	var f := FileAccess.open(ENEMIES_PATH, FileAccess.READ)
	if f == null:
		return
	f.get_line()  # header
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var c := line.split("\t")
		if c.size() < 7:
			continue
		var t := c[0].strip_edges().to_lower()
		_enemies[t] = {
			"max_hp": float(c[1]),
			"move_speed": float(c[2]),
			"damage_to_wall": float(c[3]),
			"gold_reward": int(c[4]),
			"zigzag_amplitude": float(c[5]),
			"zigzag_frequency": float(c[6]),
		}
	f.close()
	print("GameData: enemies ", _enemies.keys())


static func _load_economy() -> void:
	if not FileAccess.file_exists(ECONOMY_PATH):
		push_error("GameData: нет " + ECONOMY_PATH)
		return
	var f := FileAccess.open(ECONOMY_PATH, FileAccess.READ)
	if f == null:
		return
	f.get_line()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var c := line.split("\t")
		if c.size() < 2:
			continue
		_economy[c[0].strip_edges()] = c[1].strip_edges()
	f.close()
	print("GameData: economy ", _economy)


static func enemy_stats(type: String) -> Dictionary:
	_ensure()
	return _enemies.get(type.to_lower(), {})


static func gold_for(type: String) -> int:
	var s := enemy_stats(type)
	if s.has("gold_reward"):
		return int(s["gold_reward"])
	return 0



static func apply_to_enemy(enemy: Enemy, type: String) -> void:
	var s := enemy_stats(type)
	if s.is_empty():
		return
	enemy.max_hp = float(s["max_hp"])
	enemy.move_speed = float(s["move_speed"])
	enemy.damage_to_wall = float(s["damage_to_wall"])
	enemy.gold_reward = int(s["gold_reward"])
	enemy.zigzag_amplitude = float(s["zigzag_amplitude"])
	enemy.zigzag_frequency = float(s["zigzag_frequency"])
	enemy.hp = enemy.max_hp



static func _load_units() -> void:
	_units = {}
	if not FileAccess.file_exists(UNITS_PATH):
		push_error("GameData: нет " + UNITS_PATH)
		return
	var f := FileAccess.open(UNITS_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GameData: units.json — ожидался объект")
		return
	for type_key in data.keys():
		var tname := str(type_key).to_lower()
		var levels = data[type_key]
		if typeof(levels) != TYPE_DICTIONARY:
			continue
		_units[tname] = {}
		for lv_key in levels.keys():
			var st = levels[lv_key]
			if typeof(st) != TYPE_DICTIONARY:
				continue
			_units[tname][str(lv_key)] = {
				"damage": float(st.get("damage", 10.0)),
				"attack_speed": float(st.get("attack_speed", 1.0)),
				"range": float(st.get("range", 300.0)),
				"splash_radius": float(st.get("splash_radius", 0.0)),
			}
	print("GameData: units ", _units.keys())


static func unit_stats(type: String, level: int = 1) -> Dictionary:
	_ensure()
	var tname := type.to_lower()
	if not _units.has(tname):
		return {}
	var levels: Dictionary = _units[tname]
	var key := str(level)
	if levels.has(key):
		return levels[key]
	# fallback: nearest lower level
	var best := 0
	for k in levels.keys():
		var lv := int(k)
		if lv <= level and lv > best:
			best = lv
	if best > 0:
		return levels[str(best)]
	return {}


static func perk_cost_base() -> int:
	_ensure()
	return int(_economy.get("perk_cost", "50"))


static func perk_cost_step() -> int:
	_ensure()
	return int(_economy.get("perk_cost_step", "5"))


static func perk_bonus() -> float:
	_ensure()
	return float(_economy.get("perk_bonus", "0.10"))


## устаревший алиас
static func perk_cost() -> int:
	return perk_cost_base()
