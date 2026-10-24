extends Node3D

const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const BOSS_SCRIPT := preload("res://scripts/dungeon_boss.gd")
const PORTAL_SCRIPT := preload("res://scripts/dungeon_portal.gd")

var _config: Dictionary
var _rng := RandomNumberGenerator.new()
var _rock_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _rock_scenes: Array[PackedScene] = []
var _fungus_scene: PackedScene
var _fungus_large_scene: PackedScene


func _ready() -> void:
	_config = _dungeon_config(DungeonState.selected_dungeon_id)
	_rng.seed = hash(DungeonState.selected_dungeon_id) + 18471
	_load_cave_assets()
	_make_materials()
	_build_cavern()
	_add_biome_decorations()
	_create_encounters()
	_create_exit()
	_create_hud()


func _dungeon_config(dungeon_id: String) -> Dictionary:
	var dungeons := {
		"ash_mine": {"name":"Mina de Ceniza", "subtitle":"Galerías del volcán dormido", "accent":Color("#f58249"), "rock":Color("#342b2b"), "floor":Color("#453a35"), "enemy_model":"res://assets/quaternius/species/Imp.glb", "boss_model":"res://assets/quaternius/ultimate_monsters/quaternius-demon.glb", "enemy":"Diablillo de ceniza", "boss":"Ignivar, corazón de magma", "element":"fire", "mechanic":"magma"},
		"frost_grotto": {"name":"Gruta Glacial", "subtitle":"El silencio bajo la montaña", "accent":Color("#75dfff"), "rock":Color("#293b4b"), "floor":Color("#344858"), "enemy_model":"res://assets/quaternius/ultimate_monsters/quaternius-blue-demon.glb", "boss_model":"res://assets/quaternius/ultimate_monsters/quaternius-yeti.glb", "enemy":"Acechador glacial", "boss":"Yeti ancestral", "element":"frost", "mechanic":"nova"},
		"mushroom_nest": {"name":"Nido del Rey Hongo", "subtitle":"Raíces y esporas antiguas", "accent":Color("#a8e85d"), "rock":Color("#30382d"), "floor":Color("#3c4433"), "enemy_model":"res://assets/quaternius/ultimate_monsters/quaternius-green-blob.glb", "boss_model":"res://assets/quaternius/ultimate_monsters/quaternius-mushroom-king.glb", "enemy":"Baba de espora", "boss":"Rey Hongo corrompido", "element":"poison", "mechanic":"spores"},
	}
	return dungeons.get(dungeon_id, dungeons["ash_mine"])


func _load_cave_assets() -> void:
	for asset_path in [
		"res://assets/polyhaven/rock_07/rock_07_1k.gltf",
		"res://assets/polyhaven/boulder_01/boulder_01_1k.gltf",
		"res://assets/godot_store/nature/glTF/Rock_Medium_1.gltf",
		"res://assets/godot_store/nature/glTF/Rock_Medium_3.gltf",
	]:
		var packed := load(asset_path) as PackedScene
		if packed != null:
			_rock_scenes.append(packed)
	_fungus_scene = load("res://assets/godot_store/nature/glTF/Mushroom_Common.gltf") as PackedScene
	_fungus_large_scene = load("res://assets/godot_store/nature/glTF/Mushroom_Laetiporus.gltf") as PackedScene


func _make_materials() -> void:
	_rock_material = _material(_config["rock"], 0.0)
	_floor_material = _material(_config["floor"], 0.0)
	_accent_material = _material(_config["accent"], 2.1)


func _material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _build_cavern() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#080d13")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#66717b")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(_config["rock"]).lightened(0.4)
	environment.fog_density = 0.018
	world_environment.environment = environment
	add_child(world_environment)
	var cavern_sections: Array[Dictionary] = [
		{"start":22.0, "finish":-6.0, "width":14.0},
		{"start":-6.0, "finish":-26.0, "width":5.0},
		{"start":-26.0, "finish":-50.0, "width":16.0},
		{"start":-50.0, "finish":-70.0, "width":5.0},
		{"start":-70.0, "finish":-96.0, "width":18.0},
	]
	for section in cavern_sections:
		var length: float = section["start"] - section["finish"]
		var center_z: float = (section["start"] + section["finish"]) * 0.5
		var width: float = section["width"] * 2.0
		_add_solid_box("Piso rocoso", Vector3(0.0, -0.55, center_z), Vector3(width, 1.0, length + 0.8), _floor_material)
		_add_solid_box("Techo de caverna", Vector3(0.0, 9.0, center_z), Vector3(width + 3.0, 1.8, length + 1.0), _rock_material)
		for side in [-1.0, 1.0]:
			var wall_x: float = side * (section["width"] + 0.65)
			_add_solid_box("Pared cavernosa", Vector3(wall_x, 4.2, center_z), Vector3(1.6, 9.2, length + 0.8), _rock_material)
			_add_wall_relief(side, float(section["width"]), float(section["start"]), float(section["finish"]))
		_add_ceiling_stalactites(float(section["width"]), float(section["start"]), float(section["finish"]))
		_add_cave_light(Vector3(0.0, 3.5, center_z), _config["accent"])
	# Close the exposed corners where a wide chamber meets a narrow corridor.
	_add_section_transition(-6.0, 14.0, 5.0)
	_add_section_transition(-26.0, 16.0, 5.0)
	_add_section_transition(-50.0, 16.0, 5.0)
	_add_section_transition(-70.0, 18.0, 5.0)
	_add_solid_box("Fondo de la caverna", Vector3(0.0, 4.3, -97.0), Vector3(38.0, 9.5, 2.0), _rock_material)
	_add_solid_box("Entrada derrumbada", Vector3(0.0, 4.3, 23.0), Vector3(30.0, 9.5, 2.0), _rock_material)
	_add_crystal_cluster(Vector3(-5.0, 0.0, -34.0))
	_add_crystal_cluster(Vector3(7.0, 0.0, -77.0))
	_add_crystal_cluster(Vector3(-8.0, 0.0, 4.0))


func _add_section_transition(z: float, wide_half_width: float, narrow_half_width: float) -> void:
	var inner_edge := narrow_half_width + 0.25
	var outer_edge := wide_half_width + 1.55
	var wall_width := outer_edge - inner_edge
	for side in [-1.0, 1.0]:
		var x: float = side * (inner_edge + wall_width * 0.5)
		_add_solid_box("Cierre lateral de pasillo", Vector3(x, 4.2, z), Vector3(wall_width, 9.2, 1.8), _rock_material)


func _add_solid_box(label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.collision_layer = 2
	body.collision_mask = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_wall_relief(side: float, half_width: float, start_z: float, finish_z: float) -> void:
	var z := start_z - 1.5
	while z > finish_z + 1.0:
		var rock_position := Vector3(side * (half_width + _rng.randf_range(-0.15, 0.65)), _rng.randf_range(1.4, 6.8), z)
		if not _rock_scenes.is_empty() and _rng.randf() > 0.28:
			var rock_asset := _rock_scenes[_rng.randi_range(0, _rock_scenes.size() - 1)].instantiate() as Node3D
			if rock_asset != null:
				rock_asset.position = rock_position
				var asset_scale := _rng.randf_range(0.65, 1.5)
				rock_asset.scale = Vector3(asset_scale, asset_scale * _rng.randf_range(0.8, 1.4), asset_scale)
				rock_asset.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-PI, PI), _rng.randf_range(-0.2, 0.2))
				add_child(rock_asset)
		else:
			var rock := MeshInstance3D.new()
			var size := _rng.randf_range(1.4, 3.6)
			var mesh := SphereMesh.new()
			mesh.radius = 0.5
			mesh.height = 1.0
			rock.mesh = mesh
			rock.position = rock_position
			rock.scale = Vector3(size * 0.8, size * _rng.randf_range(0.7, 1.5), size * _rng.randf_range(0.9, 1.8))
			rock.material_override = _rock_material
			add_child(rock)
		z -= _rng.randf_range(2.7, 4.8)


func _add_biome_decorations() -> void:
	if DungeonState.selected_dungeon_id != "mushroom_nest":
		return
	if _fungus_scene == null and _fungus_large_scene == null:
		return
	var positions := [
		Vector3(-10.0, 0.0, 8.0), Vector3(10.0, 0.0, 3.0),
		Vector3(-12.0, 0.0, -34.0), Vector3(12.0, 0.0, -40.0),
		Vector3(-14.0, 0.0, -76.0), Vector3(14.0, 0.0, -81.0),
		Vector3(-8.0, 0.0, -4.0), Vector3(8.0, 0.0, -54.0),
	]
	for index in range(positions.size()):
		var fungus_scene := _fungus_large_scene if index % 3 == 0 else _fungus_scene
		if fungus_scene == null:
			continue
		var fungus := fungus_scene.instantiate() as Node3D
		if fungus == null:
			continue
		fungus.position = positions[index]
		fungus.scale = Vector3.ONE * _rng.randf_range(0.8, 1.7)
		fungus.rotation.y = _rng.randf_range(-PI, PI)
		add_child(fungus)


func _add_ceiling_stalactites(half_width: float, start_z: float, finish_z: float) -> void:
	var z := start_z - 2.0
	while z > finish_z:
		var x := _rng.randf_range(-half_width + 1.5, half_width - 1.5)
		if _rng.randf() > 0.35:
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = _rng.randf_range(0.35, 0.8)
			cone.height = _rng.randf_range(1.1, 3.4)
			spike.mesh = cone
			spike.position = Vector3(x, 7.85 - cone.height * 0.5, z)
			spike.material_override = _rock_material
			add_child(spike)
		z -= _rng.randf_range(2.5, 4.6)


func _add_crystal_cluster(position: Vector3) -> void:
	for index in range(3):
		var crystal := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(_rng.randf_range(0.45, 0.9), _rng.randf_range(1.2, 2.4), _rng.randf_range(0.45, 0.9))
		crystal.mesh = mesh
		crystal.position = position + Vector3(float(index - 1) * 0.65, mesh.size.y * 0.5, _rng.randf_range(-0.3, 0.3))
		crystal.rotation.z = _rng.randf_range(-0.18, 0.18)
		crystal.material_override = _accent_material
		add_child(crystal)
	_add_cave_light(position + Vector3(0.0, 1.5, 0.0), _config["accent"])


func _add_cave_light(position: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 15.0
	add_child(light)


func _create_encounters() -> void:
	var monster_scene := load(_config["enemy_model"]) as PackedScene
	var boss_scene := load(_config["boss_model"]) as PackedScene
	if monster_scene == null or boss_scene == null:
		push_error("No se pudo cargar la criatura de esta mazmorra.")
		return
	var encounters := [
		{"name":_config["enemy"], "position":Vector3(2.5, 0.95, -1.0), "health":100.0, "damage":7.0, "xp":45, "scale":0.55},
		{"name":_config["enemy"], "position":Vector3(-3.0, 0.95, -34.0), "health":150.0, "damage":9.0, "xp":65, "scale":0.7},
		{"name":_config["enemy"] + " acechador", "position":Vector3(3.5, 0.95, -22.0), "health":125.0, "damage":8.0, "xp":55, "scale":0.62},
		{"name":_config["enemy"], "position":Vector3(4.0, 0.95, -42.0), "health":165.0, "damage":10.0, "xp":70, "scale":0.72},
		{"name":_config["enemy"] + " guardián", "position":Vector3(-2.5, 0.95, -57.0), "health":185.0, "damage":11.0, "xp":78, "scale":0.76},
		{"name":_config["enemy"], "position":Vector3(-4.0, 0.95, -76.0), "health":200.0, "damage":11.0, "xp":85, "scale":0.78},
		{"name":_config["boss"], "position":Vector3(2.0, 0.95, -85.0), "health":620.0, "damage":17.0, "xp":300, "scale":1.0, "boss":true},
	]
	for encounter in encounters:
		var is_boss: bool = encounter.get("boss", false)
		var encounter_model: PackedScene = boss_scene if is_boss else monster_scene
		var enemy := CharacterBody3D.new()
		enemy.name = str(encounter["name"]).replace(" ", "_")
		enemy.set_script(BOSS_SCRIPT if is_boss else ENEMY_SCRIPT)
		enemy.set("boss_name", encounter["name"])
		enemy.set("max_health", encounter["health"])
		enemy.set("attack_damage", encounter["damage"])
		enemy.set("xp_reward", encounter["xp"])
		enemy.set("move_speed", 1.45 if is_boss else 1.8)
		enemy.set("attack_range", 2.4)
		enemy.set("attack_cooldown", 1.8)
		enemy.set("skill_name", "Aliento cavernario")
		enemy.set("skill_element", _config["element"])
		enemy.set("skill_range", 13.0)
		enemy.set("skill_damage_multiplier", 1.5 if is_boss else 1.25)
		enemy.set("aggression_range", 38.0 if is_boss else 30.0)
		enemy.set("preferred_range", 9.0 if _config["element"] == "fire" else 7.0)
		enemy.set("respawn_delay", 45.0)
		enemy.set("collision_radius", 0.8 if is_boss else 0.55)
		enemy.set("collision_height", 2.4 if is_boss else 1.8)
		enemy.set("model_scene", encounter_model)
		enemy.set("model_scale", encounter["scale"])
		if is_boss:
			enemy.set("mechanic_type", _config["mechanic"])
			enemy.set("mechanic_color", _config["accent"])
			enemy.set("mechanic_name", _boss_mechanic_name())
		enemy.position = encounter["position"]
		add_child(enemy)


func _boss_mechanic_name() -> String:
	match _config["mechanic"]:
		"magma":
			return "Ola de magma"
		"nova":
			return "Nova glacial"
		_:
			return "Lluvia de esporas"


func _create_exit() -> void:
	var exit_portal := Area3D.new()
	exit_portal.name = "PortalDeSalida"
	exit_portal.set_script(PORTAL_SCRIPT)
	exit_portal.set("is_exit", true)
	exit_portal.set("dungeon_name", str(_config["name"]))
	exit_portal.set("portal_color", _config["accent"])
	exit_portal.position = Vector3(0.0, 0.0, -91.0)
	add_child(exit_portal)


func _create_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var title := Label.new()
	title.text = "%s  ·  INSTANCIA" % _config["name"].to_upper()
	title.position = Vector2(24.0, 22.0)
	title.size = Vector2(600.0, 38.0)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", _config["accent"].lightened(0.35))
	hud.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "%s\nBusca el portal de salida al final de la caverna. Pulsa E cerca de un portal." % _config["subtitle"]
	subtitle.position = Vector2(24.0, 58.0)
	subtitle.size = Vector2(420.0, 64.0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("#d8e0e4"))
	hud.add_child(subtitle)
