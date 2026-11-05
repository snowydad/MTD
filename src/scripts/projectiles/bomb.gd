extends Node2D

## Бомба мортиры: навес + урон по площади. Размер от уровня.

const Z_PROJECTILE := 25
const Z_DECOR := 10

@export var max_speed: float = 480.0
@export var min_flight_time: float = 0.4
@export var max_flight_time: float = 1.5
@export var arc_height: float = 140.0
@export var arc_dist_factor: float = 0.18
@export var lead_factor: float = 0.3
@export var hit_radius: float = 36.0
@export var stuck_lifetime: float = 2.5

var damage: float = 25.0
var splash_radius: float = 90.0
var accuracy: float = 1.0
var level: int = 1
var _target: Enemy = null
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _duration: float = 0.6
var _elapsed: float = 0.0
var _prev: Vector2 = Vector2.ZERO
var _flying: bool = true
var _stuck: bool = false
var _stuck_t: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func launch(from_global: Vector2, target: Enemy, dmg: float, acc: float = 1.0, lvl: int = 1, splash: float = 90.0) -> void:
	global_position = from_global
	_from = from_global
	_prev = from_global
	damage = dmg
	accuracy = maxf(acc, 0.05)
	level = lvl
	splash_radius = splash
	_target = target
	_flying = true
	_stuck = false
	_elapsed = 0.0
	z_index = Z_PROJECTILE
	_apply_level_look()

	_to = _aim(from_global, target, 0.7)
	_finalize()
	_to = _aim(from_global, target, _duration)
	_finalize()


func _apply_level_look() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
	if sprite == null:
		return
	var s := 0.85 + (level - 1) * 0.3
	sprite.scale = Vector2(s, s)
	match level:
		1:
			sprite.modulate = Color(1.0, 0.85, 0.5)
		2:
			sprite.modulate = Color(1.0, 0.55, 0.25)
		_:
			sprite.modulate = Color(1.0, 0.3, 0.15)


func _finalize() -> void:
	var dist := _from.distance_to(_to)
	_duration = clampf(dist / maxf(max_speed, 1.0), min_flight_time, max_flight_time)
	_arc = minf(arc_height, dist * arc_dist_factor)


func _aim(from: Vector2, target: Enemy, flight_t: float) -> Vector2:
	if not is_instance_valid(target):
		return from + Vector2(0, -350)
	var p := target.global_position
	p.y += target.move_speed * flight_t * lead_factor
	var miss := 50.0 / (accuracy * accuracy)
	p.x += randf_range(-miss, miss)
	if p.y > from.y - 16.0:
		p.y = from.y - 48.0
	return p


func _point(u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	var p := _from.lerp(_to, u)
	p.y -= _arc * sin(PI * u)
	return p


func _process(delta: float) -> void:
	if _stuck:
		_stuck_t -= delta
		if sprite and _stuck_t < 0.8:
			sprite.modulate.a = clampf(_stuck_t / 0.8, 0.0, 1.0)
		if _stuck_t <= 0.0:
			queue_free()
		return
	if not _flying:
		return

	_elapsed += delta
	var u := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var pos := _point(u)
	var d := pos - _prev
	_prev = pos
	global_position = pos
	if d.length_squared() > 0.2:
		rotation = d.angle() + PI * 0.5

	if _try_hit():
		return
	if u >= 1.0:
		_explode(null)
		_stick()


func _try_hit() -> bool:
	if is_instance_valid(_target) and _target._alive:
		if global_position.distance_to(_target.global_position) <= hit_radius:
			_explode(_target)
			queue_free()
			return true
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e._alive and global_position.distance_to(e.global_position) <= hit_radius:
			_explode(e)
			queue_free()
			return true
	return false


func _explode(primary: Enemy) -> void:
	var origin := global_position
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e._alive:
			continue
		if origin.distance_to(e.global_position) <= splash_radius:
			e.take_damage(damage)


func _stick() -> void:
	_flying = false
	_stuck = true
	_stuck_t = stuck_lifetime
	z_index = Z_DECOR
	if sprite:
		sprite.scale *= 0.85
