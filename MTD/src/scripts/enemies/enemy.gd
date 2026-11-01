class_name Enemy
extends Node2D

## Базовый враг. Движется вниз к стене, лёгкий зигзаг.

@export_group("Stats")
@export var max_hp: float = 30.0
@export var move_speed: float = 180.0
@export var damage_to_wall: float = 5.0

@export_group("Zigzag")
@export var zigzag_amplitude: float = 40.0
@export var zigzag_frequency: float = 2.0

var hp: float = 30.0
var _target_y: float = 2070.0
var _base_x: float = 0.0
var _time: float = 0.0
var _alive: bool = true

signal reached_wall(enemy: Enemy)
signal died(enemy: Enemy)

@onready var sprite: Sprite2D = $Sprite2D


func setup(spawn_pos: Vector2, target_y: float) -> void:
	global_position = spawn_pos
	_base_x = spawn_pos.x
	_target_y = target_y
	hp = max_hp
	_alive = true
	_time = randf() * TAU  # разный фазовый сдвиг зигзага


func _process(delta: float) -> void:
	if not _alive:
		return

	_time += delta

	# Движение вниз
	var pos := global_position
	pos.y += move_speed * delta

	# Зигзаг по X вокруг базовой линии
	pos.x = _base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude

	global_position = pos

	if global_position.y >= _target_y:
		_alive = false
		reached_wall.emit(self)
		queue_free()


func take_damage(amount: float) -> void:
	if not _alive:
		return
	hp -= amount
	if hp <= 0.0:
		_alive = false
		died.emit(self)
		queue_free()
