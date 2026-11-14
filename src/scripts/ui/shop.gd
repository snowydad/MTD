extends Control

const META := "res://src/scenes/ui/meta_map.tscn"

const PACKS := [
	{"title": "Gold 50", "gold": 50},
	{"title": "Gold 200", "gold": 200},
	{"title": "Gold 1000", "gold": 1000},
]

@onready var list: VBoxContainer = $Safe/Scroll/List
@onready var frame: CanvasLayer = $UIFrame


func _ready() -> void:
	frame.back_pressed.connect(func(): get_tree().change_scene_to_file(META))
	for pack in PACKS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 80)
		b.add_theme_font_size_override("font_size", 30)
		b.text = "%s  (cheat)" % pack["title"]
		var amount: int = int(pack["gold"])
		b.pressed.connect(func():
			ProgressData.add_gold(amount)
			print("Shop cheat +", amount, " gold=", ProgressData.gold)
		)
		list.add_child(b)
