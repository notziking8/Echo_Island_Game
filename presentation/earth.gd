extends "res://integration/earth_adapter.gd"
## Replace only render mesh/caption; receiver and collider are unchanged.
func _refresh() -> void:
	super._refresh()
	caption.hide()
	var size := dimensions()
	if kind == "rock":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1
		visual.mesh = sphere
		visual.scale = size
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1
		cylinder.radial_segments = 32
		visual.mesh = cylinder
		visual.scale = size
