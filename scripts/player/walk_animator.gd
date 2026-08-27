class_name WalkAnimator
extends Sprite2D

@export var bounce_frequency: float = 10.0

@export var bounce_height: float = 5.0

@export var rotation_amount: float = 6.0

@export var squash_amount: float = 0.08

@export var reference_speed: float = 320.0

@export var move_threshold: float = 5.0

@export var return_speed: float = 12.0

var _body: CharacterBody2D = null
var _base_scale: Vector2 = Vector2.ONE
var _phase: float = 0.0


func _ready() -> void:
	_base_scale = scale
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_warning("[WalkAnimator] O parent de %s não é um CharacterBody2D; efeito desativado." % name)


func _process(delta: float) -> void:
	if _body == null:
		return

	var speed: float = _body.velocity.length()

	if speed > move_threshold:
		_animate_walk(delta, speed)
	else:
		_return_to_rest(delta)


func _animate_walk(delta: float, speed: float) -> void:
	var intensity: float = clampf(speed / reference_speed, 0.35, 1.0)

	_phase += delta * bounce_frequency * intensity
	var bounce: float = absf(sin(_phase))

	offset.y = -bounce * bounce_height * intensity
	rotation = sin(_phase) * deg_to_rad(rotation_amount) * intensity

	var stretch: float = bounce * squash_amount * intensity
	scale = _base_scale * Vector2(1.0 - stretch * 0.7, 1.0 + stretch)


func _return_to_rest(delta: float) -> void:
	_phase = 0.0
	var weight: float = minf(return_speed * delta, 1.0)
	offset.y = lerpf(offset.y, 0.0, weight)
	rotation = lerpf(rotation, 0.0, weight)
	scale = scale.lerp(_base_scale, weight)
