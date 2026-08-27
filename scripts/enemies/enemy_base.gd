class_name EnemyBase
extends CharacterBody2D

signal died(enemy: EnemyBase)

enum EnemyType { COMMON, FAST, TANK }

const PRESETS: Dictionary = {
	EnemyType.COMMON: {
		"max_hp": 30.0,
		"speed": 140.0,
		"contact_damage": 10.0,
		"collision_radius": 18.0,
		"trail_color": Color("b43434", 0.85),
		"trail_radius": 10.0,
		"sheet": "res://assets/sprites/enemies/slime.png",
		"columns": 2, "rows": 3, "frame_count": 6,
		"fps": 8.0,
		"sprite_scale": 0.22,
		"shape": "square", "texture_half_size": 10, "color": Color("d94f4f"),
	},
	EnemyType.FAST: {
		"max_hp": 15.0,
		"speed": 260.0,
		"contact_damage": 5.0,
		"collision_radius": 14.0,
		"trail_color": Color("0b35dc", 0.85),
		"trail_radius": 7.0,
		"sheet": "res://assets/sprites/enemies/bola.png",
		"columns": 4, "rows": 4, "frame_count": 14,
		"fps": 14.0,
		"sprite_scale": 0.25,
		"shape": "circle", "texture_half_size": 8, "color": Color("4fa3d9"),
	},
	EnemyType.TANK: {
		"max_hp": 90.0,
		"speed": 90.0,
		"contact_damage": 15.0,
		"collision_radius": 32.0,
		"trail_color": Color("15b10f", 0.85),
		"trail_radius": 18.0,
		"sheet": "res://assets/sprites/enemies/quadrado.png",
		"columns": 5, "rows": 5, "frame_count": 23,
		"fps": 16.0,
		"sprite_scale": 0.30,
		"shape": "square", "texture_half_size": 16, "color": Color("8a4fd9"),
	},
}

const SHEET_CELL_SIZE: int = 256

const PAINT_SPACING: float = 6.0

const DEATH_ANIM_DURATION: float = 0.15

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")

static var _frames_cache: Dictionary = {}

@export var enemy_type: EnemyType = EnemyType.COMMON

@export var chase_acceleration: float = 1200.0

@export var contact_damage_interval: float = 1.0

var max_hp: float = 30.0
var current_hp: float = 30.0
var speed: float = 140.0
var contact_damage: float = 10.0
var trail_color: Color = Color.RED
var trail_radius: float = 5.0

var _damage_timer: float = 0.0
var _is_dying: bool = false
var _player: Player = null
var _paint_canvas: PaintCanvas = null
var _last_paint_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	_apply_preset()
	_last_paint_position = global_position


func _apply_preset() -> void:
	var preset: Dictionary = PRESETS[enemy_type]

	max_hp = preset["max_hp"]
	current_hp = max_hp
	contact_damage = preset["contact_damage"]
	trail_color = preset["trail_color"]
	trail_radius = preset["trail_radius"]

	speed = preset["speed"] * randf_range(0.9, 1.1)

	_apply_visual(preset)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = preset["collision_radius"]
	collision_shape.shape = shape


func _apply_visual(preset: Dictionary) -> void:
	var frames: SpriteFrames = _get_sprite_frames(enemy_type, preset)
	if frames != null:
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * preset["sprite_scale"]
		sprite.speed_scale = speed / preset["speed"]
		sprite.play("walk")
	else:
		push_warning("[EnemyBase] Sprite sheet ausente (%s); usando visual procedural." % preset["sheet"])
		var fallback: SpriteFrames = SpriteFrames.new()
		fallback.add_frame("default", _build_texture(
			preset["shape"], preset["texture_half_size"], preset["color"]
		))
		sprite.sprite_frames = fallback
		sprite.scale = Vector2(2, 2)
		sprite.play("default")


static func _get_sprite_frames(type: EnemyType, preset: Dictionary) -> SpriteFrames:
	if _frames_cache.has(type):
		return _frames_cache[type]

	var sheet_path: String = preset["sheet"]
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path)
	if sheet == null:
		return null

	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", preset["fps"])
	frames.set_animation_loop("walk", true)

	var columns: int = preset["columns"]
	var frame_count: int = preset["frame_count"]
	for index in frame_count:
		var column: int = index % columns
		var row: int = int(index / float(columns))
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			column * SHEET_CELL_SIZE, row * SHEET_CELL_SIZE,
			SHEET_CELL_SIZE, SHEET_CELL_SIZE
		)
		frames.add_frame("walk", atlas)

	_frames_cache[type] = frames
	return frames


func _physics_process(delta: float) -> void:
	_damage_timer = maxf(_damage_timer - delta, 0.0)

	var player: Player = _get_player()
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, chase_acceleration * delta)
		move_and_slide()
		return

	var direction: Vector2 = (player.global_position - global_position).normalized()
	velocity = velocity.move_toward(direction * speed, chase_acceleration * delta)
	move_and_slide()

	_update_facing()
	_check_contact_damage()
	_paint_trail()


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func _update_facing() -> void:
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false


func _check_contact_damage() -> void:
	if _damage_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider is Player:
			collider.take_damage(contact_damage)
			collider.apply_knockback(global_position)
			_damage_timer = contact_damage_interval
			return


func _get_paint_canvas() -> PaintCanvas:
	if _paint_canvas == null or not is_instance_valid(_paint_canvas):
		_paint_canvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	return _paint_canvas


func _paint_trail() -> void:
	var canvas: PaintCanvas = _get_paint_canvas()
	if canvas == null:
		return
	if global_position.distance_to(_last_paint_position) < PAINT_SPACING:
		return
	canvas.paint_line(_last_paint_position, global_position, trail_radius, trail_color)
	_last_paint_position = global_position


func _splat_on_death() -> void:
	var canvas: PaintCanvas = _get_paint_canvas()
	if canvas == null:
		return
	canvas.paint_circle(global_position, trail_radius * 2.4, trail_color)
	for i in 4:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) \
			* randf_range(trail_radius * 1.5, trail_radius * 3.5)
		canvas.paint_circle(
			global_position + offset,
			randf_range(trail_radius * 0.4, trail_radius * 0.9),
			trail_color
		)


func apply_wave_scaling(hp_multiplier: float) -> void:
	max_hp *= hp_multiplier
	current_hp = max_hp


func take_damage(amount: float) -> void:
	if _is_dying:
		return
	current_hp -= amount
	_flash_damage()
	_spawn_damage_number(amount)
	AudioManager.play_hit()
	if current_hp <= 0.0:
		_die()


func _flash_damage() -> void:
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _spawn_damage_number(amount: float) -> void:
	var container: Node = get_tree().get_first_node_in_group("effects_container")
	if container == null:
		return
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	container.add_child(number)
	number.global_position = global_position + Vector2(randf_range(-6.0, 6.0), -12.0)
	number.setup(amount)


func _die() -> void:
	_is_dying = true
	_splat_on_death()
	AudioManager.play_enemy_death()
	died.emit(self)

	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 0.2, DEATH_ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_ANIM_DURATION)
	await tween.finished
	queue_free()


func _build_texture(shape: String, half_size: int, color: Color) -> ImageTexture:
	var texture_size: int = half_size * 2
	var image: Image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var border_color: Color = color.darkened(0.45)

	if shape == "circle":
		var center: Vector2 = Vector2(half_size - 0.5, half_size - 0.5)
		for y in texture_size:
			for x in texture_size:
				var distance: float = Vector2(x, y).distance_to(center)
				if distance <= half_size - 0.5:
					var pixel: Color = border_color if distance > half_size - 2.5 else color
					image.set_pixel(x, y, pixel)
	else:
		for y in texture_size:
			for x in texture_size:
				var on_border: bool = x < 2 or y < 2 or x >= texture_size - 2 or y >= texture_size - 2
				image.set_pixel(x, y, border_color if on_border else color)

	return ImageTexture.create_from_image(image)
