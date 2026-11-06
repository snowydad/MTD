class_name WaveManager
extends Node

## Управляет волнами: параллельные сабволны, entries с delay от старта сабволны.
## Wave Spawn Complete — все заспавнены.
## Wave Cleared — спавн завершён и на поле нет живых врагов.

signal wave_started(wave_index: int, wave_name: String)
signal wave_spawn_complete(wave_index: int)
signal wave_cleared(wave_index: int)
signal all_waves_complete

@export var target_y: float = 2070.0
@export var goblin_scene: PackedScene
@export var orc_scene: PackedScene
@export var spawn_parent_path: NodePath = ^"../Enemies"
@export var pause_between_waves: float = 2.0
@export var auto_start: bool = true

## spawn_x_min/max — из waves.csv на каждую entry (пиксели)
@export var spawn_y: float = -50.0

var current_wave_index: int = -1
var _spawn_parent: Node2D
var _planned: int = 0
var _spawned: int = 0
var _spawn_done: bool = false
var _cleared: bool = false
var _running: bool = false
var _entry_jobs_left: int = 0


func _ready() -> void:
	_spawn_parent = get_node_or_null(spawn_parent_path) as Node2D
	if _spawn_parent == null:
		_spawn_parent = get_parent() as Node2D
	if auto_start:
		call_deferred("start_sequence")


func start_sequence() -> void:
	if _running:
		return
	_running = true
	current_wave_index = -1
	_start_next_wave()


func restart_sequence() -> void:
	## Новый уровень / повтор с первой волны текущего WaveData.
	_running = false
	_spawn_done = false
	_cleared = false
	_entry_jobs_left = 0
	_planned = 0
	_spawned = 0
	current_wave_index = -1
	start_sequence()


func _start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= WaveData.wave_count():
		_running = false
		print("=== ALL WAVES COMPLETE ===")
		all_waves_complete.emit()
		return

	var wave: Dictionary = WaveData.get_wave(current_wave_index)
	_planned = WaveData.total_enemies_in_wave(wave)
	_spawned = 0
	_spawn_done = false
	_cleared = false
	_entry_jobs_left = 0

	var wname: String = str(wave.get("name", "Wave %d" % (current_wave_index + 1)))
	print("=== WAVE START: ", wname, " (enemies=", _planned, ") ===")
	wave_started.emit(current_wave_index, wname)

	# Все сабволны — параллельно
	for sw in wave.get("subwaves", []):
		_start_subwave(sw)

	if _entry_jobs_left == 0:
		_on_all_entries_finished()


func _start_subwave(sw: Dictionary) -> void:
	for entry in sw.get("entries", []):
		_entry_jobs_left += 1
		_run_entry(entry)


func _run_entry(entry: Dictionary) -> void:
	var delay: float = float(entry.get("delay", 0.0))
	var count: int = int(entry.get("count", 0))
	var interval: float = float(entry.get("interval", 1.0))
	var etype: String = str(entry.get("type", "goblin"))
	var x_min: float = float(entry.get("spawn_x_min", 35.0))
	var x_max: float = float(entry.get("spawn_x_max", 1100.0))

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not _running:
		_entry_jobs_left -= 1
		return

	for i in range(count):
		if not _running:
			break
		_spawn_enemy(etype, x_min, x_max)
		if i < count - 1 and interval > 0.0:
			await get_tree().create_timer(interval).timeout

	_entry_jobs_left -= 1
	if _entry_jobs_left <= 0:
		_on_all_entries_finished()


func _spawn_enemy(etype: String, x_min: float = 35.0, x_max: float = 1100.0) -> void:
	var scene: PackedScene = null
	match etype:
		"orc":
			scene = orc_scene
		_:
			scene = goblin_scene

	if scene == null:
		push_warning("WaveManager: no scene for type " + etype)
		return

	var enemy: Enemy = scene.instantiate()
	GameData.apply_to_enemy(enemy, etype)
	var x := randf_range(x_min, x_max)
	var pos := Vector2(x, spawn_y)
	_spawn_parent.add_child(enemy)
	enemy.setup(pos, target_y)
	# setup сбрасывает hp из max_hp — данные уже на enemy
	enemy.hp = enemy.max_hp
	enemy.reached_wall.connect(_on_enemy_resolved)
	enemy.died.connect(_on_enemy_resolved)
	_spawned += 1


func _on_all_entries_finished() -> void:
	if _spawn_done:
		return
	_spawn_done = true
	print("=== WAVE SPAWN COMPLETE: wave ", current_wave_index + 1, " ===")
	wave_spawn_complete.emit(current_wave_index)
	_check_cleared()


func _on_enemy_resolved(_enemy: Enemy) -> void:
	# Смерть или дошёл до стены — с поля ушёл
	_check_cleared()


func _check_cleared() -> void:
	if _cleared or not _spawn_done:
		return
	# Дать queue_free отработать
	await get_tree().process_frame
	if _cleared or not _spawn_done:
		return

	var alive := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e != null and e._alive:
			alive += 1
	if alive > 0:
		return

	_cleared = true
	print("=== WAVE CLEARED: wave ", current_wave_index + 1, " ===")
	wave_cleared.emit(current_wave_index)

	if pause_between_waves > 0.0:
		await get_tree().create_timer(pause_between_waves).timeout
	if _running:
		_start_next_wave()


func stop() -> void:
	_running = false
