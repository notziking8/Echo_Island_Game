extends Node3D
const Art = preload("res://presentation/island_art.gd")
var element := "kip"
var body: Node3D
var clock := 0.0

func _ready() -> void:
	_rebuild()

func set_element(value: String) -> void:
	if element == value:
		return
	element = value
	if is_inside_tree():
		_rebuild()

func _rebuild() -> void:
	if is_instance_valid(body):
		body.queue_free()
	body = Node3D.new()
	add_child(body)
	var color: Color = {"earth": Art.GRASS, "wind": Art.SKY, "water": Color("80dce5"), "time": Art.GOLD}.get(element, Color("bd9ee3"))
	Art.orb(body, Vector3.ZERO, Vector3(0.6, 0.65, 0.55), color)
	Art.orb(body, Vector3(0, 0.01, -0.26), Vector3(0.3, 0.32, 0.13), Art.MAGIC, 0.6)
	for x in [-0.08, 0.08]:
		Art.orb(body, Vector3(x, 0.06, -0.33), Vector3(0.045, 0.075, 0.025), Color("fff5d9"), 0.4)
	match element:
		"earth":
			for i in 6:
				var a := i * TAU / 6
				Art.orb(body, Vector3(cos(a) * 0.28, sin(a) * 0.25, 0.07), Vector3(0.28, 0.3, 0.25), Color("9c9874"))
			Art.orb(body, Vector3(0, 0.32, 0), Vector3(0.3, 0.12, 0.3), Art.GRASS)
		"wind":
			for side in [-1, 1]:
				for i in 3:
					var wing := Art.orb(body, Vector3(side * (0.3 + i * 0.13), i * 0.09, 0), Vector3(0.35, 0.12, 0.15), Color("d7f3ec"))
					wing.rotation.z = side * 0.3
			for i in 3:
				Art.ring(body, Vector3(0, -0.24 - i * 0.11, 0), 0.2 - i * 0.045, Art.SKY, 0.025)
		"water":
			for i in 5:
				Art.orb(body, Vector3(sin(i * 2) * 0.38, cos(i * 2) * 0.35, 0), Vector3.ONE * 0.15, Art.SKY, 0.2)
			for x in [-0.2, 0.2]:
				Art.rod(body, Vector3(x, 0.15, 0), Vector3(x * 1.4, 0.45, 0), 0.055, Art.CORAL)
		"time":
			var ring := Art.ring(body, Vector3.ZERO, 0.4, Art.GOLD)
			ring.rotation.x = PI / 2
			for i in 8:
				var a := i * TAU / 8
				Art.orb(body, Vector3(cos(a) * 0.4, sin(a) * 0.4, 0), Vector3.ONE * 0.12, Art.GOLD)
		_:
			for i in 4:
				Art.orb(body, Vector3(sin(i) * 0.09, -0.27 - i * 0.09, 0.08), Vector3.ONE * (0.28 - i * 0.05), color)
	body.scale = Vector3.ONE * 0.05
	create_tween().tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	clock += delta
	body.position.y = sin(clock * 2.6) * 0.12
	body.rotation.z = sin(clock * 1.7) * 0.07
