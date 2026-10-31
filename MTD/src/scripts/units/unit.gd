class_name Unit
extends Node2D

## Базовый юнит на стене.
## Статы берутся из UnitStats (assets/data/unit_stats.gd).

enum UnitType { ARCHER, MAGE, CANNON }

@export var unit_type: UnitType = UnitType.ARCHER
@export var level: int = 1

# Боевые статы (заполняются из UnitStats)
var damage: float = 10.0
var attack_speed: float = 1.0
var attack_range: float = 300.0
var splash_radius: float = 0.0

var slot_index: int = -1
var target_global: Vector2 = Vector2.ZERO

## --- Прыжок / движение (видно в инспекторе) ---
@export_group("Jump")
@export var gravity: float = 3200.0
@export var jump_duration: float = 0.55
@export var shift_duration: float = 0.28

var _flying: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _flight_time: float = 0.0
var _flight_max: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func setup(type: UnitType, lvl: int = 1) -> void:
	unit_type = type
	level = lvl
	_apply_stats()


func _apply_stats() -> void:
	var stats_type := _to_stats_type(unit_type)
	var base: Dictionary = UnitStats.get_base(stats_type)
	if base.is_empty():
		push_warning("UnitStats: нет данных для типа %s" % unit_type)
		return

	damage = base.get("damage", 10.0)
	attack_speed = base.get("attack_speed", 1.0)
	attack_range = base.get("range", 300.0)
	splash_radius = base.get("splash_radius", 0.0)

	for _i in range(level - 1):
		damage *= UnitStats.MERGE_DAMAGE_MULT
		attack_range *= UnitStats.MERGE_RANGE_MULT


func _to_stats_type(t: UnitType) -> UnitStats.UnitType:
	match t:
		UnitType.ARCHER:
			return UnitStats.UnitType.ARCHER
		UnitType.MAGE:
			return UnitStats.UnitType.MAGE
		UnitType.CANNON:
			return UnitStats.UnitType.CANNON
	return UnitStats.UnitType.ARCHER


func play_spawn_jump(from_global: Vector2, to_global: Vector2) -> void:
	global_position = from_global
	target_global = to_global
	z_index = 30

	var T := jump_duration
	var dx := to_global.x - from_global.x
	var dy := to_global.y - from_global.y

	_velocity = Vector2(
		dx / T,
		(dy / T) - 0.5 * gravity * T
	)

	_flight_time = 0.0
	_flight_max = T
	_flying = true


func _process(delta: float) -> void:
	if not _flying:
		return

	_flight_time += delta
	_velocity.y += gravity * delta
	global_position += _velocity * delta

	if _flight_time >= _flight_max:
		_flying = false
		global_position = target_global
		z_index = 0


func move_to_slot(to_global: Vector2) -> void:
	if _flying:
		return
	target_global = to_global
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", to_global, shift_duration)
