extends Control

const META := "res://src/scenes/ui/meta_map.tscn"

const MOB_ICONS := {
	"goblin": "res://assets/sprites/enemies/goblin.png",
	"goblin_swift": "res://assets/sprites/enemies/goblin_swift.png",
	"goblin_armor": "res://assets/sprites/enemies/goblin_armor.png",
	"goblin_mage": "res://assets/sprites/enemies/goblin_mage.png",
	"goblin_armor_mage": "res://assets/sprites/enemies/goblin_armor_mage.png",
	"orc": "res://assets/sprites/enemies/orc.png",
}

@onready var list: VBoxContainer = $Safe/Scroll/List
@onready var frame: CanvasLayer = $UIFrame


func _ready() -> void:
	frame.back_pressed.connect(func(): get_tree().change_scene_to_file(META))
	GameData.reload()
	var keys: Array = MOB_ICONS.keys()
	# Prefer order from enemies.tsv via GameData if possible
	for type_name in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var tex_path: String = MOB_ICONS[type_name]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(tex_path):
			icon.texture = load(tex_path)
		row.add_child(icon)
		var lb := Label.new()
		lb.text = type_name
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.add_theme_font_size_override("font_size", 42)
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lb)
		list.add_child(row)
