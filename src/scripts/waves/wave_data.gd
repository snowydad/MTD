class_name WaveData
extends RefCounted

## Волны из assets/data/waves.tsv
## Колонки: wave, subwave, type, delay, count, interval, spawn_x_min, spawn_x_max
## Имя в UI = "Wave {wave}".

const WAVES_PATH := "res://assets/data/waves.tsv"

static var _waves: Array = []
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_waves = []

	if not FileAccess.file_exists(WAVES_PATH):
		push_error("WaveData: нет файла " + WAVES_PATH)
		return

	var f := FileAccess.open(WAVES_PATH, FileAccess.READ)
	if f == null:
		push_error("WaveData: не открыть " + WAVES_PATH)
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

	print("WaveData: TSV → волн: ", _waves.size())


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
