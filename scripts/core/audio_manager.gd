extends Node

var _cache: Dictionary = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_tween: Tween

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s := load(path)
	_cache[path] = s
	return s

func play_sfx(key: String, pitch_variation := 0.06, volume_db := 0.0) -> void:
	var p := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	var s := _stream("res://assets/audio/%s.wav" % key)
	if s == null:
		return
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()

func play_ui(key := "ui_click") -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "UI"
	p.stream = _stream("res://assets/audio/%s.wav" % key)
	if p.stream == null:
		p.queue_free()
		return
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_music(key := "forest_theme") -> void:
	var s := _stream("res://assets/audio/%s.wav" % key)
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stream = s
	_music.volume_db = -8.0
	_music.play()

func play_ambience(key := "forest_crickets") -> void:
	var s := _stream("res://assets/audio/%s.wav" % key)
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience.stream = s
	_ambience.volume_db = -14.0
	_ambience.play()

func set_music_muffled(muffled: bool) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -18.0 if muffled else -8.0, 0.5)
