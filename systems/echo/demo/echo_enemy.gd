extends CharacterBody3D
## Small reference Combat receiver with real movement/status reactions, no game combat ownership.

var target_id: String = "training_guardian"
var channel: String = "combat"
var effects: Dictionary = {}
var impulse := Vector3.ZERO
var home: Vector3
var label: Label3D
var shell: MeshInstance3D
var _phase: float = 0.0


func _ready() -> void:
	home = position
	collision_layer = 1
	collision_mask = 3
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff7a59")
	body.material_override = material
	add_child(body)
	shell = MeshInstance3D.new()
	shell.mesh = mesh
	shell.position = body.position
	shell.scale = Vector3.ONE * 1.12
	var ice := StandardMaterial3D.new()
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.albedo_color = Color(0.45, 0.9, 1, 0.45)
	shell.material_override = ice
	add_child(shell)
	shell.visible = false
	label = Label3D.new()
	label.position.y = 2.3
	label.font_size = 42
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func echo_action(element: String, _held: bool) -> String:
	return str({"earth": "stun", "wind": "push", "water": "freeze", "time": "slow"}.get(element, ""))


func prompt() -> String:
	return "Earth stuns • Wind pushes • Water freezes • Time slows"


func set_highlight(_value: bool) -> void:
	pass


func apply_event(event: Dictionary) -> bool:
	var action: String = event["intended_effect"]
	if action != echo_action(event["echo_id"], false):
		return false
	effects[action] = clampf(float(event.get("duration_seconds", 2)), 0.1, 30)
	if action == "push":
		var direction: Vector3 = global_position - event.get("origin", Vector3.ZERO)
		direction.y = 0
		if direction.length() < 0.1:
			direction = Vector3.BACK
		impulse = direction.normalized() * clampf(float(event.get("strength", 9)), 0, 20)
	return true


func movement_multiplier() -> float:
	if effects.has("freeze") or effects.has("stun"):
		return 0.0
	return 0.25 if effects.has("slow") else 1.0


func _physics_process(delta: float) -> void:
	for effect: String in effects.keys():
		effects[effect] -= delta
		if effects[effect] <= 0:
			effects.erase(effect)
	var multiplier := movement_multiplier()
	_phase += delta * multiplier
	var destination := home + Vector3(sin(_phase) * 1.8, 0, 0)
	var direction := destination - position
	direction.y = 0
	var movement := direction.normalized() * minf(direction.length(), 1.3) * multiplier
	velocity.x = movement.x + impulse.x
	velocity.z = movement.z + impulse.z
	velocity.y -= 18 * delta
	impulse = impulse.move_toward(Vector3.ZERO, delta * 18)
	move_and_slide()
	if position.y < -4 or absf(position.x) > 13 or absf(position.z) > 10:
		position = home
		velocity = Vector3.ZERO
	shell.visible = effects.has("freeze")
	label.text = "TRAINING GUARDIAN"
	for effect: String in effects:
		label.text += "\n%s %.1fs" % [effect.to_upper(), effects[effect]]
