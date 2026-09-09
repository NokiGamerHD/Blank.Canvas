class_name EnemyBase
extends CharacterBody2D

signal died(enemy: EnemyBase)

enum EnemyType { COMMON, FAST, TANK, STALKER }

enum Behavior { CHASE, ZIGZAG, ORBIT }

enum DashPhase { READY, WINDUP, DASHING, RECOVER }

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
		"behavior": Behavior.ZIGZAG,
		"dash_speed": 620.0, "dash_windup": 0.32, "dash_duration": 0.20,
		"dash_recover": 0.35, "dash_cooldown": 3.2, "dash_range": 320.0,
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
		"behavior": Behavior.CHASE,
	},
	EnemyType.TANK: {
		"max_hp": 60.0,
		"speed": 90.0,
		"contact_damage": 25.0,
		"collision_radius": 32.0,
		"trail_color": Color("15b10f", 0.85),
		"trail_radius": 18.0,
		"sheet": "res://assets/sprites/enemies/quadrado.png",
		"columns": 5, "rows": 5, "frame_count": 23,
		"fps": 16.0,
		"sprite_scale": 0.30,
		"shape": "square", "texture_half_size": 16, "color": Color("8a4fd9"),
		"behavior": Behavior.CHASE,
	},
	EnemyType.STALKER: {
		"max_hp": 12.0,
		"speed": 320.0,
		"contact_damage": 15.0,
		"collision_radius": 11.0,
		"trail_color": Color("e0b400", 0.85),
		"trail_radius": 5.0,
		"sheet": "res://assets/sprites/enemies/bola_amarela.png",
		"columns": 4, "rows": 4, "frame_count": 14,
		"fps": 16.0,
		"sprite_scale": 0.18,
		"shape": "circle", "texture_half_size": 6, "color": Color("f2d541"),
		"behavior": Behavior.ORBIT,
		"dash_speed": 820.0, "dash_windup": 0.26, "dash_duration": 0.24,
		"dash_recover": 0.30, "dash_cooldown": 2.4, "dash_range": 420.0,
	},
}

const SHEET_CELL_SIZE: int = 256

const PAINT_SPACING: float = 6.0

const DEATH_ANIM_DURATION: float = 0.15

const DASH_ALPHA: float = 0.6
const DASH_BRAKE: float = 2400.0
const GHOST_INTERVAL: float = 0.035
const GHOST_FADE: float = 0.22
const GHOST_ALPHA: float = 0.5
const ORBIT_CORRECTION: float = 1.6

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")

static var _frames_cache: Dictionary = {}

@export var enemy_type: EnemyType = EnemyType.COMMON

@export var chase_acceleration: float = 1200.0

@export var contact_damage_interval: float = 1.0

@export var zigzag_amplitude: float = 0.95

@export var zigzag_interval: float = 0.55

@export var orbit_radius: float = 190.0

@export var dash_patience: float = 6.0

@export var dash_crowd_threshold: int = 3

@export var dash_crowd_radius: float = 260.0

@export var shove_strength: float = 900.0

@export var shove_player_bias: float = 0.45

var max_hp: float = 30.0
var current_hp: float = 30.0
var speed: float = 140.0
var contact_damage: float = 10.0
var trail_color: Color = Color.RED
var trail_radius: float = 5.0
var collision_radius: float = 18.0
var behavior: Behavior = Behavior.CHASE
var dash_speed: float = 0.0
var dash_windup: float = 0.0
var dash_duration: float = 0.0
var dash_recover: float = 0.0
var dash_cooldown: float = 0.0
var dash_range: float = 0.0

var _damage_timer: float = 0.0
var _dash_phase: DashPhase = DashPhase.READY
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _ghost_countdown: float = 0.0
var _patience: float = 0.0
var _zigzag_timer: float = 0.0
var _zigzag_side: float = 1.0
var _orbit_sign: float = 1.0
var _is_dying: bool = false
var _player: Player = null
var _paint_canvas: PaintCanvas = null
var _last_paint_position: Vector2 = Vector2.ZERO
var _arena_bounds: Rect2 = Rect2()

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
	collision_radius = preset["collision_radius"]

	speed = preset["speed"] * randf_range(0.9, 1.1)

	behavior = preset.get("behavior", Behavior.CHASE)
	dash_speed = preset.get("dash_speed", 0.0)
	dash_windup = preset.get("dash_windup", 0.0)
	dash_duration = preset.get("dash_duration", 0.0)
	dash_recover = preset.get("dash_recover", 0.0)
	dash_cooldown = preset.get("dash_cooldown", 0.0)
	dash_range = preset.get("dash_range", 0.0)

	_zigzag_timer = randf() * zigzag_interval
	_zigzag_side = 1.0 if randf() < 0.5 else -1.0
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0

	_apply_visual(preset)

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = collision_radius
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
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_zigzag_timer += delta
	if _zigzag_timer >= zigzag_interval:
		_zigzag_timer -= zigzag_interval
		_zigzag_side = -_zigzag_side

	var player: Player = _get_player()
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, chase_acceleration * delta)
		move_and_slide()
		_keep_inside_arena()
		return

	if _dash_phase == DashPhase.READY:
		_patience += delta
		if _should_start_dash(player):
			_begin_dash(player)

	match _dash_phase:
		DashPhase.WINDUP:
			_process_windup(delta)
		DashPhase.DASHING:
			_process_dash(delta)
		DashPhase.RECOVER:
			_process_recover(delta)
		_:
			velocity = velocity.move_toward(_desired_velocity(player), chase_acceleration * delta)

	if behavior == Behavior.ORBIT:
		_apply_enemy_shove(player, delta)

	move_and_slide()
	_keep_inside_arena()

	_update_facing()
	_check_contact_damage()
	_paint_trail()


func _desired_velocity(player: Player) -> Vector2:
	var to_player: Vector2 = player.global_position - global_position
	var radial: Vector2 = to_player.normalized()
	if radial.is_zero_approx():
		return Vector2.ZERO

	match behavior:
		Behavior.ZIGZAG:
			var lateral: Vector2 = radial.orthogonal() * _zigzag_side * zigzag_amplitude
			return (radial + lateral).normalized() * speed
		Behavior.ORBIT:
			var error: float = clampf(
				(to_player.length() - orbit_radius) / maxf(orbit_radius, 1.0), -1.0, 1.0
			)
			var tangent: Vector2 = radial.orthogonal() * _orbit_sign
			return (tangent + radial * error * ORBIT_CORRECTION).normalized() * speed
	return radial * speed


func _should_start_dash(player: Player) -> bool:
	if dash_speed <= 0.0 or _dash_cooldown_timer > 0.0:
		return false
	if global_position.distance_to(player.global_position) > dash_range:
		return false
	if behavior != Behavior.ORBIT:
		return true
	if _patience >= dash_patience:
		return true
	return _enemies_near_player(player) >= dash_crowd_threshold


func _enemies_near_player(player: Player) -> int:
	var count: int = 0
	var radius_squared: float = dash_crowd_radius * dash_crowd_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var other: EnemyBase = node as EnemyBase
		if other == null or other == self:
			continue
		if other.global_position.distance_squared_to(player.global_position) <= radius_squared:
			count += 1
	return count


func _begin_dash(player: Player) -> void:
	_dash_phase = DashPhase.WINDUP
	_dash_timer = dash_windup
	_dash_direction = (player.global_position - global_position).normalized()
	_patience = 0.0


func _process_windup(delta: float) -> void:
	velocity = velocity.move_toward(-_dash_direction * speed * 0.25, DASH_BRAKE * delta)
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return
	_dash_phase = DashPhase.DASHING
	_dash_timer = dash_duration
	_ghost_countdown = 0.0
	modulate.a = DASH_ALPHA


func _process_dash(delta: float) -> void:
	velocity = _dash_direction * dash_speed
	_spawn_dash_ghost(delta)
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return
	_dash_phase = DashPhase.RECOVER
	_dash_timer = dash_recover
	modulate.a = 1.0


func _process_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, DASH_BRAKE * delta)
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return
	_dash_phase = DashPhase.READY
	_dash_cooldown_timer = dash_cooldown


func _spawn_dash_ghost(delta: float) -> void:
	_ghost_countdown -= delta
	if _ghost_countdown > 0.0:
		return
	_ghost_countdown = GHOST_INTERVAL

	var container: Node = get_tree().get_first_node_in_group("effects_container")
	if container == null:
		return
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return

	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	container.add_child(ghost)
	ghost.global_position = global_position

	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


func _apply_enemy_shove(player: Player, delta: float) -> void:
	var push: Vector2 = Vector2.ZERO
	var toward: Vector2 = (player.global_position - global_position).normalized()

	for node in get_tree().get_nodes_in_group("enemies"):
		var other: EnemyBase = node as EnemyBase
		if other == null or other == self:
			continue
		var offset: Vector2 = global_position - other.global_position
		var overlap: float = collision_radius + other.collision_radius - offset.length()
		if overlap <= 0.0:
			continue
		var away: Vector2 = offset.normalized() if not offset.is_zero_approx() else toward
		push += away.lerp(toward, shove_player_bias) * overlap

	if push.is_zero_approx():
		return
	velocity += push.normalized() * shove_strength * delta


func set_arena_bounds(bounds: Rect2) -> void:
	_arena_bounds = bounds


func _keep_inside_arena() -> void:
	if _arena_bounds.size.x <= 0.0 or _arena_bounds.size.y <= 0.0:
		return
	var inset: Vector2 = Vector2(collision_radius, collision_radius)
	global_position = global_position.clamp(
		_arena_bounds.position + inset,
		_arena_bounds.end - inset
	)


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
