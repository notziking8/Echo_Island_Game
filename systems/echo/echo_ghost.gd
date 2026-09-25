extends Node3D
## Replaceable procedural ancestor presentation; no state or gameplay effects live here.

var element: String = "earth"
var material: StandardMaterial3D
var ornaments: Array[MeshInstance3D] = []
var clock: float = 0.0


func _ready() -> void:
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.35
	var robe := CapsuleMesh.new()
	robe.radius = 0.3
	robe.height = 1.05
	_part(robe, Vector3(0, 0.8, 0))
	var head := SphereMesh.new()
	head.radius = 0.24
	head.height = 0.48
	_part(head, Vector3(0, 1.55, 0))
	for side in [-1, 1]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.1
		arm.height = 0.65
		var limb := _part(arm, Vector3(side * 0.37, 1.0, 0))
		limb.rotation.z = side * 0.35
	for i in 5:
		var stone := SphereMesh.new()
		stone.radius = 0.08
		stone.height = 0.16
		ornaments.append(_part(stone, Vector3.ZERO))
	set_element(element)


func set_element(value: String) -> void:
	element = value
	if material == null:
		return
	var color: Color = {"earth": Color("ffd166"), "wind": Color("74c7ec"), "water": Color("59bca2")}.get(element, Color.WHITE)
	material.albedo_color = Color(color, 0.55)
	material.emission = color


func _process(delta: float) -> void:
	clock += delta
	for i in ornaments.size():
		var angle := clock * (2.0 if element == "wind" else 0.8) + TAU * i / ornaments.size()
		ornaments[i].position = Vector3(cos(angle) * 0.65, 0.5 + sin(angle * 2) * 0.2, sin(angle) * 0.65)


func _part(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance
