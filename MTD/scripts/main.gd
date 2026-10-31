extends Node2D

## Main entry point of the prototype.
## Здесь пока только базовая структура под GDD.

@onready var wave_label: Label = $UI/HUD/TopBar/WaveLabel
@onready var btn_archer: Button = $UI/HUD/BottomBar/BtnArcher
@onready var btn_mage: Button = $UI/HUD/BottomBar/BtnMage
@onready var btn_cannon: Button = $UI/HUD/BottomBar/BtnCannon
@onready var tower_hp: ProgressBar = $UI/HUD/TowerHP

func _ready() -> void:
	print("MTD Prototype started")
	print("Viewport size: ", get_viewport().get_visible_rect().size)
	
	# Пока просто заглушки
	btn_archer.pressed.connect(_on_spawn_pressed.bind("archer"))
	btn_mage.pressed.connect(_on_spawn_pressed.bind("mage"))
	btn_cannon.pressed.connect(_on_spawn_pressed.bind("cannon"))


func _on_spawn_pressed(unit_type: String) -> void:
	print("Spawn requested: ", unit_type)
	# TODO: здесь будет логика спавна + сброс прогресс-баров
