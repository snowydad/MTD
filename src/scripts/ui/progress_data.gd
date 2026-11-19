extends Node

## Сохранение прогресса: user://mtd_progress.cfg

const SAVE_PATH := "user://mtd_progress.cfg"

var gold: int = 0
## Максимальный открытый номер уровня (1 = только первый).
var max_unlocked_level: int = 1
var selected_level: int = 1
var sfx_on: bool = true
var music_on: bool = true
var language: String = "en"  # en | ru
var player_id: String = ""

## id апгрейда кузницы → купленный ранг (0 = не куплен).
var forge_ranks: Dictionary = {}

signal gold_changed(value: int)
signal progress_changed
signal forge_changed


func _ready() -> void:
	if player_id.is_empty():
		player_id = _make_player_id()
	load_save()


func _make_player_id() -> String:
	return "MTD-%s" % str(Time.get_unix_time_from_system()).sha256_text().substr(0, 12).to_upper()


func max_level_available() -> int:
	return WaveData.max_level()


func is_unlocked(level_id: int) -> bool:
	return level_id >= 1 and level_id <= max_unlocked_level and level_id <= max_level_available()


func select_level(level_id: int) -> void:
	if not is_unlocked(level_id):
		return
	selected_level = level_id
	save()
	progress_changed.emit()


func unlock_through(level_id: int) -> void:
	var cap := max_level_available()
	var n := clampi(level_id, 1, cap)
	if n > max_unlocked_level:
		max_unlocked_level = n
	if selected_level < max_unlocked_level:
		selected_level = max_unlocked_level
	save()
	progress_changed.emit()


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)
	save()


func set_gold(value: int) -> void:
	gold = maxi(0, value)
	gold_changed.emit(gold)
	save()


func forge_rank(id: String) -> int:
	return int(forge_ranks.get(id, 0))


func forge_is_unlocked(id: String) -> bool:
	var u: Dictionary = GameData.forge_upgrade(id)
	if u.is_empty():
		return false
	return max_unlocked_level >= int(u.get("unlock_level", 1))


func forge_is_maxed(id: String) -> bool:
	var u: Dictionary = GameData.forge_upgrade(id)
	if u.is_empty():
		return true
	return forge_rank(id) >= int(u.get("max_rank", 0))


func forge_next_cost(id: String) -> int:
	if forge_is_maxed(id):
		return 0
	return GameData.forge_cost(id, forge_rank(id))


func can_buy_forge(id: String) -> bool:
	if not forge_is_unlocked(id):
		return false
	if forge_is_maxed(id):
		return false
	return gold >= forge_next_cost(id)


## Покупка следующего ранга. true если успешно.
func buy_forge(id: String) -> bool:
	if not can_buy_forge(id):
		return false
	var cost := forge_next_cost(id)
	gold = maxi(0, gold - cost)
	forge_ranks[id] = forge_rank(id) + 1
	gold_changed.emit(gold)
	forge_changed.emit()
	progress_changed.emit()
	save()
	return true


## Множители кузницы для типа юнита: { "range": 1.x, "fire_rate": 1.x }
func unit_forge_multipliers(unit_type: String) -> Dictionary:
	return GameData.forge_multiplier_for_unit(unit_type, forge_ranks)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "gold", gold)
	cfg.set_value("progress", "max_unlocked_level", max_unlocked_level)
	cfg.set_value("progress", "selected_level", selected_level)
	cfg.set_value("settings", "sfx_on", sfx_on)
	cfg.set_value("settings", "music_on", music_on)
	cfg.set_value("settings", "language", language)
	cfg.set_value("player", "id", player_id)
	## ranks as "id:rank,id:rank"
	var parts: PackedStringArray = PackedStringArray()
	for k in forge_ranks.keys():
		var r := int(forge_ranks[k])
		if r > 0:
			parts.append("%s:%d" % [str(k), r])
	cfg.set_value("forge", "ranks", ",".join(parts))
	cfg.save(SAVE_PATH)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		save()
		return
	gold = int(cfg.get_value("progress", "gold", 0))
	max_unlocked_level = int(cfg.get_value("progress", "max_unlocked_level", 1))
	selected_level = int(cfg.get_value("progress", "selected_level", 1))
	sfx_on = bool(cfg.get_value("settings", "sfx_on", true))
	music_on = bool(cfg.get_value("settings", "music_on", true))
	language = str(cfg.get_value("settings", "language", "en"))
	player_id = str(cfg.get_value("player", "id", player_id))
	max_unlocked_level = maxi(1, max_unlocked_level)
	selected_level = clampi(selected_level, 1, maxi(max_unlocked_level, 1))
	forge_ranks = {}
	var ranks_str := str(cfg.get_value("forge", "ranks", ""))
	if not ranks_str.is_empty():
		for part in ranks_str.split(","):
			var kv := part.strip_edges().split(":")
			if kv.size() >= 2:
				forge_ranks[str(kv[0])] = int(kv[1])
	gold_changed.emit(gold)
	progress_changed.emit()
	forge_changed.emit()
