extends Node

const CLICK_SOUND: AudioStream = preload("res://assets/audio/click.wav")
const HIT_SOUND: AudioStream = preload("res://assets/audio/hit.wav")
const ENEMY_DEATH_SOUND: AudioStream = preload("res://assets/audio/enemy_death.wav")
const PLAYER_HURT_SOUND: AudioStream = preload("res://assets/audio/player_hurt.wav")

@export_range(-40.0, 6.0) var master_volume_db: float = -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		(node as Button).pressed.connect(play_click)


func play_click() -> void:
	_play(CLICK_SOUND)


func play_hit() -> void:
	_play(HIT_SOUND)


func play_enemy_death() -> void:
	_play(ENEMY_DEATH_SOUND)


func play_player_hurt() -> void:
	_play(PLAYER_HURT_SOUND)


func _play(stream: AudioStream) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = master_volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
