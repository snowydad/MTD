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

signal gold_changed(value: int)
signal progress_changed


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


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "gold", gold)
	cfg.set_value("progress", "max_unlocked_level", max_unlocked_level)
	cfg.set_value("progress", "selected_level", selected_level)
	cfg.set_value("settings", "sfx_on", sfx_on)
	cfg.set_value("settings", "music_on", music_on)
	cfg.set_value("settings", "language", language)
	cfg.set_value("player", "id", player_id)
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
	gold_changed.emit(gold)
	progress_changed.emit()
