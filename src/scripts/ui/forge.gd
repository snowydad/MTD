extends Control

const META := "res://src/scenes/ui/meta_map.tscn"

const UPGRADES := [
	"Archer / Distance",
	"Archer / Fire Rate",
	"Archer / Armor crusher",
	"Archer / Double Arrow",
	"Mage / Distance",
	"Mage / Fire Rate",
	"Mage / Freezer",
	"Mortar / Distance",
	"Mortar / Fire Rate",
	"Mortar / Fragmentation Bomb",
]

@onready var list: VBoxContainer = $Safe/Scroll/List
@onready var frame: CanvasLayer = $UIFrame


func _ready() -> void:
	frame.back_pressed.connect(func(): get_tree().change_scene_to_file(META))
	for name in UPGRADES:
		var b := Button.new()
		b.text = "%s   — stub" % name
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 42)
		b.disabled = true
		list.add_child(b)
