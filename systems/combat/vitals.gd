extends Node
signal changed
signal damaged(amount: float, source: Object)
signal defeated
@export var max_health := 100.0
var health := 100.0
var shield := 0.0
var shield_remaining := 0.0
var recovery_remaining := 0.0
var invulnerable := false
var dead: bool:
	get: return health <= 0.0

func reset() -> void:
	health = max_health
	shield = 0
	shield_remaining = 0
	recovery_remaining = 0
	invulnerable = false
	changed.emit()

func tick(delta: float) -> void:
	recovery_remaining = maxf(0, recovery_remaining - delta)
	if shield_remaining > 0:
		shield_remaining = maxf(0, shield_remaining - delta)
		if shield_remaining == 0:
			shield = 0
			changed.emit()

func grant_shield(amount: float, seconds: float) -> void:
	if dead or not is_finite(amount) or not is_finite(seconds) or amount <= 0 or seconds <= 0:
		return
	shield = maxf(shield, minf(amount, max_health))
	shield_remaining = maxf(shield_remaining, seconds)
	changed.emit()

func receive_damage(amount: float, source: Object = null) -> Dictionary:
	if not is_finite(amount) or amount <= 0 or dead:
		return {"success": false, "outcome": "invalid_or_dead", "damage": 0.0}
	if invulnerable or recovery_remaining > 0:
		return {"success": false, "outcome": "evaded", "damage": 0.0}
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var applied := minf(health, amount - absorbed)
	health -= applied
	recovery_remaining = 0.55
	changed.emit()
	damaged.emit(applied, source)
	if dead:
		defeated.emit()
	return {"success": true, "outcome": "shielded" if applied == 0 else "damaged", "damage": applied, "absorbed": absorbed}
