extends Node

const OUTPUT_PATH: String = "user://menu_background_raw.png"
const SETTLE_FRAMES: int = 8
const VIEW_HALF: Vector2 = Vector2(320.0, 240.0)
const GRID: Vector2i = Vector2i(5, 4)
const STROKE_SEGMENTS: int = 3
const SEGMENT_LENGTH: float = 46.0

const MARK_TYPES: Array[int] = [
	EnemyBase.EnemyType.COMMON,
	EnemyBase.EnemyType.FAST,
	EnemyBase.EnemyType.TANK,
	EnemyBase.EnemyType.STALKER,
]

const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(3, 1), Vector2i(0, 2), Vector2i(4, 3),
]

@export var composition_seed: int = 20260910

@export var splat_chance: float = 0.5

@export var mark_radius: float = 15.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var arena: Arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	add_child(arena)
	await get_tree().process_frame

	arena.hud.visible = false
	arena.player.sprite.visible = false
	arena.ability_controller.set_physics_process(false)
	var manager: WaveManager = arena.get_node("WaveManager") as WaveManager
	manager.first_wave_delay = 9000.0

	var origin: Vector2 = arena.player.global_position
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = composition_seed

	_paint_marks(arena, origin, rng)
	_place_enemies(arena, origin, rng)

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var save_error: int = image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_warning("[MenuBackgroundMaker] Falha ao salvar %s (erro %d)." % [OUTPUT_PATH, save_error])
		get_tree().quit(1)
		return

	print("fundo cru: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	get_tree().quit()


func _cell_center(origin: Vector2, column: int, row: int, rng: RandomNumberGenerator) -> Vector2:
	var step: Vector2 = VIEW_HALF * 2.0 / Vector2(GRID)
	var corner: Vector2 = origin - VIEW_HALF
	var jitter: Vector2 = Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * step
	return corner + step * Vector2(column + 0.5, row + 0.5) + jitter


func _paint_marks(arena: Arena, origin: Vector2, rng: RandomNumberGenerator) -> void:
	var index: int = 0
	for row in GRID.y:
		for column in GRID.x:
			var preset: Dictionary = EnemyBase.PRESETS[MARK_TYPES[index % MARK_TYPES.size()]]
			var color: Color = preset["trail_color"]
			var radius: float = mark_radius
			var spot: Vector2 = _cell_center(origin, column, row, rng)

			if rng.randf() < splat_chance:
				_paint_splat(arena, spot, radius, color, rng)
			else:
				_paint_stroke(arena, spot, radius, color, rng)
			index += 1


func _paint_stroke(
	arena: Arena, spot: Vector2, radius: float, color: Color, rng: RandomNumberGenerator
) -> void:
	var heading: float = rng.randf() * TAU
	var point: Vector2 = spot
	for i in STROKE_SEGMENTS:
		heading += rng.randf_range(-0.9, 0.9)
		var next: Vector2 = point + Vector2.from_angle(heading) * SEGMENT_LENGTH
		arena.paint_canvas.paint_line(point, next, radius, color)
		point = next


func _paint_splat(
	arena: Arena, spot: Vector2, radius: float, color: Color, rng: RandomNumberGenerator
) -> void:
	arena.paint_canvas.paint_circle(spot, radius * 2.2, color)
	for i in 3:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) \
			* rng.randf_range(radius * 1.6, radius * 3.2)
		arena.paint_canvas.paint_circle(spot + offset, rng.randf_range(radius * 0.5, radius), color)


func _place_enemies(arena: Arena, origin: Vector2, rng: RandomNumberGenerator) -> void:
	var scene: PackedScene = load("res://scenes/enemies/enemy_base.tscn")
	if scene == null:
		push_warning("[MenuBackgroundMaker] Cena do inimigo ausente; fundo sem sprites.")
		return

	for i in MARK_TYPES.size():
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = MARK_TYPES[i]
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		enemy.position = _cell_center(origin, ENEMY_CELLS[i].x, ENEMY_CELLS[i].y, rng)
		arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
