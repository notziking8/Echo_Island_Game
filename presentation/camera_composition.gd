extends Node
## Visibility only. Never moves the camera/player or touches a physics object.
var actor: Node3D
var camera: Camera3D
var decorations: Array[MeshInstance3D] = []
var bounds: Array[AABB] = []
var hidden_count := 0

func configure(stage: Node, player: Node3D, view: Camera3D) -> void:
	actor = player
	camera = view
	for node in stage.find_children("*", "MeshInstance3D", true, false):
		if not node.get_meta("camera_decoration", false):
			continue
		var box: AABB = node.global_transform * node.get_aabb()
		if box.size.y < 0.45:
			continue
		decorations.append(node)
		# Conservative envelope includes leaf sway and the whole Lilo silhouette.
		bounds.append(box.grow(1.05))
	process_priority = 100
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(camera):
		return
	var focus := actor.global_position + Vector3.UP * 0.85
	var eye := camera.global_position
	hidden_count = 0
	for i in decorations.size():
		# Conservative whole-mesh culling avoids transparent sorting, screen-door
		# noise, and fragment overdraw on Web. Ground/targets/actors are never tagged.
		var blocked: bool = bounds[i].has_point(eye) or bounds[i].intersects_segment(eye, focus) != null
		decorations[i].visible = not blocked
		if blocked:
			hidden_count += 1

func remaining_obstructions() -> int:
	var count := 0
	for i in decorations.size():
		if decorations[i].visible and bounds[i].intersects_segment(camera.global_position, actor.global_position + Vector3.UP * 0.85) != null:
			count += 1
	return count
