class_name Player
extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)
signal died

@export var max_speed: float = 320.0

@export var acceleration: float = 2400.0

@export var friction: float = 1800.0

@export var max_hp: float = 100.0

@export var knockback_strength: float = 260.0

@export var knockback_decay: float = 900.0

var current_hp: float = 100.0
var _is_dead: bool = false
var _flash_tween: Tween = null

var _input_velocity: Vector2 = Vector2.ZERO

var _knockback: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	_apply_character_texture()


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		_input_velocity = _input_velocity.move_toward(input_direction * max_speed, acceleration * delta)
	else:
		_input_velocity = _input_velocity.move_toward(Vector2.ZERO, friction * delta)

	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity = _input_velocity + _knockback

	move_and_slide()
	_update_facing()


func apply_knockback(from_position: Vector2, strength_multiplier: float = 1.0) -> void:
	if _is_dead:
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


func take_damage(amount: float) -> void:
	if _is_dead:
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
