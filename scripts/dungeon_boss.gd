extends "res://scripts/enemy.gd"

@export var mechanic_type := "magma"
@export var mechanic_name := "Ataque especial"
@export var mechanic_color := Color("#f58249")

var _special_cooldown := 6.0
var _warning_remaining := 0.0
var _special_cycle := 0
var _special_targets: Array[Vector3] = []
var _warning_markers: Array[MeshInstance3D] = []
var _warning_radii: Array[float] = []
var _mechanic_label: Label3D


func _ready() -> void:
	super._ready()
	_mechanic_label = Label3D.new()
	_mechanic_label.name = "AvisoMecanica"
	_mechanic_label.position.y = collision_height * 1.35
	_mechanic_label.font_size = 28
	_mechanic_label.pixel_size = 0.008
	_mechanic_label.modulate = mechanic_color.lightened(0.45)
	_mechanic_label.visible = false
	add_child(_mechanic_label)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_alive():
		_warning_remaining = 0.0
		_special_cooldown = 6.0
		_clear_warning_markers()
		if is_instance_valid(_mechanic_label):
			_mechanic_label.visible = false
		return
	if is_instance_valid(_mechanic_label) and is_instance_valid(_player):
		_mechanic_label.look_at(_player.global_position + Vector3.UP * 1.5, Vector3.UP)
	if _warning_remaining > 0.0:
		_warning_remaining = maxf(0.0, _warning_remaining - delta)
		_update_warning_markers()
		if _warning_remaining == 0.0:
			_resolve_special_attack()
		return
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	if _special_cooldown == 0.0 and is_instance_valid(_player):
		_begin_special_attack()


func _begin_special_attack() -> void:
	_special_cycle += 1
	_special_targets.clear()
	_warning_radii.clear()
	_clear_warning_markers()
	var phase_two := health <= max_health * 0.5
	var base_radius := 4.2 if not phase_two else 5.0
	if mechanic_type == "nova":
		_special_targets.append(Vector3(global_position.x, 0.0, global_position.z))
		_warning_radii.append(6.0 if not phase_two else 7.5)
	elif mechanic_type == "spores":
		var target := Vector3(_player.global_position.x, 0.0, _player.global_position.z)
		var spread := 2.8 if not phase_two else 3.5
		_special_targets.append(target + Vector3(-spread, 0.0, -spread * 0.5))
		_special_targets.append(target + Vector3(spread, 0.0, -spread * 0.5))
		_special_targets.append(target + Vector3(0.0, 0.0, spread))
		for index in range(3):
			_warning_radii.append(2.3 if not phase_two else 2.8)
	else:
		_special_targets.append(Vector3(_player.global_position.x, 0.0, _player.global_position.z))
		_warning_radii.append(base_radius)
	for index in range(_special_targets.size()):
		_add_warning_marker(_special_targets[index], _warning_radii[index])
	_warning_remaining = 1.7 if not phase_two else 1.25
	_special_cooldown = 11.0 if not phase_two else 7.0
	_mechanic_label.text = mechanic_name.to_upper() + " · ESQUIVA"
	_mechanic_label.visible = true


func _add_warning_marker(target: Vector3, radius: float) -> void:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.07
	mesh.radial_segments = 40
	marker.mesh = mesh
	marker.global_position = target + Vector3.UP * 0.06
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(mechanic_color.r, mechanic_color.g, mechanic_color.b, 0.34)
	material.emission_enabled = true
	material.emission = mechanic_color
	material.emission_energy_multiplier = 1.5
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	marker.material_override = material
	get_tree().current_scene.add_child(marker)
	_warning_markers.append(marker)


func _update_warning_markers() -> void:
	var pulse := 1.0 + absf(sin(_warning_remaining * 13.0)) * 0.12
	for marker in _warning_markers:
		if is_instance_valid(marker):
			marker.scale = Vector3(pulse, 1.0, pulse)


func _resolve_special_attack() -> void:
	if is_instance_valid(_player) and _player.is_inside_tree() and _player.has_method("receive_damage"):
		var player_position := Vector2(_player.global_position.x, _player.global_position.z)
		var damage_multiplier := 2.0 if health > max_health * 0.5 else 2.7
		for index in range(_special_targets.size()):
			var target: Vector3 = _special_targets[index]
			var target_position := Vector2(target.x, target.z)
			if player_position.distance_to(target_position) <= _warning_radii[index]:
				_player.call("receive_damage", attack_damage * damage_multiplier, self)
				break
	_clear_warning_markers()
	_mechanic_label.visible = false


func _clear_warning_markers() -> void:
	for marker in _warning_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_warning_markers.clear()
