class_name MapOverlay
extends Control

const ACTION: String = "map"
const SCREEN_MARGIN: float = 26.0
const FRAME_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const FRAME_WIDTH: float = 2.0
const BACKDROP_COLOR: Color = Color(0.96, 0.96, 0.93, 1.0)
const PLAYER_COLOR: Color = Color(0.1, 0.1, 0.1, 1.0)
const PLAYER_SIZE: float = 6.0
const ENEMY_COLOR: Color = Color(0.8, 0.25, 0.2, 0.95)
const ENEMY_SIZE: float = 4.0
const ITEM_COLOR: Color = Color(0.96, 0.78, 0.18, 1.0)
const ITEM_OUTLINE: Color = Color(0.16, 0.13, 0.04, 1.0)
const ITEM_SIZE: float = 6.0
const ITEM_GROUPS: Array[String] = ["paint_flasks", "palette_coins"]
const IDLE_ALPHA: float = 0.95
const MOVING_ALPHA: float = 0.35
const FADE_SPEED: float = 8.0
const REFRESH_INTERVAL: float = 0.15

var _canvas_view: TextureRect = null
var _backdrop: ColorRect = null
var _markers: Control = null
var _arena_size: Vector2 = Vector2.ONE
var _player: Player = null
var _enemy_positions: PackedVector2Array = PackedVector2Array()
var _item_positions: PackedVector2Array = PackedVector2Array()
var _refresh_countdown: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = SCREEN_MARGIN
	offset_top = SCREEN_MARGIN
	offset_right = -SCREEN_MARGIN
	offset_bottom = -SCREEN_MARGIN
	visible = false
	modulate = Color(1.0, 1.0, 1.0, IDLE_ALPHA)

	_backdrop = ColorRect.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_canvas_view = TextureRect.new()
	_canvas_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas_view.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas_view)

	_markers = Control.new()
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_markers)
	_markers.draw.connect(_on_markers_draw)


func setup(arena: Arena) -> void:
	if arena.arena_size.x <= 0.0 or arena.arena_size.y <= 0.0:
		push_warning("[MapOverlay] Arena sem tamanho válido; mapa grande desativado.")
		return
	_arena_size = arena.arena_size
	_player = arena.player
	_canvas_view.texture = arena.paint_canvas.get_texture()


func _process(delta: float) -> void:
	var wanted: bool = Input.is_action_pressed(ACTION) and _player != null \
		and is_instance_valid(_player) and not _player.is_dead()
	if wanted != visible:
		visible = wanted
		if wanted:
			_refresh_countdown = 0.0
	if not visible:
		return

	var target: float = MOVING_ALPHA if _player.is_moving() else IDLE_ALPHA
	modulate.a = move_toward(modulate.a, target, FADE_SPEED * delta)

	_refresh_countdown -= delta
	if _refresh_countdown <= 0.0:
		_refresh_countdown = REFRESH_INTERVAL
		_collect_positions()
	_markers.queue_redraw()


func is_open() -> bool:
	return visible


func alpha() -> float:
	return modulate.a


func item_count() -> int:
	return _item_positions.size()


func _collect_positions() -> void:
	_enemy_positions.clear()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null and not enemy.is_queued_for_deletion():
			_enemy_positions.append(enemy.global_position)
	_item_positions.clear()
	for group in ITEM_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var item: Node2D = node as Node2D
			if item != null and not item.is_queued_for_deletion():
				_item_positions.append(item.global_position)


func _to_map(world_position: Vector2) -> Vector2:
	return world_position / _arena_size * _markers.size


func _draw_marker(spot: Vector2, side: float, color: Color, outline: Color) -> void:
	var corner: Vector2 = (spot - Vector2.ONE * (side * 0.5)).floor()
	if outline.a > 0.0:
		_markers.draw_rect(Rect2(corner - Vector2.ONE, Vector2.ONE * (side + 2.0)), outline, true)
	_markers.draw_rect(Rect2(corner, Vector2.ONE * side), color, true)


func _on_markers_draw() -> void:
	_markers.draw_rect(Rect2(Vector2.ZERO, _markers.size), FRAME_COLOR, false, FRAME_WIDTH)
	for enemy_position in _enemy_positions:
		_draw_marker(_to_map(enemy_position), ENEMY_SIZE, ENEMY_COLOR, Color(0, 0, 0, 0))
	for item_position in _item_positions:
		_draw_marker(_to_map(item_position), ITEM_SIZE, ITEM_COLOR, ITEM_OUTLINE)
	if _player != null and is_instance_valid(_player):
		_draw_marker(_to_map(_player.global_position), PLAYER_SIZE, PLAYER_COLOR, Color(0, 0, 0, 0))
