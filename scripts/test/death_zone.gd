class_name IslandDeathZone
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("respawn"):
		print("[IslandDeathZone] Player fell off island - triggering respawn() for %s" % body.name)
		body.respawn()
