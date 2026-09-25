extends Node
## Owns inheritance state. Receivers, not Echo, apply combat/world effects.

signal state_changed
signal hint_ready(echo_id: String, text: String)
signal ability_finished(response: Dictionary)
signal AbilityEvent(event: Dictionary)
signal TraversalAbilityEvent(event: Dictionary)
signal ability_started(event: Dictionary)

const ELEMENTS := ["earth", "wind", "water", "time"]
const COMBAT_EFFECTS := {"earth": "stun", "wind": "push", "water": "freeze", "time": "slow"}
const WORLD_ACTIONS := {
	"earth": ["crack", "move", "raise_platform", "raise_barrier", "lower", "reveal"],
	"wind": ["glide", "air_dash", "wind_current"],
	"water": ["freeze_water", "redirect_current", "underwater_access"],
	"time": ["freeze_object", "reset_object"],
}

@export var cooldown_seconds: float = 0.6
@export var response_timeout: float = 3.0
@export var enforce_story_order: bool = false
var focus_personal: bool = false
var generation: int = 1
var active_echo: String = ""
var collected_stones: Array[String] = []
var cooldowns: Dictionary = {}
var heard_hints: Array[String] = []
var _pending: Dictionary = {}
var _next_request: int = 1


func _process(delta: float) -> void:
	for element: String in cooldowns.keys():
		cooldowns[element] = maxf(0.0, float(cooldowns[element]) - delta)
		if cooldowns[element] == 0.0:
			cooldowns.erase(element)
	for request_id: String in _pending.keys():
		_pending[request_id]["remaining"] -= delta
		if _pending[request_id]["remaining"] <= 0.0:
			_resolve({"request_id": request_id, "target_id": _pending[request_id]["target_id"],
				"success": false, "resulting_status": "receiver_timeout"}, _pending[request_id]["channel"])


func personal_power() -> String:
	var element: String = ELEMENTS[generation - 1] if enforce_story_order else "time"
	return element if element in collected_stones else ""


func unlocked_echoes() -> Array[String]:
	var result: Array[String] = []
	for i in range(generation - 1 if enforce_story_order else 3):
		if ELEMENTS[i] in collected_stones:
			result.append(ELEMENTS[i])
	return result


func unlocked_abilities() -> Dictionary:
	var result: Dictionary = {}
	for element in unlocked_echoes():
		result[element] = WORLD_ACTIONS[element].duplicate() + [COMBAT_EFFECTS[element]]
	if not personal_power().is_empty():
		result[personal_power()] = WORLD_ACTIONS[personal_power()].duplicate() + [COMBAT_EFFECTS[personal_power()]]
	return result


func all_stones_collected() -> bool:
	return collected_stones.size() == ELEMENTS.size()


func collect_stone(element: String) -> bool:
	if element not in ELEMENTS or element in collected_stones:
		return false
	if enforce_story_order and element != ELEMENTS[generation - 1]:
		return false
	collected_stones.append(element)
	state_changed.emit()
	return true


func unlock_all() -> void:
	# Standalone testing needs no story coordinator or discovery sequence.
	enforce_story_order = false
	collected_stones.assign(ELEMENTS)
	state_changed.emit()


func select_power(element: String) -> bool:
	if element == personal_power() and not element.is_empty():
		focus_personal = true
		state_changed.emit()
		return true
	return summon(element)


func begin_generation(next_generation: int) -> bool:
	# The story coordinator calls this. Finding a stone never advances automatically.
	if not enforce_story_order or next_generation != generation + 1 or next_generation > 4 or personal_power().is_empty() or not _pending.is_empty():
		return false
	generation = next_generation
	active_echo = ""
	cooldowns.clear()
	state_changed.emit()
	return true


func summon(element: String) -> bool:
	if element not in unlocked_echoes() or not _pending.is_empty():
		return false
	active_echo = element
	focus_personal = false
	state_changed.emit()
	return true


func cycle_echo() -> void:
	var available := unlocked_echoes()
	if not available.is_empty():
		summon(available[(available.find(active_echo) + 1) % available.size()])


func dismiss() -> void:
	if not _pending.is_empty():
		return
	active_echo = ""
	state_changed.emit()


func selected_power(personal: bool = false) -> String:
	return personal_power() if personal or focus_personal or active_echo.is_empty() else active_echo


func can_use(element: String) -> bool:
	if element.is_empty() or (element != active_echo and element != personal_power()):
		return false
	if float(cooldowns.get(element, 0.0)) > 0.0:
		return false
	for pending: Dictionary in _pending.values():
		if pending["element"] == element:
			return false
	return true


func request_ability(element: String, action: String, target_id: String, position: Vector3 = Vector3.ZERO, channel: String = "traversal", context: Dictionary = {}) -> String:
	if not can_use(element) or target_id.is_empty() or not position.is_finite():
		return ""
	if channel == "combat":
		if action != COMBAT_EFFECTS[element]:
			return ""
	elif channel == "traversal":
		if action not in WORLD_ACTIONS[element]:
			return ""
	else:
		return ""
	var request_id := "echo_%d" % _next_request
	_next_request += 1
	var event := {"request_id": request_id, "echo_id": element,
		"ability_id": element + "." + action, "target_id": target_id,
		"intended_effect": action, "position": position}
	var tuning: Dictionary = preload("res://systems/echo/power_catalog.gd").parameters(action)
	event.merge(tuning)
	var origin: Variant = context.get("origin", Vector3.ZERO)
	var direction: Variant = context.get("direction", Vector3.FORWARD)
	if not origin is Vector3 or not origin.is_finite() or not direction is Vector3 or not direction.is_finite():
		return ""
	event["origin"] = origin
	event["direction"] = direction.normalized()
	_pending[request_id] = {"element": element, "target_id": target_id,
		"channel": channel, "remaining": maxf(0.1, response_timeout)}
	ability_started.emit(event.duplicate(true))
	if channel == "combat":
		AbilityEvent.emit(event)
	else:
		TraversalAbilityEvent.emit(event)
	return request_id


func receive_ability_response(response: Dictionary) -> bool:
	return _resolve(response, "combat")


func receive_traversal_response(response: Dictionary) -> bool:
	return _resolve(response, "traversal")


func _resolve(response: Dictionary, channel: String) -> bool:
	var id: Variant = response.get("request_id")
	if not id is String or not _pending.has(id):
		return false
	var pending: Dictionary = _pending[id]
	if pending["channel"] != channel or response.get("target_id") != pending["target_id"]:
		return false
	if not response.get("success") is bool or not response.get("resulting_status") is String:
		return false
	_pending.erase(id)
	# Failed/unsupported effects cost no cooldown. Never assume a receiver applied them.
	if response["success"]:
		cooldowns[pending["element"]] = maxf(0.0, cooldown_seconds)
	ability_finished.emit(response.duplicate(true))
	state_changed.emit()
	return true


func receive_echo_interaction(event: Dictionary) -> bool:
	# Traversal supplies contextual hints for its authored locations/objects.
	if active_echo.is_empty() or event.get("echo_id") != active_echo:
		return false
	var location: Variant = event.get("object_or_area_id")
	var hint: Variant = event.get("hint")
	if not location is String or location.is_empty() or not hint is String or hint.is_empty():
		return false
	var key: String = active_echo + ":" + location
	if key in heard_hints:
		return false
	heard_hints.append(key)
	hint_ready.emit(active_echo, hint)
	return true


func snapshot() -> Dictionary:
	return {"version": 2, "generation": generation, "active_echo": active_echo,
		"story_order": enforce_story_order, "focus_personal": focus_personal,
		"collected_stones": collected_stones.duplicate(), "cooldowns": cooldowns.duplicate(),
		"heard_hints": heard_hints.duplicate()}


func valid_snapshot(data: Dictionary) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2) or (not data.get("generation") is float and not data.get("generation") is int):
		return false
	if not is_finite(float(data["generation"])):
		return false
	var gen := int(data["generation"])
	if gen < 1 or gen > 4 or float(gen) != float(data["generation"]):
		return false
	if not data.get("collected_stones") is Array or not data.get("active_echo") is String:
		return false
	var stones: Array = data["collected_stones"]
	var story: Variant = data.get("story_order", true)
	if not story is bool or not data.get("focus_personal", false) is bool:
		return false
	if story:
		if stones.size() < gen - 1 or stones.size() > gen:
			return false
		for i in stones.size():
			if stones[i] != ELEMENTS[i]:
				return false
	var seen: Array = []
	for element: Variant in stones:
		if element not in ELEMENTS or element in seen:
			return false
		seen.append(element)
	var active: String = data["active_echo"]
	var own_element: String = ELEMENTS[gen - 1] if story else "time"
	if data.get("focus_personal", false) and own_element not in stones:
		return false
	if not active.is_empty() and (active not in stones or active == "time" or (story and ELEMENTS.find(active) >= gen - 1)):
		return false
	if not data.get("cooldowns") is Dictionary or not data.get("heard_hints") is Array:
		return false
	for element: Variant in data["cooldowns"]:
		var value: Variant = data["cooldowns"][element]
		if element not in stones or (not value is float and not value is int):
			return false
		if not is_finite(float(value)) or float(value) < 0.0 or float(value) > 3600.0:
			return false
	for hint: Variant in data["heard_hints"]:
		if not hint is String:
			return false
	return true


func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data):
		return false
	generation = int(data["generation"])
	enforce_story_order = data.get("story_order", true)
	focus_personal = data.get("focus_personal", false)
	active_echo = data["active_echo"]
	collected_stones.assign(data["collected_stones"])
	cooldowns = data["cooldowns"].duplicate()
	heard_hints.assign(data["heard_hints"])
	_pending.clear()
	state_changed.emit()
	return true
