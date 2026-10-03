extends RefCounted
## Scene progression data, not an alternative Echo progression implementation.
const STAGES = [
	{"name": "Arrival", "generation": 1, "stone": "", "tasks": [], "enemy": 0, "text": "Follow the sun-stone path. Defeat the shore crab with close strikes.", "memory": "Every journey begins with a small, brave step."},
	{"name": "Earth Ruins", "generation": 1, "stone": "earth", "tasks": ["crack"], "enemy": 0, "text": "Defeat the guard. Approach the green stone and press F. Aim at the boulder and tap E twice.", "memory": "The first keeper becomes the Earth ancestor. Their strength lives on."},
	{"name": "Overgrown Path", "generation": 2, "stone": "", "tasks": ["crack", "stun"], "enemy": 2, "text": "Hold Tab to summon Earth. Q cracks rock and staggers the armored crab.", "memory": "The next keeper walks beside the strength of those before them."},
	{"name": "Wind Cliffs", "generation": 2, "stone": "wind", "tasks": ["raise_platform", "air_dash"], "enemy": 3, "text": "Raise the Earth platform with Q. Reach the blue stone. Step on the launch pad & hold W to mantle the cliff. E dashes across the gap; hold E to glide.", "memory": "The second keeper becomes Wind. Two ancestors now answer the call."},
	{"name": "Flooded Trail", "generation": 3, "stone": "", "tasks": ["crack", "air_dash"], "enemy": 3, "text": "Switch between Earth and Wind with Tab. Clear the boulder, then dash or glide across the channel.", "memory": "Strength and freedom are better together."},
	{"name": "Water Ruins", "generation": 3, "stone": "water", "tasks": ["crack", "air_dash", "freeze_water"], "enemy": 0, "text": "Use Earth and Wind to reach the coral stone. Freeze the pool with E from its bank.", "memory": "The third keeper becomes Water. The island remembers every kindness."},
	{"name": "Forbidden Interior", "generation": 4, "stone": "", "tasks": ["crack", "wind_current", "freeze_water"], "enemy": 2, "text": "Three ancestors: clear stone, awaken the updraft, and freeze the channel. Ride the moving platform across. Follow the golden clock fragments.", "memory": "Something beneath the island has been waiting, outside of time."},
	{"name": "Time Temple", "generation": 4, "stone": "time", "tasks": ["crack", "wind_current", "freeze_water", "freeze_object"], "enemy": 1, "text": "Earth, Wind and Water open the way. Find the golden stone; use E to stop the moving relic.", "memory": "Time is not an enemy to conquer. It is a gift to pass on."},
	{"name": "Island Core", "generation": 4, "stone": "", "tasks": ["raise_platform", "wind_current", "freeze_water", "freeze_object", "stun"], "enemy": 4, "text": "Bring the four powers together. Earth exposes the Sentinel's core. Defeat it, then approach the final arch.", "memory": "The island was never powered by stones alone. It was kept alive by generations caring for one another. Your story becomes their next Echo."}
]
const PATHS = ["01_arrival", "02_earth_ruins", "03_overgrown_path", "04_wind_cliffs", "05_flooded_trail", "06_water_ruins", "07_forbidden_interior", "08_time_temple", "09_island_core"]

static func scene_path(index: int) -> String:
	return "res://campaign/scenes/" + PATHS[index] + ".tscn"
