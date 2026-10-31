extends Node2D

## Main — спавн юнитов, динамическая формация на стене.

@onready var wave_label: Label = $UI/HUD/TopBar/WaveLabel
@onready var btn_archer: Button = $UI/HUD/BottomBar/BtnArcher
@onready var btn_mage: Button = $UI/HUD/BottomBar/BtnMage
@onready var btn_cannon: Button = $UI/HUD/BottomBar/BtnCannon
@onready var tower_hp: ProgressBar = $UI/HUD/TowerHP
@onready var units_root: Node2D = $World/Units
@onready var wall: Sprite2D = $World/Wall

const ARCHER_SCENE := preload("res://src/scenes/units/archer.tscn")

var units: Array[Unit] = []

## --- Формация (видно в инспекторе у Main) ---
@export_group("Formation")
@export var wall_y: float = 2070.0
@export var slot_spacing: float = 120.0
@export var max_units: int = 9

## --- Прыжок по умолчанию (прокидывается в юнита при спавне) ---
@export_group("Jump Defaults")
@export var gravity: float = 3200.0
@export var jump_duration: float = 0.55
@export var shift_duration: float = 0.28


func _ready() -> void:
	print("MTD Prototype started")
	print("Viewport size: ", get_viewport().get_visible_rect().size)

	btn_archer.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.ARCHER))
	btn_mage.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.MAGE))
	btn_cannon.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.CANNON))


func _on_spawn_pressed(unit_type: Unit.UnitType) -> void:
	if units.size() >= max_units:
		print("Стена заполнена")
		return

	if unit_type != Unit.UnitType.ARCHER:
		print("Пока только лучник")
		return

	_spawn_unit(unit_type)


func _spawn_unit(unit_type: Unit.UnitType) -> void:
	var unit: Unit = ARCHER_SCENE.instantiate()
	unit.setup(unit_type, 1)

	# Прокидываем настройки прыжка из Main
	unit.gravity = gravity
	unit.jump_duration = jump_duration
	unit.shift_duration = shift_duration

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
