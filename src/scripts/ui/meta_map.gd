extends Control

const BATTLE_SCENE := "res://src/scenes/main.tscn"
const OPTIONS_SCENE := "res://src/scenes/ui/options.tscn"
const FORGE_SCENE := "res://src/scenes/ui/forge.tscn"
const COLLECTION_SCENE := "res://src/scenes/ui/collection.tscn"
const SHOP_SCENE := "res://src/scenes/ui/shop.tscn"

@onready var levels_row: HBoxContainer = $Safe/VBox/LevelsScroll/LevelsRow
@onready var btn_battle: Button = $Safe/VBox/BtnBattle
@onready var btn_forge: Button = $Safe/VBox/BottomBar/BtnForge
@onready var btn_collection: Button = $Safe/VBox/BottomBar/BtnCollection
@onready var btn_shop: Button = $Safe/VBox/BottomBar/BtnShop
@onready var btn_options: Button = $Safe/VBox/BottomBar/BtnOptions
@onready var title_label: Label = $Safe/VBox/Title
@onready var gold_label: Label = $Safe/VBox/TopRow/GoldLabel


func _ready() -> void:
	btn_battle.pressed.connect(_on_battle)
	btn_forge.pressed.connect(func(): get_tree().change_scene_to_file(FORGE_SCENE))
	btn_collection.pressed.connect(func(): get_tree().change_scene_to_file(COLLECTION_SCENE))
	btn_shop.pressed.connect(func(): get_tree().change_scene_to_file(SHOP_SCENE))
	btn_options.pressed.connect(func(): get_tree().change_scene_to_file(OPTIONS_SCENE))
	ProgressData.gold_changed.connect(func(v): gold_label.text = str(v))
	ProgressData.progress_changed.connect(_rebuild_levels)
	gold_label.text = str(ProgressData.gold)
	_rebuild_levels()


func _rebuild_levels() -> void:
	for c in levels_row.get_children():
		c.queue_free()
	var n := ProgressData.max_level_available()
	for i in range(1, n + 1):
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 120)
		b.text = str(i)
		b.add_theme_font_size_override("font_size", 36)
		var unlocked := ProgressData.is_unlocked(i)
		b.disabled = not unlocked
		if not unlocked:
			b.modulate = Color(0.45, 0.45, 0.5)
		else:
			b.modulate = Color(0.35, 0.75, 1.0)
		if unlocked and i == ProgressData.selected_level:
			b.add_theme_stylebox_override("normal", _selected_style())
		var level_id := i
		b.pressed.connect(func(): _select(level_id))
		levels_row.add_child(b)
	btn_battle.text = "To Battle!  (Lv %d)" % ProgressData.selected_level


func _selected_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.45, 0.75)
	s.set_border_width_all(6)
	s.border_color = Color(1.0, 0.85, 0.2)
	s.set_corner_radius_all(12)
	return s


func _select(level_id: int) -> void:
	ProgressData.select_level(level_id)
	_rebuild_levels()


func _on_battle() -> void:
	var lv := ProgressData.selected_level
	if not ProgressData.is_unlocked(lv):
		return
	WaveData.set_level(lv)
	get_tree().change_scene_to_file(BATTLE_SCENE)
