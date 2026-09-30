extends "res://systems/echo/echo_system.gd"
## Opt-in Echo extension: base inheritance/traversal files remain untouched.
signal energy_changed(value: float)
signal combat_feedback(event: Dictionary)
const CAST_COST := 15.0
const MAX_ENERGY := 100.0
var energy := MAX_ENERGY
var reservations: Dictionary = {}
var rewarded: Dictionary = {}
var regen_delay := 0.0
var pending_reward := 0.0

func _process(delta: float) -> void:
	super._process(delta)
	regen_delay = maxf(0, regen_delay - delta)
	if regen_delay == 0 and energy < MAX_ENERGY:
		energy = minf(MAX_ENERGY, energy + delta * 8.0)
		energy_changed.emit(energy)

func available_energy() -> float:
	return energy - reservations.size() * CAST_COST

func request_ability(element: String, action: String, target_id: String, position: Vector3 = Vector3.ZERO, channel: String = "traversal", context: Dictionary = {}) -> String:
	var expected := "echo_%d" % _next_request
	if channel == "combat":
		if available_energy() < CAST_COST:
			hint_ready.emit(element, "Echo energy is recovering.")
			return ""
		reservations[expected] = true
	var id := super.request_ability(element, action, target_id, position, channel, context)
	if id.is_empty():
		reservations.erase(expected)
	return id

func _resolve(response: Dictionary, channel: String) -> bool:
	var id := str(response.get("request_id", ""))
	var reserved := reservations.has(id)
	var accepted := super._resolve(response, channel)
	if accepted:
		reservations.erase(id)
		if channel == "combat" and reserved and response.success:
			energy = maxf(0, energy - CAST_COST)
			regen_delay = 1.5
			energy_changed.emit(energy)
		if reservations.is_empty() and pending_reward > 0:
			energy = minf(MAX_ENERGY, energy + pending_reward)
			pending_reward = 0
			energy_changed.emit(energy)
	return accepted

func receive_combat_event(event: Dictionary) -> bool:
	var id := str(event.get("event_id", ""))
	if id.is_empty() or rewarded.has(id):
		return false
	var amount: float = {"shatter_combo": 8.0, "launch_combo": 8.0, "core_exposed": 8.0, "enemy_defeated": 10.0}.get(event.get("kind"), 0.0)
	# Ignore caller-suggested reward amounts; the Echo extension owns its economy.
	rewarded[id] = true
	if rewarded.size() > 512:
		rewarded.erase(rewarded.keys()[0])
	if not reservations.is_empty():
		pending_reward += amount
	else:
		energy = minf(MAX_ENERGY, energy + amount)
	energy_changed.emit(energy)
	combat_feedback.emit(event.duplicate(true))
	return true

func restore(data: Dictionary) -> bool:
	var saved_energy: Variant = data.get("combat_energy", MAX_ENERGY)
	if (not saved_energy is float and not saved_energy is int) or not is_finite(float(saved_energy)) or saved_energy < 0 or saved_energy > MAX_ENERGY:
		return false
	if not super.restore(data):
		return false
	reservations.clear()
	rewarded.clear()
	pending_reward = 0
	energy = float(saved_energy)
	energy_changed.emit(energy)
	return true

func snapshot() -> Dictionary:
	var data := super.snapshot()
	data["combat_energy"] = energy
	return data
