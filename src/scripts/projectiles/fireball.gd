extends Node2D

## Фаербол мага: извилистая траектория. Уровень → цвет / размер / амплитуда волны.

const Z_PROJECTILE := 25

@export var max_speed: float = 520.0
@export var min_flight_time: float = 0.35
@export var max_flight_time: float = 1.4
@export var lead_factor: float = 0.25
@export var hit_radius: float = 40.0
@export var wave_count: float = 2.0

var damage: float = 10.0
var accuracy: float = 1.0
var level: int = 1
var _target: Enemy = null
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _duration: float = 0.5
var _elapsed: float = 0.0
var _prev: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.UP
var _amp: float = 40.0
var _alive: bool = true

@onready var sprite: Sprite2D = $Sprite2D


func launch(from_global: Vector2, target: Enemy, dmg: float, acc: float = 1.0, lvl: int = 1) -> void:
	global_position = from_global
	_from = from_global
	_prev = from_global
	_move_direction = Vector2.UP
	damage = dmg
	accuracy = maxf(acc, 0.05)
	level = lvl
	_target = target
	_alive = true
	_elapsed = 0.0
	z_index = Z_PROJECTILE
	_apply_level_look()

	_to = _aim(from_global, target, 0.6)
	var dist := _from.distance_to(_to)
	_duration = clampf(dist / maxf(max_speed, 1.0), min_flight_time, max_flight_time)
	_to = _aim(from_global, target, _duration)
	dist = _from.distance_to(_to)
	_duration = clampf(dist / maxf(max_speed, 1.0), min_flight_time, max_flight_time)


func _apply_level_look() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
	if sprite == null:
		return
	match level:
		1:
			sprite.modulate = Color(0.45, 0.7, 1.0)
			sprite.scale = Vector2(0.85, 0.85)
			_amp = 36.0
			wave_count = 2.0
		2:
			sprite.modulate = Color(0.7, 0.45, 1.0)
			sprite.scale = Vector2(1.1, 1.1)
			_amp = 52.0
			wave_count = 2.5
		_:
			sprite.modulate = Color(1.0, 0.4, 0.85)
			sprite.scale = Vector2(1.35, 1.35)
			_amp = 70.0
			wave_count = 3.0


func _aim(from: Vector2, target: Enemy, flight_t: float) -> Vector2:
	if not is_instance_valid(target):
		return from + Vector2(0, -400)
	var p := target.global_position
	p.y += target.move_speed * flight_t * lead_factor
	var miss := 40.0 / (accuracy * accuracy)
	p.x += randf_range(-miss, miss)
	if p.y > from.y - 16.0:
		p.y = from.y - 48.0
	return p


func _point(u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	var p := _from.lerp(_to, u)
	var delta := _to - _from
	var perp := Vector2(-delta.y, delta.x)
	if perp.length_squared() > 0.001:
		perp = perp.normalized()
	# Извилистая дуга, затухает к концам
	var envelope := sin(PI * u)
	p += perp * sin(u * TAU * wave_count) * _amp * envelope
	return p


func _process(delta: float) -> void:
	if not _alive:
		return
	_elapsed += delta
	var u := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var pos := _point(u)
	var d := pos - _prev
	_prev = pos
	global_position = pos
	if d.length_squared() > 0.2:
		rotation = d.angle() + PI * 0.5
		_move_direction = d.normalized()
	if _try_hit() or u >= 1.0:
		_alive = false
		queue_free()


func _try_hit() -> bool:
	if is_instance_valid(_target) and _target._alive:
		if global_position.distance_to(_target.global_position) <= hit_radius:
			_target.take_damage(damage, _move_direction)
			return true
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e._alive and global_position.distance_to(e.global_position) <= hit_radius:
			e.take_damage(damage, _move_direction)
			return true
	return false
