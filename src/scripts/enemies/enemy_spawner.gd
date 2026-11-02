class_name EnemySpawner
extends Node2D

## Цифры спавна — только в сцене (main.tscn → GoblinSpawner).
## Дефолты в скрипте — запасные, если в tscn ничего не записано.

@export var enemy_scene: PackedScene
@export var target_y: float = 2070.0

@export_group("Spawn")
@export var auto_start: bool = true
@export var spawn_interval: float = 1.0
@export var spawn_count: int = -1
@export var spawn_x_min: float = 300.0
@export var spawn_x_max: float = 825.0
@export var spawn_y: float = -50.0

var _timer: float = 0.0
var _spawned: int = 0
var _running: bool = false

signal enemy_spawned(enemy: Node2D)
signal enemy_reached_wall(enemy: Node2D)
signal enemy_died(enemy: Node2D)


func _ready() -> void:
	print("EnemySpawner ready: interval=", spawn_interval,
		" x=[", spawn_x_min, "..", spawn_x_max, "]",
		" scene=", enemy_scene)
	if auto_start:
		start()


func start() -> void:
	_running = true
	_spawned = 0
	_timer = spawn_interval


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	if enemy_scene == null:
		return
	if spawn_count >= 0 and _spawned >= spawn_count:
		_running = false
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_spawn_one()


func _spawn_one() -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	var x := randf_range(spawn_x_min, spawn_x_max)
	var pos := Vector2(x, spawn_y)
	add_child(enemy)
	enemy.setup(pos, target_y)
	enemy.reached_wall.connect(_on_reached_wall)
	enemy.died.connect(_on_died)
	_spawned += 1
	enemy_spawned.emit(enemy)


func _on_reached_wall(enemy: Enemy) -> void:
	enemy_reached_wall.emit(enemy)
	print(enemy.name, " reached wall, dmg=", enemy.damage_to_wall)


func _on_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
