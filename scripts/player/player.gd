class_name Player
extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)
signal died
signal dashed

const ENEMY_LAYER_NUMBER: int = 3
const DASH_ALPHA: float = 0.55
const GHOST_INTERVAL: float = 0.03
const GHOST_FADE: float = 0.22
const GHOST_ALPHA: float = 0.5
const MIN_DASH_COOLDOWN: float = 0.35

@export var max_speed: float = 320.0

@export var acceleration: float = 2400.0

@export var friction: float = 1800.0

@export var max_hp: float = 100.0

@export var knockback_strength: float = 260.0

@export var knockback_decay: float = 900.0

@export var dash_speed: float = 950.0

@export var dash_duration: float = 0.16

@export var dash_cooldown: float = 1.6

@export var dash_invulnerability_grace: float = 0.12

var current_hp: float = 100.0
var _is_dead: bool = false
var _flash_tween: Tween = null

var _input_velocity: Vector2 = Vector2.ZERO

var _knockback: Vector2 = Vector2.ZERO

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _invulnerable_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _ghost_countdown: float = 0.0

var _aim_override_enabled: bool = false
var _aim_override: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	_apply_character_texture()


func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)

	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash"):
		try_dash(input_direction)

	if _dash_timer > 0.0:
		_process_dash(delta)
	else:
		if input_direction != Vector2.ZERO:
			_input_velocity = _input_velocity.move_toward(input_direction * max_speed, acceleration * delta)
		else:
			_input_velocity = _input_velocity.move_toward(Vector2.ZERO, friction * delta)
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity = _input_velocity + _knockback

	move_and_slide()
	_update_facing()


func try_dash(direction: Vector2) -> bool:
	if _is_dead or _dash_timer > 0.0 or _dash_cooldown_timer > 0.0:
		return false

	var dash_direction: Vector2 = direction.normalized()
	if dash_direction.is_zero_approx():
		dash_direction = (aim_position() - global_position).normalized()
	if dash_direction.is_zero_approx():
		dash_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

	_dash_direction = dash_direction
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_invulnerable_timer = dash_duration + dash_invulnerability_grace
	_ghost_countdown = 0.0
	_knockback = Vector2.ZERO
	set_collision_mask_value(ENEMY_LAYER_NUMBER, false)
	modulate.a = DASH_ALPHA
	AudioManager.play_player_dash()
	dashed.emit()
	return true


func _process_dash(delta: float) -> void:
	velocity = _dash_direction * dash_speed
	_spawn_dash_ghost(delta)
	_dash_timer -= delta
	if _dash_timer > 0.0:
		return
	_end_dash()


func _end_dash() -> void:
	_dash_timer = 0.0
	_input_velocity = _dash_direction * max_speed
	set_collision_mask_value(ENEMY_LAYER_NUMBER, true)
	modulate.a = 1.0


func _spawn_dash_ghost(delta: float) -> void:
	_ghost_countdown -= delta
	if _ghost_countdown > 0.0:
		return
	_ghost_countdown = GHOST_INTERVAL

	var container: Node = get_tree().get_first_node_in_group("effects_container")
	if container == null or sprite.texture == null:
		return

	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = sprite.scale
	ghost.offset = sprite.offset
	ghost.rotation = sprite.global_rotation
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	container.add_child(ghost)
	ghost.global_position = sprite.global_position

	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


func is_dashing() -> bool:
	return _dash_timer > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0


func dash_cooldown_fraction() -> float:
	if dash_cooldown <= 0.0:
		return 0.0
	return clampf(_dash_cooldown_timer / dash_cooldown, 0.0, 1.0)


func reduce_dash_cooldown(multiplier: float) -> void:
	dash_cooldown = maxf(dash_cooldown * multiplier, MIN_DASH_COOLDOWN)


func aim_position() -> Vector2:
	if _aim_override_enabled:
		return _aim_override
	return get_global_mouse_position()


func set_aim_override(point: Vector2) -> void:
	_aim_override_enabled = true
	_aim_override = point


func apply_knockback(from_position: Vector2, strength_multiplier: float = 1.0) -> void:
	if _is_dead or is_invulnerable():
		return
	var push_direction: Vector2 = (global_position - from_position).normalized()
	if push_direction == Vector2.ZERO:
		push_direction = Vector2.from_angle(randf() * TAU)
	_knockback = push_direction * knockback_strength * strength_multiplier


func _update_facing() -> void:
	if _input_velocity.x < -1.0:
		sprite.flip_h = true
	elif _input_velocity.x > 1.0:
		sprite.flip_h = false


func is_moving() -> bool:
	return velocity.length() > 5.0


func is_dead() -> bool:
	return _is_dead


func take_damage(amount: float) -> void:
	if _is_dead or is_invulnerable():
		return
	current_hp = maxf(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	_flash_damage()
	AudioManager.play_player_hurt()
	if current_hp <= 0.0:
		_die()


func heal_to_full() -> void:
	if _is_dead:
		return
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


func heal_fraction(fraction: float) -> void:
	if _is_dead:
		return
	current_hp = minf(current_hp + max_hp * fraction, max_hp)
	health_changed.emit(current_hp, max_hp)


func _flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = Color(1.0, 0.3, 0.3, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	_input_velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_dash_timer = 0.0
	modulate.a = 1.0
	set_physics_process(false)
	died.emit()

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	await get_tree().create_timer(1.2).timeout
	GameManager.go_to_game_over()


func set_camera_limits(limits: Rect2) -> void:
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.end.x)
	camera.limit_bottom = int(limits.end.y)
	camera.reset_smoothing()


func _apply_character_texture() -> void:
	var texture: ImageTexture = GameManager.get_character_texture()
	if texture == null:
		if GameManager.load_character_drawing_from_disk():
			texture = GameManager.get_character_texture()
	if texture == null:
		texture = _create_placeholder_texture()
		push_warning("[Player] Sem desenho de personagem; usando placeholder.")
	sprite.texture = texture


func _create_placeholder_texture() -> ImageTexture:
	var image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(17.5, 17.5)
	for y in 36:
		for x in 36:
			var distance: float = Vector2(x, y).distance_to(center)
			if distance <= 16.0:
				var pixel_color: Color = Color(0.6, 0.6, 0.6) if distance < 14.0 else Color(0.3, 0.3, 0.3)
				image.set_pixel(x, y, pixel_color)
	return ImageTexture.create_from_image(image)
