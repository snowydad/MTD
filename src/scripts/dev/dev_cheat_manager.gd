extends Node

## Dev cheats (только для разработки).
## 0 — пауза, 1 — x1, 2 — x2
## [ / ] — энергия −5 / +5
## - / = — золото −5 / +5

const ENERGY_STEP := 5.0
const GOLD_STEP := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("DevCheatManager ready")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_0:
			Engine.time_scale = 0.0
			print("DEV: pause (time_scale=0)")
			get_viewport().set_input_as_handled()
		KEY_1:
			Engine.time_scale = 1.0
			print("DEV: speed x1")
			get_viewport().set_input_as_handled()
		KEY_2:
			Engine.time_scale = 2.0
			print("DEV: speed x2")
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			_add_energy(-ENERGY_STEP)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			_add_energy(ENERGY_STEP)
			get_viewport().set_input_as_handled()
		KEY_MINUS:
			_add_gold(-GOLD_STEP)
			get_viewport().set_input_as_handled()
		KEY_EQUAL:
			_add_gold(GOLD_STEP)
			get_viewport().set_input_as_handled()


func _main() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("game_main")


func _add_energy(delta: float) -> void:
	var main := _main()
	if main == null:
		return
	if not ("charge" in main):
		return
	main.charge = maxf(0.0, float(main.charge) + delta)
	if main.has_method("_update_buttons"):
		main._update_buttons()
	print("DEV: energy ", main.charge)


func _add_gold(delta: int) -> void:
	var main := _main()
	if main == null:
		return
	if not ("gold" in main):
		return
	main.gold = maxi(0, int(main.gold) + delta)
	if main.has_method("_update_gold_label"):
		main._update_gold_label()
	print("DEV: gold ", main.gold)
