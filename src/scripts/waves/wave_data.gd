class_name WaveData
extends RefCounted

## Все уровни в одном файле: assets/data/levels.tsv
## Колонки: level, wave, subwave, type, delay, count, interval, spawn_x_min, spawn_x_max
## Имя в UI = "Wave {wave}".

const LEVELS_FILE := "res://assets/data/levels.tsv"

## Сырые строки всего файла (после первого чтения).
static var _raw_rows: Array = []
## level_id → true
static var _level_ids: Dictionary = {}
static var _file_loaded: bool = false

static var _waves: Array = []
static var _level_built: bool = false
static var _level_id: int = 1


static func levels_path() -> String:
	return LEVELS_FILE


## Совместимость со старым API (один общий файл).
static func level_path(_level_id_arg: int = -1) -> String:
	return LEVELS_FILE


static func set_level(level_id: int) -> void:
	_level_id = maxi(level_id, 1)
	_level_built = false
	_waves = []
	_ensure_level_built()


static func current_level() -> int:
	return _level_id


static func max_level() -> int:
	_ensure_file_loaded()
	var n := 0
	for k in _level_ids.keys():
		n = maxi(n, int(k))
	return n


static func has_level(level_id: int) -> bool:
	_ensure_file_loaded()
	return _level_ids.has(level_id)


static func next_level_id() -> int:
	_ensure_file_loaded()
	var nxt := _level_id + 1
	if has_level(nxt):
		return nxt
	return 1  # цикл с 1-го


static func all_level_ids() -> Array:
	_ensure_file_loaded()
	var ids: Array = _level_ids.keys()
	ids.sort()
	return ids


static func _ensure_file_loaded() -> void:
	if _file_loaded:
		return
	_file_loaded = true
	_raw_rows = []
	_level_ids = {}

	if not FileAccess.file_exists(LEVELS_FILE):
		push_error("WaveData: нет файла " + LEVELS_FILE)
		return

	var f := FileAccess.open(LEVELS_FILE, FileAccess.READ)
	if f == null:
		push_error("WaveData: не открыть " + LEVELS_FILE)
		return

	var header_line := f.get_line().strip_edges()
	if header_line.is_empty():
		f.close()
		push_error("WaveData: пустой TSV")
		return

	## Ожидаем: level, wave, subwave, type, delay, count, interval, spawn_x_min, spawn_x_max
	## (старый формат без level больше не поддерживается)

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols := _parse_tsv_line(line)
		if cols.size() < 7:
			push_warning("WaveData: пропуск строки (мало колонок): " + line)
			continue

		var lid := int(cols[0])
		var wid := int(cols[1])
		var sid := String(cols[2])
		var etype := String(cols[3]).to_lower()
		var delay := float(cols[4])
		var count := int(cols[5])
		var interval := float(cols[6])
		var x_min := 35.0
		var x_max := 1100.0
		if cols.size() >= 9:
			x_min = float(cols[7])
			x_max = float(cols[8])

		if lid < 1 or wid < 1:
			push_warning("WaveData: пропуск строки (level/wave < 1): " + line)
			continue

		_level_ids[lid] = true
		_raw_rows.append({
			"level": lid,
			"wave": wid,
			"subwave": sid,
			"type": etype,
			"delay": delay,
			"count": count,
			"interval": interval,
			"spawn_x_min": x_min,
			"spawn_x_max": x_max,
		})

	f.close()
	print("WaveData: файл загружен, уровней: ", _level_ids.size(), ", строк: ", _raw_rows.size())


static func _ensure_level_built() -> void:
	if _level_built:
		return
	_ensure_file_loaded()
	_level_built = true
	_waves = []

	var by_wave: Dictionary = {}

	for row in _raw_rows:
		if int(row["level"]) != _level_id:
			continue
		var wid: int = int(row["wave"])
		var sid: String = str(row["subwave"])

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
			"type": str(row["type"]),
			"delay": float(row["delay"]),
			"count": int(row["count"]),
			"interval": float(row["interval"]),
			"spawn_x_min": float(row["spawn_x_min"]),
			"spawn_x_max": float(row["spawn_x_max"]),
		})

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
	_file_loaded = false
	_level_built = false
	_raw_rows = []
	_level_ids = {}
	_waves = []
	_ensure_level_built()


static func wave_count() -> int:
	_ensure_level_built()
	return _waves.size()


static func get_wave(index: int) -> Dictionary:
	_ensure_level_built()
	if index < 0 or index >= _waves.size():
		return {}
	return _waves[index]


static func total_enemies_in_wave(wave: Dictionary) -> int:
	var total := 0
	for sw in wave.get("subwaves", []):
		for e in sw.get("entries", []):
			total += int(e.get("count", 0))
	return total
