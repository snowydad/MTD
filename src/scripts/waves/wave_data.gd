class_name WaveData
extends RefCounted

## Волны уровня: assets/data/levels/level_XX.tsv
## Колонки: wave, subwave, type, delay, count, interval, spawn_x_min, spawn_x_max
## Имя в UI = "Wave {wave}".

const LEVELS_DIR := "res://assets/data/levels/"

static var _waves: Array = []
static var _loaded: bool = false
static var _level_id: int = 1
static var _level_path: String = ""


static func level_path(level_id: int = -1) -> String:
	var id := level_id if level_id > 0 else _level_id
	return "%slevel_%02d.tsv" % [LEVELS_DIR, id]


static func set_level(level_id: int) -> void:
	_level_id = maxi(level_id, 1)
	_loaded = false
	_waves = []
	_ensure_loaded()


static func current_level() -> int:
	return _level_id


static func max_level() -> int:
	## Сколько level_XX.tsv подряд начиная с 01.
	var n := 0
	var i := 1
	while FileAccess.file_exists(level_path(i)):
		n = i
		i += 1
		if i > 99:
			break
	return n


static func next_level_id() -> int:
	var cur := _level_id
	var nxt := cur + 1
	if FileAccess.file_exists(level_path(nxt)):
		return nxt
	return 1  # цикл с 1-го


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_waves = []
	_level_path = level_path(_level_id)

	if not FileAccess.file_exists(_level_path):
		push_error("WaveData: нет файла " + _level_path)
		return

	var f := FileAccess.open(_level_path, FileAccess.READ)
	if f == null:
		push_error("WaveData: не открыть " + _level_path)
		return

	var header_line := f.get_line().strip_edges()
	if header_line.is_empty():
		f.close()
		push_error("WaveData: пустой TSV")
		return

	var by_wave: Dictionary = {}

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols := _parse_tsv_line(line)
		if cols.size() < 6:
			push_warning("WaveData: пропуск строки (мало колонок): " + line)
			continue

		var wid := int(cols[0])
		var sid := String(cols[1])
		var etype := String(cols[2]).to_lower()
		var delay := float(cols[3])
		var count := int(cols[4])
		var interval := float(cols[5])
		var x_min := 35.0
		var x_max := 1100.0
		if cols.size() >= 8:
			x_min = float(cols[6])
			x_max = float(cols[7])

		if not by_wave.has(wid):
			by_wave[wid] = {
				"id": wid,
				"name": "Wave %d" % wid,
				"_subs": {},
			}

		var subs: Dictionary = by_wave[wid]["_subs"]
		if not subs.has(sid):
			subs[sid] = []
		subs[sid].append({
			"type": etype,
			"delay": delay,
			"count": count,
			"interval": interval,
			"spawn_x_min": x_min,
			"spawn_x_max": x_max,
		})

	f.close()

	var ids: Array = by_wave.keys()
	ids.sort()
	for wid in ids:
		var w: Dictionary = by_wave[wid]
		var subs: Dictionary = w["_subs"]
		var sub_ids: Array = subs.keys()
		sub_ids.sort()
		var subwaves: Array = []
		for sid in sub_ids:
			subwaves.append({
				"id": str(sid),
				"entries": subs[sid],
			})
		_waves.append({
			"id": int(w["id"]),
			"name": str(w["name"]),
			"subwaves": subwaves,
		})

	print("WaveData: level ", _level_id, " → волн: ", _waves.size())


static func _parse_tsv_line(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for part in line.split("\t"):
		out.append(part.strip_edges())
	return out


static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func wave_count() -> int:
	_ensure_loaded()
	return _waves.size()


static func get_wave(index: int) -> Dictionary:
	_ensure_loaded()
	if index < 0 or index >= _waves.size():
		return {}
	return _waves[index]


static func total_enemies_in_wave(wave: Dictionary) -> int:
	var total := 0
	for sw in wave.get("subwaves", []):
		for e in sw.get("entries", []):
			total += int(e.get("count", 0))
	return total
