extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal defeated(reward: int)

@export var boss_name := "Boss"
@export var max_health := 250.0
@export var attack_damage := 8.0
@export var xp_reward := 120
@export var move_speed := 1.6
@export var attack_range := 2.6
@export var attack_cooldown := 1.6
@export var skill_name := ""
@export var skill_element := "fire"
@export var skill_range := 14.0
@export var skill_damage_multiplier := 1.45
@export var aggression_range := 34.0
@export var preferred_range := 8.0
@export var spell_variation := 0.0
@export var respawn_delay := 25.0
@export var collision_radius := 1.1
@export var collision_height := 2.8
@export var model_scene: PackedScene
@export var model_scale := 0.7

var health := 0.0
var _player: CharacterBody3D
var _attack_remaining := 0.0
var _respawning := false
var _visual: Node3D
var _model_animation_player: AnimationPlayer
var _collision: CollisionShape3D
var _visual_rest_height := 0.0
var _motion_phase := 0.0
var _attack_windup := 0.0
var _attack_marker: MeshInstance3D
var _hydra_heads: Array[Node3D] = []
var _hydra_necks: Array[Node3D] = []
var _hydra_legs: Array[Node3D] = []
var _hydra_feet: Array[Node3D] = []
var _hydra_tail: Array[Node3D] = []
var _dragon_wings: Array[Node3D] = []
var _dragon_head: Node3D
var _dragon_feet: Array[Node3D] = []
var _articulation_rest_rotations: Dictionary[Node3D, Vector3] = {}
var _network_send_remaining := 0.0
var _network_target_position := Vector3.ZERO
var _network_target_yaw := 0.0
var _spell_cycle := 0
var _strafe_sign := 1.0
var _decision_timer := 0.0
var _has_aggro := false
var _defeat_count := 0
var _base_max_health := 0.0
var _base_attack_damage := 0.0
var _base_move_speed := 0.0
var _base_attack_cooldown := 0.0
var _base_skill_damage_multiplier := 0.0
var _base_xp_reward := 0
var _base_aggression_range := 0.0
var _base_preferred_range := 0.0
var _learned_damage_resistance := 0.0
var _last_attacker_class := -1


func _ready() -> void:
	_base_max_health = max_health
	_base_attack_damage = attack_damage
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	_base_skill_damage_multiplier = skill_damage_multiplier
	_base_xp_reward = xp_reward
	_base_aggression_range = aggression_range
	_base_preferred_range = preferred_range
	health = max_health
	collision_layer = 2
	# Detect both the player and dungeon geometry (floor/walls use layer 2).
	collision_mask = 3
	add_to_group("enemies")
	_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = collision_radius
	shape.height = collision_height
	_collision.shape = shape
	add_child(_collision)
	if model_scene == null:
		push_error("%s no tiene un modelo asignado." % boss_name)
		return
	_visual = model_scene.instantiate() as Node3D
	if _visual == null:
		push_error("El modelo de %s no tiene raíz Node3D." % boss_name)
		return
	_visual.name = "BossVisual"
	if boss_name.begins_with("Ignivar") or boss_name.begins_with("Vyrm"):
		_remove_boss_pedestal(_visual)
	_visual.position.y = -collision_height * 0.5
	_visual_rest_height = _visual.position.y
	_visual.scale = Vector3.ONE * model_scale
	add_child(_visual)
	_model_animation_player = _find_animation_player(_visual)
	_play_model_animation(["idle", "stand"])
	_setup_articulations()
	_create_attack_marker()
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_network_target_position = global_position
	_network_target_yaw = rotation.y


func _physics_process(delta: float) -> void:
	if MultiplayerSession.is_active() and not multiplayer.is_server():
		global_position = global_position.lerp(_network_target_position, 1.0 - exp(-delta * 12.0))
		rotation.y = lerp_angle(rotation.y, _network_target_yaw, 1.0 - exp(-delta * 12.0))
		return
	if _respawning:
		return
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_motion_phase += delta * (3.3 if Vector2(velocity.x, velocity.z).length() > 0.15 else 1.7)
	if is_instance_valid(_visual):
		var is_walking := Vector2(velocity.x, velocity.z).length() > 0.15
		var is_mythic_boss := boss_name.begins_with("Ignivar") or boss_name.begins_with("Vyrm")
		_visual.position.y = _visual_rest_height + sin(_motion_phase * 2.0) * (0.11 if is_walking and is_mythic_boss else (0.08 if is_walking else 0.035))
		_visual.rotation.x = sin(_motion_phase) * (0.045 if is_walking and is_mythic_boss else (0.025 if is_walking else 0.012))
		_visual.rotation.z = cos(_motion_phase * 0.5) * (0.025 if is_mythic_boss else 0.012)
		if is_mythic_boss:
			_visual.scale = Vector3.ONE * model_scale * (1.0 + sin(_motion_phase * 0.72) * 0.012)
		_animate_articulations(is_walking)
	if _attack_windup > 0.0:
		_attack_windup = maxf(0.0, _attack_windup - delta)
		if _attack_windup == 0.0:
			_finish_attack()
	if is_instance_valid(_attack_marker):
		_attack_marker.visible = _attack_windup > 0.0
		var pulse := 0.7 + absf(sin(_motion_phase * 8.0)) * 0.5
		_attack_marker.scale = Vector3.ONE * pulse
	if MultiplayerSession.is_active():
		var closest_distance := INF
		for candidate in get_tree().get_nodes_in_group("player"):
			if not candidate is CharacterBody3D:
				continue
			var candidate_body := candidate as CharacterBody3D
			var candidate_distance := global_position.distance_squared_to(candidate_body.global_position)
			if candidate_distance < closest_distance:
				closest_distance = candidate_distance
				_player = candidate_body
	elif not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(_player):
		return
	if MultiplayerSession.is_active():
		_network_send_remaining -= delta
		if _network_send_remaining <= 0.0:
			_network_send_remaining = 0.1
			receive_enemy_state.rpc(global_position, rotation.y)

	var offset := _player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= aggression_range:
		_has_aggro = true
	elif distance > aggression_range * 1.7:
		_has_aggro = false
	var effective_attack_range := skill_range if not skill_name.is_empty() else attack_range
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		var learned_reaction := minf(float(_defeat_count) * 0.055, 0.48)
		_decision_timer = randf_range(1.4 - learned_reaction, 2.8 - learned_reaction)
		_strafe_sign = -_strafe_sign if randf() < 0.62 else _strafe_sign
	if not _has_aggro:
		_play_model_animation(["idle", "stand"])
	elif _attack_windup > 0.0:
		_play_model_animation(["attack", "cast", "spell", "shoot"])
	elif distance > effective_attack_range:
		_play_model_animation(["run", "walk", "move"])
	else:
		_play_model_animation(["idle", "stand"])
	if not _has_aggro:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 3.0 * delta)
	elif distance > effective_attack_range or (not skill_name.is_empty() and distance < preferred_range * 0.55):
		var move_direction := offset.normalized()
		if not skill_name.is_empty() and distance < preferred_range * 0.55:
			move_direction = -move_direction
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed
	else:
		var tangent := Vector3(-offset.z, 0.0, offset.x).normalized() * _strafe_sign
		var learned_strafe := minf(float(_defeat_count) * 0.025, 0.2)
		var strafe_speed := move_speed * ((0.28 + learned_strafe) if not skill_name.is_empty() else (0.12 + learned_strafe * 0.5))
		velocity.x = move_toward(velocity.x, tangent.x * strafe_speed, move_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, tangent.z * strafe_speed, move_speed * 3.0 * delta)
		if _attack_remaining <= 0.0 and _attack_windup <= 0.0:
			_attack_remaining = attack_cooldown
			_attack_windup = 0.38
			if is_instance_valid(_visual):
				_visual.rotation.x = -0.12

	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	if distance > 0.1 and is_instance_valid(_visual):
		_visual.rotation.y = atan2(offset.x, offset.z)
	move_and_slide()


func _setup_articulations() -> void:
	if boss_name.begins_with("Vyrm"):
		_hydra_heads = _find_named_parts(_visual, "vyrm | serpent head")
		_hydra_necks = _find_named_parts(_visual, "vyrm | serpent neck")
		_hydra_legs = _find_named_parts(_visual, "vyrm | rear leg")
		_hydra_feet = _find_named_parts(_visual, "vyrm | rear foot")
		_hydra_tail.append_array(_find_named_parts(_visual, "vyrm | heavy tail"))
		_hydra_tail.append_array(_find_named_parts(_visual, "vyrm | tapering tail"))
		_hydra_tail.append_array(_find_named_parts(_visual, "vyrm | spade tail"))
		for part in _hydra_heads + _hydra_necks + _hydra_legs + _hydra_feet + _hydra_tail:
			_remember_rest_rotation(part)
	elif boss_name.begins_with("Ignivar"):
		var dragon_heads := _find_named_parts(_visual, "ignivar | sculpted continuous head")
		if not dragon_heads.is_empty():
			_dragon_head = dragon_heads[0]
		_dragon_feet = _find_named_parts(_visual, "ignivar | rear claw foot")
		_remember_rest_rotation(_dragon_head)
		for part in _dragon_feet:
			_remember_rest_rotation(part)
		for side in [-1.0, 1.0]:
			var wing_parts := _find_named_parts(_visual, "ignivar | wing %d |" % int(side))
			if wing_parts.is_empty():
				continue
			var wing_joint := Node3D.new()
			wing_joint.name = "WingJointLeft" if side < 0.0 else "WingJointRight"
			wing_joint.position = Vector3(side * 0.45, 2.0, 0.0)
			_visual.add_child(wing_joint)
			for part in wing_parts:
				part.reparent(wing_joint, true)
			_dragon_wings.append(wing_joint)
			_remember_rest_rotation(wing_joint)


func _animate_articulations(is_walking: bool) -> void:
	var stride := sin(_motion_phase * 2.0) if is_walking else 0.0
	var attack_progress := 1.0 - _attack_windup / 0.38
	var attack_swing := sin(clampf(attack_progress, 0.0, 1.0) * PI)
	for index in range(_hydra_heads.size()):
		var phase := _motion_phase * 1.35 + float(index) * 1.7
		_set_part_rotation(_hydra_heads[index], Vector3(
			sin(phase) * 0.09 - attack_swing * 0.24,
			sin(phase * 0.7) * 0.08,
			cos(phase) * 0.07
		))
	for index in range(_hydra_necks.size()):
		var phase := _motion_phase * 1.1 + float(index) * 1.7
		_set_part_rotation(_hydra_necks[index], Vector3(
			sin(phase) * 0.07 - attack_swing * 0.17,
			sin(phase * 0.8) * 0.045,
			cos(phase) * 0.05
		))
	for index in range(_hydra_legs.size()):
		var leg_swing := stride * (1.0 if index == 0 else -1.0)
		_set_part_rotation(_hydra_legs[index], Vector3(leg_swing * 0.2, 0.0, 0.0))
	for index in range(_hydra_feet.size()):
		var foot_swing := stride * (1.0 if index == 0 else -1.0)
		_set_part_rotation(_hydra_feet[index], Vector3(foot_swing * 0.12, 0.0, 0.0))
	for index in range(_hydra_tail.size()):
		var tail_sway := sin(_motion_phase * 1.25 - float(index) * 0.55) * 0.085
		_set_part_rotation(_hydra_tail[index], Vector3(sin(_motion_phase - float(index) * 0.3) * 0.025, tail_sway, 0.0))
	if is_instance_valid(_dragon_head):
		_set_part_rotation(_dragon_head, Vector3(
			sin(_motion_phase) * 0.05 - attack_swing * 0.16,
			sin(_motion_phase * 0.65) * 0.06,
			cos(_motion_phase * 0.65) * 0.045
		))
	for index in range(_dragon_wings.size()):
		_set_part_rotation(
			_dragon_wings[index],
			Vector3((sin(_motion_phase * 2.15) * 0.3 + attack_swing * 0.25) * (1.0 if index == 0 else -1.0), 0.0, sin(_motion_phase * 1.1) * 0.035)
		)
	for index in range(_dragon_feet.size()):
		var foot_swing := stride * (1.0 if index == 0 else -1.0)
		_set_part_rotation(_dragon_feet[index], Vector3(foot_swing * 0.12, 0.0, 0.0))


func _find_named_parts(node: Node, name_fragment: String) -> Array[Node3D]:
	var parts: Array[Node3D] = []
	if node is Node3D and String(node.name).to_lower().contains(name_fragment):
		parts.append(node as Node3D)
	for child in node.get_children():
		parts.append_array(_find_named_parts(child, name_fragment))
	return parts


func _remove_boss_pedestal(node: Node) -> void:
	for child in node.get_children():
		var part_name := String(child.name).to_lower()
		if part_name.contains("stone base") or part_name.contains("bronze rim") or part_name.contains("top surface"):
			child.free()
		else:
			_remove_boss_pedestal(child)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_model_animation(preferred_terms: Array[String]) -> void:
	if not is_instance_valid(_model_animation_player):
		return
	var available := _model_animation_player.get_animation_list()
	for term in preferred_terms:
		for animation_name in available:
			if str(animation_name).to_lower().contains(term):
				if _model_animation_player.current_animation != animation_name:
					_model_animation_player.play(animation_name)
				return


func _remember_rest_rotation(part: Node3D) -> void:
	if is_instance_valid(part):
		_articulation_rest_rotations[part] = part.rotation


func _set_part_rotation(part: Node3D, offset: Vector3) -> void:
	if is_instance_valid(part) and _articulation_rest_rotations.has(part):
		part.rotation = _articulation_rest_rotations[part] + offset


func _create_attack_marker() -> void:
	_attack_marker = MeshInstance3D.new()
	_attack_marker.name = "AttackWarning"
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	_attack_marker.mesh = mesh
	_attack_marker.position.y = collision_height * 0.72
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var warning_colors := {"fire": Color("#ff513f"), "poison": Color("#9ee744"), "frost": Color("#76dfff")}
	var warning_color: Color = warning_colors.get(skill_element, Color("#bd78ff"))
	material.albedo_color = warning_color
	material.emission_enabled = true
	material.emission = warning_color
	material.emission_energy_multiplier = 2.2
	_attack_marker.material_override = material
	_attack_marker.visible = false
	add_child(_attack_marker)


func _finish_attack() -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var distance := global_position.distance_to(_player.global_position)
	if not skill_name.is_empty():
		if distance <= skill_range + 0.5:
			var pattern := _spell_cycle % 3
			_spell_cycle += 1
			if pattern == 0 or distance > preferred_range * 1.5:
				_launch_skill_projectile()
			elif pattern == 1:
				_launch_skill_burst()
			else:
				_launch_skill_volley()
		return
	if distance <= attack_range + 0.8 and _player.has_method("receive_damage"):
		_player.call("receive_damage", attack_damage, self)


func _launch_skill_projectile() -> void:
	var projectile := MeshInstance3D.new()
	projectile.name = "Proyectil_" + skill_element
	var mesh := SphereMesh.new()
	mesh.radius = 0.24 if skill_element != "frost" else 0.3
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	projectile.mesh = mesh
	var colors := {
		"fire": Color("#ff642e"),
		"poison": Color("#89db43"),
		"frost": Color("#6bdcff"),
	}
	var element_color: Color = colors.get(skill_element, Color("#b66bff"))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = element_color
	material.emission_enabled = true
	material.emission = element_color
	material.emission_energy_multiplier = 2.4
	projectile.material_override = material
	var particle_texture := "fire_01.png" if skill_element == "fire" else ("smoke_04.png" if skill_element == "poison" else "magic_03.png")
	var sprite := Sprite3D.new()
	sprite.name = "Resplandor_elemental"
	sprite.texture = load("res://assets/kenney_particle_pack/PNG/" + particle_texture) as Texture2D
	sprite.pixel_size = 0.00075
	var sprite_material := StandardMaterial3D.new()
	sprite_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_material.albedo_texture = sprite.texture
	sprite_material.albedo_color = element_color.lightened(0.45)
	sprite_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sprite_material.emission_enabled = true
	sprite_material.emission = element_color
	sprite_material.emission_energy_multiplier = 1.8
	sprite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite.material_override = sprite_material
	projectile.add_child(sprite)
	var glow := OmniLight3D.new()
	glow.light_color = element_color
	glow.light_energy = 1.4
	glow.omni_range = 3.2
	projectile.add_child(glow)
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * (collision_height * 0.72)
	var target_position := _player.global_position + Vector3.UP * 0.8
	var tween := get_tree().create_tween()
	tween.tween_property(projectile, "global_position", target_position, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_skill_projectile_impact.bind(projectile, target_position))


func _launch_skill_burst() -> void:
	var impact_position := _player.global_position
	var radius := (3.2 if skill_element == "fire" else 2.7) + minf(float(_defeat_count) * 0.16, 0.64)
	_spawn_spell_effect(impact_position, radius, 46)
	if _player.global_position.distance_to(impact_position) <= radius and _player.has_method("receive_damage"):
		_player.call("receive_damage", attack_damage * skill_damage_multiplier * 0.82, self)


func _launch_skill_volley() -> void:
	if not is_instance_valid(_player):
		return
	var origin := global_position + Vector3.UP * (collision_height * 0.72)
	var target := _player.global_position + Vector3.UP * 0.8
	var shot_count := 3 + mini(_defeat_count, 3)
	for shot in range(shot_count):
		var projectile := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.32
		projectile.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = _spell_color().lightened(0.25)
		material.emission_enabled = true
		material.emission = _spell_color()
		material.emission_energy_multiplier = 3.0
		projectile.material_override = material
		var root := get_tree().current_scene
		if root == null:
			return
		root.add_child(projectile)
		projectile.global_position = origin
		var spread_amount := (float(shot) / float(maxi(1, shot_count - 1)) - 0.5) * 1.8
		var spread := Vector3(spread_amount, 0.0, 0.0)
		var destination := target + spread
		var tween := get_tree().create_tween()
		var travel_time := maxf(0.27, 0.48 - float(_defeat_count) * 0.015) + float(shot) * 0.025
		tween.tween_property(projectile, "global_position", destination, travel_time)
		tween.finished.connect(_on_skill_projectile_impact.bind(projectile, destination, 0.34))


func _spell_color() -> Color:
	var colors := {"fire": Color("#ff642e"), "poison": Color("#89db43"), "frost": Color("#6bdcff"), "arcane": Color("#bd78ff")}
	return colors.get(skill_element, Color("#bd78ff"))


func _spawn_spell_effect(effect_position: Vector3, radius: float, particle_count: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var color := _spell_color()
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.84
	ring_mesh.outer_radius = radius
	ring.mesh = ring_mesh
	ring.position = effect_position + Vector3.UP * 0.08
	ring.rotation.x = PI * 0.5
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = color
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 2.5
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_material
	root.add_child(ring)
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = particle_count
	particles.lifetime = 0.7
	particles.direction = Vector3.UP
	particles.spread = 76.0
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0.0, 1.2 if skill_element == "fire" else -0.4, 0.0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.6
	particles.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2(0.36, 0.36)
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.albedo_color = color
	var texture_name := "fire_01.png" if skill_element == "fire" else ("smoke_04.png" if skill_element == "poison" else "magic_03.png")
	particle_material.albedo_texture = load("res://assets/kenney_particle_pack/PNG/" + texture_name) as Texture2D
	particle_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_material.emission_enabled = true
	particle_material.emission = color
	particle_material.emission_energy_multiplier = 2.0
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = particle_material
	particles.mesh = quad
	root.add_child(particles)
	particles.global_position = effect_position + Vector3.UP * 0.25
	particles.emitting = true
	var tween := get_tree().create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.35, 0.55)
	tween.parallel().tween_property(ring_material, "albedo_color:a", 0.0, 0.55)
	tween.finished.connect(ring.queue_free)
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


func _on_skill_projectile_impact(projectile: MeshInstance3D, target_position: Vector3, damage_scale: float = 1.0) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	_spawn_spell_effect(target_position, 1.15, 18)
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	if _player.global_position.distance_to(target_position) <= 1.8 and global_position.distance_to(_player.global_position) <= skill_range + 2.0 and _player.has_method("receive_damage"):
		_player.call("receive_damage", attack_damage * skill_damage_multiplier * damage_scale, self)


func take_damage(amount: float, attacker: Node) -> void:
	if _respawning or amount <= 0.0:
		return
	if MultiplayerSession.is_active() and not multiplayer.is_server():
		request_enemy_damage.rpc_id(1, amount, attacker.get_multiplayer_authority())
		return
	health = maxf(0.0, health - amount * (1.0 - _learned_damage_resistance))
	health_changed.emit(health, max_health)
	if MultiplayerSession.is_active():
		sync_enemy_health.rpc(health, health == 0.0)
	if health == 0.0:
		_defeat(attacker)


@rpc("any_peer", "call_remote", "reliable")
func request_enemy_damage(amount: float, attacker_peer_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != attacker_peer_id:
		return
	if amount > 1000.0 or amount <= 0.0:
		return
	var attacker := get_tree().root.get_node_or_null("World/PeerPlayer_%d" % attacker_peer_id)
	if not is_instance_valid(attacker):
		return
	if attacker.global_position.distance_to(global_position) > 45.0:
		return
	take_damage(amount, attacker)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_enemy_state(position: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_network_target_position = position
	_network_target_yaw = yaw


@rpc("authority", "call_remote", "reliable")
func sync_enemy_health(new_health: float, is_defeated: bool) -> void:
	health = new_health
	_respawning = is_defeated
	health_changed.emit(health, max_health)
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", is_defeated)
	collision_layer = 0 if is_defeated else 2
	collision_mask = 0 if is_defeated else 3
	if is_instance_valid(_visual):
		_visual.visible = not is_defeated


@rpc("authority", "call_remote", "reliable")
func sync_enemy_growth(
		new_max_health: float,
		new_attack_damage: float,
		new_move_speed: float,
		new_attack_cooldown: float,
		new_skill_multiplier: float,
		new_rank: int,
		new_preferred_range: float,
		new_aggression_range: float,
		new_resistance: float,
		new_xp_reward: int
) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	max_health = new_max_health
	attack_damage = new_attack_damage
	move_speed = new_move_speed
	attack_cooldown = new_attack_cooldown
	skill_damage_multiplier = new_skill_multiplier
	_defeat_count = new_rank
	preferred_range = new_preferred_range
	aggression_range = new_aggression_range
	_learned_damage_resistance = new_resistance
	xp_reward = new_xp_reward
	health_changed.emit(health, max_health)


func is_alive() -> bool:
	return not _respawning


func _defeat(attacker: Node) -> void:
	_learn_from_defeat(attacker)
	_respawning = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_collision.set_deferred("disabled", true)
	if is_instance_valid(_visual):
		_visual.visible = false
	defeated.emit(xp_reward)
	if attacker.has_method("grant_experience"):
		if MultiplayerSession.is_active() and multiplayer.is_server() and attacker.get_multiplayer_authority() != 1:
			attacker.call("grant_network_experience", xp_reward)
		else:
			attacker.call("grant_experience", xp_reward)
	_spawn_loot_drop()
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	health = max_health
	if MultiplayerSession.is_active():
		sync_enemy_health.rpc(health, false)
		sync_enemy_growth.rpc(
			max_health, attack_damage, move_speed, attack_cooldown,
			skill_damage_multiplier, _defeat_count, preferred_range,
			aggression_range, _learned_damage_resistance, xp_reward
		)
	_attack_remaining = 1.0
	_attack_windup = 0.0
	_spell_cycle = _defeat_count % 3
	_respawning = false
	collision_layer = 2
	collision_mask = 3
	_collision.set_deferred("disabled", false)
	if is_instance_valid(_visual):
		_visual.visible = true
	_has_aggro = false
	health_changed.emit(health, max_health)


func _learn_from_defeat(attacker: Node) -> void:
	_defeat_count += 1
	if is_instance_valid(attacker):
		var class_value: Variant = attacker.get("_class_id")
		if class_value != null:
			_last_attacker_class = int(class_value)
	var rank := float(_defeat_count)
	max_health = _base_max_health * (1.0 + minf(rank * 0.12, 1.2))
	attack_damage = _base_attack_damage * (1.0 + minf(rank * 0.07, 0.8))
	move_speed = _base_move_speed * (1.0 + minf(rank * 0.025, 0.4))
	attack_cooldown = maxf(_base_attack_cooldown * 0.68, _base_attack_cooldown * (1.0 - rank * 0.025))
	skill_damage_multiplier = _base_skill_damage_multiplier * (1.0 + minf(rank * 0.05, 0.5))
	_learned_damage_resistance = minf(rank * 0.012, 0.16)
	aggression_range = _base_aggression_range + minf(rank * 1.25, 12.0)
	if _last_attacker_class == 0:
		preferred_range = minf(maxf(_base_preferred_range, skill_range * 0.72), 12.0)
	elif _last_attacker_class >= 1:
		preferred_range = maxf(attack_range * 1.6, _base_preferred_range * 0.45)
	else:
		preferred_range = _base_preferred_range
	xp_reward = roundi(float(_base_xp_reward) * (1.0 + minf(rank * 0.04, 0.6)))


func _spawn_loot_drop() -> void:
	var drop_chance := 0.12
	if xp_reward >= 80:
		drop_chance = 0.22
	if xp_reward >= 150:
		drop_chance = 0.38
	if boss_name.begins_with("Ignivar") or boss_name.begins_with("Vyrm"):
		drop_chance = 1.0
	if randf() >= drop_chance:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if MultiplayerSession.is_active():
		spawn_shared_loot.rpc(boss_name, global_position + Vector3.UP * 0.3)
		return
	_create_loot_drop(boss_name, global_position + Vector3.UP * 0.3)


@rpc("authority", "call_local", "reliable")
func spawn_shared_loot(source: String, drop_position: Vector3) -> void:
	_create_loot_drop(source, drop_position)


func _create_loot_drop(source: String, drop_position: Vector3) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var drop := Area3D.new()
	drop.name = "Botin_" + source.replace(" ", "_")
	drop.set_script(load("res://scripts/loot_drop.gd"))
	drop.set("source_name", source)
	scene_root.add_child(drop)
	drop.global_position = drop_position
