extends Node2D

## Main — юниты, формация, общий заряд, HP башни, мерж ×3.

@onready var wave_label: Label = $UI/HUD/TopBar/WaveLabel
@onready var gold_label: Label = $UI/HUD/GoldLabel
@onready var btn_archer: Button = $UI/HUD/BottomBar/BtnArcher
@onready var btn_mage: Button = $UI/HUD/BottomBar/BtnMage
@onready var btn_cannon: Button = $UI/HUD/BottomBar/BtnCannon
@onready var tower_hp_bar: ProgressBar = $UI/HUD/TowerHP
var tower_hp_label: Label = null
@onready var perk_panel: HBoxContainer = $UI/HUD/PerkPanel
@onready var btn_perk_range: Button = $UI/HUD/PerkPanel/BtnPerkRange
@onready var btn_perk_speed: Button = $UI/HUD/PerkPanel/BtnPerkSpeed
@onready var btn_perk_damage: Button = $UI/HUD/PerkPanel/BtnPerkDamage
@onready var units_root: Node2D = $World/Units
@onready var wall: Sprite2D = $World/Wall
@onready var wave_manager: WaveManager = $World/WaveManager

const ARCHER_SCENE := preload("res://src/scenes/units/archer.tscn")

var units: Array[Unit] = []

@export_group("Formation")
@export var wall_y: float = 2070.0
@export var slot_spacing: float = 120.0
@export var max_units: int = 9

@export_group("Charge")
@export var fill_rate: float = 10.0
## Шаг цены: 1-й юнит = step, 2-й = 2*step, 3-й = 3*step...
@export var cost_step: int = 6

@export_group("Tower")
@export var tower_max_hp: float = 100.0

@export_group("Merge")
@export var merge_delay: float = 1.0
@export var merge_converge_time: float = 0.4

var charge: float = 0.0
## Покупки по типам — своя прогрессия цены у каждого.
var bought_archer: int = 0
var bought_mage: int = 0
var bought_cannon: int = 0
var tower_hp: float = 100.0
var gold: int = 0
var _game_over: bool = false
var _merges_in_flight: int = 0
var _perk_panel_open: bool = false

## Перки: 3 из 7, шаг за золото. Шаг — economy.tsv perk_bonus.
var perk_cost: int = 50
var perk_cost_step: int = 5
var perk_bonus: float = 0.10
var perk_damage: float = 1.0
var perk_range: float = 1.0
var perk_speed: float = 1.0
var perk_accuracy: float = 1.0
var perk_gold: float = 1.0
## fill_rate и tower_max_hp растут на месте (export-базы * накопленные множители)
var _energy_mult: float = 1.0
var _hp_mult: float = 1.0
var _base_fill_rate: float = 10.0
var _base_tower_max_hp: float = 100.0
## Текущие 3 предложения на панели
var _perk_offers: Array[String] = []
const PERK_POOL: Array[String] = [
	"range", "damage", "speed", "accuracy", "hp", "energy", "gold",
]


func _ready() -> void:
	add_to_group("game_main")
	print("MTD Prototype started")
	print("Viewport size: ", get_viewport().get_visible_rect().size)

	GameData.reload()
	perk_cost = GameData.perk_cost_base()
	perk_cost_step = GameData.perk_cost_step()
	perk_bonus = GameData.perk_bonus()
	_base_fill_rate = fill_rate
	_base_tower_max_hp = tower_max_hp

	tower_hp = tower_max_hp
	_ensure_hp_label()
	_setup_hp_bar()
	_update_hp_bar()
	_update_gold_label()
	perk_panel.visible = false

	btn_archer.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.ARCHER))
	btn_mage.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.MAGE))
	btn_cannon.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.CANNON))

	btn_perk_range.pressed.connect(_on_perk_slot.bind(0))
	btn_perk_speed.pressed.connect(_on_perk_slot.bind(1))
	btn_perk_damage.pressed.connect(_on_perk_slot.bind(2))

	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_spawn_complete.connect(_on_wave_spawn_complete)
		wave_manager.wave_cleared.connect(_on_wave_cleared)
		wave_manager.all_waves_complete.connect(_on_all_waves_complete)

	_update_buttons()
	var enemies_root := $World/Enemies
	enemies_root.child_entered_tree.connect(_on_enemy_spawned_for_damage)


func _process(delta: float) -> void:
	if _game_over:
		return

	# Копим до самой дорогой «следующей» цены среди трёх типов
	var cap := float(maxi(_cost_for(Unit.UnitType.ARCHER), maxi(_cost_for(Unit.UnitType.MAGE), _cost_for(Unit.UnitType.CANNON))))
	if charge < cap:
		charge = minf(charge + fill_rate * delta, cap)
	_update_buttons()


# ─── HP ───────────────────────────────────────────────────────────────────────


func _ensure_hp_label() -> void:
	## Лейбл абсолютного HP — из сцены или создаём в рантайме.
	tower_hp_label = get_node_or_null("UI/HUD/TowerHPLabel") as Label
	if tower_hp_label != null:
		return
	var hud := get_node_or_null("UI/HUD") as Control
	if hud == null or tower_hp_bar == null:
		return
	var lb := Label.new()
	lb.name = "TowerHPLabel"
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 28)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 5)
	hud.add_child(lb)
	# Повторяем якоря/отступы полоски HP
	lb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lb.offset_left = tower_hp_bar.offset_left
	lb.offset_right = tower_hp_bar.offset_right
	lb.offset_top = tower_hp_bar.offset_top
	lb.offset_bottom = tower_hp_bar.offset_bottom
	tower_hp_label = lb


func _setup_hp_bar() -> void:
	tower_hp_bar.min_value = 0.0
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = tower_hp
	tower_hp_bar.show_percentage = false


func _update_hp_bar() -> void:
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = clampf(tower_hp, 0.0, tower_max_hp)
	if tower_hp_label:
		tower_hp_label.text = "%d / %d" % [int(round(tower_hp)), int(round(tower_max_hp))]

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
	if wave_manager:
		wave_manager.stop()
	btn_archer.disabled = true
	btn_mage.disabled = true
	btn_cannon.disabled = true
	wave_label.text = "GAME OVER"


func _on_enemy_spawned_for_damage(node: Node) -> void:
	var e := node as Enemy
	if e == null:
		return
	if not e.reached_wall.is_connected(_on_enemy_reached_wall):
		e.reached_wall.connect(_on_enemy_reached_wall)
	if not e.died.is_connected(_on_enemy_died):
		e.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	if _game_over or enemy == null:
		return
	gold += int(round(float(enemy.gold_reward) * perk_gold))
	_update_gold_label()
	_try_show_perks()


func _update_gold_label() -> void:
	if gold_label:
		gold_label.text = str(gold)


func get_perk_multipliers() -> Dictionary:
	return {
		"damage": perk_damage,
		"range": perk_range,
		"speed": perk_speed,
		"accuracy": perk_accuracy,
	}


func _perk_title(kind: String) -> String:
	match kind:
		"range":
			return "Дальность"
		"damage":
			return "Сила"
		"speed":
			return "Скорость"
		"accuracy":
			return "Точность"
		"hp":
			return "Здоровье"
		"energy":
			return "Энергия"
		"gold":
			return "Золото"
	return kind


func _roll_perk_offers() -> void:
	var pool: Array[String] = PERK_POOL.duplicate()
	pool.shuffle()
	_perk_offers = [pool[0], pool[1], pool[2]]


func _apply_perk_labels() -> void:
	var pct := int(round(perk_bonus * 100.0))
	var btns: Array[Button] = [btn_perk_range, btn_perk_speed, btn_perk_damage]
	for i in range(3):
		var kind := _perk_offers[i] if i < _perk_offers.size() else "range"
		btns[i].text = "%s\n+%d%%\n%d" % [_perk_title(kind), pct, perk_cost]


func _try_show_perks() -> void:
	## После убийства, если хватает золота. После выбора — только со следующего килла.
	if _game_over or _perk_panel_open:
		return
	if gold < perk_cost:
		return
	_roll_perk_offers()
	_apply_perk_labels()
	_perk_panel_open = true
	perk_panel.visible = true


func _on_perk_slot(slot: int) -> void:
	if slot < 0 or slot >= _perk_offers.size():
		_hide_perks()
		return
	_on_perk_chosen(_perk_offers[slot])


func _on_perk_chosen(kind: String) -> void:
	if gold < perk_cost:
		_hide_perks()
		return
	gold -= perk_cost
	_update_gold_label()

	var b := 1.0 + perk_bonus
	match kind:
		"range":
			perk_range *= b
		"speed":
			perk_speed *= b
		"damage":
			perk_damage *= b
		"accuracy":
			perk_accuracy *= b
		"hp":
			_hp_mult *= b
			var old_max := tower_max_hp
			var old_hp := tower_hp
			tower_max_hp = _base_tower_max_hp * _hp_mult
			# 1) потолок +10%  2) лечение на величину прироста потолка
			var gained := tower_max_hp - old_max
			tower_hp = clampf(tower_hp + gained, 0.0, tower_max_hp)
			_setup_hp_bar()
			_update_hp_bar()
			print("HP boost: ", old_hp, "/", old_max, " → ", tower_hp, "/", tower_max_hp)
		"energy":
			_energy_mult *= b
			fill_rate = _base_fill_rate * _energy_mult
			print("Energy boost: fill_rate=", fill_rate, " (x", _energy_mult, ")")
		"gold":
			perk_gold *= b

	perk_cost += perk_cost_step
	print("PERK ", kind, " x", b, " cost_next=", perk_cost,
		" dmg=", perk_damage, " range=", perk_range, " spd=", perk_speed,
		" acc=", perk_accuracy, " gold=", perk_gold, " energy=", fill_rate, " hp_max=", tower_max_hp)
	_refresh_all_unit_stats()
	_hide_perks()


func _hide_perks() -> void:
	_perk_panel_open = false
	perk_panel.visible = false
	_perk_offers.clear()


func _refresh_all_unit_stats() -> void:
	for u in units:
		if is_instance_valid(u):
			u._apply_stats()


func _on_wave_started(wave_index: int, wave_name: String) -> void:
	var total := WaveData.wave_count()
	wave_label.text = "%s / %d" % [wave_name, total]
	print("UI: ", wave_label.text)


func _on_wave_spawn_complete(wave_index: int) -> void:
	print("UI: spawn complete wave ", wave_index + 1)


func _on_wave_cleared(wave_index: int) -> void:
	print("UI: cleared wave ", wave_index + 1)


func _on_all_waves_complete() -> void:
	wave_label.text = "Победа!"
	print("=== WIN ===")


# ─── Кнопки / спавн ───────────────────────────────────────────────────────────

func _bought_count(unit_type: Unit.UnitType) -> int:
	match unit_type:
		Unit.UnitType.ARCHER:
			return bought_archer
		Unit.UnitType.MAGE:
			return bought_mage
		Unit.UnitType.CANNON:
			return bought_cannon
	return 0


func _cost_for(unit_type: Unit.UnitType) -> int:
	## Своя прогрессия: 1-й = step, 2-й = 2*step, ...
	return cost_step * (_bought_count(unit_type) + 1)


func _register_purchase(unit_type: Unit.UnitType) -> void:
	match unit_type:
		Unit.UnitType.ARCHER:
			bought_archer += 1
		Unit.UnitType.MAGE:
			bought_mage += 1
		Unit.UnitType.CANNON:
			bought_cannon += 1


func _update_buttons() -> void:
	if _game_over:
		return
	_refresh_button(btn_archer, "Лучник", _cost_for(Unit.UnitType.ARCHER))
	_refresh_button(btn_mage, "Маг", _cost_for(Unit.UnitType.MAGE))
	_refresh_button(btn_cannon, "Пушка", _cost_for(Unit.UnitType.CANNON))


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

	charge = 0.0
	_register_purchase(unit_type)
	_update_buttons()
	_spawn_unit(unit_type)


func _spawn_unit(unit_type: Unit.UnitType) -> void:
	var unit: Unit = ARCHER_SCENE.instantiate()
	units_root.add_child(unit)
	unit.setup(unit_type, 1)
	units.append(unit)
	unit.landed.connect(_on_unit_landed)

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


func _on_unit_landed(_unit: Unit) -> void:
	# После посадки любого юнита проверяем, есть ли тройка для мержа
	_try_merge()


# ─── Merge ×3 ─────────────────────────────────────────────────────────────────

func _try_merge() -> void:
	if _game_over:
		return

	# Ищем первую тройку: один тип + один уровень, все уже на стене
	var groups: Dictionary = {}  # key "type_level" → Array[Unit]
	for u in units:
		if not is_instance_valid(u):
			continue
		if not u.is_ready_on_wall():
			continue
		var key := "%d_%d" % [u.unit_type, u.level]
		if not groups.has(key):
			groups[key] = [] as Array[Unit]
		groups[key].append(u)

	for key in groups:
		var group: Array = groups[key]
		while group.size() >= 3:
			var triple: Array[Unit] = [group[0], group[1], group[2]]
			group.remove_at(0)
			group.remove_at(0)
			group.remove_at(0)
			# Сразу лочим — в новую тройку не попадут, но ещё стреляют
			for u in triple:
				u.merge_locked = true
			_merges_in_flight += 1
			_run_merge(triple)
			# один мерж за вызов; остальные подхватятся после
			return


func _run_merge(triple: Array[Unit]) -> void:
	# 1 сек пауза — юниты продолжают стрелять
	await get_tree().create_timer(merge_delay).timeout

	if _game_over:
		_merges_in_flight -= 1
		return

	var alive: Array[Unit] = []
	for u in triple:
		if is_instance_valid(u):
			alive.append(u)
	if alive.size() < 3:
		for u in alive:
			u.merge_locked = false
			u.is_merging = false
		_merges_in_flight -= 1
		_try_merge()
		return

	# Съезд — атака выключается
	var center := Vector2.ZERO
	for u in alive:
		u.is_merging = true
		center += u.global_position
	center /= float(alive.size())

	var tweens_done := 0
	var total := alive.size()
	for u in alive:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN)
		tw.set_trans(Tween.TRANS_BACK)
		tw.tween_property(u, "global_position", center, merge_converge_time)
		tw.finished.connect(func():
			tweens_done += 1
		)

	# Ждём съезд
	await get_tree().create_timer(merge_converge_time + 0.05).timeout

	if _game_over:
		_merges_in_flight -= 1
		return

	# Выживший — первый, остальные удаляем
	var survivor: Unit = alive[0]
	var new_level := survivor.level + 1

	for i in range(1, alive.size()):
		var dying := alive[i]
		units.erase(dying)
		dying.queue_free()

	survivor.upgrade_to_level(new_level)
	survivor.merge_locked = false
	survivor.is_merging = false
	survivor.target_global = center
	# Лёгкий «попап» масштаба
	if survivor.sprite:
		var base_scale := survivor.sprite.scale
		survivor.sprite.scale = base_scale * 1.35
		var pop := create_tween()
		pop.tween_property(survivor.sprite, "scale", base_scale, 0.2).set_ease(Tween.EASE_OUT)

	print("MERGE → %s Lv.%d  (осталось юнитов: %d)" % [
		Unit.UnitType.keys()[survivor.unit_type], survivor.level, units.size()
	])

	_reform_formation()
	_merges_in_flight -= 1

	# Возможно, после мержа снова есть тройка (например 6 лучников)
	_try_merge()


func _reform_formation() -> void:
	# Чистим мёртвые ссылки
	units = units.filter(func(u: Unit) -> bool: return is_instance_valid(u))

	var slots := _compute_slots(units.size())
	for i in range(units.size()):
		units[i].slot_index = i
		if not units[i].merge_locked:
			units[i].is_merging = false
		units[i].move_to_slot(slots[i])


# ─── Формация ─────────────────────────────────────────────────────────────────

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
