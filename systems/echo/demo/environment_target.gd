extends StaticBody3D
## Working reference receiver for persistent Wind/Water changes and Time objects.

@export_enum("vent", "pool", "stream", "clockwork") var kind: String = "vent"
var target_id: String = ""
var channel: String = "traversal"
var active: bool = false
var reversed: bool = false
var phase: float = 0.0
var frozen_remaining: float = 0.0
var home: Vector3
var mesh: MeshInstance3D
var shape: CollisionShape3D
var label: Label3D
var motes: Array[MeshInstance3D] = []
var _highlight: bool = false


func _ready() -> void:
	home = position
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions()
	mesh.mesh = box
	mesh.position.y = 0.06 if kind != "clockwork" else 0.55
	add_child(mesh)
	shape = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position = mesh.position
	add_child(shape)
	label = Label3D.new()
	label.font_size = 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 0.8 if kind != "clockwork" else 1.5
	add_child(label)
	for i in 8:
		var mote := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		mote.mesh = sphere
		add_child(mote)
		motes.append(mote)
	_refresh()


func dimensions() -> Vector3:
	match kind:
		"pool": return Vector3(6, 0.12, 6)
		"stream": return Vector3(2, 0.12, 5)
		"clockwork": return Vector3(2, 0.8, 1.6)
	return Vector3(2, 0.15, 2)


func echo_action(element: String, held: bool) -> String:
	match kind:
		"vent": return "wind_current" if element == "wind" else ""
		"pool": return ("underwater_access" if held else "freeze_water") if element == "water" else ""
		"stream": return "redirect_current" if element == "water" else ""
		"clockwork": return ("reset_object" if held else "freeze_object") if element == "time" else ""
	return ""


func prompt() -> String:
	match kind:
		"vent": return "toggle updraft • Step onto it to rise"
		"pool": return "tap: freeze/thaw path • Hold while in water: dive"
		"stream": return "reverse the stream • Step in to feel its pull"
		"clockwork": return "tap: freeze motion • Hold: reset position"
	return ""


func apply_event(event: Dictionary, actor: CharacterBody3D = null) -> bool:
	var action: String = event["intended_effect"]
	if action not in [echo_action(event["echo_id"], false), echo_action(event["echo_id"], true)]:
		return false
	match action:
		"wind_current": active = not active
		"freeze_water":
			# Do not seal a swimmer below the ice or grow it through a character.
			if not active and is_instance_valid(actor) and contains(actor.global_position):
				return false
			active = not active
		"redirect_current": reversed = not reversed
		"underwater_access":
			if active or not is_instance_valid(actor) or not contains(actor.global_position):
				return false
			actor.in_water = true
			return actor.apply_event(event)
		"freeze_object": frozen_remaining = clampf(float(event.get("duration_seconds", 6.0)), 0.1, 30)
		"reset_object":
			if not _clear_at(home):
				return false
			position = home
			phase = 0
			frozen_remaining = 0
		_:
			return false
	_refresh()
	return true


func contains(at: Vector3) -> bool:
	var delta := at - global_position
	var size := dimensions()
	return absf(delta.x) < size.x / 2 and absf(delta.z) < size.z / 2


func _physics_process(delta: float) -> void:
	if frozen_remaining > 0:
		frozen_remaining = maxf(0, frozen_remaining - delta)
		if frozen_remaining == 0:
			_refresh()
	elif kind == "clockwork":
		var next_phase := phase + delta * 0.7
		var next_position := home + Vector3(sin(next_phase) * 2.5, 0, 0)
		if _clear_at(next_position):
			phase = next_phase
			position = next_position
	else:
		phase = fmod(phase + delta, TAU)
	for i in motes.size():
		var t := fmod(phase + i * 0.5, 4.0)
		var mote: MeshInstance3D = motes[i]
		mote.visible = kind == "stream" or (kind == "vent" and active)
		mote.position = Vector3(sin(i * 2.0) * 0.6, t, cos(i * 2.0) * 0.6) if kind == "vent" else Vector3(sin(i) * 0.5, 0.18, (t - 2) * (-1 if reversed else 1))
	if kind == "clockwork" and frozen_remaining > 0:
		label.text = "TIME LOCK  %.1fs" % frozen_remaining


func _clear_at(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, at + shape.position)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func set_highlight(value: bool) -> void:
	if _highlight != value:
		_highlight = value
		_refresh()


func _refresh() -> void:
	collision_layer = 1 if kind == "clockwork" or (kind == "pool" and active) else 4
	collision_mask = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("74c7ec")
	if kind == "pool":
		material.albedo_color = Color("c1f2f5") if active else Color(0.12, 0.62, 0.77, 0.55)
		if not active:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if kind == "clockwork":
		material.albedo_color = Color("b79ccc") if frozen_remaining > 0 else Color("c6b797")
	if _highlight:
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.3
	mesh.material_override = material
	match kind:
		"vent": label.text = "UPDRAFT ON" if active else "WIND VENT"
		"pool": label.text = "ICE PATH" if active else "WATER BASIN"
		"stream": label.text = "CURRENT  ↑" if reversed else "CURRENT  ↓"
		"clockwork": label.text = "MOVING RELIC"


func snapshot() -> Dictionary:
	return {"kind": kind, "active": active, "reversed": reversed, "phase": phase, "frozen_remaining": frozen_remaining}


func valid_snapshot(data: Dictionary) -> bool:
	if data.get("kind") != kind or not data.get("active") is bool or not data.get("reversed") is bool:
		return false
	for key in ["phase", "frozen_remaining"]:
		var value: Variant = data.get(key)
		if (not value is float and not value is int) or not is_finite(float(value)) or float(value) < 0:
			return false
	return float(data["phase"]) <= 1000000 and float(data["frozen_remaining"]) <= 30


func restore(data: Dictionary) -> void:
	active = data["active"]
	reversed = data["reversed"]
	phase = float(data["phase"])
	frozen_remaining = float(data["frozen_remaining"])
	if kind == "clockwork":
		position = home + Vector3(sin(phase) * 2.5, 0, 0)
	_refresh()
