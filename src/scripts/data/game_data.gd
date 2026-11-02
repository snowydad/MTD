class_name GameData
extends RefCounted

## Читает CSV из assets/data/. Править таблицы, не код.

const ENEMIES_PATH := "res://assets/data/enemies.csv"
const ECONOMY_PATH := "res://assets/data/economy.csv"

static var _enemies: Dictionary = {}  # type -> stats dict
static var _economy: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {}
	_economy = {}
	_load_enemies()
	_load_economy()


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
		var c := line.split(",")
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
		var c := line.split(",")
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


static func perk_cost() -> int:
	_ensure()
	return int(_economy.get("perk_cost", "50"))


static func perk_bonus() -> float:
	_ensure()
	return float(_economy.get("perk_bonus", "0.15"))
