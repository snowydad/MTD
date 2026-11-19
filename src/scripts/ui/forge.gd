extends Control

const META := "res://src/scenes/ui/meta_map.tscn"

## Остальные апгрейды пока заглушки (не в forge_upgrades.tsv).
const STUBS := [
	"Archer / Armor crusher",
	"Archer / Double Arrow",
	"Mage / Freezer",
	"Mortar / Fragmentation Bomb",
]

@onready var list: VBoxContainer = $Safe/Scroll/List
@onready var frame: CanvasLayer = $UIFrame

var _buttons: Dictionary = {}  # id → Button


func _ready() -> void:
	frame.back_pressed.connect(func(): get_tree().change_scene_to_file(META))
	_build_list()
	var pd := _pd()
	if pd != null:
		if pd.has_signal("gold_changed"):
			pd.gold_changed.connect(func(_v): _refresh())
		if pd.has_signal("forge_changed"):
			pd.forge_changed.connect(_refresh)
		if pd.has_signal("progress_changed"):
			pd.progress_changed.connect(_refresh)
	_refresh()


func _pd() -> Node:
	return get_tree().root.get_node_or_null("ProgressData")


func _build_list() -> void:
	for c in list.get_children():
		c.queue_free()
	_buttons.clear()

	for id in GameData.forge_upgrade_ids():
		var u: Dictionary = GameData.forge_upgrade(id)
		if u.is_empty():
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var upgrade_id := str(id)
		b.pressed.connect(_on_buy.bind(upgrade_id))
		list.add_child(b)
		_buttons[upgrade_id] = b

	for name in STUBS:
		var b := Button.new()
		b.text = "%s   — soon" % name
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 36)
		b.disabled = true
		list.add_child(b)


func _refresh() -> void:
	var pd := _pd()
	for id in _buttons.keys():
		var b: Button = _buttons[id]
		var u: Dictionary = GameData.forge_upgrade(id)
		var label := str(u.get("label", id))
		var rank := 0
		var max_r := int(u.get("max_rank", 0))
		var unlocked := true
		var maxed := false
		var cost := 0
		var can := false
		if pd != null:
			rank = pd.forge_rank(id)
			unlocked = pd.forge_is_unlocked(id)
			maxed = pd.forge_is_maxed(id)
			cost = pd.forge_next_cost(id)
			can = pd.can_buy_forge(id)
		var bonus := float(u.get("bonus_per_rank", 0.0))
		var total_pct := int(round(bonus * float(rank) * 100.0))
		var line := "%s   Lv %d/%d" % [label, rank, max_r]
		if total_pct > 0:
			line += "   (+%d%%)" % total_pct
		if not unlocked:
			line += "   🔒 meta %d" % int(u.get("unlock_level", 1))
			b.disabled = true
		elif maxed:
			line += "   MAX"
			b.disabled = true
		else:
			line += "   %dg" % cost
			b.disabled = not can
		b.text = line


func _on_buy(id: String) -> void:
	var pd := _pd()
	if pd == null:
		return
	if pd.buy_forge(id):
		_refresh()
	else:
		_refresh()
