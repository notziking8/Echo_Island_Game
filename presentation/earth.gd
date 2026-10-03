extends "res://integration/earth_adapter.gd"
## Replace only render mesh/caption; receiver and collider are unchanged.
func _refresh() -> void:
	super._refresh()
	caption.hide()
	var size := dimensions()
	if kind == "rock":
		var wall := BoxMesh.new()
		wall.size = size
		visual.mesh = wall
		visual.scale = Vector3.ONE
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1
		cylinder.radial_segments = 32
		visual.mesh = cylinder
		visual.scale = size
