extends Node2D

## Стрела: от лучника (низ экрана) к врагу (выше по полю).
## Траектория — почти прямая с лёгкой дугой «вверх», как на схеме.
## В середине пути scale 150%, к концу снова 100%.

@export_group("Flight")
@export var max_speed: float = 650.0
@export var min_flight_time: float = 0.3
@export var max_flight_time: float = 1.2
## Доп. подъём дуги в пикселях (вверх экрана). Масштабируется дистанцией.
@export var arc_height: float = 80.0
@export var arc_dist_factor: float = 0.12
@export var lead_factor: float = 0.2

@export_group("Visual")
## Множитель масштаба в пике дуги (1.5 = +50%).
@export var peak_scale: float = 1.5

@export_group("Hit")
@export var hit_radius: float = 42.0

var damage: float = 10.0
var _alive: bool = true
var _target: Enemy = null
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _arc: float = 0.0
var _duration: float = 0.5
var _elapsed: float = 0.0
var _prev_pos: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D


func launch(from_global: Vector2, target: Enemy, dmg: float, _flight_time: float = -1.0) -> void:
	global_position = from_global
	_from = from_global
	_prev_pos = from_global
	damage = dmg
	_target = target
	_alive = true
	_elapsed = 0.0
	if sprite:
		_base_scale = sprite.scale

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
	# Упреждение: враг ползёт вниз (+Y)
	p.y += target.move_speed * flight_t * lead_factor

	# Стреляем в сторону поля (вверх экрана). Не целимся ниже лучника.
	if p.y > from.y - 16.0:
		p = Vector2(target.global_position.x, from.y - 48.0)

	return p


func _point_on_path(u: float) -> Vector2:
	u = clampf(u, 0.0, 1.0)
	# Прямая к цели
	var p := _from.lerp(_to, u)
	# Лёгкая дуга вверх по экрану (−Y), пик в середине — как на рисунке
	p.y -= _arc * sin(PI * u)
	return p


func _process(delta: float) -> void:
	if not _alive:
		return

	_elapsed += delta
	var u := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
	var pos := _point_on_path(u)
	var dpos := pos - _prev_pos
	_prev_pos = pos
	global_position = pos

	if dpos.length_squared() > 0.2:
		_update_rotation(dpos)

	# Пик масштаба в середине пути: 1.0 → peak_scale → 1.0
	if sprite:
		var k := sin(PI * u)  # 0..1..0
		var s := lerpf(1.0, peak_scale, k)
		sprite.scale = _base_scale * s

	_try_hit()

	if u >= 1.0:
		_try_hit()
		_die()


func _update_rotation(dir: Vector2) -> void:
	# Спрайт остриём вверх (−Y)
	rotation = dir.angle() + PI * 0.5


func _try_hit() -> void:
	if is_instance_valid(_target) and _target._alive:
		if global_position.distance_to(_target.global_position) <= hit_radius:
			_target.take_damage(damage)
			_die()
			return

	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e._alive:
			continue
		if global_position.distance_to(e.global_position) <= hit_radius:
			e.take_damage(damage)
			_die()
			return


func _die() -> void:
	_alive = false
	queue_free()
