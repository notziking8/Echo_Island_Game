class_name CollectibleRelic
extends Area3D

signal relic_collected(relic: CollectibleRelic)

@export var relic_name: String = "Sun Crystal"
@export var glow_color: Color = Color("FFD166")

var initial_y: float = 0.0
var time_passed: float = 0.0
var is_collected: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready() -> void:
	add_to_group("collectible_relics")
	initial_y = position.y
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _process(delta: float) -> void:
	if is_collected:
		return
	time_passed += delta
	# Whimsical floating bob and rotation
	position.y = initial_y + sin(time_passed * 2.8) * 0.12
	rotate_y(delta * 2.2)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body is CharacterBody3D or body.name == "Player":
		is_collected = true
		relic_collected.emit(self)
		print("[CollectibleRelic] Collected: %s by %s" % [name, body.name])
		
		# Notify UI manager if present
		var ui = get_tree().get_first_node_in_group("art_test_ui")
		if ui and ui.has_method("on_relic_collected"):
			ui.on_relic_collected(self)
		
		# Animate collect and remove
		var tween = create_tween()
		if tween:
			tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_callback(queue_free)
		else:
			queue_free()

func _update_visuals() -> void:
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = glow_color
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 1.8
		mesh_instance.material_override = mat
	if omni_light:
		omni_light.light_color = glow_color
		omni_light.light_energy = 1.2
		omni_light.omni_range = 3.0
