extends Node

signal music_settings_changed

const MENU_TRACK: String = "menu"
const ARENA_TRACK: String = "arena"
const BOSS_TRACK: String = "boss"
const TRACK_DIR: String = "res://assets/audio/music"
const TRACK_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const FADE_TIME: float = 1.2
const AUDIO_SECTION: String = "audio"
const MUSIC_VOLUME_KEY: String = "music_volume"
const SILENT_DB: float = -60.0
const TRIM_DB: float = -9.0

@export_range(0.0, 1.0, 0.05) var volume: float = 0.6

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: String = ""
var _tracks: Dictionary = {}
var _fades: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_load_tracks()
	AudioManager.audio_settings_changed.connect(_apply_volume)
	for index in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func has_track(track: String) -> bool:
	return _tracks.has(track)


func current_track() -> String:
	return _current


func track_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for track in _tracks:
		names.append(track)
	return names


func play(track: String) -> bool:
	if track == _current and _players[_active].playing:
		return true
	if not _tracks.has(track):
		_current = track
		_fade_out_all()
		return false
	_current = track
	if _target_db() <= SILENT_DB:
		_silence()
		return true
	var next: int = 1 - _active
	_players[next].stream = _tracks[track]
	_players[next].volume_db = SILENT_DB
	_players[next].play()
	_fade(next, _target_db())
	_fade(_active, SILENT_DB)
	_active = next
	return true


func play_menu() -> bool:
	return play(MENU_TRACK)


func play_arena() -> bool:
	return play(ARENA_TRACK)


func play_boss() -> bool:
	return play(BOSS_TRACK)


func stop() -> void:
	_current = ""
	_fade_out_all()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_settings()
	music_settings_changed.emit()


func is_playing() -> bool:
	return _players[_active].playing and _players[_active].volume_db > SILENT_DB


func _target_db() -> float:
	if volume <= 0.0 or AudioManager.muted:
		return SILENT_DB
	return linear_to_db(volume) + TRIM_DB


func _apply_volume() -> void:
	if _players.is_empty():
		return
	if _target_db() <= SILENT_DB:
		_silence()
		return
	if not _players[_active].playing:
		if _tracks.has(_current):
			play(_current)
		return
	if _fades[_active] != null and _fades[_active].is_valid():
		_fades[_active].kill()
	_players[_active].volume_db = _target_db()


func _silence() -> void:
	for index in _players.size():
		if _fades[index] != null and _fades[index].is_valid():
			_fades[index].kill()
		_players[index].volume_db = SILENT_DB
		_players[index].stop()


func _fade(index: int, target_db: float) -> void:
	if _fades[index] != null and _fades[index].is_valid():
		_fades[index].kill()
	var tween: Tween = create_tween()
	tween.tween_property(_players[index], "volume_db", target_db, FADE_TIME)
	if target_db <= SILENT_DB:
		tween.tween_callback(_players[index].stop)
	_fades[index] = tween


func _fade_out_all() -> void:
	for index in _players.size():
		if _players[index].playing:
			_fade(index, SILENT_DB)


func _load_tracks() -> void:
	for track in [MENU_TRACK, ARENA_TRACK, BOSS_TRACK]:
		for extension in TRACK_EXTENSIONS:
			var path: String = "%s/%s.%s" % [TRACK_DIR, track, extension]
			if not ResourceLoader.exists(path):
				continue
			var stream: AudioStream = load(path) as AudioStream
			if stream == null:
				push_warning("[MusicManager] %s existe mas não carregou como áudio." % path)
				continue
			_loop(stream)
			_tracks[track] = stream
			break


func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(GameManager.SETTINGS_PATH) != OK:
		return
	volume = clampf(float(settings.get_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, volume)), 0.0, 1.0)


func _save_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(GameManager.SETTINGS_PATH)
	settings.set_value(AUDIO_SECTION, MUSIC_VOLUME_KEY, volume)
	var save_error: int = settings.save(GameManager.SETTINGS_PATH)
	if save_error != OK:
		push_warning("[MusicManager] Não foi possível salvar o volume da música (erro %d)." % save_error)
