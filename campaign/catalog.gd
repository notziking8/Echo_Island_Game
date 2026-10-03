extends RefCounted
## Scene progression data, not an alternative Echo progression implementation.
const STAGES = [
	{"name": "Arrival", "generation": 1, "stone": "", "tasks": [], "enemy": 0, "text": "Follow the sun-stone path. Defeat the shore crab with your normal attack.", "memory": "Every journey begins with a small, brave step."},
	{"name": "Earth Ruins", "generation": 1, "stone": "earth", "tasks": ["crack"], "enemy": 0, "text": "Defeat the guard and collect Earth. The Earth wall blocks the only route. Press E twice to break it.", "memory": "The first keeper becomes the Earth ancestor. Their strength lives on."},
	{"name": "Overgrown Path", "generation": 2, "stone": "", "tasks": ["crack", "stun"], "enemy": 2, "text": "Select Earth with Tab. Q breaks the wall and staggers the armored guard. Normal attacks finish the fight.", "memory": "The next keeper walks beside the strength of those before them."},
	{"name": "Wind Cliffs", "generation": 2, "stone": "wind", "tasks": ["raise_platform", "air_dash"], "enemy": 3, "text": "Q raises the Earth bridge to reach Wind. Then use E at the far gap to dash across.", "memory": "The second keeper becomes Wind. Two ancestors now answer the call."},
	{"name": "Flooded Trail", "generation": 3, "stone": "", "tasks": ["crack", "air_dash"], "enemy": 3, "text": "Break the Earth wall with Q, then use Wind dash across the gap. Defeat the guard with normal attacks or Wind.", "memory": "Strength and freedom are better together."},
	{"name": "Water Ruins", "generation": 3, "stone": "water", "tasks": ["crack", "air_dash", "freeze_water"], "enemy": 0, "text": "Break the wall, then Wind-dash to the coral stone. Collect Water and press E at the far pool to make a bridge.", "memory": "The third keeper becomes Water. The island remembers every kindness."},
	{"name": "Forbidden Interior", "generation": 4, "stone": "", "tasks": ["crack", "wind_current", "freeze_water"], "enemy": 2, "text": "Break the Earth wall, activate the Wind updraft, then freeze the Water crossing. Each opens the only route forward.", "memory": "Something beneath the island has been waiting, outside of time."},
	{"name": "Time Temple", "generation": 4, "stone": "time", "tasks": ["crack", "wind_current", "freeze_water", "freeze_object"], "enemy": 1, "text": "Earth, Wind and Water open the route to Time. Collect its stone, then press E to freeze the moving gate.", "memory": "Time is not an enemy to conquer. It is a gift to pass on."},
	{"name": "Island Core", "generation": 4, "stone": "", "tasks": ["raise_platform", "wind_current", "freeze_water", "freeze_object", "stun"], "enemy": 4, "text": "Raise the Earth bridge, ride the Wind updraft, freeze the Water crossing, and open the Time gate. Earth exposes the Sentinel; normal attacks can finish it.", "memory": "The island was never powered by stones alone. It was kept alive by generations caring for one another. Your story becomes their next Echo."}
]
const PATHS = ["01_arrival", "02_earth_ruins", "03_overgrown_path", "04_wind_cliffs", "05_flooded_trail", "06_water_ruins", "07_forbidden_interior", "08_time_temple", "09_island_core"]

static func scene_path(index: int) -> String:
	return "res://campaign/scenes/" + PATHS[index] + ".tscn"
