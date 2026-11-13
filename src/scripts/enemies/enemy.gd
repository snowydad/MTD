class_name Enemy
extends Node2D

## Базовый враг. Движется вниз к стене, лёгкий зигзаг.

@export_group("Stats")
@export var max_hp: float = 30.0
## Броня (physical). Позже режет физ. урон.
@export var max_ap: float = 0.0
## Маг. защита. Позже режет маг. урон.
@export var max_mp: float = 0.0
@export var move_speed: float = 180.0
@export var damage_to_wall: float = 5.0
@export var gold_reward: int = 10
## Дистанция до стены (px), на которой останавливается / бьёт. 0 = вплотную к wall_y.
@export var wall_attack: float = 0.0
## Период атаки стены (сек).
@export var attack_speed: float = 1.0
## Момент удара внутри цикла (сек от старта атаки) — под синхрон с анимацией.
@export var attack_moment: float = 0.25
## Полёт кинжала до стены (сек). 0 = урон сразу без полёта (мили).
@export var dagger_flight_time: float = 0.35

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
@export var spine_die_animation: String = "die"
@export var spine_attack_animation: String = "attack"
@export var spine_move_threshold: float = 5.0
## Если длительность die из Spine недоступна.
@export var die_fallback_duration: float = 0.8
## После die — гасим альфу (как стрелы в земле).
@export var die_fade_duration: float = 0.5

var hp: float = 30.0
var ap: float = 0.0
var mp: float = 0.0
var _wall_y: float = 2070.0
var _stop_y: float = 2070.0
var _base_x: float = 0.0
var _base_y: float = 0.0
var _hit_offset: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null
var _time: float = 0.0
var _alive: bool = true
var _dying: bool = false
var _freeze_left: float = 0.0
var _slow_left: float = 0.0
var _pre_freeze_modulate: Color = Color.WHITE
var _attacking: bool = false
var _attack_timer: float = 0.0
var _attack_damage_done: bool = false
var _dagger_templates: Array[Sprite2D] = []
var _dagger_throw_index: int = 0

var _current_speed: float = 0.0
var _speed_tween: Tween = null

var _spine_state = null
var _current_spine_animation: String = ""

signal reached_wall(enemy: Enemy)
## Урон по стене в момент удара (attack_moment).
signal wall_hit(enemy: Enemy, damage: float)
signal died(enemy: Enemy)


## Скорость для lead прицела снарядов (0 если стоит / бьёт стену).
func get_lead_speed() -> float:
	if not _alive or _dying or _attacking:
		return 0.0
	return _current_speed

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var spine = get_node_or_null("SpineSprite")


func _ready() -> void:
	add_to_group("enemies")
	_cache_dagger_templates()

	if spine != null:
		_spine_state = spine.get_animation_state()

		# Скрываем старый Sprite2D, если используется Spine.
		if sprite != null:
			sprite.hide()

		_play_spine_animation(spine_idle_animation)
		_update_spine_animation()


func setup(spawn_pos: Vector2, wall_y: float) -> void:
	global_position = spawn_pos
	_base_x = spawn_pos.x
	_base_y = spawn_pos.y
	_hit_offset = Vector2.ZERO

	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = null

	_wall_y = wall_y
	# Останавливается за wall_attack пикселей до верха стены
	_stop_y = wall_y - wall_attack
	hp = max_hp
	ap = max_ap
	mp = max_mp
	_alive = true
	_dying = false
	_attacking = false
	_attack_timer = 0.0
	_attack_damage_done = false
	_freeze_left = 0.0
	_slow_left = 0.0
	_time = randf() * TAU

	_current_speed = move_speed
	modulate = Color(1, 1, 1, 1)

	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_speed_tween = null

	if not is_in_group("enemies"):
		add_to_group("enemies")

	_cache_dagger_templates()
	_update_spine_animation()


func _process(delta: float) -> void:
	if _dying:
		return
	if not _alive:
		return

	if _attacking:
		_process_wall_attack(delta)
		return

	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			if _slow_left > 0.0:
				_current_speed = move_speed * 0.5
				modulate = Color(1.0, 0.75, 0.4, modulate.a)
			else:
				_current_speed = move_speed
				modulate = Color(1, 1, 1, modulate.a)
			_update_spine_animation()
		# Полный стоп: не двигаем Y и не крутим зигзаг по X
		global_position = Vector2(
			_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
			_base_y
		) + _hit_offset
		return

	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_left = 0.0
			_current_speed = move_speed
			modulate = Color(1, 1, 1, modulate.a)
			_update_spine_animation()

	_time += delta
	_base_y += _current_speed * delta

	global_position = Vector2(
		_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
		_base_y
	) + _hit_offset

	_update_spine_animation()

	if not _attacking and _base_y >= _stop_y:
		_begin_wall_attack()


## Отскок от направления удара. Если бил стену — срыв атаки и снова подход к wall_attack.
func hit(direction: Vector2, amount: float) -> void:
	if not _alive or _dying or amount <= 0.0:
		return

	if direction.length_squared() < 0.0001:
		return

	var impulse := direction.normalized() * amount * hit_distance_per_damage

	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = null

	# Срыв атаки стены: импульс в базовую позицию, снова идём к _stop_y
	if _attacking:
		_attacking = false
		_attack_timer = 0.0
		_attack_damage_done = false
		_base_x += impulse.x
		_base_y += impulse.y
		# Чуть выше линии атаки, чтобы точно перейти в walk и дойти снова
		_base_y = minf(_base_y, _stop_y - 1.0)
		_hit_offset = Vector2.ZERO
		global_position = Vector2(
			_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
			_base_y
		)
	else:
		var hit_position := _hit_offset + impulse
		_hit_tween = create_tween()
		_hit_tween.tween_property(
			self,
			"_hit_offset",
			hit_position,
			hit_out_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()

	_current_speed = 0.0
	_update_spine_animation()

	if _freeze_left > 0.0:
		return

	var resume := move_speed * 0.5 if _slow_left > 0.0 else move_speed
	_speed_tween = create_tween()
	_speed_tween.tween_property(
		self,
		"_current_speed",
		resume,
		hit_speed_recovery_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Заморозка (маг): на duration сек скорость 0.
func apply_freeze(duration: float) -> void:
	if not _alive or _dying or duration <= 0.0:
		return
	_freeze_left = maxf(_freeze_left, duration)
	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_speed_tween = null
	_current_speed = 0.0
	modulate = Color(0.55, 0.85, 1.0, modulate.a)
	_update_spine_animation()


## Slowdown (мортира): speed/2 на duration сек.
func apply_slow(duration: float) -> void:
	if not _alive or _dying or duration <= 0.0:
		return
	_slow_left = maxf(_slow_left, duration)
	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_speed_tween = null
	# Freeze сильнее slow
	if _freeze_left > 0.0:
		return
	_current_speed = move_speed * 0.5
	modulate = Color(1.0, 0.75, 0.4, modulate.a)
	_update_spine_animation()




func _cache_dagger_templates() -> void:
	_dagger_templates.clear()
	for c in get_children():
		if c is Sprite2D and "dagger" in str(c.name).to_lower():
			var s := c as Sprite2D
			_dagger_templates.append(s)
			s.visible = false


func _do_wall_attack_strike() -> void:
	## Есть кинжалы в сцене → бросок; нет → мили (урон сразу).
	if _dagger_templates.is_empty():
		wall_hit.emit(self, damage_to_wall)
		return
	_throw_dagger()


func _throw_dagger() -> void:
	if _dagger_templates.is_empty():
		wall_hit.emit(self, damage_to_wall)
		return
	var tmpl: Sprite2D = _dagger_templates[_dagger_throw_index % _dagger_templates.size()]
	_dagger_throw_index += 1

	var world: Node = get_parent()
	if world == null:
		world = self

	var dagger: Sprite2D = tmpl.duplicate() as Sprite2D
	world.add_child(dagger)
	dagger.global_position = tmpl.global_position
	dagger.global_scale = tmpl.global_scale
	dagger.modulate = tmpl.modulate
	dagger.visible = true
	dagger.z_index = 20

	var target := Vector2(dagger.global_position.x, _wall_y)
	var dir := target - dagger.global_position
	if dir.length_squared() > 0.01:
		dagger.rotation = dir.angle() + PI * 0.5

	var flight := maxf(dagger_flight_time, 0.05)
	var tw := dagger.create_tween()
	tw.set_parallel(false)
	tw.tween_property(dagger, "global_position", target, flight).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and _alive and not _dying:
			wall_hit.emit(self, damage_to_wall)
		if is_instance_valid(dagger):
			dagger.queue_free()
	)


func _begin_wall_attack() -> void:
	_attacking = true
	_current_speed = 0.0
	_base_y = _stop_y
	_attack_timer = 0.0
	_attack_damage_done = false
	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_speed_tween = null
	# Зафиксировать позицию на линии атаки
	global_position = Vector2(
		_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
		_base_y
	) + _hit_offset
	reached_wall.emit(self)  # «дошёл» — без смерти; урон идёт через wall_hit
	_play_spine_animation_once(spine_attack_animation)
	_update_spine_animation()


func _process_wall_attack(delta: float) -> void:
	# Freeze ставит атаку на паузу
	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			modulate = Color(1, 1, 1, modulate.a)
		global_position = Vector2(
			_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
			_base_y
		) + _hit_offset
		return

	_attack_timer += delta
	var moment := clampf(attack_moment, 0.0, maxf(attack_speed, 0.01))
	if not _attack_damage_done and _attack_timer >= moment:
		_attack_damage_done = true
		_do_wall_attack_strike()

	if _attack_timer >= maxf(attack_speed, 0.05):
		_attack_timer = 0.0
		_attack_damage_done = false
		_play_spine_animation_once(spine_attack_animation)

	global_position = Vector2(
		_base_x + sin(_time * zigzag_frequency * TAU) * zigzag_amplitude,
		_base_y
	) + _hit_offset


## Урон по пулам: amp→AP, mhp→MP, dhp→HP.
## HP получает урон только если AP<=0 и MP<=0 (сначала все защиты).
func take_damage(dhp: float = 0.0, mhp: float = 0.0, amp: float = 0.0, impact_direction: Vector2 = Vector2.ZERO) -> void:
	if not _alive or _dying:
		return

	var total := maxf(dhp, 0.0) + maxf(mhp, 0.0) + maxf(amp, 0.0)
	if total > 0.0:
		var dir := impact_direction
		if dir.length_squared() < 0.0001:
			dir = Vector2(0, -1)  # fallback: от стены вверх
		hit(dir, total)

	# 1) броня
	if amp > 0.0 and ap > 0.0:
		var used_ap := minf(ap, amp)
		ap -= used_ap
	# 2) маг. защита
	if mhp > 0.0 and mp > 0.0:
		var used_mp := minf(mp, mhp)
		mp -= used_mp
	# 3) HP — только когда обе защиты сняты
	if dhp > 0.0 and ap <= 0.0 and mp <= 0.0:
		hp -= dhp

	if hp <= 0.0:
		_start_die()


func _start_die() -> void:
	_alive = false
	_dying = true

	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	if _speed_tween and _speed_tween.is_running():
		_speed_tween.kill()
	_current_speed = 0.0

	if is_in_group("enemies"):
		remove_from_group("enemies")

	_play_spine_animation_once(spine_die_animation)
	died.emit(self)

	var wait := _die_anim_duration()
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(self):
		return
	# Пропадание по альфе после анимации смерти
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, die_fade_duration)
	await fade.finished
	if is_instance_valid(self):
		queue_free()


func _die_anim_duration() -> float:
	if spine != null and spine.has_method("get_skeleton"):
		var sk = spine.get_skeleton()
		if sk != null and sk.has_method("get_data"):
			var data = sk.get_data()
			if data != null and data.has_method("find_animation"):
				var anim = data.find_animation(spine_die_animation)
				if anim != null:
					if "duration" in anim:
						return maxf(float(anim.duration), 0.05)
					if anim.has_method("get_duration"):
						return maxf(float(anim.get_duration()), 0.05)
	return die_fallback_duration


## Запускает Spine-анимацию, если она отличается от текущей (loop).
func _play_spine_animation(animation_name: String) -> void:
	if _spine_state == null:
		return

	if _current_spine_animation == animation_name:
		return

	_spine_state.set_animation(animation_name, true, 0)
	_current_spine_animation = animation_name


## One-shot (die) — всегда с loop=false.
func _play_spine_animation_once(animation_name: String) -> void:
	if _spine_state == null:
		return
	_spine_state.set_animation(animation_name, false, 0)
	_current_spine_animation = animation_name


## Выбирает анимацию в зависимости от текущей скорости.
func _update_spine_animation() -> void:
	if _spine_state == null or _dying or _attacking:
		return

	if _current_speed > spine_move_threshold:
		_play_spine_animation(spine_walk_animation)
	else:
		_play_spine_animation(spine_idle_animation)
