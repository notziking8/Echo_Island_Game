extends Node3D
## Bounded cosmetic pool. Ability receivers remain the source of success/failure.
const Art = preload("res://presentation/island_art.gd")
var rings: Array[MeshInstance3D] = []
var particles: Array[MeshInstance3D] = []
var ages: Array[float] = []
var cursor := 0

func _ready() -> void:
	for i in 12:
		var ring := Art.ring(self, Vector3.ZERO, 1, Art.GOLD)
		ring.hide()
		rings.append(ring)
		ages.append(0.0)
		for j in 8:
			var particle := Art.orb(ring, Vector3.ZERO, Vector3.ONE * 0.12, Art.GOLD)
			particles.append(particle)

func burst(at: Vector3, element: String, impact: bool = true) -> void:
	var index := cursor
	cursor = (cursor + 1) % rings.size()
	var ring := rings[index]
	ring.global_position = at + Vector3.UP * 0.15
	ring.set_meta("impact", impact)
	ring.material_override = Art.material({"earth": Art.GOLD, "wind": Art.SKY, "water": Color("a4f0ef"), "time": Art.MAGIC}.get(element, Art.CORAL), 0.4)
	ring.show()
	ages[index] = 0.65
	for j in 8:
		particles[index * 8 + j].material_override = ring.material_override

func _process(delta: float) -> void:
	for i in rings.size():
		if ages[i] <= 0:
			continue
		ages[i] -= delta
		var t := 1.0 - ages[i] / 0.65
		var ring := rings[i]
		ring.scale = Vector3.ONE * maxf(0.05, t * (1.5 if ring.get_meta("impact") else 0.6))
		for j in 8:
			var a := j * TAU / 8 + t
			particles[i * 8 + j].position = Vector3(cos(a), sin(t * PI) * 0.5, sin(a))
		if ages[i] <= 0:
			ring.hide()
