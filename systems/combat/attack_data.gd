extends RefCounted
## Authoritative seconds, independent of render FPS. Values correspond to 60 Hz frame data.
const LIGHT = [
	{"name": "light_1", "startup": 7.0/60, "active": 4.0/60, "recovery": 13.0/60, "damage": 10.0, "reach": 2.7, "arc": 140.0},
	{"name": "light_2", "startup": 8.0/60, "active": 5.0/60, "recovery": 15.0/60, "damage": 13.0, "reach": 2.9, "arc": 155.0},
	{"name": "light_3", "startup": 12.0/60, "active": 6.0/60, "recovery": 20.0/60, "damage": 18.0, "reach": 3.0, "arc": 170.0}
]
const HEAVY = {"name": "heavy", "startup": 24.0/60, "active": 7.0/60, "recovery": 27.0/60, "damage": 28.0, "reach": 3.1, "arc": 150.0}
const BUFFER_SECONDS = 0.12
const DODGE_SECONDS = 0.42
const DODGE_IFRAME_START = 0.04
const DODGE_IFRAME_END = 0.25
const DODGE_COOLDOWN = 0.65

static func duration(attack: Dictionary) -> float:
	return attack.startup + attack.active + attack.recovery

static func clear_line(actor: Node3D, victim: Node3D) -> bool:
	if not actor.is_inside_tree() or not victim.is_inside_tree():
		return false
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, victim.global_position + Vector3.UP, 1)
	var excluded: Array[RID] = []
	if actor is CollisionObject3D:
		excluded.append(actor.get_rid())
	if victim is CollisionObject3D:
		excluded.append(victim.get_rid())
	ray.exclude = excluded
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
