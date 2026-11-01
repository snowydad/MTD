class_name Projectile
extends Node2D

## Стрела / снаряд. Летит по баллистике, спрайт остриём по направлению скорости.
## Спрайт должен смотреть ВВЕРХ ( -Y ).

@export var gravity: float = 1800.0
@export var hit_radius: float = 28.0

var damage: float = 10.0
var _velocity: Vector2 = Vector2.ZERO
var _alive: bool = true
var _target: Enemy = null
var _lifetime: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D


func launch(from_global: Vector2, target: Enemy, dmg: float, flight_time: float = 0.45) -> void:
	global_position = from_global
	damage = dmg
	_target = target
	_alive = true
	_lifetime = maxf(flight_time + 0.8, 1.2)

	# Цель — текущая позиция врага (с небольшим упреждением по Y, он идёт вниз)
	var to := target.global_position
	if is_instance_valid(target):
		to.y += target.move_speed * flight_time * 0.35

	var T := flight_time
	var dx := to.x - from_global.x
	var dy := to.y - from_global.y
	# y = y0 + vy*t + 0.5*g*t²  (Y вниз)
	_velocity = Vector2(
		dx / T,
		(dy / T) - 0.5 * gravity * T
	)
	_update_rotation()


func _process(delta: float) -> void:
	if not _alive:
		return

	_lifetime -= delta
	if _lifetime <= 0.0:
		_die()
		return

	_velocity.y += gravity * delta
	global_position += _velocity * delta
	_update_rotation()

	_try_hit()


func _update_rotation() -> void:
	# Спрайт остриём вверх (-Y). angle() даёт угол от +X.
	# Нужен угол, чтобы -Y спрайта смотрел вдоль velocity.
	if _velocity.length_squared() < 1.0:
		return
	rotation = _velocity.angle() + PI * 0.5


func _try_hit() -> void:
	# Приоритет — назначенная цель
	if is_instance_valid(_target) and _target._alive:
		if global_position.distance_to(_target.global_position) <= hit_radius:
			_target.take_damage(damage)
			_die()
			return

	# Иначе любой враг в радиусе
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
