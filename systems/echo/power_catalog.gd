extends RefCounted
## Proposed seam defaults. Durations are seconds; strength is units/second for movement.

const SETTINGS := {
	"stun": {"duration_seconds": 2.5, "strength": 0.0},
	"push": {"duration_seconds": 0.5, "strength": 9.0},
	"freeze": {"duration_seconds": 4.0, "strength": 0.0},
	"slow": {"duration_seconds": 6.0, "strength": 0.25},
	"glide": {"duration_seconds": 8.0, "strength": 1.5},
	"air_dash": {"duration_seconds": 0.25, "strength": 16.0},
	"wind_current": {"duration_seconds": 0.0, "strength": 8.0},
	"underwater_access": {"duration_seconds": 15.0, "strength": 4.0},
	"freeze_object": {"duration_seconds": 6.0, "strength": 0.0},
	"reset_object": {"duration_seconds": 0.0, "strength": 0.0},
	"freeze_water": {"duration_seconds": 0.0, "strength": 0.0},
	"redirect_current": {"duration_seconds": 0.0, "strength": 3.0},
}


static func parameters(action: String) -> Dictionary:
	return SETTINGS.get(action, {"duration_seconds": 0.0, "strength": 0.0}).duplicate()
