class_name AudioManager
extends Node

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var music_started := false

const SFX := {
	"swing": "res://assets/audio/swing.wav",
	"dash": "res://assets/audio/dash.wav",
	"hit": "res://assets/audio/hit.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"eat": "res://assets/audio/eat.wav",
	"heal": "res://assets/audio/heal.wav",
	"coin": "res://assets/audio/coin.wav",
	"chest": "res://assets/audio/chest.wav",
	"enemy_windup": "res://assets/audio/enemy_windup.wav",
	"enemy_swing": "res://assets/audio/enemy_swing.wav",
	"enemy_die": "res://assets/audio/enemy_die.wav",
	"die": "res://assets/audio/die.wav",
	"ignite": "res://assets/audio/ignite.wav",
	"slam": "res://assets/audio/slam.wav",
	"campfire": "res://assets/audio/campfire.wav",
	"deny": "res://assets/audio/deny.wav",
	"victory": "res://assets/audio/victory.wav",
	"ui_click": "res://assets/audio/ui_click.wav",
	"pickup": "res://assets/audio/pickup.wav",
	"map": "res://assets/audio/map.wav",
}

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = "Music"
	music_player.volume_db = -12.0
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "OceanAmbience"
	ambience_player.bus = "Ambience"
	ambience_player.volume_db = -1.0
	add_child(ambience_player)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = -2.0
		add_child(p)
		sfx_players.append(p)
	for key in SFX:
		if ResourceLoader.exists(SFX[key]):
			streams[key] = load(SFX[key])
	_start_ambience()

func _setup_loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream

func start_music() -> void:
	if music_started:
		return
	music_started = true
	var path := "res://assets/audio/island_theme.wav"
	if ResourceLoader.exists(path):
		music_player.stream = _setup_loop(load(path))
		music_player.volume_db = -22.0
		music_player.play()
		var tw := create_tween()
		tw.tween_property(music_player, "volume_db", -8.5, 2.5)

func _start_ambience() -> void:
	var path := "res://assets/audio/ocean_ambience.wav"
	if ResourceLoader.exists(path):
		ambience_player.stream = _setup_loop(load(path))
		ambience_player.volume_db = -18.0
		ambience_player.play()
		var tw := create_tween()
		tw.tween_property(ambience_player, "volume_db", -5.0, 2.0)

func play_sfx(key: String, pitch_variation := 0.08) -> void:
	if not streams.has(key):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = streams[key]
			p.pitch_scale = clampf(1.0 + randf_range(-pitch_variation, pitch_variation), 0.6, 1.6)
			p.play()
			return
	var p := sfx_players[0]
	p.stream = streams[key]
	p.pitch_scale = 1.0
	p.play()

func set_music_muffled(muffled: bool) -> void:
	if music_player:
		music_player.volume_db = -20.0 if muffled else -8.5
