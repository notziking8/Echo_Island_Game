extends "res://systems/combat/combat_enemy.gd"
## Presentation/target descriptor only. All effect and health decisions remain in CombatEnemy.

var channel: String = "combat"
var label: Label3D
var mesh: MeshInstance3D


func _ready() -> void:
	super._ready()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	collider.shape = capsule
	collider.position.y = 0.8
	add_child(collider)
	mesh = MeshInstance3D.new()
	var visual := CapsuleMesh.new()
	visual.radius = 0.4
	visual.height = 1.6
	mesh.mesh = visual
	mesh.position.y = 0.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff7a59")
	mesh.material_override = material
	add_child(mesh)
	label = Label3D.new()
	label.font_size = 40
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.1
	add_child(label)


func _process(_delta: float) -> void:
	label.text = "%s · %s\n%s  %.0f / %.0f" % [Archetype.keys()[archetype].capitalize(), weakness().capitalize(), State.keys()[state], health, max_health]
	mesh.material_override.albedo_color = Color("74c7ec") if _status_remaining.has("freeze") else (Color("b29ac6") if _status_remaining.has("slow") else Color("ff7a59"))
	if state == State.DEAD:
		collision_layer = 0
		collision_mask = 0
		mesh.rotation.z = PI / 2
		mesh.position.y = 0.4


func weakness() -> String:
	for element in ["earth", "wind", "water", "time"]:
		if not echo_action(element).is_empty():
			return element
	return ""


func set_highlight(value: bool) -> void:
	mesh.material_override.emission_enabled = value
	mesh.material_override.emission = Color("ffd166") * 0.25


func prompt() -> String:
	return "%s required • Left click within 3m to attack" % weakness().capitalize()
