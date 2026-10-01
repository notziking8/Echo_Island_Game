extends RefCounted
## Saves a coherent scene-entry checkpoint, never a partial mix of receiver states.
const Catalog = preload("res://campaign/catalog.gd")
const PATH := "user://echo_island_journey_v1.json"
const STONE_COUNTS = [0, 0, 1, 1, 2, 2, 3, 3, 4]

static func valid(data: Variant, echo: Node) -> bool:
	if not data is Dictionary or data.get("version") != 1:
		return false
	var index: Variant = data.get("stage")
	if not (index is int or index is float) or not is_finite(float(index)):
		return false
	if float(index) != float(int(index)) or index < 0 or index > 8:
		return false
	var state: Variant = data.get("echo")
	if not state is Dictionary or not echo.valid_snapshot(state):
		return false
	if not state.get("story_order", false) or state.generation != Catalog.STAGES[int(index)].generation:
		return false
	if state.collected_stones.size() != STONE_COUNTS[int(index)]:
		return false
	if not data.get("relics") is Array:
		return false
	var seen: Array[int] = []
	for relic: Variant in data.relics:
		if not (relic is int or relic is float) or not is_finite(float(relic)):
			return false
		if float(relic) != float(int(relic)) or int(relic) not in [0, 2, 4, 6, 8] or int(relic) >= int(index) or int(relic) in seen:
			return false
		seen.append(int(relic))
	return true

static func read_checkpoint(echo: Node, path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data: Variant = parser.data
	return data if valid(data, echo) else {}

static func write_checkpoint(data: Dictionary, echo: Node, path: String = PATH) -> bool:
	if not valid(data, echo):
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
