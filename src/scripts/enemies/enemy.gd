
class_name Enemy
extends Node2D

## Базовый враг. Движется вниз к стене, лёгкий зигзаг.

@export_group("Stats")
@export var max_hp: float = 30.0
@export var move_speed: float = 180.0
@export var damage_to_wall: float = 5.0
@export var gold_reward: int = 10

@export_group("Zigzag")
@export var zigzag_amplitude: float = 40.0
@export var zigzag_frequency: float = 2.0

@export_group("Hit")
## Отбрасывание при попадании: пикселей на единицу урона.
@export var hit_distance_per_damage: float = 1.0
## Длительность визуального отскока.
@export var hit_out_duration: float = 0.07
@export var hit_return_duration: float = 0.16
## Время восстановления скорости после попадания.
@export var hit_speed_recovery_duration: float = 1.3

@export_group("Spine")
@export var spine_idle_animation: String = "idle"
@export var spine_walk_animation: String = "walk"
@export var spine_move_threshold: float = 5.0

var hp: float = 30.0
var _target_y: float = 2070.0
var _base_x: float = 0.0
var _base_y: float = 0.0
var _hit_offset: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null
var _time: float = 0.0
var _alive: bool = true

var _current_speed: float = 0.0
var _speed_tween: Tween = null

var _spine_state = null
var _current_spine_animation: String = ""

signal reached_wall(enemy: Enemy)
signal died(enemy: Enemy)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var spine = get_node_or_null("SpineSprite")


func _ready() -> void:
	add_to_group("enemies")

	if spine != null:
		_spine_state = spine.get_animation_state()

		# Скрываем старый Sprite2D, если используется Spine.
		if sprite != null:
			sprite.hide()

		_play_spine_animation(spine_idle_animation)
		_update_spine_animation()


func setup(spawn_pos: Vector2, target_y: float) -> void:
	global_position = spawn_pos
	_base_x = spawn_pos.x
	_base_y = spawn_pos.y
	_hit_offset = Vector2.ZERO

	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = null

	_target_y = target_y
	hp = max_hp
	_alive = true
	_time = randf() * TAU

	_current_speed = move_speed

	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_speed_tween = null

	if not is_in_group("enemies"):
		add_to_group("enemies")

	_update_spine_animation()


func _process(delta: float) -> void:
	if not _alive:
		return

	_time += delta
	_base_y += _current_speed * delta

	global_position = Vector2(
		_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
		_base_y
	) + _hit_offset

	_update_spine_animation()

	if _base_y >= _target_y:
		_alive = false
		reached_wall.emit(self)
		queue_free()


## Визуальный отскок от направления прилёта. Не изменяет HP.
func hit(direction: Vector2, amount: float) -> void:
	if not _alive or amount <= 0.0:
		return

	if direction.length_squared() < 0.0001:
		return

	var impulse := direction.normalized() * amount * hit_distance_per_damage

	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()

	var hit_position := _hit_offset + impulse

	_hit_tween = create_tween()
	_hit_tween.tween_property(
		self,
		"_hit_offset",
		hit_position,
		hit_out_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Останавливаем врага и плавно восстанавливаем скорость.
	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()

	_current_speed = 0.0
	_update_spine_animation()

	_speed_tween = create_tween()
	_speed_tween.tween_property(
		self,
		"_current_speed",
		move_speed,
		hit_speed_recovery_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func take_damage(amount: float, impact_direction: Vector2 = Vector2.ZERO) -> void:
	if not _alive:
		return

	# Hit вызывается из центрального обработчика урона.
	if impact_direction.length_squared() > 0.0001:
		hit(impact_direction, amount)

	hp -= amount

	if hp <= 0.0:
		_alive = false
		died.emit(self)
		queue_free()


## Запускает Spine-анимацию, если она отличается от текущей.
func _play_spine_animation(animation_name: String) -> void:
	if _spine_state == null:
		return

	if _current_spine_animation == animation_name:
		return

	_spine_state.set_animation(animation_name, true, 0)
	_current_spine_animation = animation_name


## Выбирает анимацию в зависимости от текущей скорости.
func _update_spine_animation() -> void:
	if _spine_state == null:
		return

	if _current_speed > spine_move_threshold:
		_play_spine_animation(spine_walk_animation)
	else:
		_play_spine_animation(spine_idle_animation)
