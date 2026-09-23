class_name Minimap
extends Control


const PLAYER_COLOR: Color = Color(0.1, 0.1, 0.1, 1.0)
const ENEMY_COLOR: Color = Color(0.8, 0.25, 0.2, 0.9)
const VIEW_COLOR: Color = Color(0.2, 0.2, 0.2, 0.55)
const ITEM_COLOR: Color = Color(0.96, 0.78, 0.18, 1.0)
const ITEM_OUTLINE: Color = Color(0.16, 0.13, 0.04, 1.0)
const ITEM_SIZE: float = 3.0
const ITEM_GROUPS: Array[String] = ["paint_flasks", "palette_coins"]

@export var player_radius: float = 3.0

@export var enemy_radius: float = 2.0

@export var enemy_refresh_interval: float = 0.2

@onready var canvas_view: TextureRect = $CanvasView
@onready var markers: Control = $Markers

var _arena_size: Vector2 = Vector2.ONE
var _player: Player = null
var _enemy_positions: PackedVector2Array = PackedVector2Array()
var _item_positions: PackedVector2Array = PackedVector2Array()
var _refresh_countdown: float = 0.0


func _ready() -> void:
	markers.draw.connect(_on_markers_draw)
	set_process(false)


func setup(arena: Arena) -> void:
	if arena.arena_size.x <= 0.0 or arena.arena_size.y <= 0.0:
		push_warning("[Minimap] Arena sem tamanho válido; minimapa desativado.")
		return
	_arena_size = arena.arena_size
	_player = arena.player
	canvas_view.texture = arena.paint_canvas.get_texture()
	set_process(true)


func _process(delta: float) -> void:
	_refresh_countdown -= delta
	if _refresh_countdown <= 0.0:
		_refresh_countdown = enemy_refresh_interval
		_collect_enemy_positions()
		_collect_item_positions()
	markers.queue_redraw()


func _collect_enemy_positions() -> void:
	_enemy_positions.clear()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null:
			continue
		_enemy_positions.append(enemy.global_position)


func _collect_item_positions() -> void:
	_item_positions.clear()
	for group in ITEM_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var item: Node2D = node as Node2D
			if item == null or item.is_queued_for_deletion():
				continue
			_item_positions.append(item.global_position)


func item_count() -> int:
	return _item_positions.size()


func _draw_item(target: Control, spot: Vector2) -> void:
	var corner: Vector2 = (spot - Vector2.ONE * (ITEM_SIZE * 0.5)).floor()
	target.draw_rect(Rect2(corner - Vector2.ONE, Vector2.ONE * (ITEM_SIZE + 2.0)), ITEM_OUTLINE, true)
	target.draw_rect(Rect2(corner, Vector2.ONE * ITEM_SIZE), ITEM_COLOR, true)


func _to_minimap(world_position: Vector2) -> Vector2:
	return world_position / _arena_size * markers.size


func _view_rect() -> Rect2:
	var view_size: Vector2 = get_viewport_rect().size
	var top_left: Vector2 = _player.global_position - view_size / 2.0
	return Rect2(_to_minimap(top_left), view_size / _arena_size * markers.size)


func _on_markers_draw() -> void:
	for enemy_position in _enemy_positions:
		markers.draw_circle(_to_minimap(enemy_position), enemy_radius, ENEMY_COLOR)
	for item_position in _item_positions:
		_draw_item(markers, _to_minimap(item_position))
	if _player == null or not is_instance_valid(_player):
		return
	markers.draw_rect(_view_rect(), VIEW_COLOR, false, 1.0)
	markers.draw_circle(_to_minimap(_player.global_position), player_radius, PLAYER_COLOR)
