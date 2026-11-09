class_name Unit
extends Node2D

const Z_UNITS := 40
const Z_UNIT_JUMP := 45

## Базовый юнит на стене.
## Статы из UnitStats. После приземления ищет врагов и стреляет.
## Мерж: 3 одинаковых → 1 следующего уровня.

enum UnitType { ARCHER, MAGE, CANNON }

signal landed(unit: Unit)

@export var unit_type: UnitType = UnitType.ARCHER
@export var level: int = 1

var dhp: float = 0.0  # урон по HP
var mhp: float = 0.0  # урон по MP (маг. защита)
var amp: float = 0.0  # урон по AP (броня)
var attack_speed: float = 1.0
var attack_range: float = 300.0
var splash_radius: float = 0.0
var accuracy: float = 1.0

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

## Занят мержем (не брать в новую тройку). Во время паузы ещё стреляет.
var merge_locked: bool = false
## Сейчас съезжается — не атакует.
var is_merging: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func setup(type: UnitType, lvl: int = 1) -> void:
	unit_type = type
	level = lvl
	_apply_stats()
	_apply_visual_level()
	_landed = false
	_attack_cd = 0.15


func _type_key() -> String:
	match unit_type:
		UnitType.ARCHER:
			return "archer"
		UnitType.MAGE:
			return "mage"
		UnitType.CANNON:
			return "cannon"
	return "archer"


func _apply_stats() -> void:
	## Статы из assets/data/units.json по type+level, затем глобальные перки.
	var base: Dictionary = GameData.unit_stats(_type_key(), level)
	if base.is_empty():
		push_warning("GameData: нет статов %s lv%d" % [_type_key(), level])
		return

	dhp = float(base.get("dhp", base.get("damage", 0.0)))
	mhp = float(base.get("mhp", 0.0))
	amp = float(base.get("amp", 0.0))
	attack_speed = float(base.get("attack_speed", 1.0))
	attack_range = float(base.get("range", 300.0))
	splash_radius = float(base.get("splash_radius", 0.0))
	accuracy = 1.0

	var tree := get_tree()
	if tree == null:
		return
	var main := tree.get_first_node_in_group("game_main") as Node
	if main != null and main.has_method("get_perk_multipliers"):
		var m: Dictionary = main.get_perk_multipliers()
		var dmul := float(m.get("damage", 1.0))
		dhp *= dmul
		mhp *= dmul
		amp *= dmul
		attack_range *= float(m.get("range", 1.0))
		attack_speed *= float(m.get("speed", 1.0))
		accuracy = float(m.get("accuracy", 1.0))


func _apply_visual_level() -> void:
	if sprite == null:
		return
	# Пока нет отдельных спрайтов — масштаб + лёгкий tint
	var s := 1.0 + (level - 1) * 0.28
	sprite.scale = Vector2(s, s)
	match level:
		1:
			sprite.modulate = Color.WHITE
		2:
			sprite.modulate = Color(1.15, 1.05, 0.75)  # тёплый «прокачанный»
		_:
			sprite.modulate = Color(1.25, 0.95, 0.55)


func upgrade_to_level(new_level: int) -> void:
	level = new_level
	_apply_stats()
	_apply_visual_level()
	print("Unit upgraded → Lv.%d  dhp=%.1f mhp=%.1f amp=%.1f range=%.0f" % [level, dhp, mhp, amp, attack_range])


func play_spawn_jump(from_global: Vector2, to_global: Vector2) -> void:
	global_position = from_global
	target_global = to_global
	z_index = Z_UNIT_JUMP
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
			z_index = Z_UNITS
			_landed = true
			landed.emit(self)
		return

	if not _landed:
		return
	if is_merging:
		return

	_attack_cd -= delta
	if _attack_cd <= 0.0:
		var target := _find_target()
		if target != null:
			_fire_at(target)
			_attack_cd = 1.0 / maxf(attack_speed, 0.05)


func move_to_slot(to_global: Vector2) -> void:
	if _flying or is_merging:
		return
	target_global = to_global
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", to_global, shift_duration)


func is_ready_on_wall() -> bool:
	return _landed and not _flying and not merge_locked and not is_merging


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
	var proj = projectile_scene.instantiate()
	var parent := get_parent()
	while parent and parent.name != "World":
		parent = parent.get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(proj)
	var from := global_position + muzzle_offset
	# Снаряды принимают разный launch: стрела / фаербол / бомба
	match unit_type:
		UnitType.ARCHER:
			proj.launch(from, target, dhp, mhp, amp, accuracy, arrow_flight_time)
		UnitType.MAGE:
			proj.launch(from, target, dhp, mhp, amp, accuracy, level)
		UnitType.CANNON:
			proj.launch(from, target, dhp, mhp, amp, accuracy, level, splash_radius)
		_:
			proj.launch(from, target, dhp, mhp, amp, accuracy)
