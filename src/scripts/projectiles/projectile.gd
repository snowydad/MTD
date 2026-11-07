extends Node2D

const Z_DECOR := 10
const Z_PROJECTILE := 25

## Стрела: полёт по дуге. Попадание → удаление.
## Промах → торчит в земле, потом исчезает.

@export_group("Flight")
@export var max_speed: float = 650.0
@export var min_flight_time: float = 0.3
@export var max_flight_time: float = 1.2
@export var arc_height: float = 80.0
@export var arc_dist_factor: float = 0.12
@export var lead_factor: float = 0.2
## Разброс прицела при accuracy=1 (px). Реальный = max_miss / accuracy.
@export var max_miss_px: float = 36.0

@export_group("Visual")
@export var peak_scale: float = 1.5

@export_group("Hit")
@export var hit_radius: float = 42.0

@export_group("Stuck")
## Сколько секунд торчит в земле после промаха.
@export var stuck_lifetime: float = 4.0
## Случайный доп. наклон при посадке (радианы).
@export var stuck_tilt_max: float = 0.35
## Провал в «землю» по Y (px вниз).
@export var stuck_embed_y: float = 12.0

var damage: float = 10.0
var accuracy: float = 1.0
var _flying: bool = true
var _stuck: bool = false
var _target: Enemy = null
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _duration: float = 0.5
var _elapsed: float = 0.0
var _stuck_timer: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.UP
var _base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D


func launch(from_global: Vector2, target: Enemy, dmg: float, acc: float = 1.0, _flight_time: float = -1.0) -> void:
	global_position = from_global
	_from = from_global
	_prev_pos = from_global
	_move_direction = Vector2.UP
	damage = dmg
	accuracy = maxf(acc, 0.05)
	_target = target
	_flying = true
	_stuck = false
	_elapsed = 0.0
	_stuck_timer = 0.0
	z_index = Z_PROJECTILE
	if sprite:
		_base_scale = sprite.scale
		sprite.modulate = Color(1, 1, 1, 1)
	elif has_node("Sprite2D"):
		sprite = $Sprite2D
		_base_scale = sprite.scale
		sprite.modulate = Color(1, 1, 1, 1)

	_to = _compute_aim(from_global, target, 0.5)
	_finalize_timing()
	_to = _compute_aim(from_global, target, _duration)
	_finalize_timing()

	var dir := _to - _from
	if dir.length_squared() < 1.0:
		dir = Vector2(0, -1)
	_update_rotation(dir)


func _finalize_timing() -> void:
	var dist := _from.distance_to(_to)
	_duration = clampf(dist / maxf(max_speed, 1.0), min_flight_time, max_flight_time)
	_arc = minf(arc_height, dist * arc_dist_factor)


func _compute_aim(from: Vector2, target: Enemy, flight_t: float) -> Vector2:
	if not is_instance_valid(target):
		return from + Vector2(0, -400)

	var p := target.global_position
	p.y += target.move_speed * flight_t * lead_factor

	# Разброс меткости: чем выше accuracy, тем меньше miss
	var miss := max_miss_px / accuracy
	p.x += randf_range(-miss, miss)
	p.y += randf_range(-miss * 0.5, miss * 0.5)

	if p.y > from.y - 16.0:
		p = Vector2(target.global_position.x, from.y - 48.0)

	return p


func _point_on_path(u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	var p := _from.lerp(_to, u)
	p.y -= _arc * sin(PI * u)
	return p


func _process(delta: float) -> void:
	if _stuck:
		_process_stuck(delta)
		return
	if not _flying:
		return

	_elapsed += delta
	var u := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var pos := _point_on_path(u)
	var dpos := pos - _prev_pos
	_prev_pos = pos
	global_position = pos

	if dpos.length_squared() > 0.2:
		_update_rotation(dpos)
		_move_direction = dpos.normalized()

	if sprite:
		var k := sin(PI * u)
		sprite.scale = _base_scale * lerpf(1.0, peak_scale, k)

	if _try_hit():
		return

	if u >= 1.0:
		if not _try_hit():
			_stick_in_ground()


func _process_stuck(delta: float) -> void:
	_stuck_timer -= delta
	if sprite and _stuck_timer < 1.0:
		sprite.modulate.a = clampf(_stuck_timer, 0.0, 1.0)
	if _stuck_timer <= 0.0:
		queue_free()


func _stick_in_ground() -> void:
	_flying = false
	_stuck = true
	_stuck_timer = stuck_lifetime
	# Чуть втыкаем в землю
	global_position.y += stuck_embed_y
	# Лёгкий случайный наклон «воткнулась»
	rotation += randf_range(-stuck_tilt_max, stuck_tilt_max)
	if sprite:
		sprite.scale = _base_scale
		sprite.modulate.a = 1.0
	# Выше фона (Background z=0), ниже UI; -1 прятало стрелу под bg
	z_index = Z_DECOR


func _update_rotation(dir: Vector2) -> void:
	rotation = dir.angle() + PI * 0.5


func _try_hit() -> bool:
	if is_instance_valid(_target) and _target._alive:
		if global_position.distance_to(_target.global_position) <= hit_radius:
			_target.take_damage(damage, _move_direction)
			_remove()
			return true

	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e._alive:
			continue
		if global_position.distance_to(e.global_position) <= hit_radius:
			e.take_damage(damage, _move_direction)
			_remove()
			return true
	return false


func _remove() -> void:
	_flying = false
	_stuck = false
	queue_free()
