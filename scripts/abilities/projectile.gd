class_name Projectile
extends Area2D

static var _paint_color_cache: Dictionary = {}

const HOMING_START_FRACTION: float = 0.4
const HOMING_RADIUS: float = 260.0
const HOMING_CONE: float = 0.25
const HOMING_CLOSE_BOOST: float = 2.5
const PROJECTILE_SCENE_PATH: String = "res://scenes/abilities/projectile.tscn"
const BLAST_PAINT_FRACTION: float = 0.45
const TINT_SHADER: Shader = preload("res://assets/shaders/fusion_tint.gdshader")
const TINT_MIN_SATURATION: float = 0.12
const TINT_SATURATION_BOOST: float = 0.45

@export var speed: float = 600.0

@export var damage: float = 20.0

@export var max_distance: float = 400.0

@export var paint_radius: float = 9.0

var direction: Vector2 = Vector2.RIGHT

var pierce_remaining: int = 0

var size_scale: float = 1.0

var homing_turn_rate: float = 0.0

var perks: Array[String] = []

var fully_charged: bool = false

var ricochets_remaining: int = 0

var shard_count: int = 0

var is_critical: bool = false

var tint_color: Color = Color(0, 0, 0, 0)

var zigzag_swing: float = 0.0

var burst_radius: float = 0.0

var _has_impacted: bool = false
var _travelled: float = 0.0
var _homing_target: EnemyBase = null
var _homing_lost: bool = false
var _last_hit: Node = null
var _burst_done: bool = false
var _zigzag_side: float = 1.0
var _zigzag_timer: float = FlaskEffects.ZIGZAG_INTERVAL * 0.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func configure(texture: Texture2D, fly_direction: Vector2) -> void:
	direction = fly_direction.normalized()
	if texture != null:
		set_meta("configured_texture", texture)


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var texture: Texture2D = get_meta("configured_texture", null)
	if texture == null:
		texture = _resolve_ability_texture()
	sprite.texture = texture

	rotation = direction.angle()
	scale = Vector2.ONE * size_scale
	if tint_color.a > 0.0:
		_apply_tint()


func _physics_process(delta: float) -> void:
	if _has_impacted:
		return
	if homing_turn_rate > 0.0 and not _homing_lost and _travelled >= max_distance * HOMING_START_FRACTION:
		_steer_toward_target(delta)
	var step: float = speed * delta
	global_position += direction * step
	if zigzag_swing > 0.0:
		global_position += _zigzag_offset(delta)
	_travelled += step
	if _travelled >= max_distance:
		_finish_impact()


func _zigzag_offset(delta: float) -> Vector2:
	_zigzag_timer -= delta
	if _zigzag_timer <= 0.0:
		_zigzag_timer = FlaskEffects.ZIGZAG_INTERVAL
		_zigzag_side = -_zigzag_side
	return direction.orthogonal() * zigzag_swing * _zigzag_side * delta


func _apply_tint() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TINT_SHADER
	material.set_shader_parameter("target_hue", tint_color.h)
	material.set_shader_parameter("min_saturation", TINT_MIN_SATURATION)
	material.set_shader_parameter("saturation_boost", TINT_SATURATION_BOOST)
	sprite.material = material


func _steer_toward_target(delta: float) -> void:
	if _homing_target == null or not is_instance_valid(_homing_target) \
			or _homing_target.is_queued_for_deletion():
		_homing_target = _find_homing_target()
	if _homing_target == null:
		return
	var offset: Vector2 = _homing_target.global_position - global_position
	var desired: Vector2 = offset.normalized()
	if direction.dot(desired) < 0.0:
		_homing_lost = true
		return
	var closeness: float = 1.0 - clampf(offset.length() / HOMING_RADIUS, 0.0, 1.0)
	var max_turn: float = homing_turn_rate * (1.0 + HOMING_CLOSE_BOOST * closeness) * delta
	direction = direction.rotated(clampf(direction.angle_to(desired), -max_turn, max_turn))
	rotation = direction.angle()


func _find_homing_target() -> EnemyBase:
	var best: EnemyBase = null
	var best_distance: float = HOMING_RADIUS * HOMING_RADIUS
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		var distance: float = offset.length_squared()
		if distance > best_distance or direction.dot(offset.normalized()) < HOMING_CONE:
			continue
		best = enemy
		best_distance = distance
	return best


func _on_body_entered(body: Node2D) -> void:
	if _has_impacted:
		return
	if body is EnemyBase:
		var enemy: EnemyBase = body
		if enemy == _last_hit:
			return
		_last_hit = enemy
		var enemy_max_hp: float = enemy.max_hp
		var dealt: float = _damage_against(enemy)
		enemy.take_damage(dealt, true, is_critical)
		if is_critical:
			AudioManager.play_critical_hit()
		_apply_hit_perks(enemy, dealt, enemy_max_hp)
		_burst_on(enemy)
		_paint_impact(global_position)
		if pierce_remaining > 0:
			pierce_remaining -= 1
			return
		if ricochets_remaining > 0 and _ricochet_from(enemy):
			return
		_finish_impact()
		return
	_paint_impact(global_position)
	_finish_impact()


func ignore_body(body: Node) -> void:
	_last_hit = body


func _damage_against(enemy: EnemyBase) -> float:
	var amount: float = damage
	if perks.has("focus"):
		amount *= 1.0 + ShotPerks.FOCUS_BONUS_PER_STACK * enemy.focus_stacks()
		enemy.add_focus_stack()
	return amount


func _apply_hit_perks(enemy: EnemyBase, dealt: float, enemy_max_hp: float) -> void:
	if perks.has("vampirism"):
		var player: Player = get_tree().get_first_node_in_group("player") as Player
		if player != null:
			player.heal(minf(dealt, enemy_max_hp * ShotPerks.VAMPIRISM_FRACTION))
	if perks.has("poison"):
		enemy.add_poison(damage * ShotPerks.POISON_DPS_FRACTION)
	if _burst_done:
		return
	_burst_done = true
	if perks.has("explosion") and fully_charged:
		_blast(enemy)
	if shard_count > 0:
		_spawn_shards(enemy)


func _burst_on(center: EnemyBase) -> void:
	if burst_radius <= 0.0:
		return
	burst_radius = 0.0
	var radius: float = FlaskEffects.BURST_RADIUS * size_scale
	var radius_squared: float = radius * radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy == center or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_squared_to(global_position) <= radius_squared:
			enemy.take_damage(damage * FlaskEffects.BURST_DAMAGE, false)
	var canvas: PaintCanvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	if canvas != null:
		canvas.paint_circle(global_position, radius * FlaskEffects.BURST_PAINT, _get_paint_color())
	AudioManager.play_enemy_explode()


func _blast(center: EnemyBase) -> void:
	var radius: float = ShotPerks.blast_radius(size_scale)
	var radius_squared: float = radius * radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy == center or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_squared_to(global_position) <= radius_squared:
			enemy.take_damage(damage * ShotPerks.BLAST_DAMAGE_FRACTION, false)
	var canvas: PaintCanvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	if canvas != null:
		canvas.paint_circle(global_position, radius * BLAST_PAINT_FRACTION, _get_paint_color())
	AudioManager.play_enemy_explode()


func _spawn_shards(center: EnemyBase) -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE_PATH)
	var container: Node = get_parent()
	if scene == null or container == null:
		push_warning("[Projectile] Não foi possível soltar os estilhaços.")
		return
	var start_angle: float = randf() * TAU
	for index in shard_count:
		var shard: Projectile = scene.instantiate()
		shard.configure(sprite.texture, Vector2.from_angle(start_angle + TAU * float(index) / float(shard_count)))
		shard.damage = damage * ShotPerks.SHARD_DAMAGE_FRACTION
		shard.speed = speed
		shard.size_scale = ShotPerks.SHARD_SIZE
		shard.max_distance = ShotPerks.SHARD_RANGE
		shard.ignore_body(center)
		shard.position = global_position
		container.add_child.call_deferred(shard)


func _ricochet_from(enemy: EnemyBase) -> bool:
	var next: EnemyBase = null
	var best_distance: float = ShotPerks.RICOCHET_RANGE * ShotPerks.RICOCHET_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var candidate: EnemyBase = node as EnemyBase
		if candidate == null or candidate == enemy or candidate.is_queued_for_deletion():
			continue
		var distance: float = candidate.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			next = candidate
	if next == null:
		return false
	ricochets_remaining -= 1
	direction = (next.global_position - global_position).normalized()
	rotation = direction.angle()
	_travelled = maxf(max_distance - ShotPerks.RICOCHET_RANGE * 1.2, 0.0)
	_homing_target = next
	_homing_lost = false
	return true


func _finish_impact() -> void:
	_has_impacted = true
	queue_free()


func _paint_impact(impact_position: Vector2) -> void:
	var canvas: PaintCanvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	if canvas == null:
		return

	var color: Color = _get_paint_color()
	var radius: float = paint_radius * size_scale
	canvas.paint_circle(impact_position, radius, color)
	for i in 3:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) \
			* randf_range(radius * 1.2, radius * 2.5)
		canvas.paint_circle(
			impact_position + offset,
			randf_range(radius * 0.3, radius * 0.6),
			color
		)


func _get_paint_color() -> Color:
	if tint_color.a > 0.0:
		return tint_color
	var texture: Texture2D = sprite.texture
	if texture == null:
		return Color(0.2, 0.2, 0.2, 1.0)
	if _paint_color_cache.has(texture):
		return _paint_color_cache[texture]

	var color: Color = _compute_average_color(texture.get_image())
	_paint_color_cache[texture] = color
	return color


static func _compute_average_color(image: Image) -> Color:
	var fallback: Color = Color(0.2, 0.2, 0.2, 1.0)
	if image == null:
		return fallback

	var bright_sum: Vector3 = Vector3.ZERO
	var bright_count: int = 0
	var all_sum: Vector3 = Vector3.ZERO
	var all_count: int = 0

	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.1:
				continue
			all_sum += Vector3(pixel.r, pixel.g, pixel.b)
			all_count += 1
			if pixel.r + pixel.g + pixel.b > 0.35:
				bright_sum += Vector3(pixel.r, pixel.g, pixel.b)
				bright_count += 1

	if bright_count > 0:
		var bright: Vector3 = bright_sum / float(bright_count)
		return Color(bright.x, bright.y, bright.z, 1.0)
	if all_count > 0:
		var average: Vector3 = all_sum / float(all_count)
		return Color(average.x, average.y, average.z, 1.0)
	return fallback


func _resolve_ability_texture() -> Texture2D:
	var texture: ImageTexture = GameManager.get_ability_texture(0)
	if texture == null:
		if GameManager.load_ability_drawing_from_disk(0):
			texture = GameManager.get_ability_texture(0)
	if texture == null:
		push_warning("[Projectile] Sem desenho de habilidade; usando placeholder.")
		texture = _create_placeholder_texture()
	return texture


func _create_placeholder_texture() -> ImageTexture:
	var image: Image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(5.5, 5.5)
	for y in 12:
		for x in 12:
			if Vector2(x, y).distance_to(center) <= 5.5:
				image.set_pixel(x, y, Color(0.95, 0.55, 0.1))
	return ImageTexture.create_from_image(image)
