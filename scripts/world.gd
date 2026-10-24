extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var _asset_scenes: Dictionary[String, PackedScene] = {}
var _tree_instance_count := 0
var _world_environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sunlight: DirectionalLight3D
var _rain_particles: GPUParticles3D
var _time_label: Label
var _day_clock := 0.5
var _weather_clock := 0.0
var _weather_name := "Despejado"
var _weather_index := 0
var _villager_routines: Array[Dictionary] = []
const DAY_CYCLE_SECONDS := 900.0
const WEATHER_CHANGE_SECONDS := 240.0


func _ready() -> void:
	if MultiplayerSession.is_active():
		_setup_network_players()
	_load_environment_assets()
	_create_environment()
	_create_weather_effects()
	_create_ground()
	_create_trails()
	_create_ancient_ruins()
	_create_bosses()
	_create_landmarks()
	_create_dungeon_entrances()
	_create_wilderness()
	_create_settlements()
	_create_castle()
	_create_fauna()
	_create_lake()
	_create_distant_mountains()
	_create_boundary()
	_create_hud()
	_update_world_conditions()


func _setup_network_players() -> void:
	var template := get_node_or_null("Player")
	if is_instance_valid(template):
		template.free()
	var peer_ids: Array[int] = [multiplayer.get_unique_id()]
	for peer_id in multiplayer.get_peers():
		if not peer_ids.has(peer_id):
			peer_ids.append(peer_id)
	peer_ids.sort()
	for peer_id in peer_ids:
		_spawn_network_player(peer_id)
	MultiplayerSession.peer_joined.connect(_on_network_peer_joined)
	MultiplayerSession.peer_left.connect(_on_network_peer_left)
	if not multiplayer.is_server():
		call_deferred("_request_network_player_snapshot")


func _request_network_player_snapshot() -> void:
	if MultiplayerSession.is_active() and not multiplayer.is_server():
		request_network_player_snapshot.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_network_player_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var requesting_peer := multiplayer.get_remote_sender_id()
	var peer_ids: Array[int] = [1]
	for peer_id in multiplayer.get_peers():
		if not peer_ids.has(peer_id):
			peer_ids.append(peer_id)
	for peer_id in peer_ids:
		spawn_network_player.rpc_id(requesting_peer, peer_id)


func _on_network_peer_joined(peer_id: int) -> void:
	if multiplayer.is_server():
		spawn_network_player.rpc(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	if multiplayer.is_server():
		remove_network_player.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func spawn_network_player(peer_id: int) -> void:
	_spawn_network_player(peer_id)


@rpc("authority", "call_local", "reliable")
func remove_network_player(peer_id: int) -> void:
	var player := get_node_or_null("PeerPlayer_%d" % peer_id)
	if is_instance_valid(player):
		player.queue_free()


func _spawn_network_player(peer_id: int) -> void:
	var node_name := "PeerPlayer_%d" % peer_id
	if has_node(node_name):
		return
	var player := PLAYER_SCENE.instantiate() as CharacterBody3D
	if player == null:
		return
	player.name = node_name
	player.set_multiplayer_authority(peer_id)
	var slot := maxi(0, peer_id - 1)
	var angle := float(slot) * 2.4
	player.position = Vector3(cos(angle) * 1.7, 1.0, 4.0 + sin(angle) * 1.7)
	add_child(player)


func _create_dungeon_entrances() -> void:
	var entrances := [
		{"id":"ash_mine", "name":"Mina de Ceniza", "position":Vector3(-8.0, 0.0, -17.0), "color":Color("#f58249")},
		{"id":"frost_grotto", "name":"Gruta Glacial", "position":Vector3(0.0, 0.0, -23.0), "color":Color("#75dfff")},
		{"id":"mushroom_nest", "name":"Nido del Rey Hongo", "position":Vector3(8.0, 0.0, -17.0), "color":Color("#a8e85d")},
	]
	for entrance in entrances:
		var portal := Area3D.new()
		portal.name = str(entrance["id"]).capitalize() + "Portal"
		portal.set_script(load("res://scripts/dungeon_portal.gd"))
		portal.set("dungeon_id", entrance["id"])
		portal.set("dungeon_name", entrance["name"])
		portal.set("portal_color", entrance["color"])
		portal.position = entrance["position"]
		add_child(portal)


func _process(delta: float) -> void:
	_day_clock = fposmod(_day_clock + delta / DAY_CYCLE_SECONDS, 1.0)
	_update_villagers(delta)
	_weather_clock += delta
	if _weather_clock >= WEATHER_CHANGE_SECONDS:
		_weather_clock = 0.0
		_weather_index = (_weather_index + 1) % 3
		_weather_name = ["Despejado", "Lluvia", "Niebla"][_weather_index]
	_update_world_conditions()


func _update_world_conditions() -> void:
	if _world_environment == null or _sky_material == null or _sunlight == null:
		return
	var daylight_curve := sin(TAU * (_day_clock - 0.25))
	var daylight := smoothstep(-0.16, 0.28, daylight_curve)
	_sky_material.sky_top_color = Color("#081426").lerp(Color("#28577e"), daylight)
	_sky_material.sky_horizon_color = Color("#14243d").lerp(Color("#e9bd8c"), daylight)
	_sky_material.ground_bottom_color = Color("#101b24").lerp(Color("#344538"), daylight)
	_sky_material.ground_horizon_color = Color("#253143").lerp(Color("#b6b895"), daylight)
	_sunlight.rotation_degrees.x = lerpf(18.0, -58.0, daylight)
	_sunlight.light_color = Color("#9bb9e8").lerp(Color("#ffe1b1"), daylight)
	_sunlight.light_energy = lerpf(0.08, 1.45, daylight)
	_world_environment.ambient_light_energy = lerpf(0.28, 0.95, daylight)
	_world_environment.fog_density = 0.00135 if _weather_name == "Niebla" else 0.00075
	_world_environment.fog_light_color = Color("#91a2b5") if _weather_name == "Niebla" else Color("#d6c39e")
	if _rain_particles != null:
		_rain_particles.emitting = _weather_name == "Lluvia"
	if _time_label != null:
		var hour := int(_day_clock * 24.0)
		_time_label.text = "%02d:00  |  %s" % [hour, _weather_name]


func _create_weather_effects() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "Lluvia"
	_rain_particles.amount = 900
	_rain_particles.lifetime = 1.25
	_rain_particles.position = Vector3(0.0, 15.0, 0.0)
	_rain_particles.visibility_aabb = AABB(Vector3(-26.0, -4.0, -26.0), Vector3(52.0, 32.0, 52.0))
	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(24.0, 0.0, 24.0)
	rain_process.direction = Vector3(0.0, -1.0, 0.0)
	rain_process.initial_velocity_min = 18.0
	rain_process.initial_velocity_max = 25.0
	rain_process.gravity = Vector3(0.0, -2.0, 0.0)
	_rain_particles.process_material = rain_process
	var rain_mesh := QuadMesh.new()
	rain_mesh.size = Vector2(0.035, 0.42)
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color = Color("#b9d9ed", 0.62)
	rain_mesh.material = rain_material
	_rain_particles.draw_pass_1 = rain_mesh
	_rain_particles.emitting = false
	player.add_child(_rain_particles)


func _create_bosses() -> void:
	var bosses := [
		{"scene": "res://scenes/ignivar.tscn", "position": Vector3(-8.0, 1.9, -39.0)},
		{"scene": "res://scenes/vyrm.tscn", "position": Vector3(9.0, 1.6, -44.0)},
	]
	for boss_data in bosses:
		var packed_boss := load(boss_data["scene"]) as PackedScene
		if packed_boss == null:
			push_error("No se pudo cargar el jefe: %s" % boss_data["scene"])
			continue
		var boss := packed_boss.instantiate() as CharacterBody3D
		if boss == null:
			push_error("La escena del jefe no tiene una raíz CharacterBody3D: %s" % boss_data["scene"])
			continue
		boss.position = boss_data["position"]
		add_child(boss)
	_spawn_monster("Imp de ceniza", "res://assets/quaternius/species/Imp.glb", Vector3(-34.0, 1.0, -66.0), 125.0, 7.0, 45, 2.5, 0.62)
	_spawn_monster("Imp acechador", "res://assets/quaternius/species/Imp.glb", Vector3(35.0, 1.0, -92.0), 145.0, 8.0, 50, 2.8, 0.68)
	_spawn_monster("Imp guardián", "res://assets/quaternius/species/Imp.glb", Vector3(-72.0, 1.0, -134.0), 185.0, 10.0, 65, 2.2, 0.76)
	_spawn_monster("Puglin saqueador", "res://assets/quaternius/species/Puglin.glb", Vector3(78.0, 1.0, 26.0), 170.0, 9.0, 60, 2.3, 0.62)
	_spawn_monster("Puglin cazador", "res://assets/quaternius/species/Puglin.glb", Vector3(-94.0, 1.0, 78.0), 190.0, 10.0, 70, 2.6, 0.66)
	_spawn_monster("Puglin campeón", "res://assets/quaternius/species/Puglin.glb", Vector3(238.0, 1.0, -24.0), 250.0, 13.0, 95, 2.0, 0.72)
	_spawn_monster("Gelatina verde", "res://assets/quaternius/ultimate_monsters/quaternius-green-blob.glb", Vector3(-55.0, 0.8, -82.0), 105.0, 7.0, 40, 2.0, 1.0)
	_spawn_monster("Demonio de brasa", "res://assets/quaternius/ultimate_monsters/quaternius-demon.glb", Vector3(46.0, 1.0, -108.0), 220.0, 12.0, 85, 2.5, 0.78)
	_spawn_monster("Demonio glacial", "res://assets/quaternius/ultimate_monsters/quaternius-blue-demon.glb", Vector3(-112.0, 1.0, -174.0), 270.0, 14.0, 110, 2.3, 0.82)
	_spawn_monster("Rey hongo", "res://assets/quaternius/ultimate_monsters/quaternius-mushroom-king.glb", Vector3(104.0, 1.0, 108.0), 240.0, 11.0, 95, 1.9, 0.82)
	_spawn_monster("Yeti de la cumbre", "res://assets/quaternius/ultimate_monsters/quaternius-yeti.glb", Vector3(-232.0, 1.0, -194.0), 360.0, 16.0, 145, 2.1, 0.92)
	_spawn_monster("Orco quebrantahuesos", "res://assets/quaternius/ultimate_monsters/quaternius-orc.glb", Vector3(198.0, 1.0, 154.0), 330.0, 15.0, 130, 2.4, 0.85)
	_spawn_monster("Alien del bosque", "res://assets/quaternius/ultimate_monsters/quaternius-alien.glb", Vector3(286.0, 1.0, -184.0), 285.0, 13.0, 120, 2.7, 0.85)
	_spawn_monster("Imp de las ruinas", "res://assets/quaternius/species/Imp.glb", Vector3(-48.0, 1.0, 116.0), 155.0, 9.0, 55, 2.9, 0.7)
	_spawn_monster("Puglin chamán", "res://assets/quaternius/species/Puglin.glb", Vector3(124.0, 1.0, -138.0), 225.0, 11.0, 90, 2.0, 0.74)
	_spawn_monster("Gelatina abisal", "res://assets/quaternius/ultimate_monsters/quaternius-green-blob.glb", Vector3(-156.0, 0.8, 42.0), 190.0, 10.0, 75, 1.8, 1.12)
	_spawn_monster("Demonio de la falla", "res://assets/quaternius/ultimate_monsters/quaternius-demon.glb", Vector3(154.0, 1.0, -218.0), 310.0, 16.0, 135, 2.8, 0.9)
	_spawn_monster("Yeti errante", "res://assets/quaternius/ultimate_monsters/quaternius-yeti.glb", Vector3(-282.0, 1.0, 102.0), 410.0, 18.0, 165, 2.35, 0.98)
	_spawn_monster("Orco centinela", "res://assets/quaternius/ultimate_monsters/quaternius-orc.glb", Vector3(252.0, 1.0, 102.0), 390.0, 17.0, 150, 2.55, 0.9)
	_spawn_monster("Alien del claro", "res://assets/quaternius/ultimate_monsters/quaternius-alien.glb", Vector3(18.0, 1.0, -226.0), 320.0, 15.0, 135, 2.9, 0.9)


func _spawn_monster(
		monster_name: String,
		model_path: String,
		spawn_position: Vector3,
		monster_health: float,
		monster_damage: float,
		experience_reward: int,
		monster_speed: float,
		monster_scale: float
) -> void:
	var monster_model := load(model_path) as PackedScene
	if monster_model == null:
		push_error("No se pudo cargar el modelo del monstruo: %s" % model_path)
		return
	var monster := CharacterBody3D.new()
	monster.name = monster_name.replace(" ", "_")
	monster.set_script(load("res://scripts/enemy.gd"))
	monster.set("boss_name", monster_name)
	monster.set("max_health", monster_health)
	monster.set("attack_damage", monster_damage)
	monster.set("xp_reward", experience_reward)
	monster.set("move_speed", monster_speed)
	monster.set("attack_range", 2.2)
	monster.set("attack_cooldown", 1.8)
	monster.set("aggression_range", 42.0 if monster_health >= 250.0 else 34.0)
	var skill_element := "fire"
	var skill_name := "Bola de fuego"
	if monster_name.contains("Puglin") or monster_name.contains("hongo") or monster_name.contains("Gelatina"):
		skill_element = "poison"
		skill_name = "Proyectil tóxico"
	elif monster_name.contains("glacial") or monster_name.contains("Yeti"):
		skill_element = "frost"
		skill_name = "Ráfaga de hielo"
	elif monster_name.contains("Alien"):
		skill_element = "arcane"
		skill_name = "Pulso arcano"
	monster.set("skill_name", skill_name)
	monster.set("skill_element", skill_element)
	monster.set("skill_range", 18.0 if monster_name == "Puglin campeón" or monster_name.contains("Alien") else 14.0)
	monster.set("skill_damage_multiplier", 1.5 if monster_name == "Puglin campeón" or monster_name.contains("Yeti") else 1.35)
	monster.set("preferred_range", 9.0 if skill_element == "fire" or skill_element == "arcane" else 7.0)
	monster.set("collision_radius", 0.62)
	monster.set("collision_height", 1.9)
	monster.set("respawn_delay", 35.0)
	monster.set("model_scene", monster_model)
	monster.set("model_scale", monster_scale)
	monster.position = spawn_position
	add_child(monster)


func _load_environment_assets() -> void:
	var asset_paths := {
		"pine_sapling_small": "res://assets/polyhaven/pine_sapling_small/pine_sapling_small_1k.gltf",
		"fern_02": "res://assets/polyhaven/fern_02/fern_02_1k.gltf",
		"shrub_01": "res://assets/polyhaven/shrub_01/shrub_01_1k.gltf",
		"boulder_01": "res://assets/polyhaven/boulder_01/boulder_01_1k.gltf",
		"rock_07": "res://assets/polyhaven/rock_07/rock_07_1k.gltf",
		"tree_stump_01": "res://assets/polyhaven/tree_stump_01/tree_stump_01_1k.gltf",
		"dead_tree_trunk_02": "res://assets/polyhaven/dead_tree_trunk_02/dead_tree_trunk_02_1k.gltf",
		"stylized_pine": "res://assets/godot_store/nature/glTF/Pine_2.gltf",
		"stylized_tree": "res://assets/godot_store/nature/glTF/CommonTree_3.gltf",
		"village_bush": "res://assets/godot_store/nature/glTF/Bush_Common_Flowers.gltf",
		"village_flowers": "res://assets/godot_store/nature/glTF/Flower_3_Group.gltf",
		"tall_grass": "res://assets/godot_store/nature/glTF/Grass_Common_Tall.gltf",
		"wispy_grass": "res://assets/godot_store/nature/glTF/Grass_Wispy_Tall.gltf",
		"forest_bush": "res://assets/godot_store/nature/glTF/Bush_Common.gltf",
		"forest_mushroom": "res://assets/godot_store/nature/glTF/Mushroom_Common.gltf",
		"autumn_tree": "res://assets/godot_store/nature/glTF/CommonTree_5.gltf",
		"frost_pine": "res://assets/godot_store/nature/glTF/Pine_4.gltf",
		"dead_tree": "res://assets/godot_store/nature/glTF/DeadTree_3.gltf",
		"wildflowers": "res://assets/godot_store/nature/glTF/Flower_4_Group.gltf",
		"clover": "res://assets/godot_store/nature/glTF/Clover_2.gltf",
		"forest_fern": "res://assets/godot_store/nature/glTF/Fern_1.gltf",
		"village_door_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_Plaster_Door_Flat.gltf",
		"village_window_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_Plaster_Window_Wide_Flat.gltf",
		"village_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_Plaster_Straight.gltf",
		"village_stone_door_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_UnevenBrick_Door_Flat.gltf",
		"village_stone_window_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_UnevenBrick_Window_Wide_Flat.gltf",
		"village_stone_wall": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_UnevenBrick_Straight.gltf",
		"castle_stone_door": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Wall_UnevenBrick_Door_Round.gltf",
		"castle_tower_roof": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Roof_Tower_RoundTiles.gltf",
		"village_roof": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Roof_RoundTiles_6x6.gltf",
		"village_chimney": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Prop_Chimney.gltf",
		"village_door": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Door_1_Flat.gltf",
		"village_floor": "res://assets/godot_store/village/Medieval Village MegaKit[Standard]/glTF/Floor_WoodDark.gltf",
	}
	for asset_name in asset_paths:
		var packed_scene := load(asset_paths[asset_name]) as PackedScene
		if packed_scene == null:
			push_error("No se pudo cargar el modelo 3D: %s" % asset_paths[asset_name])
			continue
		_asset_scenes[asset_name] = packed_scene


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	_world_environment = Environment.new()
	var environment: Environment = _world_environment
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("#28577e")
	_sky_material.sky_horizon_color = Color("#e9bd8c")
	_sky_material.ground_bottom_color = Color("#344538")
	_sky_material.ground_horizon_color = Color("#b6b895")
	sky.sky_material = _sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("#d6c39e")
	environment.fog_light_energy = 0.9
	environment.fog_density = 0.00075
	environment.fog_sun_scatter = 0.35
	environment.fog_aerial_perspective = 0.35
	environment.fog_sky_affect = 0.35
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_strength = 0.35
	environment.ssao_enabled = true
	environment.ssao_radius = 2.5
	environment.ssao_intensity = 1.1
	environment.ssao_power = 1.25
	world_environment.environment = environment
	add_child(world_environment)

	_sunlight = DirectionalLight3D.new()
	_sunlight.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	_sunlight.light_color = Color("#ffe1b1")
	_sunlight.light_energy = 1.45
	_sunlight.shadow_enabled = true
	_sunlight.directional_shadow_max_distance = 180.0
	_sunlight.shadow_opacity = 0.8
	add_child(_sunlight)


func _create_ground() -> void:
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	ground_mesh.mesh = plane
	ground_mesh.position.y = -0.12
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_diff_2k.jpg")
	ground_material.albedo_color = Color("#b2c49a")
	ground_material.normal_enabled = true
	ground_material.normal_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_nor_gl_2k.jpg")
	var ground_arm := _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_arm_2k.jpg")
	ground_material.ao_enabled = true
	ground_material.ao_texture = ground_arm
	ground_material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	ground_material.roughness_texture = ground_arm
	ground_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	ground_material.roughness = 0.96
	ground_material.uv1_scale = Vector3(36.0, 36.0, 1.0)
	ground_mesh.material_override = ground_material
	add_child(ground_mesh)

	var ground_body := StaticBody3D.new()
	ground_body.position.y = -0.22
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 0.2, 800.0)
	ground_shape.shape = box
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	_add_box("Spawn Plaza", Vector3(0.0, 0.02, 2.0), Vector3(16.0, 0.16, 16.0), Color(0.38, 0.43, 0.43))
	_add_box("North Walkway", Vector3(0.0, 0.015, -11.0), Vector3(5.0, 0.12, 16.0), Color(0.48, 0.51, 0.48))


func _create_landmarks() -> void:
	_add_pillar("Plaza Beacon West", Vector3(-7.0, 1.5, 2.0), 0.42, 3.0, Color(0.85, 0.72, 0.43))
	_add_pillar("Plaza Beacon East", Vector3(7.0, 1.5, 2.0), 0.42, 3.0, Color(0.85, 0.72, 0.43))

	for tree_position in [
		Vector3(-13.0, 0.0, -5.0),
		Vector3(13.0, 0.0, -5.0),
		Vector3(-14.0, 0.0, 12.0),
		Vector3(14.0, 0.0, 12.0),
	]:
		_add_tree(tree_position, 0.72)


func _create_wilderness() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	# Forest groves make the playable area read as a landscape while leaving a
	# clear opening around the spawn, lake, paths, and settlements.
	for tree_index in range(900):
		var tree_position := Vector3(rng.randf_range(-330.0, 330.0), 0.0, rng.randf_range(-330.0, 330.0))
		if _is_clear_of_settlements(tree_position, 30.0) or _is_open_trail(tree_position, 6.0):
			continue
		if tree_position.length() < 25.0 or (tree_position - Vector3(76.0, 0.0, 73.0)).length() < 32.0 or (tree_position - Vector3(0.0, 0.0, -250.0)).length() < 52.0:
			continue
		_add_tree(tree_position, rng.randf_range(0.82, 1.4), rng.randf_range(-PI, PI))

	for vegetation_index in range(1350):
		var vegetation_position := Vector3(rng.randf_range(-340.0, 340.0), 0.0, rng.randf_range(-340.0, 340.0))
		if _is_clear_of_settlements(vegetation_position, 20.0) or _is_open_trail(vegetation_position, 3.5):
			continue
		if vegetation_position.length() < 18.0 or (vegetation_position - Vector3(76.0, 0.0, 73.0)).length() < 25.0 or (vegetation_position - Vector3(0.0, 0.0, -250.0)).length() < 48.0:
			continue
		var fern_scale := rng.randf_range(0.32, 0.78)
		var ground_plant := "fern_02" if vegetation_index % 3 == 0 else "tall_grass"
		_add_asset_instance(ground_plant, self, vegetation_position, Vector3.ONE * fern_scale, rng.randf_range(-PI, PI))

	for shrub_index in range(250):
		var shrub_position := Vector3(rng.randf_range(-330.0, 330.0), 0.0, rng.randf_range(-330.0, 330.0))
		if _is_clear_of_settlements(shrub_position, 18.0) or _is_open_trail(shrub_position, 3.5):
			continue
		if shrub_position.length() < 28.0 or (shrub_position - Vector3(76.0, 0.0, 73.0)).length() < 29.0 or (shrub_position - Vector3(0.0, 0.0, -250.0)).length() < 45.0:
			continue
		_add_asset_instance("shrub_01", self, shrub_position, Vector3.ONE * rng.randf_range(0.32, 0.58), rng.randf_range(-PI, PI))

	for rock_index in range(185):
		var rock_position := Vector3(rng.randf_range(-350.0, 350.0), 0.0, rng.randf_range(-350.0, 350.0))
		if _is_clear_of_settlements(rock_position, 18.0) or _is_open_trail(rock_position, 3.5):
			continue
		if rock_position.length() < 28.0 or (rock_position - Vector3(76.0, 0.0, 73.0)).length() < 28.0:
			continue
		var rock_asset := "rock_07" if rock_index % 3 != 0 else "boulder_01"
		_add_rock(rock_position, rng.randf_range(0.35, 0.82), rock_asset, rng.randf_range(-PI, PI))

	for debris_index in range(82):
		var debris_position := Vector3(rng.randf_range(-330.0, 330.0), 0.0, rng.randf_range(-330.0, 330.0))
		if _is_clear_of_settlements(debris_position, 18.0) or _is_open_trail(debris_position, 3.5):
			continue
		if debris_position.length() < 25.0 or (debris_position - Vector3(76.0, 0.0, 73.0)).length() < 27.0:
			continue
		var debris_asset := "tree_stump_01" if debris_index % 2 == 0 else "dead_tree_trunk_02"
		_add_asset_instance(debris_asset, self, debris_position, Vector3.ONE * rng.randf_range(0.35, 0.62), rng.randf_range(-PI, PI))
	_create_biome_pockets(rng)


func _create_biome_pockets(rng: RandomNumberGenerator) -> void:
	var biomes := [
		{"name":"Arboleda dorada", "center":Vector3(248.0, 0.0, -250.0), "color":Color("#ae9852"), "tree":"autumn_tree", "ground":"clover", "accent":"wildflowers"},
		{"name":"Pinar de escarcha", "center":Vector3(-250.0, 0.0, -252.0), "color":Color("#76949c"), "tree":"frost_pine", "ground":"wispy_grass", "accent":"forest_fern"},
		{"name":"Humedal de hongos", "center":Vector3(250.0, 0.0, 248.0), "color":Color("#697e55"), "tree":"stylized_tree", "ground":"forest_fern", "accent":"forest_mushroom"},
		{"name":"Tierras de ceniza", "center":Vector3(-248.0, 0.0, 250.0), "color":Color("#82665b"), "tree":"dead_tree", "ground":"wispy_grass", "accent":"forest_bush"},
		{"name":"Bosque esmeralda", "center":Vector3(0.0, 0.0, 286.0), "color":Color("#58764c"), "tree":"stylized_tree", "ground":"forest_fern", "accent":"wildflowers"},
		{"name":"Robledal otoñal", "center":Vector3(-286.0, 0.0, 0.0), "color":Color("#8c7647"), "tree":"autumn_tree", "ground":"clover", "accent":"forest_bush"},
	]
	for biome in biomes:
		var center: Vector3 = biome["center"]
		_add_biome_terrain(str(biome["name"]), center, biome["color"], 72.0, rng)
		for index in range(34):
			var angle := rng.randf_range(0.0, TAU)
			var distance := sqrt(rng.randf()) * 62.0
			var spot := center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if index % 3 == 0:
				_add_asset_instance(str(biome["tree"]), self, spot, Vector3.ONE * rng.randf_range(0.72, 1.24), rng.randf_range(-PI, PI))
			elif index % 3 == 1:
				_add_asset_instance(str(biome["accent"]), self, spot, Vector3.ONE * rng.randf_range(0.65, 1.2), rng.randf_range(-PI, PI))
			else:
				_add_asset_instance(str(biome["ground"]), self, spot, Vector3.ONE * rng.randf_range(0.75, 1.45), rng.randf_range(-PI, PI))
		for tuft in range(74):
			var patch_angle := rng.randf_range(0.0, TAU)
			var patch_radius := sqrt(rng.randf()) * 68.0
			var plant_spot := center + Vector3(cos(patch_angle) * patch_radius, 0.0, sin(patch_angle) * patch_radius)
			_add_asset_instance(str(biome["ground"]), self, plant_spot, Vector3.ONE * rng.randf_range(0.28, 0.62), rng.randf_range(-PI, PI))


func _add_biome_terrain(label: String, center: Vector3, tint: Color, radius: float, rng: RandomNumberGenerator) -> void:
	var rings := 7
	var segments := 56
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3(0.0, -0.095, 0.0))
	colors.append(Color(tint.r, tint.g, tint.b, 0.16))
	uvs.append(Vector2.ZERO)
	for ring in range(1, rings + 1):
		var fraction := float(ring) / float(rings)
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var edge_noise := 1.0 + 0.09 * sin(angle * 5.0 + center.x) + 0.055 * cos(angle * 9.0 + center.z)
			var point_radius := radius * fraction * edge_noise
			var subtle_height := 0.045 * sin(angle * 4.0 + center.x) * fraction + rng.randf_range(-0.012, 0.012)
			vertices.append(Vector3(cos(angle) * point_radius, -0.095 + subtle_height, sin(angle) * point_radius))
			var variation := rng.randf_range(-0.045, 0.045)
			colors.append(Color(clampf(tint.r + variation, 0.0, 1.0), clampf(tint.g + variation, 0.0, 1.0), clampf(tint.b + variation, 0.0, 1.0), 0.16 * pow(1.0 - fraction, 1.5)))
			uvs.append(Vector2(cos(angle) * point_radius, sin(angle) * point_radius) * 0.055)
	for segment in range(segments):
		indices.append_array(PackedInt32Array([0, 1 + (segment + 1) % segments, 1 + segment]))
	for ring in range(1, rings):
		var inner_start := 1 + (ring - 1) * segments
		var outer_start := 1 + ring * segments
		for segment in range(segments):
			var next_segment := (segment + 1) % segments
			indices.append_array(PackedInt32Array([
				inner_start + segment, inner_start + next_segment, outer_start + segment,
				inner_start + next_segment, outer_start + next_segment, outer_start + segment,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var patch := MeshInstance3D.new()
	patch.name = label
	patch.position = center
	patch.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_diff_2k.jpg")
	material.normal_enabled = true
	material.normal_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_nor_gl_2k.jpg")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch.material_override = material
	add_child(patch)


func _is_clear_of_settlements(position: Vector3, radius: float) -> bool:
	for village_center in [Vector3(145.0, 0.0, -105.0), Vector3(-175.0, 0.0, 145.0)]:
		if position.distance_to(village_center) < radius:
			return true
	return false


func _is_open_trail(position: Vector3, width: float) -> bool:
	# Main north trail from the starting plaza, plus paths to the two villages.
	if absf(position.x) < width and position.z < 5.0 and position.z > -180.0:
		return true
	if _distance_to_segment_xz(position, Vector3(0.0, 0.0, -12.0), Vector3(145.0, 0.0, -105.0)) < width:
		return true
	return _distance_to_segment_xz(position, Vector3(0.0, 0.0, 8.0), Vector3(-175.0, 0.0, 145.0)) < width


func _distance_to_segment_xz(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment := Vector2(finish.x - start.x, finish.z - start.z)
	var relative := Vector2(point.x - start.x, point.z - start.z)
	var t := clampf(relative.dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return Vector2(point.x, point.z).distance_to(Vector2(start.x, start.z) + segment * t)


func _create_trails() -> void:
	_add_trail([Vector3(0.0, 0.0, -10.0), Vector3(24.0, 0.0, -29.0), Vector3(73.0, 0.0, -61.0), Vector3(145.0, 0.0, -105.0)], 3.8)
	_add_trail([Vector3(0.0, 0.0, 8.0), Vector3(-38.0, 0.0, 41.0), Vector3(-102.0, 0.0, 95.0), Vector3(-175.0, 0.0, 145.0)], 3.8)


func _add_trail(points: Array, width: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var travelled := 0.0
	for index in range(points.size() - 1):
		var start: Vector3 = points[index]
		var finish: Vector3 = points[index + 1]
		var direction := Vector2(finish.x - start.x, finish.z - start.z).normalized()
		var side := Vector3(-direction.y, 0.0, direction.x) * width * 0.5
		var vertex_index := vertices.size()
		vertices.append_array(PackedVector3Array([start - side + Vector3.UP * 0.015, start + side + Vector3.UP * 0.015, finish - side + Vector3.UP * 0.015, finish + side + Vector3.UP * 0.015]))
		normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
		var segment_length := start.distance_to(finish)
		uvs.append_array(PackedVector2Array([Vector2(0.0, travelled), Vector2(1.0, travelled), Vector2(0.0, travelled + segment_length), Vector2(1.0, travelled + segment_length)]))
		travelled += segment_length
		indices.append_array(PackedInt32Array([vertex_index, vertex_index + 2, vertex_index + 1, vertex_index + 1, vertex_index + 2, vertex_index + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var trail := MeshInstance3D.new()
	trail.name = "Ancient Forest Trail"
	trail.mesh = mesh
	var material := _material(Color("#a39778"))
	material.albedo_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_diff_2k.jpg")
	material.normal_enabled = true
	material.normal_texture = _load_texture("res://assets/polyhaven/forest_ground_04/forest_ground_04_nor_gl_2k.jpg")
	material.uv1_scale = Vector3(0.18, 0.18, 1.0)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = material
	add_child(trail)


func _create_ancient_ruins() -> void:
	# Weathered elven waystone gives the opening area a recognizable destination.
	var stone := Color("#79867a")
	var dark_stone := Color("#4e625d")
	_add_cylinder("Ruined Waystone Ring", Vector3(0.0, 0.045, -22.0), 8.0, 0.12, Color("#777b68"))
	_add_pillar("Waystone Left", Vector3(-5.0, 2.2, -22.0), 0.65, 4.4, stone)
	_add_pillar("Waystone Right", Vector3(5.0, 2.2, -22.0), 0.65, 4.4, stone)
	_add_box("Waystone Lintel", Vector3(0.0, 4.25, -22.0), Vector3(11.0, 0.8, 1.1), dark_stone)
	_add_box("Fallen Ruin", Vector3(-7.2, 0.65, -27.0), Vector3(3.8, 1.3, 1.0), stone)
	_add_box("Broken Ruin", Vector3(7.1, 0.45, -17.0), Vector3(2.4, 0.9, 1.1), dark_stone)
	_add_pillar("Runestone", Vector3(0.0, 1.1, -29.0), 0.4, 2.2, Color("#64a89d"))


func _create_lake() -> void:
	var lake_center := Vector3(76.0, 0.0, 73.0)
	_add_cylinder("Lake Shore", lake_center + Vector3(0.0, -0.085, 0.0), 26.0, 0.06, Color("#807c61"))
	_add_cylinder("Lake Water", lake_center + Vector3(0.0, -0.025, 0.0), 21.0, 0.05, Color("#477c85"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 73021
	for rock_index in range(10):
		var angle := TAU * float(rock_index) / 10.0
		var radius := rng.randf_range(22.0, 27.0)
		var rock_position := lake_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rock_asset := "rock_07" if rock_index % 3 != 0 else "boulder_01"
		_add_rock(rock_position, rng.randf_range(0.32, 0.6), rock_asset, angle)

	_add_pillar("Lake Trail Marker", Vector3(48.0, 1.1, 73.0), 0.32, 2.2, Color("#d5a95f"))


func _create_settlements() -> void:
	_create_village("Valleclaro", Vector3(145.0, 0.0, -105.0), Color("#9c6748"), ["Mara, herborista", "Edrin, herrero", "Tomas, guardia", "Lina, viajera"])
	_create_village("Piedrafría", Vector3(-175.0, 0.0, 145.0), Color("#687d83"), ["Ysolda, mercader", "Borin, minero", "Kael, explorador"])


func _create_village(village_name: String, center: Vector3, roof_color: Color, residents: Array[String]) -> void:
	_add_cylinder(village_name + " plaza", center + Vector3(0.0, 0.015, 0.0), 22.0, 0.08, Color("#95866a"))
	var door_wall_asset := "village_door_wall" if roof_color.r >= roof_color.b else "village_stone_door_wall"
	var window_wall_asset := "village_window_wall" if roof_color.r >= roof_color.b else "village_stone_window_wall"
	var wall_asset := "village_wall" if roof_color.r >= roof_color.b else "village_stone_wall"
	# Irregular street layout, with varied building sizes and orientations.
	var house_layout: Array[Vector4] = [
		Vector4(-16.0, -10.0, 1.0, 0.0),
		Vector4(15.0, -14.0, 1.18, PI * 0.5),
		Vector4(-17.0, 15.0, 0.88, PI),
		Vector4(17.0, 14.0, 1.08, -PI * 0.5),
		Vector4(-1.0, -25.0, 0.82, PI * 0.5),
		Vector4(1.0, 25.0, 0.94, -PI * 0.5),
	]
	for index in range(house_layout.size()):
		var layout := house_layout[index]
		var house_scale := layout.z
		var house := StaticBody3D.new()
		house.name = village_name + " Casa %d" % (index + 1)
		house.position = center + Vector3(layout.x, 0.0, layout.y)
		house.rotation.y = layout.w
		# The kit walls are 2 m wide and start at ground level; build a closed 6 m shell.
		for floor_x in [-2.0, 0.0, 2.0]:
			for floor_z in [-2.0, 0.0, 2.0]:
				_add_asset_instance("village_floor", house, Vector3(floor_x, 0.035, floor_z) * house_scale, Vector3.ONE * house_scale)
		for wall_x in [-2.0, 2.0]:
			_add_asset_instance(wall_asset, house, Vector3(wall_x, 0.0, 3.0) * house_scale, Vector3.ONE * house_scale)
			_add_asset_instance(wall_asset, house, Vector3(wall_x, 0.0, -3.0) * house_scale, Vector3.ONE * house_scale, PI)
		# Front and rear panels sit flush with the side walls; the old ±3 m offsets left open gaps under each roof.
		_add_asset_instance(door_wall_asset, house, Vector3(0.0, 0.0, 2.0) * house_scale, Vector3.ONE * house_scale)
		_add_asset_instance(window_wall_asset, house, Vector3(0.0, 0.0, -2.0) * house_scale, Vector3.ONE * house_scale, PI)
		for side in [-1.0, 1.0]:
			for wall_z in [-2.0, 0.0, 2.0]:
				var side_wall_asset := window_wall_asset if is_zero_approx(wall_z) else wall_asset
				_add_asset_instance(side_wall_asset, house, Vector3(side * 3.0, 0.0, wall_z) * house_scale, Vector3.ONE * house_scale, PI * 0.5)
		_add_asset_instance("village_door", house, Vector3(-0.53, 0.0, 2.12) * house_scale, Vector3.ONE * house_scale)
		_add_asset_instance("village_roof", house, Vector3(0.0, 2.9, 0.0) * house_scale, Vector3.ONE * house_scale)
		_add_asset_instance("village_chimney", house, Vector3(2.1, 2.9, -1.2) * house_scale, Vector3.ONE * house_scale * 0.8)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(6.0, 3.0, 6.0) * house_scale
		collision.shape = shape
		collision.position.y = 1.5 * house_scale
		house.add_child(collision)
		add_child(house)
	_add_pillar(village_name + " pozo", center + Vector3(0.0, 0.55, 0.0), 1.6, 1.1, Color("#6d6b5e"))
	_add_cylinder(village_name + " agua del pozo", center + Vector3(0.0, 0.66, 0.0), 0.92, 0.04, Color("#547e82"))
	_add_pillar(village_name + " farol", center + Vector3(-5.0, 2.2, 5.0), 0.15, 4.4, Color("#bd9655"))
	# A pair of colorful market stalls gives each plaza a clear focal point.
	for stall_index in range(2):
		var stall_offset := Vector3(-7.0 + float(stall_index) * 14.0, 0.0, -5.0)
		_add_box(village_name + " puesto %d" % stall_index, center + stall_offset + Vector3(0.0, 0.8, 0.0), Vector3(3.8, 1.4, 2.2), Color("#79563b"))
		_add_box(village_name + " toldo %d" % stall_index, center + stall_offset + Vector3(0.0, 2.0, 0.0), Vector3(4.4, 0.22, 2.8), roof_color.lightened(0.22 if stall_index == 0 else 0.08))
	for index in range(residents.size()):
		_create_villager(village_name, residents[index], center, center + Vector3(-6.0 + float(index % 3) * 6.0, 0.0, 3.0 + float(index / 3) * 4.0), index)
	# Small garden beds and a fence give the settlement a lived-in edge.
	for garden_offset in [Vector3(-27.0, 0.0, -18.0), Vector3(27.0, 0.0, 18.0), Vector3(28.0, 0.0, -20.0)]:
		_add_box(village_name + " huerto", center + garden_offset + Vector3(0.0, 0.12, 0.0), Vector3(5.0, 0.24, 3.4), Color("#554b38"))
		for plant_index in range(4):
			var plant_position: Vector3 = center + garden_offset + Vector3(-1.8 + plant_index * 1.2, 0.2, 0.0)
			_add_asset_instance("village_bush" if plant_index % 2 == 0 else "village_flowers", self, plant_position, Vector3.ONE * 0.62)


func _add_house_detail(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> void:
	var detail := MeshInstance3D.new()
	detail.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	detail.mesh = mesh
	detail.position = position
	detail.material_override = _material(color)
	parent.add_child(detail)


func _create_castle() -> void:
	# Model-kit masonry and tiled towers replace the former untextured primitive shell.
	var center := Vector3(0.0, 0.0, -250.0)
	_add_cylinder("Castillo | patio", center + Vector3(0.0, 0.025, 0.0), 31.0, 0.08, Color("#8e866f"))
	var wall_span := 4.0
	var wall_scale := Vector3(2.0, 2.0, 2.0)
	for row in range(2):
		var height := float(row) * 6.0
		for module in range(11):
			var offset := -20.0 + float(module) * wall_span
			var asset := "castle_stone_wall"
			if row == 0 and module == 5:
				asset = "castle_stone_door"
			_add_asset_instance(asset, self, center + Vector3(offset, height, -22.0), wall_scale)
			_add_asset_instance("castle_stone_wall", self, center + Vector3(offset, height, 22.0), wall_scale, PI)
			_add_asset_instance("castle_stone_wall", self, center + Vector3(-22.0, height, offset), wall_scale, PI * 0.5)
			_add_asset_instance("castle_stone_wall", self, center + Vector3(22.0, height, offset), wall_scale, -PI * 0.5)
	for corner in [Vector2(-22.0, -22.0), Vector2(22.0, -22.0), Vector2(-22.0, 22.0), Vector2(22.0, 22.0)]:
		var tower := Node3D.new()
		tower.name = "Torre de piedra texturizada"
		tower.position = center + Vector3(corner.x, 0.0, corner.y)
		add_child(tower)
		for row in range(2):
			var tower_y := float(row) * 6.0
			for side in range(2):
				var lateral := -2.0 if side == 0 else 2.0
				_add_asset_instance("castle_stone_wall", tower, Vector3(lateral, tower_y, -4.0), wall_scale)
				_add_asset_instance("castle_stone_wall", tower, Vector3(lateral, tower_y, 4.0), wall_scale, PI)
				_add_asset_instance("castle_stone_wall", tower, Vector3(-4.0, tower_y, lateral), wall_scale, PI * 0.5)
				_add_asset_instance("castle_stone_wall", tower, Vector3(4.0, tower_y, lateral), wall_scale, -PI * 0.5)
		_add_asset_instance("castle_tower_roof", tower, Vector3(0.0, 11.7, 0.0), Vector3.ONE * 1.45)
		_add_banner(tower.global_position + Vector3(0.0, 12.8, 0.0))
	_add_castle_collision("Castillo | colisión norte", center + Vector3(0.0, 6.0, -22.0), Vector3(44.0, 12.0, 3.0))
	_add_castle_collision("Castillo | colisión sur oeste", center + Vector3(-12.0, 6.0, 22.0), Vector3(20.0, 12.0, 3.0))
	_add_castle_collision("Castillo | colisión sur este", center + Vector3(12.0, 6.0, 22.0), Vector3(20.0, 12.0, 3.0))
	_add_castle_collision("Castillo | colisión oeste", center + Vector3(-22.0, 6.0, 0.0), Vector3(44.0, 12.0, 3.0), PI * 0.5)
	_add_castle_collision("Castillo | colisión este", center + Vector3(22.0, 6.0, 0.0), Vector3(44.0, 12.0, 3.0), PI * 0.5)
	# A compact, roofed inner hall gives the courtyard a clear focal silhouette.
	var keep := Node3D.new()
	keep.name = "Torre del homenaje"
	keep.position = center + Vector3(0.0, 0.0, -7.0)
	add_child(keep)
	for index in range(4):
		var angle := float(index) * PI * 0.5
		var side_position := Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0)
		_add_asset_instance("castle_stone_wall", keep, side_position, Vector3(3.0, 3.0, 3.0), angle + PI * 0.5)
		_add_asset_instance("castle_stone_wall", keep, side_position + Vector3.UP * 9.0, Vector3(3.0, 3.0, 3.0), angle + PI * 0.5)
	_add_asset_instance("village_roof", keep, Vector3(0.0, 17.0, 0.0), Vector3.ONE * 2.15)
	_add_castle_collision("Castillo | colisión torre del homenaje", keep.global_position + Vector3(0.0, 8.0, 0.0), Vector3(12.0, 16.0, 12.0))


func _add_castle_collision(label: String, position: Vector3, size: Vector3, rotation_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.rotation.y = rotation_y
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_banner(position: Vector3) -> void:
	_add_pillar("Estandarte | asta", position + Vector3(0.0, 2.0, 0.0), 0.08, 4.0, Color("#b69b65"))
	_add_box("Estandarte | tela", position + Vector3(0.75, 2.0, 0.0), Vector3(1.5, 2.0, 0.12), Color("#8f3f39"))


func _create_fauna() -> void:
	# Stylized deer and foxes built from lightweight meshes; keep paths and homes clear.
	var deer_positions := [Vector3(-42.0, 0.0, -86.0), Vector3(39.0, 0.0, -132.0), Vector3(92.0, 0.0, 28.0), Vector3(-82.0, 0.0, 74.0), Vector3(230.0, 0.0, 40.0), Vector3(-265.0, 0.0, -70.0)]
	for index in range(deer_positions.size()):
		_create_deer(deer_positions[index], index % 2 == 0)
	for fox_position in [Vector3(55.0, 0.0, -12.0), Vector3(-104.0, 0.0, -68.0), Vector3(285.0, 0.0, 215.0), Vector3(-290.0, 0.0, 255.0)]:
		_create_fox(fox_position)


func _create_deer(position: Vector3, antlers: bool) -> void:
	var animal := Node3D.new()
	animal.name = "Ciervo del bosque"
	animal.position = position
	_add_animal_part(animal, "Cuerpo", Vector3(0.0, 1.0, 0.0), Vector3(1.35, 0.75, 0.58), Color("#98704d"))
	_add_animal_part(animal, "Cuello", Vector3(0.0, 1.48, -0.38), Vector3(0.42, 0.78, 0.42), Color("#a9825e"))
	_add_animal_part(animal, "Cabeza", Vector3(0.0, 1.92, -0.63), Vector3(0.48, 0.45, 0.42), Color("#b18a63"))
	_add_animal_part(animal, "Hocico", Vector3(0.0, 1.82, -0.9), Vector3(0.28, 0.22, 0.32), Color("#d1b79a"))
	for x in [-0.42, 0.42]:
		for z in [-0.2, 0.28]:
			_add_animal_part(animal, "Pata", Vector3(x, 0.43, z), Vector3(0.16, 0.72, 0.17), Color("#634a38"))
	if antlers:
		for x in [-0.2, 0.2]:
			_add_animal_part(animal, "Cuerno", Vector3(x, 2.35, -0.58), Vector3(0.12, 0.56, 0.12), Color("#d1bd91"))
	add_child(animal)


func _create_fox(position: Vector3) -> void:
	var animal := Node3D.new()
	animal.name = "Zorro"
	animal.position = position
	_add_animal_part(animal, "Cuerpo", Vector3(0.0, 0.52, 0.0), Vector3(1.0, 0.52, 0.42), Color("#c76d35"))
	_add_animal_part(animal, "Pecho", Vector3(0.0, 0.57, -0.35), Vector3(0.42, 0.5, 0.38), Color("#f0d6ae"))
	_add_animal_part(animal, "Cabeza", Vector3(0.0, 0.86, -0.58), Vector3(0.46, 0.42, 0.42), Color("#cf753a"))
	_add_animal_part(animal, "Cola", Vector3(0.0, 0.48, 0.68), Vector3(0.36, 0.36, 0.88), Color("#ba5e2f"))
	_add_animal_part(animal, "Punta de cola", Vector3(0.0, 0.5, 1.25), Vector3(0.32, 0.32, 0.32), Color("#f3e5ce"))
	for x in [-0.3, 0.3]:
		_add_animal_part(animal, "Oreja", Vector3(x, 1.2, -0.58), Vector3(0.2, 0.42, 0.18), Color("#b95830"))
		_add_animal_part(animal, "Pata", Vector3(x, 0.2, 0.0), Vector3(0.14, 0.4, 0.14), Color("#4f4035"))
	add_child(animal)


func _add_animal_part(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	part.mesh = mesh
	part.position = position
	part.scale = size
	part.material_override = _material(color)
	parent.add_child(part)


func _create_villager(village_name: String, resident_name: String, center: Vector3, position: Vector3, variant: int) -> void:
	var npc := Node3D.new()
	npc.name = resident_name
	npc.position = position
	npc.add_to_group("villager_npcs")
	npc.set_meta("merchant", variant % 4 == 0)
	var villager_avatar := Node3D.new()
	villager_avatar.name = "Aspecto"
	villager_avatar.set_script(load("res://scripts/character_avatar.gd"))
	villager_avatar.call("set_spinning", false)
	villager_avatar.call("apply_profile", {
		"name": resident_name,
		"species": variant % 4,
		"body_type": variant % 2,
		"class": variant % 4,
		"build": variant % 3,
		"height": 0.94 + float(variant % 3) * 0.06,
		"skin": (variant * 2) % 8,
		"face": variant % 4,
		"eyes": variant % 6,
		"hairstyle": (variant + 1) % 6,
		"hair_color": (variant * 3) % 8,
		"outfit": variant % 5,
		"outfit_color": (variant + 2) % 8,
		"accessory": variant % 6,
	})
	npc.add_child(villager_avatar)
	var tag := Label3D.new()
	tag.text = resident_name + ("\nMercader · E" if variant % 4 == 0 else "\nVecino · E")
	tag.position.y = 2.45
	tag.font_size = 28
	tag.pixel_size = 0.008
	tag.modulate = Color("#fff0cf")
	npc.add_child(tag)
	add_child(npc)
	var garden_offset := Vector3(-26.0, 0.0, -17.0) if variant % 2 == 0 else Vector3(26.0, 0.0, 17.0)
	var garden_path_offset := Vector3(-32.0, 0.0, 0.0) if variant % 2 == 0 else Vector3(32.0, 0.0, 0.0)
	var market_offset := Vector3(-7.0, 0.0, -9.0) if variant % 2 == 0 else Vector3(7.0, 0.0, -9.0)
	var route: Array[Dictionary] = [
		{"position": center + market_offset, "activity": "Atendiendo el mercado", "pose": 1},
		{"position": center + Vector3(3.0, 0.0, 0.0), "activity": "Sacando agua del pozo", "pose": 2},
		{"position": center + Vector3(0.0, 0.0, 9.0), "activity": "Cruzando la plaza", "pose": 0},
		{"position": center + garden_path_offset, "activity": "Yendo al huerto", "pose": 0},
		{"position": center + garden_offset, "activity": "Cuidando el huerto", "pose": 3},
		{"position": center + garden_path_offset, "activity": "Volviendo del huerto", "pose": 0},
		{"position": center + Vector3(0.0, 0.0, 9.0), "activity": "Paseando por la plaza", "pose": 0},
		{"position": position, "activity": "Volviendo a casa", "pose": 0},
	]
	_villager_routines.append({
		"npc": npc,
		"avatar": villager_avatar,
		"tag": tag,
		"route": route,
		"route_index": variant % route.size(),
		"wait": float(variant) * 0.7,
		"activity_phase": float(variant),
		"walking": false,
		"speed": 1.35 + float(variant % 3) * 0.12,
	})


func _update_villagers(delta: float) -> void:
	for index in range(_villager_routines.size()):
		var routine: Dictionary = _villager_routines[index]
		var npc := routine["npc"] as Node3D
		var avatar := routine["avatar"] as Node3D
		var tag := routine["tag"] as Label3D
		if not is_instance_valid(npc) or not is_instance_valid(avatar) or not is_instance_valid(tag):
			continue
		var route: Array = routine["route"]
		var route_index := int(routine["route_index"])
		var stop: Dictionary = route[route_index]
		var target: Vector3 = stop["position"]
		var wait_time := float(routine["wait"])
		if wait_time > 0.0:
			wait_time = maxf(0.0, wait_time - delta)
			routine["wait"] = wait_time
			routine["walking"] = false
			routine["activity_phase"] = float(routine["activity_phase"]) + delta
			tag.text = "%s\n%s" % [npc.name, stop["activity"]]
			avatar.call("set_motion", 0.0, true, 0.0, false, delta)
			avatar.call("set_activity_motion", int(stop["pose"]), float(routine["activity_phase"]))
		else:
			var offset := target - npc.position
			offset.y = 0.0
			if offset.length() <= 0.22:
				route_index = (route_index + 1) % route.size()
				routine["route_index"] = route_index
				routine["wait"] = 2.5 + float((index * 3) % 5)
				routine["walking"] = false
			else:
				var direction := offset.normalized()
				npc.position += direction * float(routine["speed"]) * delta
				npc.rotation.y = lerp_angle(npc.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-delta * 6.0))
				routine["walking"] = true
				tag.text = "%s\nCaminando" % npc.name
				avatar.call("set_motion", 0.3, true, 0.0, false, delta)
		_villager_routines[index] = routine


func _create_distant_mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41308
	var mountain_colors := [
		Color("#56675e"),
		Color("#607167"),
		Color("#6d7b6d"),
	]
	for index in range(11):
		var offset := -430.0 + index * 86.0
		var radius := rng.randf_range(58.0, 92.0)
		var height := rng.randf_range(48.0, 92.0)
		var color: Color = mountain_colors[rng.randi_range(0, mountain_colors.size() - 1)]
		_add_mountain(Vector3(offset, 0.0, -420.0), radius, height, color)
		_add_mountain(Vector3(offset, 0.0, 420.0), radius, height * rng.randf_range(0.82, 1.08), color.darkened(0.08))

	for index in range(9):
		var offset := -344.0 + index * 86.0
		var radius := rng.randf_range(58.0, 92.0)
		var height := rng.randf_range(48.0, 92.0)
		var color: Color = mountain_colors[rng.randi_range(0, mountain_colors.size() - 1)]
		_add_mountain(Vector3(-420.0, 0.0, offset), radius, height, color)
		_add_mountain(Vector3(420.0, 0.0, offset), radius, height * rng.randf_range(0.82, 1.08), color.darkened(0.08))


func _create_boundary() -> void:
	_add_boundary_collider("North Boundary", Vector3(0.0, 45.0, -394.0), Vector3(800.0, 90.0, 4.0))
	_add_boundary_collider("South Boundary", Vector3(0.0, 45.0, 394.0), Vector3(800.0, 90.0, 4.0))
	_add_boundary_collider("East Boundary", Vector3(394.0, 45.0, 0.0), Vector3(4.0, 90.0, 800.0))
	_add_boundary_collider("West Boundary", Vector3(-394.0, 45.0, 0.0), Vector3(4.0, 90.0, 800.0))


func _add_boundary_collider(label: String, position: Vector3, size: Vector3) -> void:
	var boundary := StaticBody3D.new()
	boundary.name = label
	boundary.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	boundary.add_child(collision)
	add_child(boundary)


func _create_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var title := Label.new()
	title.text = "TIERRAS DE ELDORIA  |  780 x 780 m"
	title.position = Vector2(958.0, 24.0)
	title.size = Vector2(620.0, 32.0)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 0.94))
	title.add_theme_font_size_override("font_size", 20)
	hud.add_child(title)

	_time_label = Label.new()
	_time_label.position = Vector2(24.0, 24.0)
	_time_label.size = Vector2(280.0, 32.0)
	_time_label.add_theme_color_override("font_color", Color("#f3e4c7"))
	_time_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(_time_label)

	var instructions := Label.new()
	instructions.text = "WASD Mover   SHIFT Correr   ESPACIO Saltar   V Camara\nT Talentos   M Mochila   E Entrar a portales   1-6 Habilidades"
	instructions.position = Vector2(958.0, 58.0)
	instructions.size = Vector2(300.0, 72.0)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_color_override("font_color", Color(0.84, 0.9, 0.87))
	instructions.add_theme_font_size_override("font_size", 15)
	hud.add_child(instructions)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8.0, -18.0)
	crosshair.size = Vector2(24.0, 36.0)
	crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	crosshair.add_theme_font_size_override("font_size", 26)
	hud.add_child(crosshair)


func _add_box(label: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
	return body


func _add_pillar(label: String, position: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_tree(position: Vector3, tree_scale: float = 1.0, rotation: float = 0.0) -> void:
	_tree_instance_count += 1
	var tree_asset := "stylized_tree"
	var instance_scale := tree_scale
	var tree_variant := _tree_instance_count % 10
	if tree_variant >= 7 and tree_variant <= 8:
		tree_asset = "stylized_pine"
		instance_scale *= 0.82
	elif tree_variant == 9:
		tree_asset = "pine_sapling_small"
		instance_scale *= 0.92
	_add_asset_instance(tree_asset, self, position, Vector3.ONE * instance_scale, rotation)


func _add_rock(position: Vector3, rock_scale: float, asset_name: String, rotation: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Rock"
	body.position = position + Vector3(0.0, rock_scale * 0.4, 0.0)
	body.rotation.y = rotation

	_add_asset_instance(asset_name, body, Vector3.ZERO, Vector3.ONE * rock_scale)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = rock_scale * 0.85
	collision.shape = shape
	collision.position.y = rock_scale * 0.25
	body.add_child(collision)
	add_child(body)


func _add_asset_instance(
		asset_name: String,
		parent: Node3D,
		position: Vector3,
		instance_scale: Vector3,
		rotation_y: float = 0.0
) -> Node3D:
	if not _asset_scenes.has(asset_name):
		push_error("No se puede crear la instancia del modelo 3D '%s'." % asset_name)
		return null
	var instance := _asset_scenes[asset_name].instantiate() as Node3D
	if instance == null:
		push_error("El modelo 3D '%s' no tiene una raiz Node3D." % asset_name)
		return null
	instance.position = position
	instance.scale = instance_scale
	instance.rotation.y = rotation_y
	parent.add_child(instance)
	return instance


func _load_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("No se pudo cargar la textura: %s" % path)
	return texture


func _add_cylinder(label: String, position: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	var material := _material(color)
	if label == "Lake Water":
		material.albedo_color = Color("#477c85")
		material.metallic = 0.2
		material.roughness = 0.24
	else:
		material.roughness = 0.95
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _add_mountain(position: Vector3, radius: float, height: float, color: Color) -> void:
	var mountain := MeshInstance3D.new()
	mountain.name = "Ridge Mountain"
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var segments := 48
	var rings := 12
	var phase := position.x * 0.017 + position.z * 0.031
	var peaks: Array[Vector2] = [Vector2(-0.28, -0.08), Vector2(0.17, -0.22), Vector2(0.32, 0.18), Vector2(-0.12, 0.31)]
	for ring in range(rings + 1):
		var fraction := float(ring) / float(rings)
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var jagged := 1.0 + 0.1 * sin(angle * 3.0 + phase) + 0.055 * sin(angle * 7.0 - phase * 0.7) + 0.025 * sin(angle * 13.0 + phase)
			var r := radius * fraction * jagged
			var local_x := cos(angle) * fraction * jagged
			var local_z := sin(angle) * fraction * jagged
			var ridge_height := 0.24 * pow(1.0 - fraction, 0.72)
			for peak_index in range(peaks.size()):
				var peak_center := peaks[peak_index]
				var peak_radius := 0.16 + float(peak_index % 2) * 0.035
				var peak_distance := Vector2(local_x, local_z).distance_to(peak_center)
				var peak := exp(-pow(peak_distance / peak_radius, 2.0) * 1.45) * (0.56 if peak_index % 2 == 0 else 0.46)
				ridge_height = maxf(ridge_height, peak)
			var roughness := 0.045 * sin(angle * 11.0 + phase) * fraction + 0.025 * cos(angle * 17.0 - phase) * fraction
			var summit := maxf(0.0, height * (ridge_height + roughness))
			vertices.append(Vector3(cos(angle) * r, summit, sin(angle) * r))
			var alpine_tint := clampf((summit / height - 0.62) / 0.38, 0.0, 0.5)
			var rock_variation := 0.035 * sin(angle * 9.0 + phase) * fraction
			colors.append(color.lerp(Color("#ded9c8"), alpine_tint).lightened(rock_variation))
			uvs.append(Vector2(cos(angle) * r, sin(angle) * r))
	for ring in range(rings):
		for segment in range(segments):
			var a := ring * segments + segment
			var b := ring * segments + (segment + 1) % segments
			var c := (ring + 1) * segments + segment
			var d := (ring + 1) * segments + (segment + 1) % segments
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var vertex_normals := PackedVector3Array()
	vertex_normals.resize(vertices.size())
	for triangle_index in range(0, indices.size(), 3):
		var first := indices[triangle_index]
		var second := indices[triangle_index + 1]
		var third := indices[triangle_index + 2]
		var face_normal := (vertices[second] - vertices[first]).cross(vertices[third] - vertices[first]).normalized()
		vertex_normals[first] += face_normal
		vertex_normals[second] += face_normal
		vertex_normals[third] += face_normal
	for normal_index in range(vertex_normals.size()):
		vertex_normals[normal_index] = vertex_normals[normal_index].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = vertex_normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mountain.mesh = mesh
	mountain.position = position
	var material := _material(Color.WHITE)
	material.albedo_texture = _load_texture("res://assets/polyhaven/rock_07/textures/rock_07_diff_1k.jpg")
	material.normal_enabled = true
	material.normal_texture = _load_texture("res://assets/polyhaven/rock_07/textures/rock_07_nor_gl_1k.jpg")
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.035, 0.035, 0.035)
	mountain.material_override = material
	add_child(mountain)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
