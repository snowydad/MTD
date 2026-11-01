extends Node2D

## Main — юниты, формация, общий заряд кнопок, HP башни.

@onready var wave_label: Label = $UI/HUD/TopBar/WaveLabel
@onready var btn_archer: Button = $UI/HUD/BottomBar/BtnArcher
@onready var btn_mage: Button = $UI/HUD/BottomBar/BtnMage
@onready var btn_cannon: Button = $UI/HUD/BottomBar/BtnCannon
@onready var tower_hp_bar: ProgressBar = $UI/HUD/TowerHP
@onready var units_root: Node2D = $World/Units
@onready var wall: Sprite2D = $World/Wall
@onready var goblin_spawner: EnemySpawner = $World/Enemies/GoblinSpawner

const ARCHER_SCENE := preload("res://src/scenes/units/archer.tscn")

var units: Array[Unit] = []

@export_group("Formation")
@export var wall_y: float = 2070.0
@export var slot_spacing: float = 120.0
@export var max_units: int = 9

@export_group("Charge")
## Скорость наполнения (единиц в секунду). Потом перки будут множить.
@export var fill_rate: float = 10.0
@export var cost_archer: int = 12
@export var cost_mage: int = 16
@export var cost_cannon: int = 20

@export_group("Tower")
@export var tower_max_hp: float = 100.0

## Общий заряд — растёт для всех кнопок сразу. После спавна сбрасывается в 0.
var charge: float = 0.0
var tower_hp: float = 100.0
var _game_over: bool = false


func _ready() -> void:
	print("MTD Prototype started")
	print("Viewport size: ", get_viewport().get_visible_rect().size)

	tower_hp = tower_max_hp
	_setup_hp_bar()
	_update_hp_bar()

	btn_archer.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.ARCHER))
	btn_mage.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.MAGE))
	btn_cannon.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.CANNON))

	# Урон по стене, когда враг доходит
	if goblin_spawner:
		goblin_spawner.enemy_reached_wall.connect(_on_enemy_reached_wall)

	_update_buttons()


func _process(delta: float) -> void:
	if _game_over:
		return

	var max_cost: float = maxf(cost_archer, maxf(cost_mage, cost_cannon))
	if charge < max_cost:
		charge = minf(charge + fill_rate * delta, max_cost)
	_update_buttons()


func _setup_hp_bar() -> void:
	tower_hp_bar.min_value = 0.0
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = tower_hp
	tower_hp_bar.show_percentage = true


func _update_hp_bar() -> void:
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = clampf(tower_hp, 0.0, tower_max_hp)

	# Цвет: зелёный → жёлтый → красный
	var ratio := tower_hp / tower_max_hp if tower_max_hp > 0.0 else 0.0
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.85, 0.3) if ratio > 0.5 \
		else (Color(0.95, 0.75, 0.15) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
	fill_style.set_corner_radius_all(6)
	tower_hp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	bg_style.set_corner_radius_all(6)
	tower_hp_bar.add_theme_stylebox_override("background", bg_style)


func _on_enemy_reached_wall(enemy: Node2D) -> void:
	if _game_over:
		return
	var e := enemy as Enemy
	if e == null:
		return

	var dmg: float = e.damage_to_wall
	tower_hp = maxf(tower_hp - dmg, 0.0)
	_update_hp_bar()
	print("Стена получила ", dmg, " урона. HP: ", tower_hp, "/", tower_max_hp)

	if tower_hp <= 0.0:
		_on_tower_destroyed()


func _on_tower_destroyed() -> void:
	_game_over = true
	print("=== GAME OVER: стена разрушена ===")
	# Останавливаем спавн
	if goblin_spawner:
		goblin_spawner.stop()
	# Блокируем кнопки
	btn_archer.disabled = true
	btn_mage.disabled = true
	btn_cannon.disabled = true
	wave_label.text = "GAME OVER"


func _update_buttons() -> void:
	if _game_over:
		return
	_refresh_button(btn_archer, "Лучник", cost_archer)
	_refresh_button(btn_mage, "Маг", cost_mage)
	_refresh_button(btn_cannon, "Пушка", cost_cannon)


func _refresh_button(btn: Button, title: String, cost: int) -> void:
	var filled := int(charge)
	if filled >= cost:
		btn.text = "%s\n%d" % [title, cost]
		btn.disabled = false
	else:
		btn.text = "%s\n%d/%d" % [title, filled, cost]
		btn.disabled = true


func _on_spawn_pressed(unit_type: Unit.UnitType) -> void:
	if _game_over:
		return
	var cost := _cost_for(unit_type)
	if charge < cost:
		return
	if units.size() >= max_units:
		print("Стена заполнена")
		return
	if unit_type != Unit.UnitType.ARCHER:
		print("Пока только лучник")
		return

	# Спавн + сброс общего заряда (как в GDD: нажал — все полоски с нуля)
	charge = 0.0
	_update_buttons()
	_spawn_unit(unit_type)


func _cost_for(unit_type: Unit.UnitType) -> int:
	match unit_type:
		Unit.UnitType.ARCHER:
			return cost_archer
		Unit.UnitType.MAGE:
			return cost_mage
		Unit.UnitType.CANNON:
			return cost_cannon
	return 999


func _spawn_unit(unit_type: Unit.UnitType) -> void:
	var unit: Unit = ARCHER_SCENE.instantiate()
	unit.setup(unit_type, 1)
	units_root.add_child(unit)
	units.append(unit)

	var slots := _compute_slots(units.size())
	var btn := _button_for_type(unit_type)
	var from_global: Vector2 = btn.get_global_rect().get_center()
	var new_idx := units.size() - 1

	for i in range(units.size() - 1):
		units[i].slot_index = i
		units[i].move_to_slot(slots[i])

	unit.slot_index = new_idx
	unit.play_spawn_jump(from_global, slots[new_idx])
	print("Spawned archer #", units.size())


func _compute_slots(count: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	if count <= 0:
		return slots
	var total_width := (count - 1) * slot_spacing
	var center_x := wall.position.x
	var start_x := center_x - total_width * 0.5
	for i in range(count):
		slots.append(Vector2(start_x + i * slot_spacing, wall_y))
	return slots


func _button_for_type(unit_type: Unit.UnitType) -> Button:
	match unit_type:
		Unit.UnitType.ARCHER:
			return btn_archer
		Unit.UnitType.MAGE:
			return btn_mage
		Unit.UnitType.CANNON:
			return btn_cannon
	return btn_archer
