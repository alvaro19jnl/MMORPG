extends Area3D

@export var dungeon_id := "ash_mine"
@export var dungeon_name := "Mina de Ceniza"
@export var portal_color := Color("#f58249")
@export var is_exit := false

var _player_in_range: CharacterBody3D
var _ring: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("dungeon_entrances")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.4
	shape_node.shape = shape
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_portal_visuals()


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_ring):
		_ring.rotation.z = sin(_time * 1.4) * 0.035
		_ring.scale = Vector3.ONE * (1.0 + sin(_time * 2.1) * 0.025)


func is_player_in_range() -> bool:
	return is_instance_valid(_player_in_range)


func interact() -> void:
	if not is_player_in_range():
		return
	if is_exit:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		DungeonState.selected_dungeon_id = dungeon_id
		get_tree().change_scene_to_file("res://scenes/dungeon.tscn")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = body as CharacterBody3D
		var prompt := "E: Salir al mundo" if is_exit else "E: Entrar a " + dungeon_name
		body.call("set_interaction_prompt", prompt)


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if body.has_method("set_interaction_prompt"):
			body.call("set_interaction_prompt", "")


func _build_portal_visuals() -> void:
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.18
		mesh.bottom_radius = 0.28
		mesh.height = 3.2
		pillar.mesh = mesh
		pillar.position = Vector3(side * 1.45, 1.6, 0.0)
		pillar.material_override = _make_material(Color("#45434a"), 0.08)
		add_child(pillar)
		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 0.25
		crystal_mesh.height = 0.5
		crystal.mesh = crystal_mesh
		crystal.position = Vector3(side * 1.45, 2.85, 0.0)
		crystal.material_override = _make_material(portal_color, 2.0)
		add_child(crystal)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.28
	torus.outer_radius = 1.52
	_ring.mesh = torus
	_ring.position.y = 1.85
	_ring.rotation.x = deg_to_rad(90.0)
	_ring.material_override = _make_material(portal_color, 2.8)
	add_child(_ring)
	var glow := MeshInstance3D.new()
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(2.5, 2.9)
	glow.mesh = glow_mesh
	glow.position = Vector3(0.0, 1.85, 0.16)
	glow.material_override = _make_material(Color(portal_color.r, portal_color.g, portal_color.b, 0.34), 1.2, true)
	add_child(glow)
	var label := Label3D.new()
	label.text = "SALIDA" if is_exit else dungeon_name.to_upper()
	label.position = Vector3(0.0, 3.65, 0.0)
	label.font_size = 32
	label.pixel_size = 0.008
	label.modulate = Color("#fff0cf")
	add_child(label)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.2, 0.4)
	lamp.light_color = portal_color
	lamp.light_energy = 2.0
	lamp.omni_range = 8.0
	add_child(lamp)


func _make_material(color: Color, emission: float, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emission > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = color
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = emission
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
