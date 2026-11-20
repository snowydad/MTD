class_name GameData
extends RefCounted

## Читает TSV/JSON из assets/data/. Править таблицы, не код.

const ENEMIES_PATH := "res://assets/data/enemies.tsv"
const ECONOMY_PATH := "res://assets/data/economy.tsv"
const UNITS_PATH := "res://assets/data/units.json"
const FORGE_PATH := "res://assets/data/forge_upgrades.tsv"

static var _enemies: Dictionary = {}
static var _economy: Dictionary = {}
static var _units: Dictionary = {}
## id → { id, unit, stat, max_rank, cost_base, cost_step, unlock_level, bonus_per_rank, label }
static var _forge: Dictionary = {}
static var _forge_order: Array = []
## unit → open_level (meta progress)
static var _unit_open: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {}
	_economy = {}
	_forge = {}
	_forge_order = []
	_unit_open = {}
	_load_enemies()
	_load_economy()
	_load_units()
	_load_forge()


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
	f.get_line()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var c := line.split("\t")
		if c.size() < 9:
			continue
		var t := c[0].strip_edges().to_lower()
		_enemies[t] = {
			"max_hp": float(c[1]),
			"max_ap": float(c[2]),
			"max_mp": float(c[3]),
			"move_speed": float(c[4]),
			"damage_to_wall": float(c[5]),
			"gold_reward": int(c[6]),
			"zigzag_amplitude": float(c[7]),
			"zigzag_frequency": float(c[8]),
			"wall_attack": float(c[9]) if c.size() >= 10 else 0.0,
			"attack_speed": float(c[10]) if c.size() >= 11 else 1.0,
			"attack_moment": float(c[11]) if c.size() >= 12 else 0.25,
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


static func apply_to_enemy(enemy: Node, type: String) -> void:
	## Без typehint Enemy — иначе цикл class_name GameData ↔ Enemy.
	var s := enemy_stats(type)
	if s.is_empty() or enemy == null:
		return
	enemy.set("max_hp", float(s["max_hp"]))
	enemy.set("max_ap", float(s.get("max_ap", 0.0)))
	enemy.set("max_mp", float(s.get("max_mp", 0.0)))
	enemy.set("move_speed", float(s["move_speed"]))
	enemy.set("damage_to_wall", float(s["damage_to_wall"]))
	enemy.set("gold_reward", int(s["gold_reward"]))
	enemy.set("zigzag_amplitude", float(s["zigzag_amplitude"]))
	enemy.set("zigzag_frequency", float(s["zigzag_frequency"]))
	enemy.set("wall_attack", float(s.get("wall_attack", 0.0)))
	enemy.set("attack_speed", float(s.get("attack_speed", 1.0)))
	enemy.set("attack_moment", float(s.get("attack_moment", 0.25)))
	enemy.set("hp", float(s["max_hp"]))
	enemy.set("ap", float(s.get("max_ap", 0.0)))
	enemy.set("mp", float(s.get("max_mp", 0.0)))


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
			# legacy "damage" → dhp if dhp missing
			var dhp_v := float(st.get("dhp", st.get("damage", 0.0)))
			_units[tname][str(lv_key)] = {
				"dhp": dhp_v,
				"mhp": float(st.get("mhp", 0.0)),
				"amp": float(st.get("amp", 0.0)),
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


static func perk_cost() -> int:
	return perk_cost_base()


static func unit_cost_step() -> int:
	_ensure()
	return int(_economy.get("unit_cost_step", "6"))


static func unit_cost_base(type: String) -> int:
	_ensure()
	var t := type.to_lower()
	var key := "unit_cost_%s" % t
	if t == "cannon" or t == "mortar":
		key = "unit_cost_mortar"
	return int(_economy.get(key, "6"))


static func _load_forge() -> void:
	_forge = {}
	_forge_order = []
	_unit_open = {}
	if not FileAccess.file_exists(FORGE_PATH):
		push_warning("GameData: нет " + FORGE_PATH)
		return
	var f := FileAccess.open(FORGE_PATH, FileAccess.READ)
	if f == null:
		return
	f.get_line()  # header
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var c := line.split("\t")
		## id unit stat max_rank cost_base cost_step unlock_level open_level bonus label
		## legacy without open_level: 9 cols → open_level=1, bonus at [7]
		if c.size() < 8:
			continue
		var id := c[0].strip_edges()
		var unit := c[1].strip_edges().to_lower()
		if unit == "mortar":
			unit = "cannon"
		var stat := c[2].strip_edges().to_lower()
		if stat == "distance":
			stat = "range"
		if stat == "speed" or stat == "as":
			stat = "fire_rate"
		var unlock_level := int(c[6])
		var open_level := 1
		var bonus := 0.10
		var label := id
		if c.size() >= 10:
			open_level = int(c[7])
			bonus = float(c[8])
			label = c[9].strip_edges()
		elif c.size() >= 9:
			## old: unlock, bonus, label
			bonus = float(c[7])
			label = c[8].strip_edges()
		else:
			bonus = float(c[7]) if c.size() >= 8 else 0.10
		var entry := {
			"id": id,
			"unit": unit,
			"stat": stat,
			"max_rank": int(c[3]),
			"cost_base": int(c[4]),
			"cost_step": int(c[5]),
			"unlock_level": unlock_level,
			"open_level": open_level,
			"bonus_per_rank": bonus,
			"label": label,
		}
		_forge[id] = entry
		_forge_order.append(id)
		## unit open = min open_level across rows (first wins if smaller)
		if not _unit_open.has(unit):
			_unit_open[unit] = open_level
		else:
			_unit_open[unit] = mini(int(_unit_open[unit]), open_level)
	f.close()
	print("GameData: forge upgrades ", _forge_order, " unit_open ", _unit_open)


static func forge_upgrade_ids() -> Array:
	_ensure()
	return _forge_order.duplicate()


static func forge_upgrade(id: String) -> Dictionary:
	_ensure()
	return _forge.get(id, {})


static func forge_cost(id: String, current_rank: int) -> int:
	## Цена покупки следующего ранга (rank → rank+1). current_rank = уже купленный.
	var u := forge_upgrade(id)
	if u.is_empty():
		return 0
	var max_r := int(u.get("max_rank", 0))
	if current_rank >= max_r:
		return 0
	return int(u.get("cost_base", 50)) + current_rank * int(u.get("cost_step", 25))


static func forge_multiplier_for_unit(unit: String, ranks: Dictionary) -> Dictionary:
	## ranks: upgrade_id → rank. Возвращает { "range": 1.x, "fire_rate": 1.x } для unit.
	_ensure()
	var t := unit.to_lower()
	if t == "mortar":
		t = "cannon"
	var range_m := 1.0
	var rate_m := 1.0
	for id in _forge_order:
		var u: Dictionary = _forge[id]
		if str(u.get("unit", "")) != t:
			continue
		var rank := int(ranks.get(id, 0))
		if rank <= 0:
			continue
		var bonus := float(u.get("bonus_per_rank", 0.0)) * float(rank)
		match str(u.get("stat", "")):
			"range":
				range_m *= 1.0 + bonus
			"fire_rate":
				rate_m *= 1.0 + bonus
	return {"range": range_m, "fire_rate": rate_m}


static func unit_open_level(unit: String) -> int:
	_ensure()
	var t := unit.to_lower()
	if t == "mortar":
		t = "cannon"
	return int(_unit_open.get(t, 1))


static func is_unit_open(unit: String, meta_level: int) -> bool:
	## Юнит доступен в бою / forge, если прогресс >= open_level.
	return meta_level >= unit_open_level(unit)
