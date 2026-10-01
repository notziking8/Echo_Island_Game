extends Node
## Original synthesized cues; no external audio or unbounded voice allocation.
const RATE := 22050
const NOTES := {"earth": 196.0, "wind": 293.665, "water": 349.228, "time": 440.0, "strike": 130.813}
var voices: Array[AudioStreamPlayer] = []
var cues: Dictionary = {}
var voice_index := 0
var ambience: AudioStreamPlayer
var muted := false

func _ready() -> void:
	for element in NOTES:
		cues[element] = _chime(NOTES[element], 0.55)
		cues[element + "_discovery"] = _chime(NOTES[element], 1.8, true)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -19
		add_child(voice)
		voices.append(voice)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE * 8
	var samples := PackedByteArray()
	samples.resize(RATE * 8 * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 917
	var filtered := 0.0
	for i in RATE * 8:
		var t := i / float(RATE)
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.055)
		var envelope := pow(sin(PI * t / 8), 2)
		var value := filtered * 0.5 * envelope
		samples.encode_s16(i * 2, int(value * 32767))
	stream.data = samples
	ambience = AudioStreamPlayer.new()
	ambience.stream = stream
	ambience.volume_db = -24
	add_child(ambience)
	ambience.play()

func play(element: String, discovery := false) -> void:
	if muted or voices.is_empty():
		return
	var key := element + ("_discovery" if discovery else "")
	if not cues.has(key):
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = cues[key]
	voice.play()

func toggle_mute() -> void:
	muted = not muted
	ambience.stream_paused = muted
	if muted:
		for voice in voices:
			voice.stop()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	cues.clear()

static func _chime(frequency: float, duration: float, discovery := false) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in count:
		var t := i / float(RATE)
		var value := 0.0
		for note in (3 if discovery else 1):
			var age := t - note * 0.16
			if age < 0:
				continue
			var pitch: float = frequency * [1.0, 1.25, 1.5][note]
			var envelope := minf(age / 0.015, 1) * exp(-age * (3.2 if discovery else 7.0)) * minf((duration - t) / 0.08, 1)
			value += (sin(TAU * pitch * age) * 0.7 + sin(TAU * pitch * 2 * age) * 0.15) * envelope * 0.28
		samples.encode_s16(i * 2, clampi(int(value * 32767), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = samples
	return stream
