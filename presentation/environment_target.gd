extends "res://systems/echo/demo/environment_target.gd"
## Existing environment receiver with rounded presentation, without debug text.
func _ready() -> void:
	super._ready()
	var surface := CylinderMesh.new()
	surface.top_radius = 0.5
	surface.bottom_radius = 0.5
	surface.height = 1
	surface.radial_segments = 48
	mesh.mesh = surface
	mesh.scale = dimensions()
	label.hide()

func _refresh() -> void:
	super._refresh()
	label.hide()
