extends Node

signal audio_settings_changed

const CLICK_SOUND: AudioStream = preload("res://assets/audio/click.wav")
const HIT_SOUND: AudioStream = preload("res://assets/audio/hit.wav")
const ENEMY_DEATH_SOUND: AudioStream = preload("res://assets/audio/enemy_death.wav")
const PLAYER_HURT_SOUND: AudioStream = preload("res://assets/audio/player_hurt.wav")
const WARM_UP_VOLUME_DB: float = -80.0

const POOL_SIZE: int = 12

const AUDIO_SECTION: String = "audio"
const VOLUME_KEY: String = "volume"
const MUTED_KEY: String = "muted"

@export_range(0.0, 1.0, 0.05) var volume: float = 0.5

var muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _driver_warmed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_load_settings()
	_build_player_pool()
	_warm_up_audio_driver()
	_connect_existing_buttons.call_deferred()


func _input(event: InputEvent) -> void:
	if not _driver_warmed and _is_user_gesture(event):
		_driver_warmed = true
		_warm_up_audio_driver()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_muted(not muted)


func _is_user_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false


func _on_node_added(node: Node) -> void:
	var button: Button = node as Button
	if button == null or button.pressed.is_connected(play_click):
		return
	button.pressed.connect(play_click)


func _connect_existing_buttons() -> void:
	_connect_buttons_under(get_tree().root)


func _connect_buttons_under(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_connect_buttons_under(child)


func play_click() -> void:
	_play(CLICK_SOUND)


func play_hit() -> void:
	_play(HIT_SOUND)


func play_enemy_death() -> void:
	_play(ENEMY_DEATH_SOUND)


func play_player_hurt() -> void:
	_play(PLAYER_HURT_SOUND)


func is_audible() -> bool:
	return not muted and volume > 0.0


func set_volume(new_volume: float) -> void:
	var clamped: float = clampf(new_volume, 0.0, 1.0)
	if is_equal_approx(clamped, volume):
		return
	volume = clamped
	audio_settings_changed.emit()


func set_muted(new_muted: bool) -> void:
	if muted == new_muted:
		return
	muted = new_muted
	audio_settings_changed.emit()
	save_settings()


func save_settings() -> bool:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(GameManager.SETTINGS_PATH)
	settings.set_value(AUDIO_SECTION, VOLUME_KEY, volume)
	settings.set_value(AUDIO_SECTION, MUTED_KEY, muted)
	var save_error: int = settings.save(GameManager.SETTINGS_PATH)
	if save_error != OK:
		push_warning("[AudioManager] Não foi possível salvar as opções de som (erro %d)." % save_error)
		return false
	return true


func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(GameManager.SETTINGS_PATH) != OK:
		return
	volume = clampf(settings.get_value(AUDIO_SECTION, VOLUME_KEY, volume), 0.0, 1.0)
	muted = settings.get_value(AUDIO_SECTION, MUTED_KEY, muted)


func _build_player_pool() -> void:
	for i in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func _warm_up_audio_driver() -> void:
	if _players.is_empty():
		push_warning("[AudioManager] Pool de players vazio; aquecimento ignorado.")
		return
	var player: AudioStreamPlayer = _players[0]
	player.stream = CLICK_SOUND
	player.volume_db = WARM_UP_VOLUME_DB
	player.play()


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0]


func _play(stream: AudioStream) -> void:
	if not is_audible() or _players.is_empty():
		return
	var player: AudioStreamPlayer = _free_player()
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	player.play()
