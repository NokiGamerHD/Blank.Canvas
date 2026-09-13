extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(300.0, 1500.0)
const PROBE_ABILITY_INDEX: int = 9

var _arena: Arena = null
var _player: Player = null
var _controller: AbilityController = null
var _failures: int = 0
var _spawned: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(3000.0, 3000.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_player = _arena.player
	_controller = _arena.ability_controller
	_controller.set_physics_process(false)
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_arena.projectiles_container.child_entered_tree.connect(_on_projectile_spawned)
	await get_tree().process_frame
	await get_tree().process_frame

	_check_presets()
	await _check_standard_homing()
	await _check_charge_growth()
	await _check_ranges()
	await _check_fire_rates()
	await _check_charge_alternates()
	_check_cooldown_upgrade_shortens_charge()
	_check_missing_type_defaults_to_standard()
	await _check_picker_gate()
	await _check_new_ability_keeps_first_type()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _on_projectile_spawned(_node: Node) -> void:
	_spawned += 1


func _reset() -> void:
	Input.action_release("fire")
	_controller.set_physics_process(false)
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.projectiles_container.get_children():
		child.free()
	_player.global_position = PLAYER_SPOT
	_player.velocity = Vector2.ZERO
	_player.set_aim_override(PLAYER_SPOT + Vector2(400.0, 0.0))


func _use_type(shot_type: int) -> AbilityData:
	var data: AbilityData = _controller.get_abilities()[0]
	data.apply_shot_type(shot_type, _controller.damage, _controller.cooldown, _controller.projectile_speed)
	data.cooldown_remaining = 0.0
	data.charge_elapsed = 0.0
	data.charging = false
	return data


func _hold_fire(seconds: float) -> void:
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await get_tree().create_timer(seconds).timeout


func _release_fire() -> void:
	Input.action_release("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.set_physics_process(false)


func _newest_projectile() -> Projectile:
	var children: Array[Node] = _arena.projectiles_container.get_children()
	for index in range(children.size() - 1, -1, -1):
		var projectile: Projectile = children[index] as Projectile
		if projectile != null and not projectile.is_queued_for_deletion():
			return projectile
	return null


func _check_presets() -> void:
	var values: Dictionary = {}
	for shot_type in [AbilityData.ShotType.STANDARD, AbilityData.ShotType.CHARGE, AbilityData.ShotType.RAPID]:
		var data: AbilityData = AbilityData.new()
		data.apply_shot_type(shot_type, 20.0, 1.0, 720.0)
		values[shot_type] = data
	var standard: AbilityData = values[AbilityData.ShotType.STANDARD]
	var charge: AbilityData = values[AbilityData.ShotType.CHARGE]
	var rapid: AbilityData = values[AbilityData.ShotType.RAPID]
	var passed: bool = rapid.damage < standard.damage \
		and rapid.shot_range > standard.shot_range and standard.shot_range > charge.shot_range \
		and rapid.cooldown < standard.cooldown and rapid.projectile_speed > standard.projectile_speed \
		and standard.homing_turn_rate > 0.0 and rapid.homing_turn_rate == 0.0 and charge.homing_turn_rate == 0.0
	_report("tipos de tiro tem perfis distintos", passed,
		"padrao=%.0fdano/%.2fs/%.0falc rapido=%.0f/%.2fs/%.0f carregado=%.0f/%.2fs/%.0f" % [
			standard.damage, standard.cooldown, standard.shot_range,
			rapid.damage, rapid.cooldown, rapid.shot_range,
			charge.damage, charge.cooldown, charge.shot_range,
		])


func _fire_past_enemy(shot_type: int) -> Dictionary:
	_reset()
	var enemy: EnemyBase = load(ENEMY_SCENE).instantiate()
	enemy.enemy_type = EnemyBase.EnemyType.COMMON
	enemy.position = PLAYER_SPOT + Vector2(420.0, 110.0)
	_arena.enemies_container.add_child(enemy)
	enemy.set_physics_process(false)
	var starting_hp: float = enemy.current_hp
	_use_type(shot_type)
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.set_physics_process(false)
	Input.action_release("fire")

	var projectile: Projectile = _newest_projectile()
	var steepest: float = 0.0
	var elapsed: float = 0.0
	while elapsed < 1.0 and is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
		steepest = maxf(steepest, projectile.direction.y)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	var hit: bool = not is_instance_valid(enemy) or enemy.current_hp < starting_hp
	return {"hit": hit, "steepest": steepest}


func _check_standard_homing() -> void:
	var standard: Dictionary = await _fire_past_enemy(AbilityData.ShotType.STANDARD)
	var rapid: Dictionary = await _fire_past_enemy(AbilityData.ShotType.RAPID)
	_report("padrao curva ate o inimigo no fim, rapido segue reto",
		standard["hit"] and standard["steepest"] > 0.2 and not rapid["hit"] and rapid["steepest"] < 0.01,
		"padrao acertou=%s curva=%.2f | rapido acertou=%s curva=%.2f" % [
			standard["hit"], standard["steepest"], rapid["hit"], rapid["steepest"]
		])


func _charged_shot(hold_seconds: float) -> Dictionary:
	_reset()
	var data: AbilityData = _use_type(AbilityData.ShotType.CHARGE)
	var before: int = _spawned
	await _hold_fire(hold_seconds)
	var fired_while_holding: int = _spawned - before
	await _release_fire()
	var projectile: Projectile = _newest_projectile()
	if projectile == null:
		return {"fired": false, "held": fired_while_holding}
	return {
		"fired": true, "held": fired_while_holding, "damage": projectile.damage,
		"size": projectile.size_scale, "pierce": projectile.pierce_remaining,
		"charge_time": data.charge_time,
	}


func _check_charge_growth() -> void:
	var tap: Dictionary = await _charged_shot(0.2)
	var full: Dictionary = await _charged_shot(1.4)
	var long: Dictionary = await _charged_shot(3.0)
	var max_damage: float = _controller.damage * AbilityData.CHARGE_MAX_DAMAGE
	var passed: bool = tap["fired"] and full["fired"] and long["fired"] \
		and tap["held"] == 0 and long["held"] == 0 \
		and tap["damage"] < full["damage"] and tap["size"] < full["size"] \
		and is_equal_approx(full["damage"], max_damage) and is_equal_approx(long["damage"], max_damage) \
		and is_equal_approx(full["size"], AbilityData.CHARGE_MAX_SIZE) \
		and full["pierce"] == AbilityData.CHARGE_FULL_PIERCE and tap["pierce"] == 0
	_report("carregado cresce ao segurar, tem teto e so sai ao soltar", passed,
		"toque=%.0fdano/%.2fx 1.4s=%.0f/%.2fx/perf%d 3s=%.0f/%.2fx disparos_segurando=%d" % [
			tap.get("damage", 0.0), tap.get("size", 0.0), full.get("damage", 0.0), full.get("size", 0.0),
			full.get("pierce", -1), long.get("damage", 0.0), long.get("size", 0.0), long["held"]
		])


func _measure_range(shot_type: int) -> float:
	_reset()
	var data: AbilityData = _use_type(shot_type)
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if shot_type == AbilityData.ShotType.CHARGE:
		Input.action_release("fire")
		await get_tree().physics_frame
		await get_tree().physics_frame
	_controller.set_physics_process(false)
	Input.action_release("fire")
	var projectile: Projectile = _newest_projectile()
	if projectile == null:
		return 0.0
	var start: Vector2 = projectile.global_position
	var last: Vector2 = start
	var elapsed: float = 0.0
	while elapsed < 3.0 and is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
		last = projectile.global_position
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	return last.distance_to(start) + data.projectile_speed * get_physics_process_delta_time()


func _check_ranges() -> void:
	var standard: float = await _measure_range(AbilityData.ShotType.STANDARD)
	var charge: float = await _measure_range(AbilityData.ShotType.CHARGE)
	var rapid: float = await _measure_range(AbilityData.ShotType.RAPID)
	var tolerance: float = 40.0
	var passed: bool = absf(standard - 700.0) < tolerance and absf(charge - 380.0) < tolerance \
		and absf(rapid - 1100.0) < tolerance
	_report("alcance de cada tipo", passed,
		"padrao=%.0f (700) carregado=%.0f (380) rapido=%.0f (1100)" % [standard, charge, rapid])


func _count_shots(shot_type: int, seconds: float) -> int:
	_reset()
	_use_type(shot_type)
	var before: int = _spawned
	await _hold_fire(seconds)
	await _release_fire()
	return _spawned - before


func _check_fire_rates() -> void:
	var standard: int = await _count_shots(AbilityData.ShotType.STANDARD, 1.0)
	var rapid: int = await _count_shots(AbilityData.ShotType.RAPID, 1.0)
	_report("rapido dispara bem mais que o padrao", rapid >= 3 and rapid > standard,
		"em 1s: padrao=%d rapido=%d" % [standard, rapid])


func _check_cooldown_upgrade_shortens_charge() -> void:
	var data: AbilityData = AbilityData.new()
	data.apply_shot_type(AbilityData.ShotType.CHARGE, 20.0, 1.0, 720.0)
	var before: float = data.charge_time
	_arena.progression_screen._apply_upgrade("cooldown", data)
	_report("upgrade de recarga encurta a carga",
		is_equal_approx(data.charge_time, before * 0.75),
		"carga %.3fs -> %.3fs" % [before, data.charge_time])


func _check_missing_type_defaults_to_standard() -> void:
	var data: AbilityData = _controller._build_ability(8, 0)
	_report("habilidade sem tipo salvo vira padrao", data.shot_type == AbilityData.ShotType.STANDARD,
		"tipo=%d" % data.shot_type)


func _small_ability_image() -> Image:
	var image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(14, 14, 6, 6), Color("f2913d"))
	return image


func _check_charge_alternates() -> void:
	_reset()
	var first: AbilityData = _use_type(AbilityData.ShotType.CHARGE)
	GameManager.set_ability_shot_type(8, AbilityData.ShotType.CHARGE)
	_controller.add_ability(8)
	var second: AbilityData = _controller.get_abilities()[1]
	second.cooldown_remaining = 0.0

	var before: int = _spawned
	await _hold_fire(1.3)
	var both_charging: bool = first.charging and second.charging
	await _release_fire()
	var first_volley: int = _spawned - before
	var first_turn: bool = first.cooldown_remaining > 0.0 and second.cooldown_remaining <= 0.0

	before = _spawned
	await _hold_fire(1.3)
	both_charging = both_charging or (first.charging and second.charging)
	await _release_fire()
	var second_volley: int = _spawned - before
	var second_turn: bool = second.cooldown_remaining > 0.0 and first.cooldown_remaining > 0.0

	_controller.abilities.resize(1)
	GameManager.set_ability_shot_type(8, -1)
	_report("dois carregados revezam em vez de sair juntos",
		first_volley == 1 and second_volley == 1 and first_turn and second_turn and not both_charging,
		"tiros_por_soltada=%d,%d primeira_vez_da_1a=%s segunda_vez_da_2a=%s carregaram_juntos=%s recarga=%.2fs" % [
			first_volley, second_volley, first_turn, second_turn, both_charging, first.cooldown
		])


func _check_picker_gate() -> void:
	var creator: Node = load(GameManager.SCENE_ABILITY_CREATOR).instantiate()
	add_child(creator)
	await get_tree().process_frame
	await get_tree().process_frame
	creator.pixel_editor.load_from_image(_small_ability_image())
	var previous_main: int = GameManager.get_ability_shot_type(0)
	GameManager.set_ability_shot_type(0, -1)

	var picker: ShotPicker = creator.get_shot_picker()
	var opened: bool = creator.open_shot_picker()
	var locked: bool = picker.confirm_button.disabled and picker.selected_shot_type() == -1 \
		and not picker.is_locked()
	picker.back_button.pressed.emit()
	var warned: bool = not picker.visible \
		and creator.feedback_label.text == LocalizationManager.text("creator.shot_needed")
	creator.open_shot_picker()
	picker.select(AbilityData.ShotType.RAPID)
	var unlocked: bool = not picker.confirm_button.disabled

	GameManager.set_ability_shot_type(0, previous_main)
	creator.queue_free()
	_report("editor principal nao deixa sair sem escolher o tiro",
		opened and locked and warned and unlocked,
		"abriu=%s travado=%s aviso_ao_voltar=%s liberou_ao_marcar=%s" % [opened, locked, warned, unlocked])


func _check_new_ability_keeps_first_type() -> void:
	var shot_types_path: String = ProjectSettings.globalize_path("%s/shot_types.cfg" % GameManager.DRAWINGS_DIR)
	var drawing_path: String = ProjectSettings.globalize_path(
		"%s/ability_%02d.png" % [GameManager.DRAWINGS_DIR, PROBE_ABILITY_INDEX + 1])
	var had_shot_types: bool = FileAccess.file_exists(shot_types_path)
	var previous_main: int = GameManager.get_ability_shot_type(0)
	GameManager.set_ability_shot_type(0, AbilityData.ShotType.RAPID)

	var creator: Node = load(GameManager.SCENE_ABILITY_CREATOR).instantiate()
	creator.in_run_mode = true
	add_child(creator)
	await get_tree().process_frame
	await get_tree().process_frame
	creator.open_for_new_ability(PROBE_ABILITY_INDEX)
	creator.pixel_editor.load_from_image(_small_ability_image())
	var created: Array[int] = []
	creator.in_run_ability_created.connect(func(index: int) -> void: created.append(index))

	var picker: ShotPicker = creator.get_shot_picker()
	creator.open_shot_picker()
	var preset: bool = picker.is_locked() and picker.selected_shot_type() == AbilityData.ShotType.RAPID \
		and not picker.confirm_button.disabled \
		and picker.is_card_disabled(AbilityData.ShotType.STANDARD) \
		and picker.is_card_disabled(AbilityData.ShotType.CHARGE)
	picker.select(AbilityData.ShotType.CHARGE)
	var refused_other: bool = picker.selected_shot_type() == AbilityData.ShotType.RAPID
	picker.confirm_button.pressed.emit()
	var emitted: bool = created == [PROBE_ABILITY_INDEX]
	var in_memory: bool = GameManager.get_ability_shot_type(PROBE_ABILITY_INDEX) == AbilityData.ShotType.RAPID
	GameManager.set_ability_shot_type(PROBE_ABILITY_INDEX, -1)
	GameManager.load_ability_drawing_from_disk(PROBE_ABILITY_INDEX)
	var from_disk: bool = GameManager.get_ability_shot_type(PROBE_ABILITY_INDEX) == AbilityData.ShotType.RAPID

	DirAccess.remove_absolute(drawing_path)
	if had_shot_types:
		var shot_types: ConfigFile = ConfigFile.new()
		shot_types.load(shot_types_path)
		shot_types.erase_section_key(GameManager.SHOT_TYPES_SECTION, str(PROBE_ABILITY_INDEX))
		shot_types.save(shot_types_path)
	else:
		DirAccess.remove_absolute(shot_types_path)
	GameManager.set_ability_shot_type(0, previous_main)
	creator.queue_free()

	_report("habilidade nova herda o tipo da primeira e salva",
		preset and refused_other and emitted and in_memory and from_disk,
		"travada_no_rapido=%s recusou_outro=%s criou=%s memoria=%s disco=%s" % [
			preset, refused_other, emitted, in_memory, from_disk
		])
