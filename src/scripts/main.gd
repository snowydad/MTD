extends Node2D

## Main — юниты, формация, общий заряд, HP башни, мерж ×3.

@onready var wave_label: Label = $UI/HUD/TopBar/WaveLabel
@onready var gold_label: Label = $UI/HUD/GoldLabel
@onready var btn_archer: Button = $UI/HUD/BottomBar/BtnArcher
@onready var btn_mage: Button = $UI/HUD/BottomBar/BtnMage
@onready var btn_cannon: Button = $UI/HUD/BottomBar/BtnCannon
@onready var tower_hp_bar: ProgressBar = $UI/HUD/TowerHP
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
@export var cost_archer: int = 12
@export var cost_mage: int = 16
@export var cost_cannon: int = 20

@export_group("Tower")
@export var tower_max_hp: float = 100.0

@export_group("Merge")
@export var merge_delay: float = 1.0
@export var merge_converge_time: float = 0.4

var charge: float = 0.0
var tower_hp: float = 100.0
var gold: int = 0
var _game_over: bool = false
var _merges_in_flight: int = 0
var _perk_panel_open: bool = false

## Множители перков (стакаются). Числа — из assets/data/economy.csv
var perk_cost: int = 50
var perk_bonus: float = 0.15
var perk_damage: float = 1.0
var perk_range: float = 1.0
var perk_speed: float = 1.0


func _ready() -> void:
	add_to_group("game_main")
	print("MTD Prototype started")
	print("Viewport size: ", get_viewport().get_visible_rect().size)

	GameData.reload()
	perk_cost = GameData.perk_cost()
	perk_bonus = GameData.perk_bonus()
	_update_perk_button_labels()

	tower_hp = tower_max_hp
	_setup_hp_bar()
	_update_hp_bar()
	_update_gold_label()
	perk_panel.visible = false

	btn_archer.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.ARCHER))
	btn_mage.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.MAGE))
	btn_cannon.pressed.connect(_on_spawn_pressed.bind(Unit.UnitType.CANNON))

	btn_perk_range.pressed.connect(_on_perk_chosen.bind("range"))
	btn_perk_speed.pressed.connect(_on_perk_chosen.bind("speed"))
	btn_perk_damage.pressed.connect(_on_perk_chosen.bind("damage"))

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

	var max_cost: float = maxf(cost_archer, maxf(cost_mage, cost_cannon))
	if charge < max_cost:
		charge = minf(charge + fill_rate * delta, max_cost)
	_update_buttons()


# ─── HP ───────────────────────────────────────────────────────────────────────

func _setup_hp_bar() -> void:
	tower_hp_bar.min_value = 0.0
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = tower_hp
	tower_hp_bar.show_percentage = true


func _update_hp_bar() -> void:
	tower_hp_bar.max_value = tower_max_hp
	tower_hp_bar.value = clampf(tower_hp, 0.0, tower_max_hp)

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
	gold += enemy.gold_reward
	_update_gold_label()
	_try_show_perks()


func _update_gold_label() -> void:
	if gold_label:
		gold_label.text = str(gold)


func _update_perk_button_labels() -> void:
	var pct := int(round(perk_bonus * 100.0))
	btn_perk_range.text = "Range\n+%d%%" % pct
	btn_perk_speed.text = "Speed\n+%d%%" % pct
	btn_perk_damage.text = "Damage\n+%d%%" % pct


func get_perk_multipliers() -> Dictionary:
	return {
		"damage": perk_damage,
		"range": perk_range,
		"speed": perk_speed,
	}


func _try_show_perks() -> void:
	if _game_over or _perk_panel_open:
		return
	if gold < perk_cost:
		return
	_perk_panel_open = true
	perk_panel.visible = true
	# Можно чуть замедлить игру — пока просто панель поверх


func _on_perk_chosen(kind: String) -> void:
	if gold < perk_cost:
		_hide_perks()
		return
	gold -= perk_cost
	_update_gold_label()

	match kind:
		"range":
			perk_range *= (1.0 + perk_bonus)
		"speed":
			perk_speed *= (1.0 + perk_bonus)
		"damage":
			perk_damage *= (1.0 + perk_bonus)

	print("PERK ", kind, " → dmg=", perk_damage, " range=", perk_range, " speed=", perk_speed)
	_refresh_all_unit_stats()
	_hide_perks()
	# Если золота ещё хватает — снова показать выбор
	_try_show_perks()


func _hide_perks() -> void:
	_perk_panel_open = false
	perk_panel.visible = false


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
