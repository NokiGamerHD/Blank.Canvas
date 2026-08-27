class_name Arena
extends Node2D

@export var arena_size: Vector2 = Vector2(4096, 4096)

@export var wall_thickness: float = 64.0

@export var camera_margin: float = 160.0

@export var per_wave_heal_fraction: float = 0.20

@export var outside_color: Color = Color(0.82, 0.82, 0.8, 1)

@onready var boundaries: StaticBody2D = $Boundaries
@onready var board_canvas: BoardCanvas = $BoardCanvas
@onready var paint_canvas: PaintCanvas = $PaintCanvas
@onready var enemies_container: Node2D = $Enemies
@onready var player: Player = $Player
@onready var projectiles_container: Node2D = $Projectiles
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: CanvasLayer = $HUD
@onready var progression_screen: CanvasLayer = $ProgressionScreen
@onready var in_run_creator_layer: CanvasLayer = $InRunAbilityCreator
@onready var in_run_creator: DrawingCreatorBase = $InRunAbilityCreator/AbilityCreator
@onready var ability_controller: AbilityController = $Player/AbilityController
@onready var pause_screen: CanvasLayer = $PauseScreen


func _ready() -> void:
	RenderingServer.set_default_clear_color(outside_color)
	_build_boundaries()
	board_canvas.setup(arena_size)
	paint_canvas.setup(arena_size)
	_setup_player()
	_setup_hud()
	_setup_progression()
	_setup_pause()
	player.died.connect(_on_player_died_capture_canvas)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_screen.open()


func _build_boundaries() -> void:
	var span_x: float = arena_size.x + wall_thickness * 2.0
	var span_y: float = arena_size.y + wall_thickness * 2.0

	_add_wall(Vector2(arena_size.x / 2.0, -wall_thickness / 2.0), Vector2(span_x, wall_thickness))
	_add_wall(Vector2(arena_size.x / 2.0, arena_size.y + wall_thickness / 2.0), Vector2(span_x, wall_thickness))
	_add_wall(Vector2(-wall_thickness / 2.0, arena_size.y / 2.0), Vector2(wall_thickness, span_y))
	_add_wall(Vector2(arena_size.x + wall_thickness / 2.0, arena_size.y / 2.0), Vector2(wall_thickness, span_y))


func _add_wall(wall_position: Vector2, wall_size: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = wall_size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = wall_position
	boundaries.add_child(collision)


func _setup_player() -> void:
	player.position = arena_size / 2.0
	player.set_camera_limits(Rect2(
		Vector2(-camera_margin, -camera_margin),
		arena_size + Vector2(camera_margin, camera_margin) * 2.0
	))


func _setup_hud() -> void:
	player.health_changed.connect(hud.update_hp)
	hud.update_hp(player.current_hp, player.max_hp)
	wave_manager.wave_changed.connect(hud.update_wave)
	hud.setup_abilities(ability_controller)


func _setup_progression() -> void:
	wave_manager.progression_due.connect(_on_progression_due)
	wave_manager.wave_completed.connect(_on_wave_completed)
	progression_screen.upgrade_chosen.connect(_on_progression_upgrade_chosen)
	progression_screen.new_ability_chosen.connect(_on_progression_new_ability_chosen)
	in_run_creator.in_run_ability_created.connect(_on_in_run_ability_created)
	in_run_creator.in_run_cancelled.connect(_on_in_run_ability_cancelled)


func _on_wave_completed(_wave: int) -> void:
	player.heal_fraction(per_wave_heal_fraction)


func _on_progression_due(wave: int) -> void:
	player.heal_to_full()
	progression_screen.open(wave, ability_controller.get_abilities())


func _on_progression_upgrade_chosen() -> void:
	progression_screen.close()
	wave_manager.resume_after_progression()


func _on_progression_new_ability_chosen() -> void:
	progression_screen.visible = false
	in_run_creator.open_for_new_ability(_next_free_ability_index())
	in_run_creator_layer.visible = true


func _on_in_run_ability_created(index: int) -> void:
	ability_controller.add_ability(index)
	in_run_creator_layer.visible = false
	progression_screen.close()
	wave_manager.resume_after_progression()


func _on_in_run_ability_cancelled() -> void:
	in_run_creator_layer.visible = false
	progression_screen.visible = true


func _next_free_ability_index() -> int:
	var index: int = 0
	while GameManager.has_ability_drawing(index):
		index += 1
	return index


func _setup_pause() -> void:
	pause_screen.menu_requested.connect(GameManager.go_to_main_menu)


func _on_player_died_capture_canvas() -> void:
	GameManager.set_last_canvas_snapshot(paint_canvas.get_image_copy())
