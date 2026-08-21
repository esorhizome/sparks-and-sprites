extends Node2D
## SOUND BLIPS — synthesized from nothing, no audio files anywhere.
## AudioStreamGenerator lets us push raw samples (numbers between -1 and 1
## describing the speaker cone's position) from GDScript.
## C = coin (two rising notes) · L = laser (steep downward slide) · H = hit
## (low, dull, quick). Press the same key repeatedly: the pitch randomization
## ("humanize") means no two plays match. Esc = menu. Chapter 07 in the book.

const MIX_RATE := 44100.0

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var phase := 0.0
## The "score": a list of segments {freq_start, freq_end, dur, vol, left}
## consumed one after another. Empty list = silence.
var segments: Array[Dictionary] = []

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1          # small buffer = responsive blips
	player.stream = gen
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

	var l := Label.new()
	l.text = "Sound blips, synthesized live:\n  [C] coin   [L] laser   [H] hit   —   Esc = menu\nPress a key a few times: pitch randomization means no two plays match.\nRead sound_blips.gd — the whole synth is ~30 lines."
	l.position = Vector2(24, 16)
	add_child(l)

## the one-line trick that makes repeats organic
func humanize(f: float) -> float:
	return f * randf_range(0.92, 1.08)

func coin() -> void:
	var f1 := humanize(988.0)
	var f2 := humanize(1319.0)
	segments = [
		{"f0": f1, "f1": f1, "dur": 0.08, "vol": 0.2, "left": 0.08},
		{"f0": f2, "f1": f2, "dur": 0.18, "vol": 0.2, "left": 0.18},
	]

func laser() -> void:
	var f := humanize(1400.0)
	segments = [{"f0": f, "f1": 120.0, "dur": 0.25, "vol": 0.15, "left": 0.25}]

func hit() -> void:
	var f := humanize(160.0)
	segments = [{"f0": f, "f1": 55.0, "dur": 0.2, "vol": 0.35, "left": 0.2}]

func _process(_delta: float) -> void:
	# keep the generator's buffer topped up with whatever the score says
	var frames: int = playback.get_frames_available()
	for i in frames:
		var v := 0.0
		if not segments.is_empty():
			var seg: Dictionary = segments[0]
			var u: float = 1.0 - seg["left"] / seg["dur"]        # 0→1 through the segment
			var freq: float = lerpf(seg["f0"], seg["f1"], u)     # pitch slide
			var envelope: float = seg["vol"] * (1.0 - u)         # fade out = no click
			phase = fmod(phase + freq / MIX_RATE, 1.0)
			# square wave = chiptune voice (try sin(phase*TAU) for a soft flute)
			v = (1.0 if phase < 0.5 else -1.0) * envelope
			seg["left"] -= 1.0 / MIX_RATE
			if seg["left"] <= 0.0:
				segments.pop_front()
		playback.push_frame(Vector2(v, v))    # left & right speaker, same sample

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_C: coin()
			KEY_L: laser()
			KEY_H: hit()
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/menu.tscn")
