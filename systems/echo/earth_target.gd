extends StaticBody3D
## Reference environment adapter. Team-owned world objects can implement this contract.

@export var target_id: String = ""
@export_enum("rock", "ground", "discovery") var kind: String = "rock"
var damage: int = 0
var form: String = "flat"
var revealed: bool = false
var home: Vector3
var visual: MeshInstance3D
var collider: CollisionShape3D
var caption: Label3D
var _highlighted: bool = false
@export var require_ground_support: bool = false


func _ready() -> void:
	home = position
	add_to_group("echo_earth_targets")
	visual = MeshInstance3D.new()
	add_child(visual)
	collider = CollisionShape3D.new()
	add_child(collider)
	caption = Label3D.new()
	caption.font_size = 64
	caption.pixel_size = 0.009
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("fff5d9")
	add_child(caption)
	_refresh()


func dimensions(for_form: String = form) -> Vector3:
	if kind == "rock":
		return Vector3(1.5, 1.6, 1.4)
	if kind == "discovery":
		return Vector3(2.2, 0.25, 2.2)
	match for_form:
		"platform": return Vector3(2.6, 1.5, 2.6)
		"barrier": return Vector3(3.0, 2.6, 0.65)
	return Vector3(2.6, 0.12, 2.6)


func action_for(held: bool) -> String:
	if kind == "rock":
		return "" if damage >= 2 else ("move" if held else "crack")
	if kind == "discovery":
		return "" if revealed else "reveal"
	if form != "flat":
		return "lower"
	return "raise_barrier" if held else "raise_platform"


func prompt() -> String:
	if kind == "rock":
		return "Tap: %s  |  Hold: move rock" % ("break" if damage == 1 else "crack")
	if kind == "discovery":
		return "Discovery revealed" if revealed else "Tap: uncover buried entrance"
	return "Tap: lower structure" if form != "flat" else "Tap: platform  |  Hold: barrier"


func set_highlight(value: bool) -> void:
	if _highlighted != value:
		_highlighted = value
		_refresh_material()


func can_place(at: Vector3, size: Vector3) -> bool:
	if not at.is_finite() or absf(at.x) > 13.0 or absf(at.z) > 10.0 or absf(at.y) > 0.05:
		return false
	if require_ground_support:
		for x in [-0.45, 0.45]:
			for z in [-0.45, 0.45]:
				var corner := at + Vector3(size.x * x, 0.2, size.z * z)
				var support := PhysicsRayQueryParameters3D.create(corner, corner - Vector3.UP * 0.45, 3)
				support.exclude = [get_rid()]
				if get_world_3d().direct_space_state.intersect_ray(support).is_empty():
					return false
	var shape := BoxShape3D.new()
	shape.size = size * 0.96
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * size.y * 0.5)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func apply_earth(action: String, at: Vector3) -> bool:
	if action not in [action_for(false), action_for(true)] or action.is_empty():
		return false
	match action:
		"move":
			if not can_place(at, dimensions()):
				return false
			position = at
		"crack": damage = mini(2, damage + 1)
		"raise_platform", "raise_barrier":
			var next_form := "platform" if action == "raise_platform" else "barrier"
			if not can_place(position, dimensions(next_form)):
				return false
			form = next_form
		"lower": form = "flat"
		"reveal": revealed = true
	_refresh()
	return true


func snapshot() -> Dictionary:
	return {"kind": kind, "position": [position.x, position.y, position.z],
		"damage": damage, "form": form, "revealed": revealed}


func valid_snapshot(data: Dictionary) -> bool:
	if data.get("kind") != kind or not data.get("position") is Array or data["position"].size() != 3:
		return false
	for value: Variant in data["position"]:
		if (not value is float and not value is int) or not is_finite(float(value)):
			return false
	var p := Vector3(data["position"][0], data["position"][1], data["position"][2])
	if absf(p.x) > 13.0 or absf(p.z) > 10.0 or absf(p.y) > 0.05:
		return false
	if kind != "rock" and not p.is_equal_approx(home):
		return false
	var saved_damage: Variant = data.get("damage")
	if (not saved_damage is float and not saved_damage is int) or not is_finite(float(saved_damage)):
		return false
	if float(saved_damage) < 0 or float(saved_damage) > 2 or float(saved_damage) != float(int(saved_damage)):
		return false
	if not data.get("form") in ["flat", "platform", "barrier"] or not data.get("revealed") is bool:
		return false
	if kind != "rock" and saved_damage != 0:
		return false
	if kind != "ground" and data["form"] != "flat":
		return false
	if kind != "discovery" and data["revealed"]:
		return false
	return true


func restore(data: Dictionary) -> void:
	position = Vector3(data["position"][0], data["position"][1], data["position"][2])
	damage = int(data["damage"])
	form = data["form"]
	revealed = data["revealed"]
	_refresh()


func _refresh() -> void:
	var size := dimensions()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.position.y = size.y * 0.5
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = visual.position
	visible = not (kind == "rock" and damage >= 2)
	collision_layer = 1 if visible else 0
	collision_mask = 1
	caption.position.y = size.y + 0.45
	caption.text = "ROCK" if kind == "rock" else ("EARTH" if kind == "ground" else "BURIED MEMORY")
	if kind == "rock" and damage == 1:
		caption.text = "CRACKED ROCK"
	if kind == "discovery" and revealed:
		caption.text = "ANCESTRAL ENTRANCE REVEALED"
	_refresh_material()


func _refresh_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("967650") if kind == "rock" else Color("c5a666")
	if damage == 1:
		material.albedo_color = Color("665147")
	if revealed:
		material.albedo_color = Color("7b2cbf")
	if _highlighted:
		material.emission_enabled = true
		material.emission = Color("ffd166")
		material.emission_energy_multiplier = 0.4
	material.roughness = 0.85
	visual.material_override = material
