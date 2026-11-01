class_name Unit
extends Node2D

## Базовый юнит на стене.
## Статы из UnitStats. После приземления ищет врагов и стреляет.

enum UnitType { ARCHER, MAGE, CANNON }

@export var unit_type: UnitType = UnitType.ARCHER
@export var level: int = 1

var damage: float = 10.0
var attack_speed: float = 1.0
var attack_range: float = 300.0
var splash_radius: float = 0.0

var slot_index: int = -1
var target_global: Vector2 = Vector2.ZERO

@export_group("Jump")
@export var gravity: float = 3200.0
@export var jump_duration: float = 0.55
@export var shift_duration: float = 0.28

@export_group("Combat")
@export var projectile_scene: PackedScene
@export var arrow_flight_time: float = 0.45
@export var muzzle_offset: Vector2 = Vector2(0, -40)

var _flying: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _flight_time: float = 0.0
var _flight_max: float = 0.0
var _landed: bool = false
var _attack_cd: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func setup(type: UnitType, lvl: int = 1) -> void:
	unit_type = type
	level = lvl
	_apply_stats()
	_landed = false
	_attack_cd = 0.15  # чуть паузы после спавна


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
	_landed = false

	var T := jump_duration
	var dx := to_global.x - from_global.x
	var dy := to_global.y - from_global.y
	_velocity = Vector2(dx / T, (dy / T) - 0.5 * gravity * T)
	_flight_time = 0.0
	_flight_max = T
	_flying = true


func _process(delta: float) -> void:
	if _flying:
		_flight_time += delta
		_velocity.y += gravity * delta
		global_position += _velocity * delta
		if _flight_time >= _flight_max:
			_flying = false
			global_position = target_global
			z_index = 0
			_landed = true
		return

	if not _landed:
		return

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		var target := _find_target()
		if target != null:
			_fire_at(target)
			_attack_cd = 1.0 / maxf(attack_speed, 0.05)


func move_to_slot(to_global: Vector2) -> void:
	if _flying:
		return
	target_global = to_global
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", to_global, shift_duration)


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_d := attack_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e._alive:
			continue
		var d := global_position.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _fire_at(target: Enemy) -> void:
	if projectile_scene == null:
		push_warning("Unit: projectile_scene not set")
		return
	var arrow: Projectile = projectile_scene.instantiate()
	# Снаряды в тот же World, что и юниты
	var parent := get_parent()
	while parent and parent.name != "World":
		parent = parent.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(arrow)
	var from := global_position + muzzle_offset
	arrow.launch(from, target, damage, arrow_flight_time)
