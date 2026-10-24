extends CharacterBody3D

const AVATAR_SCRIPT := preload("res://scripts/character_avatar.gd")
const COMBAT_HUD_SCRIPT := preload("res://scripts/combat_hud.gd")
const CHARACTER_SAVE_PATH := "user://character.json"
const PROGRESSION_SAVE_PATH := "user://progression.json"
const SETTINGS_SAVE_PATH := "user://settings.cfg"
const CLASS_NAMES := ["Guerrera/o", "Exploradora/or", "Hechicera/o", "Pícara/o"]
const CLASS_TALENTS: Array[Array] = [
	[
		{"id": "sword_damage", "name": "Golpe demoledor", "description": "+15 % de daño con espada.", "branch": "Asalto", "tier": 1, "effect": "damage", "value": 0.15},
		{"id": "warrior_vitality", "name": "Piel de hierro", "description": "+20 % de vida máxima.", "branch": "Bastión", "tier": 1, "effect": "health", "value": 0.2},
		{"id": "sword_haste", "name": "Acero veloz", "description": "Habilidades 10 % más rápidas.", "branch": "Maestría", "tier": 1, "effect": "haste", "value": 0.1},
		{"id": "warrior_cleave", "name": "Tajo amplio", "description": "Aprende Golpe del dragón y aumenta el daño un 5 %.", "branch": "Asalto", "tier": 2, "requires": "sword_damage", "effect": "damage", "value": 0.05, "passive": false, "skill_id": "golpe_dragon"},
		{"id": "warrior_second_wind", "name": "Segundo aliento", "description": "Las curaciones restauran +20 %.", "branch": "Bastión", "tier": 2, "requires": "warrior_vitality", "effect": "healing", "value": 0.2},
		{"id": "warrior_momentum", "name": "Ímpetu", "description": "+8 % de velocidad de movimiento.", "branch": "Maestría", "tier": 2, "requires": "sword_haste", "effect": "speed", "value": 0.08},
		{"id": "warrior_finisher", "name": "Veredicto", "description": "+15 % de daño; +10 % de alcance.", "branch": "Asalto", "tier": 3, "requires": "warrior_cleave", "effect": "damage_range", "value": 0.15},
		{"id": "warrior_fortress", "name": "Fortaleza", "description": "Los golpes recibidos hacen 15 % menos daño.", "branch": "Bastión", "tier": 3, "requires": "warrior_second_wind", "effect": "defense", "value": 0.15},
		{"id": "warrior_mastery", "name": "Maestro de armas", "description": "Probabilidad de crítico +15 %.", "branch": "Maestría", "tier": 3, "requires": "sword_haste", "effect": "critical", "value": 0.15},
	],
	[
		{"id": "bow_damage", "name": "Puntería mortal", "description": "+15 % de daño con arco.", "branch": "Tirador", "tier": 1, "effect": "damage", "value": 0.15},
		{"id": "ranger_vitality", "name": "Superviviente", "description": "+20 % de vida máxima.", "branch": "Supervivencia", "tier": 1, "effect": "health", "value": 0.2},
		{"id": "bow_haste", "name": "Recarga rápida", "description": "Habilidades 10 % más rápidas.", "branch": "Explorador", "tier": 1, "effect": "haste", "value": 0.1},
		{"id": "ranger_headshot", "name": "Tiro certero", "description": "Aprende Flecha perforante y aumenta el crítico un 5 %.", "branch": "Tirador", "tier": 2, "requires": "bow_damage", "effect": "critical", "value": 0.05, "passive": false, "skill_id": "flecha_perforante"},
		{"id": "ranger_regen", "name": "Primeros auxilios", "description": "Las curaciones restauran +25 %.", "branch": "Supervivencia", "tier": 2, "requires": "ranger_vitality", "effect": "healing", "value": 0.25},
		{"id": "ranger_stride", "name": "Zancada veloz", "description": "+10 % de velocidad de movimiento.", "branch": "Explorador", "tier": 2, "requires": "bow_haste", "effect": "speed", "value": 0.1},
		{"id": "ranger_volley", "name": "Lluvia de flechas", "description": "+25 % al daño de area.", "branch": "Tirador", "tier": 3, "requires": "ranger_headshot", "effect": "area", "value": 0.25},
		{"id": "ranger_evasion", "name": "Evasión", "description": "Los golpes recibidos hacen 15 % menos daño.", "branch": "Supervivencia", "tier": 3, "requires": "ranger_regen", "effect": "defense", "value": 0.15},
		{"id": "ranger_mastery", "name": "Cazador experto", "description": "+12 % de daño y +10 % de alcance.", "branch": "Explorador", "tier": 3, "requires": "ranger_stride", "effect": "damage_range", "value": 0.12},
	],
	[
		{"id": "spell_damage", "name": "Poder arcano", "description": "+15 % de daño mágico.", "branch": "Destrucción", "tier": 1, "effect": "damage", "value": 0.15},
		{"id": "mage_vitality", "name": "Barrera mística", "description": "+20 % de vida máxima.", "branch": "Protección", "tier": 1, "effect": "health", "value": 0.2},
		{"id": "spell_haste", "name": "Canalización", "description": "Habilidades 10 % más rápidas.", "branch": "Arcano", "tier": 1, "effect": "haste", "value": 0.1},
		{"id": "mage_flare", "name": "Llama arcana", "description": "Aprende Meteoro y aumenta el daño de área un 5 %.", "branch": "Destrucción", "tier": 2, "requires": "spell_damage", "effect": "area", "value": 0.05, "passive": false, "skill_id": "meteoro"},
		{"id": "mage_ward", "name": "Égida", "description": "Los golpes recibidos hacen 15 % menos daño.", "branch": "Protección", "tier": 2, "requires": "mage_vitality", "effect": "defense", "value": 0.15},
		{"id": "mage_focus", "name": "Enfoque", "description": "Probabilidad de crítico +12 %.", "branch": "Arcano", "tier": 2, "requires": "spell_haste", "effect": "critical", "value": 0.12},
		{"id": "mage_cataclysm", "name": "Cataclismo", "description": "+15 % de daño y +10 % de alcance.", "branch": "Destrucción", "tier": 3, "requires": "mage_flare", "effect": "damage_range", "value": 0.15},
		{"id": "mage_absorption", "name": "Absorción", "description": "Las curaciones restauran +25 %.", "branch": "Protección", "tier": 3, "requires": "mage_ward", "effect": "healing", "value": 0.25},
		{"id": "mage_mastery", "name": "Maestría arcana", "description": "Habilidades 10 % más rápidas.", "branch": "Arcano", "tier": 3, "requires": "mage_focus", "effect": "haste", "value": 0.1},
	],
	[
		{"id": "dagger_damage", "name": "Filo letal", "description": "+15 % de daño con daga.", "branch": "Asesino", "tier": 1, "effect": "damage", "value": 0.15},
		{"id": "rogue_vitality", "name": "Paso evasivo", "description": "+20 % de vida máxima.", "branch": "Sombra", "tier": 1, "effect": "health", "value": 0.2},
		{"id": "dagger_crit", "name": "Golpe oportuno", "description": "+20 % de probabilidad crítica.", "branch": "Trampero", "tier": 1, "effect": "critical", "value": 0.2},
		{"id": "rogue_bleed", "name": "Herida profunda", "description": "Aprende Paso sombrío y acelera tus habilidades un 5 %.", "branch": "Asesino", "tier": 2, "requires": "dagger_damage", "effect": "haste", "value": 0.05, "passive": false, "skill_id": "paso_sombrio"},
		{"id": "rogue_shadow", "name": "Manto sombrío", "description": "Los golpes recibidos hacen 15 % menos daño.", "branch": "Sombra", "tier": 2, "requires": "rogue_vitality", "effect": "defense", "value": 0.15},
		{"id": "rogue_trap", "name": "Trampa experta", "description": "Habilidades 10 % más rápidas.", "branch": "Trampero", "tier": 2, "requires": "dagger_crit", "effect": "haste", "value": 0.1},
		{"id": "rogue_execution", "name": "Ejecución", "description": "+12 % de daño y +10 % de alcance.", "branch": "Asesino", "tier": 3, "requires": "rogue_bleed", "effect": "damage_range", "value": 0.12},
		{"id": "rogue_recovery", "name": "Repliegue", "description": "Las curaciones restauran +25 %.", "branch": "Sombra", "tier": 3, "requires": "rogue_shadow", "effect": "healing", "value": 0.25},
		{"id": "rogue_mastery", "name": "Maestro de sombras", "description": "Probabilidad de crítico +12 %.", "branch": "Trampero", "tier": 3, "requires": "rogue_trap", "effect": "critical", "value": 0.12},
	],
]
const CLASS_ABILITIES: Array[Array] = [
	[
		{"id": "corte", "name": "Corte de espada", "description": "Tajo directo.", "effect": "single", "range": 4.0, "damage": 35.0, "cooldown": 0.65, "radius": 0.0},
		{"id": "golpe", "name": "Golpe sísmico", "description": "Estalla alrededor del objetivo.", "effect": "area", "range": 10.0, "damage": 30.0, "cooldown": 4.0, "radius": 4.0},
		{"id": "carga", "name": "Carga de batalla", "description": "Embiste al objetivo.", "effect": "single", "range": 14.0, "damage": 46.0, "cooldown": 6.0, "radius": 0.0},
		{"id": "guardia", "name": "Guardia firme", "description": "Reduce el próximo daño recibido.", "effect": "guard", "range": 0.0, "damage": 0.0, "cooldown": 12.0, "radius": 0.0},
		{"id": "barrido", "name": "Barrido del acero", "description": "Daño en un amplio círculo.", "effect": "area", "range": 8.0, "damage": 40.0, "cooldown": 8.0, "radius": 5.0},
		{"id": "aliento", "name": "Segundo aliento", "description": "Recupera salud.", "effect": "heal", "range": 0.0, "damage": 0.0, "cooldown": 18.0, "radius": 0.0},
	],
	[
		{"id": "flecha", "name": "Disparo certero", "description": "Flecha de precisión.", "effect": "single", "range": 34.0, "damage": 27.0, "cooldown": 0.55, "radius": 0.0},
		{"id": "multi", "name": "Lluvia de flechas", "description": "Impacto en área.", "effect": "area", "range": 30.0, "damage": 26.0, "cooldown": 5.0, "radius": 4.5},
		{"id": "veneno", "name": "Flecha ponzoñosa", "description": "Veneno explosivo.", "effect": "area", "range": 26.0, "damage": 20.0, "cooldown": 8.0, "radius": 3.5},
		{"id": "voltereta", "name": "Voltereta evasiva", "description": "Rueda hacia delante y recupera salud.", "effect": "dash", "range": 0.0, "damage": 0.0, "cooldown": 12.0, "radius": 0.0},
		{"id": "trampa", "name": "Trampa explosiva", "description": "Trampa de daño en área.", "effect": "area", "range": 20.0, "damage": 44.0, "cooldown": 10.0, "radius": 5.5},
		{"id": "marca", "name": "Marca del cazador", "description": "Ataque de largo alcance.", "effect": "single", "range": 42.0, "damage": 58.0, "cooldown": 14.0, "radius": 0.0},
	],
	[
		{"id": "rayo", "name": "Rayo arcano", "description": "Proyectil de energía.", "effect": "single", "range": 28.0, "damage": 31.0, "cooldown": 0.7, "radius": 0.0},
		{"id": "fuego", "name": "Bola de fuego", "description": "Explosión ígnea.", "effect": "area", "range": 24.0, "damage": 36.0, "cooldown": 5.0, "radius": 4.5},
		{"id": "hielo", "name": "Nova de escarcha", "description": "Estallido de hielo cercano.", "effect": "area", "range": 12.0, "damage": 24.0, "cooldown": 7.0, "radius": 6.0},
		{"id": "parpadeo", "name": "Barrera arcana", "description": "Absorbe parte del próximo golpe.", "effect": "guard", "range": 0.0, "damage": 0.0, "cooldown": 12.0, "radius": 0.0},
		{"id": "tormenta", "name": "Tormenta de relámpagos", "description": "Rayo devastador de área.", "effect": "area", "range": 26.0, "damage": 60.0, "cooldown": 14.0, "radius": 5.5},
		{"id": "sanacion", "name": "Pulso vital", "description": "Recupera salud.", "effect": "heal", "range": 0.0, "damage": 0.0, "cooldown": 18.0, "radius": 0.0},
	],
	[
		{"id": "daga", "name": "Puñalada", "description": "Ataque veloz.", "effect": "single", "range": 3.6, "damage": 29.0, "cooldown": 0.32, "radius": 0.0},
		{"id": "abanico", "name": "Abanico de cuchillas", "description": "Cuchillas en area.", "effect": "area", "range": 12.0, "damage": 27.0, "cooldown": 4.0, "radius": 4.0},
		{"id": "veneno", "name": "Nube tóxica", "description": "Estallido de veneno.", "effect": "area", "range": 16.0, "damage": 24.0, "cooldown": 7.0, "radius": 3.5},
		{"id": "sombra", "name": "Manto de sombras", "description": "Reduce el próximo daño recibido.", "effect": "guard", "range": 0.0, "damage": 0.0, "cooldown": 12.0, "radius": 0.0},
		{"id": "emboscada", "name": "Emboscada", "description": "Ataque crítico a distancia.", "effect": "single", "range": 16.0, "damage": 62.0, "cooldown": 9.0, "radius": 0.0},
		{"id": "cura", "name": "Retirada táctica", "description": "Recupera salud.", "effect": "heal", "range": 0.0, "damage": 0.0, "cooldown": 18.0, "radius": 0.0},
	],
]
const TALENT_SKILLS := [
	{"talent": "warrior_cleave", "id": "golpe_dragon", "name": "Golpe del dragón", "description": "Tajo ígneo de medio alcance.", "effect": "area", "range": 12.0, "damage": 68.0, "cooldown": 14.0, "radius": 5.0},
	{"talent": "ranger_headshot", "id": "flecha_perforante", "name": "Flecha perforante", "description": "Disparo de gran alcance y daño.", "effect": "single", "range": 58.0, "damage": 82.0, "cooldown": 12.0, "radius": 0.0},
	{"talent": "mage_flare", "id": "meteoro", "name": "Meteoro", "description": "Impacto arcano en una gran área.", "effect": "area", "range": 35.0, "damage": 78.0, "cooldown": 16.0, "radius": 7.0},
	{"talent": "rogue_bleed", "id": "paso_sombrio", "name": "Paso sombrío", "description": "Emboscada de largo alcance.", "effect": "single", "range": 22.0, "damage": 76.0, "cooldown": 13.0, "radius": 0.0},
]
const CLASS_SPEEDS: Array[Vector3] = [
	Vector3(0.92, 0.92, 0.97),
	Vector3(1.0, 1.08, 1.02),
	Vector3(0.96, 0.94, 1.12),
	Vector3(1.06, 1.12, 1.0),
]
const SPECIES_HEALTH := [1.0, 0.92, 1.18, 1.12, 0.86, 1.08]

@export var walk_speed: float = 6.0
@export var sprint_speed: float = 8.5
@export var ground_acceleration: float = 16.0
@export var ground_deceleration: float = 19.0
@export var air_acceleration: float = 6.5
@export var jump_height: float = 1.65
@export var jump_cut_multiplier: float = 0.48
@export var fall_gravity_multiplier: float = 1.55
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var mouse_sensitivity: float = 0.002

const MAX_FALL_SPEED := 26.0
const MAX_LEVEL := 50
const CAMERA_BOB_FREQUENCY := 10.5
const CAMERA_BOB_AMPLITUDE := 0.035

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _third_person := false
var _avatar: Node3D
var _combat_hud: CanvasLayer
var _class_id := 0
var _species_id := 0
var _level := 1
var _experience := 0
var _talent_points := 0
var _gold := 100
var _attribute_points := 0
var _attributes: Dictionary = {"strength": 0, "vitality": 0, "agility": 0, "intellect": 0}
var _unlocked_talents: Array[String] = []
var _talent_ranks: Dictionary = {}
const MAX_TALENT_RANK := 1
var _hotbar_ids: Array[String] = []
var _skill_cooldowns: Array[float] = []
var _progression_data: Dictionary = {"classes": {}}
var _progression_save_path := PROGRESSION_SAVE_PATH
var _keybinds: Dictionary = {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"sprint": KEY_SHIFT, "jump": KEY_SPACE, "pause": KEY_ESCAPE, "camera": KEY_V,
	"talents": KEY_T, "inventory": KEY_M, "interact": KEY_E, "respawn": KEY_R,
	"spellbook": KEY_B,
	"ability_1": KEY_1, "ability_2": KEY_2, "ability_3": KEY_3,
	"ability_4": KEY_4, "ability_5": KEY_5, "ability_6": KEY_6,
}
var _rebinding_action := ""
static var _talent_trees_extended := false
var _health := 100.0
var _max_health := 100.0
var _hud_update_remaining := 0.0
var _is_dead := false
var _death_message := ""
var _spawn_position := Vector3.ZERO
var _damage_multiplier := 1.0
var _cooldown_multiplier := 1.0
var _speed_multiplier := 1.0
var _critical_chance := 0.0
var _healing_multiplier := 1.0
var _area_multiplier := 1.0
var _range_multiplier := 1.0
var _damage_reduction := 0.0
const INVENTORY_CAPACITY := 24
var _inventory: Array[Dictionary] = []
var _equipment: Dictionary = {"weapon": {}, "head": {}, "chest": {}, "legs": {}}
var _guard_charges := 0
var _guard_reduction := 0.65
var _dash_remaining := 0.0
var _dash_direction := Vector3.ZERO
var _attack_animation_remaining := 0.0
var _attack_animation_phase := 0.0
var _aim_target: Node3D
var _aim_target_remaining := 0.0
var _hit_flash_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _coyote_remaining := 0.0
var _jump_cut_applied := false
var _bob_phase := 0.0
var _landing_recoil := 0.0
var _camera_lean := 0.0
var _base_camera_position := Vector3.ZERO
var _base_head_position := Vector3(0.0, 0.62, 0.0)
var _network_send_remaining := 0.0
var _network_target_position := Vector3.ZERO
var _network_target_yaw := 0.0
var _network_target_head_pitch := 0.0
var _network_profile: Dictionary = {}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(48.0)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	collision_mask = 3
	add_to_group("player")
	_spawn_position = global_position
	_base_camera_position = camera.position
	_base_head_position = head.position
	_load_game_settings()
	_network_target_position = global_position
	_network_target_yaw = rotation.y
	_network_target_head_pitch = head.rotation.x
	if not MultiplayerSession.is_active() or is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true
	else:
		camera.current = false
	_create_avatar()
	if not MultiplayerSession.is_active() or is_multiplayer_authority():
		_create_combat_hud()
	else:
		_third_person = true
		_avatar.visible = true


func _process(delta: float) -> void:
	if MultiplayerSession.is_active():
		if is_multiplayer_authority():
			_network_send_remaining -= delta
			if _network_send_remaining <= 0.0:
				_network_send_remaining = 0.08
				receive_player_state.rpc(global_position, rotation.y, head.rotation.x, _network_profile)
		else:
			global_position = global_position.lerp(_network_target_position, 1.0 - exp(-delta * 14.0))
			rotation.y = lerp_angle(rotation.y, _network_target_yaw, 1.0 - exp(-delta * 14.0))
			head.rotation.x = lerpf(head.rotation.x, _network_target_head_pitch, 1.0 - exp(-delta * 14.0))
			if is_instance_valid(_avatar):
				_avatar.call("set_motion", 0.0, true, 0.0, false, delta)
			return
	_hud_update_remaining -= delta
	if _hud_update_remaining <= 0.0:
		_hud_update_remaining = 0.15
		_update_combat_hud()


func _unhandled_input(event: InputEvent) -> void:
	if MultiplayerSession.is_active() and not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if not _rebinding_action.is_empty():
			for action_name in _keybinds:
				if action_name != _rebinding_action and int(_keybinds[action_name]) == event.keycode:
					_combat_hud.call("update_options_key", _rebinding_action, int(_keybinds[_rebinding_action]))
					_combat_hud.call("set_message", "Esa tecla ya está asignada a otra acción.")
					_rebinding_action = ""
					return
			_keybinds[_rebinding_action] = event.keycode
			_combat_hud.call("update_options_key", _rebinding_action, event.keycode)
			_combat_hud.call("set_message", "Tecla asignada: %s" % OS.get_keycode_string(event.keycode))
			_rebinding_action = ""
			_save_game_settings()
			return
		if _combat_hud.call("is_options_open"):
			if event.keycode == int(_keybinds["pause"]):
				_resume_game()
			return
		var ability_slot: int = _ability_slot_for_key(event.keycode)
		if ability_slot >= 0:
			_cast_ability(ability_slot)
		elif event.keycode == int(_keybinds["pause"]):
			if is_instance_valid(_combat_hud) and _combat_hud.call("is_market_open"):
				_combat_hud.call("close_market")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_inventory_open"):
				_combat_hud.call("close_inventory")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_talent_menu_open"):
				_combat_hud.call("close_talent_tree")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_spellbook_open"):
				_combat_hud.call("close_spellbook")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_ability_picker_open"):
				_combat_hud.call("close_ability_picker")
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_toggle_options_menu()
		elif event.keycode == int(_keybinds["camera"]):
			_toggle_camera()
		elif event.keycode == int(_keybinds["jump"]):
			_jump_buffer_remaining = jump_buffer_time
		elif event.keycode == int(_keybinds["talents"]):
			_toggle_talent_menu()
		elif event.keycode == int(_keybinds["inventory"]):
			_toggle_inventory()
		elif event.keycode == int(_keybinds["spellbook"]):
			_toggle_spellbook()
		elif event.keycode == int(_keybinds["interact"]):
			_try_dungeon_interaction()
		elif event.keycode == int(_keybinds["respawn"]) and _is_dead:
			_respawn()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _combat_hud.call("is_options_open"):
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_cast_ability(0)
		else:
			if is_instance_valid(_combat_hud) and _combat_hud.call("is_talent_menu_open"):
				_combat_hud.call("close_talent_tree")
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_ability_picker_open"):
				_combat_hud.call("close_ability_picker")
			elif is_instance_valid(_combat_hud) and _combat_hud.call("is_spellbook_open"):
				_combat_hud.call("close_spellbook")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if _combat_hud.call("is_options_open"):
			return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if MultiplayerSession.is_active() and not is_multiplayer_authority():
		velocity = Vector3.ZERO
		return
	if _is_dead:
		velocity = Vector3.ZERO
		return
	if is_instance_valid(_combat_hud) and _combat_hud.call("is_options_open"):
		velocity = Vector3.ZERO
		return
	if global_position.y < -12.0:
		receive_damage(_max_health * 10.0)
		if _is_dead:
			_death_message = "Has caído al vacío. Reapareces en 3 segundos."
			_combat_hud.call("set_message", _death_message)
		return
	for index in range(_skill_cooldowns.size()):
		_skill_cooldowns[index] = maxf(0.0, _skill_cooldowns[index] - delta)
	_attack_animation_remaining = maxf(0.0, _attack_animation_remaining - delta)
	_aim_target_remaining = maxf(0.0, _aim_target_remaining - delta)
	if _aim_target_remaining <= 0.0 and is_instance_valid(_aim_target):
		_set_attack_aim_target(null)
	_hit_flash_remaining = maxf(0.0, _hit_flash_remaining - delta)
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	var was_on_floor := is_on_floor()
	if was_on_floor:
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)

	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	var input_direction := Vector2(
		float(_is_action_key_pressed("move_right")) - float(_is_action_key_pressed("move_left")),
		float(_is_action_key_pressed("move_back")) - float(_is_action_key_pressed("move_forward"))
	).normalized()
	var move_direction := global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	move_direction.y = 0.0
	move_direction = move_direction.normalized()
	var sprinting := _is_action_key_pressed("sprint") and input_direction.length_squared() > 0.0
	var target_speed := (sprint_speed if sprinting else walk_speed) * _speed_multiplier
	var target_velocity := _dash_direction * 13.0 if _dash_remaining > 0.0 else move_direction * target_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := ground_acceleration if was_on_floor else air_acceleration
	if move_direction == Vector3.ZERO and was_on_floor:
		acceleration = ground_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = sqrt(2.0 * gravity * jump_height)
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0
		_jump_cut_applied = false
	elif not was_on_floor:
		var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		if not _is_action_key_pressed("jump") and not _jump_cut_applied and velocity.y > 0.0:
			velocity.y -= gravity * (1.0 - jump_cut_multiplier) * delta
			gravity_scale = 1.0
			_jump_cut_applied = true
		velocity.y = maxf(velocity.y - gravity * gravity_scale * delta, -MAX_FALL_SPEED)
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var impact_velocity := velocity.y
	move_and_slide()
	var landed := not was_on_floor and is_on_floor()
	if landed:
		_landing_recoil = clampf(absf(impact_velocity) * 0.014, 0.035, 0.15)
	_update_camera_motion(delta, input_direction, sprinting, landed)
	if is_instance_valid(_avatar):
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if _aim_target_remaining > 0.0 and is_instance_valid(_aim_target) and _aim_target.is_inside_tree():
			var target_direction := _aim_target.global_position - global_position
			target_direction.y = 0.0
			var local_target_direction := global_basis.inverse() * target_direction
			var target_avatar_yaw := atan2(local_target_direction.x, local_target_direction.z)
			_avatar.rotation.y = lerp_angle(_avatar.rotation.y, target_avatar_yaw, 1.0 - exp(-delta * 14.0))
		elif input_direction.length_squared() > 0.0:
			var target_avatar_yaw := PI + atan2(-input_direction.x, -input_direction.y)
			_avatar.rotation.y = lerp_angle(_avatar.rotation.y, target_avatar_yaw, 1.0 - exp(-delta * 7.0))
		_avatar.call("set_motion", horizontal_speed / sprint_speed, is_on_floor(), velocity.y, sprinting, delta)
		if _avatar.has_method("set_attack_motion"):
			_avatar.call(
				"set_attack_motion",
				_attack_animation_remaining / 0.48,
				_attack_animation_phase,
				_class_id
			)


func _update_camera_motion(delta: float, input_direction: Vector2, sprinting: bool, landed: bool) -> void:
	if landed:
		_landing_recoil = maxf(_landing_recoil, 0.04)
	_landing_recoil = move_toward(_landing_recoil, 0.0, delta * 0.8)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(horizontal_speed / sprint_speed, 0.0, 1.0)
	if is_on_floor() and horizontal_speed > 0.15:
		_bob_phase += delta * CAMERA_BOB_FREQUENCY * lerpf(0.72, 1.35, speed_ratio)
	else:
		_bob_phase = lerpf(_bob_phase, 0.0, delta * 3.0)

	var grounded_bob := 1.0 if is_on_floor() else 0.18
	var bob_strength := CAMERA_BOB_AMPLITUDE * speed_ratio * grounded_bob
	var bob_offset := Vector3(
		cos(_bob_phase * 0.5) * bob_strength * 0.55,
		absf(sin(_bob_phase)) * bob_strength + clampf(-velocity.y * 0.004, -0.025, 0.045),
		0.0
	)
	var camera_target := _base_camera_position + bob_offset
	var target_fov := 82.0 if sprinting else 78.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 5.0))
	head.position.y = lerpf(head.position.y, _base_head_position.y - _landing_recoil, 1.0 - exp(-delta * 12.0))
	camera.position = camera.position.lerp(camera_target, 1.0 - exp(-delta * 12.0))

	var target_lean := -input_direction.x * deg_to_rad(2.2) * speed_ratio
	_camera_lean = lerpf(_camera_lean, target_lean, 1.0 - exp(-delta * 7.0))
	camera.rotation.z = _camera_lean


@rpc("any_peer", "call_remote", "unreliable_ordered")
func receive_player_state(position: Vector3, yaw: float, head_pitch: float, profile: Dictionary) -> void:
	if not MultiplayerSession.is_active() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_network_target_position = position
	_network_target_yaw = yaw
	_network_target_head_pitch = head_pitch
	if not profile.is_empty() and profile != _network_profile and is_instance_valid(_avatar):
		_network_profile = profile.duplicate(true)
		_avatar.call("apply_profile", profile)


func _create_avatar() -> void:
	_avatar = Node3D.new()
	_avatar.name = "CharacterAppearance"
	_avatar.position.y = -0.9
	_avatar.rotation.y = PI
	_avatar.visible = false
	_avatar.set_script(AVATAR_SCRIPT)
	add_child(_avatar)
	_avatar.call("set_spinning", false)

	if not FileAccess.file_exists(CHARACTER_SAVE_PATH):
		_load_progression()
		_recalculate_combat_stats()
		_health = _max_health
		return
	var file := FileAccess.open(CHARACTER_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo leer el personaje guardado (error %d)." % FileAccess.get_open_error())
		_load_progression()
		_recalculate_combat_stats()
		_health = _max_health
		return
	var profile: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not profile is Dictionary:
		push_error("El archivo de personaje guardado no contiene un perfil válido.")
		_load_progression()
		_recalculate_combat_stats()
		_health = _max_health
		return
	_network_profile = profile.duplicate(true)
	_class_id = clampi(int(profile.get("class", 0)), 0, 3)
	_species_id = clampi(int(profile.get("species", 0)), 0, 5)
	_load_progression()
	var species_walk := [1.0, 1.04, 0.95, 0.92, 1.0, 0.98]
	var species_sprint := [1.0, 1.04, 0.94, 0.9, 1.06, 1.0]
	var species_jump := [1.0, 1.06, 0.96, 0.9, 1.12, 0.92]
	profile["clean_preview"] = true
	walk_speed *= CLASS_SPEEDS[_class_id].x * species_walk[_species_id]
	sprint_speed *= CLASS_SPEEDS[_class_id].y * species_sprint[_species_id]
	jump_height *= CLASS_SPEEDS[_class_id].z * species_jump[_species_id]
	_avatar.call("apply_profile", profile)
	_recalculate_combat_stats()
	_health = _max_health


func _load_progression() -> void:
	_extend_talent_trees()
	if not FileAccess.file_exists(PROGRESSION_SAVE_PATH):
		_load_hotbar([])
		return
	var file := FileAccess.open(PROGRESSION_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo leer la progresión (error %d)." % FileAccess.get_open_error())
		_load_hotbar([])
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("classes", {}) is Dictionary:
		push_error("El archivo de progresión no contiene datos válidos.")
		_load_hotbar([])
		return
	_progression_data = parsed
	_reset_saved_character_progression()
	_migrate_talent_point_economy()

	var classes: Dictionary = _progression_data["classes"]
	var saved: Variant = classes.get(str(_class_id), {})
	if not saved is Dictionary:
		push_error("La progresión guardada para esta clase no es válida.")
		_load_hotbar([])
		return
	_level = clampi(int(saved.get("level", 1)), 1, MAX_LEVEL)
	_experience = maxi(0, int(saved.get("experience", 0)))
	_talent_points = maxi(0, int(saved.get("talent_points", 0)))
	_gold = maxi(0, int(saved.get("gold", 100)))
	var saved_attributes: Variant = saved.get("attributes", {})
	for attribute_id in _attributes:
		_attributes[attribute_id] = maxi(0, int(saved_attributes.get(attribute_id, 0))) if saved_attributes is Dictionary else 0
	var spent_attribute_points := 0
	for value in _attributes.values():
		spent_attribute_points += int(value)
	_attribute_points = maxi(0, int(saved.get("attribute_points", _level - 1 - spent_attribute_points)))
	_unlocked_talents.clear()
	_talent_ranks.clear()
	var saved_talents: Variant = saved.get("talents", [])
	if saved_talents is Array:
		for talent_id in saved_talents:
			if talent_id is String and _is_valid_talent(talent_id) and not _unlocked_talents.has(talent_id):
				_unlocked_talents.append(talent_id)
	var saved_ranks: Variant = saved.get("talent_ranks", {})
	for talent_id in _unlocked_talents:
		_talent_ranks[talent_id] = clampi(int(saved_ranks.get(talent_id, 1)) if saved_ranks is Dictionary else 1, 1, MAX_TALENT_RANK)
	_load_hotbar(saved.get("hotbar", []))
	var saved_inventory: Variant = saved.get("inventory", [])
	if saved_inventory is Array:
		_inventory.clear()
		for item in saved_inventory:
			if item is Dictionary and _inventory.size() < INVENTORY_CAPACITY:
				_inventory.append(item)
	var saved_equipment: Variant = saved.get("equipment", {})
	if saved_equipment is Dictionary:
		for slot in _equipment:
			var item: Variant = saved_equipment.get(slot, {})
			_equipment[slot] = item if item is Dictionary else {}
	_recalculate_combat_stats()


func _reset_saved_character_progression() -> void:
	if bool(_progression_data.get("level_one_reset_applied_v1", false)):
		return
	var classes: Dictionary = _progression_data.get("classes", {})
	for class_key in classes:
		var saved: Variant = classes[class_key]
		if not saved is Dictionary:
			continue
		saved["level"] = 1
		saved["experience"] = 0
		saved["talent_points"] = 0
		saved["talent_ranks"] = {}
		saved["talents"] = []
		saved["attribute_points"] = 0
		saved["attributes"] = {"strength":0, "vitality":0, "agility":0, "intellect":0}
		classes[class_key] = saved
	_progression_data["classes"] = classes
	_progression_data["level_one_reset_applied_v1"] = true
	var file := FileAccess.open(_progression_save_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar el reinicio de niveles (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(_progression_data, "\t"))
	file.close()


func _migrate_talent_point_economy() -> void:
	if bool(_progression_data.get("talent_points_per_level_v2", false)):
		return
	var classes: Dictionary = _progression_data.get("classes", {})
	for class_key in classes:
		var saved: Variant = classes[class_key]
		if not saved is Dictionary:
			continue
		var class_index := clampi(int(class_key), 0, CLASS_TALENTS.size() - 1)
		var valid_talents: Array[String] = []
		var old_talents: Variant = saved.get("talents", [])
		if old_talents is Array:
			for talent_id in old_talents:
				if talent_id is String and not valid_talents.has(talent_id):
					for talent in CLASS_TALENTS[class_index]:
						if talent["id"] == talent_id:
							valid_talents.append(talent_id)
							break
		var level := clampi(int(saved.get("level", 1)), 1, 20)
		var ranks: Dictionary = {}
		for talent_id in valid_talents:
			ranks[talent_id] = 1
		saved["talents"] = valid_talents
		saved["talent_ranks"] = ranks
		saved["talent_points"] = maxi(0, level - 1 - valid_talents.size())
		classes[class_key] = saved
	_progression_data["classes"] = classes
	_progression_data["talent_points_per_level_v2"] = true
	var file := FileAccess.open(_progression_save_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo actualizar los puntos de talento guardados (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(_progression_data, "\t"))
	file.close()


func _extend_talent_trees() -> void:
	if _talent_trees_extended:
		return
	_talent_trees_extended = true
	var additions: Array[Array] = [
		[
			{"id":"warrior_onslaught", "name":"Asalto imparable", "description":"+18 % de daño y +5 % de crítico.", "branch":"Asalto", "tier":4, "requires":"warrior_finisher", "effect":"damage", "value":0.18},
			{"id":"warrior_bulwark", "name":"Baluarte", "description":"+15 % de vida y +8 % de reducción de daño.", "branch":"Bastión", "tier":4, "requires":"warrior_fortress", "effect":"defense", "value":0.08},
			{"id":"warrior_blade_dance", "name":"Danza de acero", "description":"+15 % de velocidad de habilidades.", "branch":"Maestría", "tier":4, "requires":"warrior_mastery", "effect":"haste", "value":0.15},
			{"id":"warrior_avatar", "name":"Avatar de guerra", "description":"+25 % de daño con armas.", "branch":"Asalto", "tier":5, "requires":"warrior_onslaught", "effect":"damage", "value":0.25},
			{"id":"warrior_unbroken", "name":"Inquebrantable", "description":"+25 % de vida máxima.", "branch":"Bastión", "tier":5, "requires":"warrior_bulwark", "effect":"health", "value":0.25},
			{"id":"warrior_champion", "name":"Campeón", "description":"+15 % de crítico y +10 % de velocidad.", "branch":"Maestría", "tier":5, "requires":"warrior_blade_dance", "effect":"critical", "value":0.15}
		],
		[
			{"id":"ranger_deadeye", "name":"Ojo de halcón", "description":"+20 % de daño a distancia.", "branch":"Tirador", "tier":4, "requires":"ranger_volley", "effect":"damage", "value":0.2},
			{"id":"ranger_nature", "name":"Resistencia natural", "description":"+10 % de reducción de daño.", "branch":"Supervivencia", "tier":4, "requires":"ranger_evasion", "effect":"defense", "value":0.1},
			{"id":"ranger_wind", "name":"Viento a favor", "description":"+15 % de velocidad y alcance.", "branch":"Explorador", "tier":4, "requires":"ranger_mastery", "effect":"speed", "value":0.15},
			{"id":"ranger_storm", "name":"Tormenta de flechas", "description":"+30 % de daño de área.", "branch":"Tirador", "tier":5, "requires":"ranger_deadeye", "effect":"area", "value":0.3},
			{"id":"ranger_last_stand", "name":"Último refugio", "description":"+25 % de vida máxima.", "branch":"Supervivencia", "tier":5, "requires":"ranger_nature", "effect":"health", "value":0.25},
			{"id":"ranger_legend", "name":"Cazador legendario", "description":"+20 % de daño y crítico.", "branch":"Explorador", "tier":5, "requires":"ranger_wind", "effect":"critical", "value":0.2}
		],
		[
			{"id":"mage_singularity", "name":"Singularidad", "description":"+22 % de daño mágico.", "branch":"Destrucción", "tier":4, "requires":"mage_cataclysm", "effect":"damage", "value":0.22},
			{"id":"mage_aegis", "name":"Égida superior", "description":"+12 % de reducción de daño.", "branch":"Protección", "tier":4, "requires":"mage_absorption", "effect":"defense", "value":0.12},
			{"id":"mage_flow", "name":"Flujo arcano", "description":"+15 % de velocidad de habilidades.", "branch":"Arcano", "tier":4, "requires":"mage_mastery", "effect":"haste", "value":0.15},
			{"id":"mage_annihilation", "name":"Aniquilación", "description":"+30 % de daño de área.", "branch":"Destrucción", "tier":5, "requires":"mage_singularity", "effect":"area", "value":0.3},
			{"id":"mage_phoenix", "name":"Fénix", "description":"+25 % de vida máxima.", "branch":"Protección", "tier":5, "requires":"mage_aegis", "effect":"health", "value":0.25},
			{"id":"mage_archon", "name":"Archimago", "description":"+20 % de crítico.", "branch":"Arcano", "tier":5, "requires":"mage_flow", "effect":"critical", "value":0.2}
		],
		[
			{"id":"rogue_assassin", "name":"Asesino experto", "description":"+22 % de daño.", "branch":"Asesino", "tier":4, "requires":"rogue_execution", "effect":"damage", "value":0.22},
			{"id":"rogue_vanish", "name":"Desvanecerse", "description":"+12 % de reducción de daño.", "branch":"Sombra", "tier":4, "requires":"rogue_recovery", "effect":"defense", "value":0.12},
			{"id":"rogue_reflex", "name":"Reflejos de sombra", "description":"+15 % de velocidad de habilidades.", "branch":"Trampero", "tier":4, "requires":"rogue_mastery", "effect":"haste", "value":0.15},
			{"id":"rogue_deathmark", "name":"Marca mortal", "description":"+30 % de crítico.", "branch":"Asesino", "tier":5, "requires":"rogue_assassin", "effect":"critical", "value":0.3},
			{"id":"rogue_night", "name":"Noche eterna", "description":"+25 % de vida máxima.", "branch":"Sombra", "tier":5, "requires":"rogue_vanish", "effect":"health", "value":0.25},
			{"id":"rogue_master_trap", "name":"Maestro de trampas", "description":"+20 % de daño de área.", "branch":"Trampero", "tier":5, "requires":"rogue_reflex", "effect":"area", "value":0.2}
		]
	]
	for class_index in range(CLASS_TALENTS.size()):
		CLASS_TALENTS[class_index].append_array(additions[class_index])
	var specializations: Array[Array] = [
		[
			{"id":"warrior_bloodlust","name":"Sed de batalla","description":"Los críticos infligen más daño.","branch":"Asalto","tier":4,"requires":"warrior_finisher","effect":"critical","value":0.12},
			{"id":"warrior_phalanx","name":"Formación de hierro","description":"Reduce el daño recibido.","branch":"Bastión","tier":4,"requires":"warrior_fortress","effect":"defense","value":0.08},
			{"id":"warrior_vanguard","name":"Vanguardia","description":"Aumenta la velocidad de movimiento.","branch":"Maestría","tier":4,"requires":"warrior_mastery","effect":"speed","value":0.1},
			{"id":"warrior_executioner","name":"Ejecutor","description":"Aumenta el daño de forma notable.","branch":"Asalto","tier":5,"requires":"warrior_bloodlust","effect":"damage","value":0.2},
			{"id":"warrior_last_wall","name":"Último bastión","description":"Gran aumento de vida máxima.","branch":"Bastión","tier":5,"requires":"warrior_phalanx","effect":"health","value":0.2},
			{"id":"warrior_warlord","name":"Señor de guerra","description":"Mejora el daño y el alcance.","branch":"Maestría","tier":5,"requires":"warrior_vanguard","effect":"damage_range","value":0.15}
		],
		[
			{"id":"ranger_piercing","name":"Punta perforante","description":"Aumenta el daño de tus ataques.","branch":"Tirador","tier":4,"requires":"ranger_volley","effect":"damage","value":0.16},
			{"id":"ranger_camouflage","name":"Camuflaje","description":"Reduce el daño recibido.","branch":"Supervivencia","tier":4,"requires":"ranger_evasion","effect":"defense","value":0.08},
			{"id":"ranger_pathfinder","name":"Trotamundos","description":"Aumenta velocidad y alcance.","branch":"Explorador","tier":4,"requires":"ranger_stride","effect":"speed","value":0.12},
			{"id":"ranger_barrage","name":"Andanada","description":"Aumenta el daño de área.","branch":"Tirador","tier":5,"requires":"ranger_piercing","effect":"area","value":0.24},
			{"id":"ranger_endurance","name":"Resistencia salvaje","description":"Aumenta la vida máxima.","branch":"Supervivencia","tier":5,"requires":"ranger_camouflage","effect":"health","value":0.2},
			{"id":"ranger_predator","name":"Depredador","description":"Más daño y probabilidad crítica.","branch":"Explorador","tier":5,"requires":"ranger_pathfinder","effect":"critical","value":0.16}
		],
		[
			{"id":"mage_scorch","name":"Quemadura arcana","description":"Aumenta el daño mágico.","branch":"Destrucción","tier":4,"requires":"mage_cataclysm","effect":"damage","value":0.18},
			{"id":"mage_barrier","name":"Barrera de maná","description":"Reduce el daño recibido.","branch":"Protección","tier":4,"requires":"mage_ward","effect":"defense","value":0.08},
			{"id":"mage_quickcast","name":"Conjuración veloz","description":"Reduce la recarga de habilidades.","branch":"Arcano","tier":4,"requires":"mage_focus","effect":"haste","value":0.12},
			{"id":"mage_supernova","name":"Supernova","description":"Gran mejora al daño de área.","branch":"Destrucción","tier":5,"requires":"mage_scorch","effect":"area","value":0.25},
			{"id":"mage_sanctuary","name":"Santuario","description":"Aumenta la vida máxima.","branch":"Protección","tier":5,"requires":"mage_barrier","effect":"health","value":0.2},
			{"id":"mage_timewarp","name":"Distorsión temporal","description":"Acelera aún más tus habilidades.","branch":"Arcano","tier":5,"requires":"mage_quickcast","effect":"haste","value":0.12}
		],
		[
			{"id":"rogue_precision","name":"Precisión letal","description":"Aumenta el daño y el crítico.","branch":"Asesino","tier":4,"requires":"rogue_execution","effect":"critical","value":0.14},
			{"id":"rogue_smoke","name":"Bomba de humo","description":"Reduce el daño recibido.","branch":"Sombra","tier":4,"requires":"rogue_shadow","effect":"defense","value":0.08},
			{"id":"rogue_fleet","name":"Pies ligeros","description":"Aumenta velocidad y alcance.","branch":"Trampero","tier":4,"requires":"rogue_trap","effect":"speed","value":0.12},
			{"id":"rogue_assassinate","name":"Asesinato","description":"Aumenta mucho el daño crítico.","branch":"Asesino","tier":5,"requires":"rogue_precision","effect":"damage","value":0.2},
			{"id":"rogue_umbra","name":"Umbra","description":"Aumenta la vida máxima.","branch":"Sombra","tier":5,"requires":"rogue_smoke","effect":"health","value":0.2},
			{"id":"rogue_snare","name":"Trampa mortal","description":"Aumenta el daño de área.","branch":"Trampero","tier":5,"requires":"rogue_fleet","effect":"area","value":0.22}
		]
	]
	for class_index in range(CLASS_TALENTS.size()):
		CLASS_TALENTS[class_index].append_array(specializations[class_index])
	var expansion_paths: Array[Array] = [
		[
			{"key":"warrior_assault","branch":"Asalto","root":"sword_damage","names":["Tajo de guerra","Filo sangriento","Corte devastador","Avatar del acero"],"effects":["damage","critical","damage","area"]},
			{"key":"warrior_bastion","branch":"Bastión","root":"warrior_vitality","names":["Guardia de hierro","Piel endurecida","Muralla viviente","Corazón de piedra"],"effects":["defense","health","defense","health"]},
			{"key":"warrior_mastery","branch":"Maestría","root":"sword_haste","names":["Ritmo de combate","Paso firme","Maestría marcial","Leyenda de guerra"],"effects":["haste","speed","damage_range","critical"]}
		],
		[
			{"key":"ranger_sharpshooter","branch":"Tirador","root":"bow_damage","names":["Flecha precisa","Punta afilada","Disparo mortal","Ojo infalible"],"effects":["damage","critical","damage","area"]},
			{"key":"ranger_survivor","branch":"Supervivencia","root":"ranger_vitality","names":["Vendaje rápido","Instinto salvaje","Piel de corteza","Último superviviente"],"effects":["healing","health","defense","health"]},
			{"key":"ranger_explorer","branch":"Explorador","root":"bow_haste","names":["Paso del viento","Manos veloces","Cazador incansable","Flecha viajera"],"effects":["speed","haste","range","damage_range"]}
		],
		[
			{"key":"mage_destruction","branch":"Destrucción","root":"spell_damage","names":["Chispa arcana","Llama creciente","Ruptura mágica","Sol abrasador"],"effects":["damage","area","damage","critical"]},
			{"key":"mage_protection","branch":"Protección","root":"mage_vitality","names":["Velo protector","Barrera vital","Égida mayor","Bastión arcano"],"effects":["defense","health","healing","health"]},
			{"key":"mage_arcane","branch":"Arcano","root":"spell_haste","names":["Flujo de maná","Canalización","Mente enfocada","Tiempo detenido"],"effects":["haste","critical","range","haste"]}
		],
		[
			{"key":"rogue_assassin","branch":"Asesino","root":"dagger_damage","names":["Corte preciso","Sangrado","Ejecución veloz","Muerte certera"],"effects":["critical","damage","haste","damage_range"]},
			{"key":"rogue_shadow","branch":"Sombra","root":"rogue_vitality","names":["Velo oscuro","Esquiva umbría","Retirada segura","Sombra eterna"],"effects":["defense","speed","health","defense"]},
			{"key":"rogue_trapper","branch":"Trampero","root":"dagger_crit","names":["Trampa de alambre","Dosis tóxica","Red mortal","Maestro emboscador"],"effects":["area","damage","critical","area"]}
		]
	]
	for class_index in range(expansion_paths.size()):
		for path in expansion_paths[class_index]:
			var previous_id: String = path["root"]
			for step in range(4):
				var effect: String = path["effects"][step]
				var value := 0.1 if effect in ["damage", "area", "defense", "health", "haste", "critical", "healing"] else 0.12
				var new_id := "%s_%d" % [path["key"], step + 2]
				CLASS_TALENTS[class_index].append({
					"id": new_id,
					"name": path["names"][step],
					"description": "%s: mejora tu especialización en esta rama." % effect.capitalize(),
					"branch": path["branch"],
					"tier": step + 2,
					"requires": previous_id,
					"effect": effect,
					"value": value,
				})
				previous_id = new_id
	var master_paths: Array[Array] = [
		[
			{"key":"warrior_warlord","branch":"Asalto","root":"sword_damage","names":["Golpe del titán","Sed de batalla","Ruptura de guardia","Rey de la arena"],"effects":["damage","area","critical","damage_range"]},
			{"key":"warrior_guardian","branch":"Bastión","root":"warrior_vitality","names":["Escudo firme","Acero templado","Voto protector","Baluarte eterno"],"effects":["defense","health","healing","health"]},
			{"key":"warrior_duelist","branch":"Maestría","root":"sword_haste","names":["Paso de duelista","Contraataque","Filo danzante","Maestro del acero"],"effects":["speed","critical","haste","damage"]}
		],
		[
			{"key":"ranger_longshot","branch":"Tirador","root":"bow_damage","names":["Tiro lejano","Punta de acero","Disparo penetrante","Francotirador"],"effects":["range","damage","critical","damage"]},
			{"key":"ranger_warden","branch":"Supervivencia","root":"ranger_vitality","names":["Paso silencioso","Instinto guardabosques","Piel de roble","Espíritu del bosque"],"effects":["speed","healing","defense","health"]},
			{"key":"ranger_hunter","branch":"Explorador","root":"bow_haste","names":["Rastreador veloz","Ojo del cazador","Presa marcada","Cazador supremo"],"effects":["speed","critical","range","damage_range"]}
		],
		[
			{"key":"mage_pyromancer","branch":"Destrucción","root":"spell_damage","names":["Ascua viva","Combustión","Llama voraz","Fuego primordial"],"effects":["damage","area","critical","damage"]},
			{"key":"mage_sentinel","branch":"Protección","root":"mage_vitality","names":["Escudo rúnico","Piel de maná","Reflejo arcano","Fortaleza mística"],"effects":["defense","health","healing","health"]},
			{"key":"mage_scholar","branch":"Arcano","root":"spell_haste","names":["Aprendizaje veloz","Pulso arcano","Convergencia","Archimago antiguo"],"effects":["haste","critical","range","damage"]}
		],
		[
			{"key":"rogue_blade","branch":"Asesino","root":"dagger_damage","names":["Corte doble","Filo hambriento","Golpe de gracia","Sicario"],"effects":["damage","critical","damage_range","damage"]},
			{"key":"rogue_ghost","branch":"Sombra","root":"rogue_vitality","names":["Paso fantasmal","Manto oscuro","Evasión perfecta","Fantasma"],"effects":["speed","defense","health","defense"]},
			{"key":"rogue_ambush","branch":"Trampero","root":"dagger_crit","names":["Trampa oculta","Veneno concentrado","Red de acero","Maestro emboscador"],"effects":["area","damage","critical","area"]}
		]
	]
	for class_index in range(master_paths.size()):
		for path in master_paths[class_index]:
			var previous_id: String = path["root"]
			for step in range(4):
				var effect: String = path["effects"][step]
				var new_id := "%s_%d" % [path["key"], step + 2]
				CLASS_TALENTS[class_index].append({
					"id": new_id,
					"name": path["names"][step],
					"description": "Perfecciona %s y potencia esta especialización." % effect.capitalize(),
					"branch": path["branch"],
					"tier": step + 2,
					"requires": previous_id,
					"effect": effect,
					"value": 0.12 if effect in ["range", "speed", "damage_range"] else 0.1,
				})
				previous_id = new_id
	var mastery_paths: Array[Array] = [
		[
			{"key":"warrior_berserker","branch":"Asalto","root":"sword_damage","names":["Pulso de acero","Furia creciente","Ruptura brutal","Tormenta de filos"],"effects":["damage","critical","area","damage"]},
			{"key":"warrior_vanguard","branch":"Bastión","root":"warrior_vitality","names":["Aguante férreo","Paso de guardia","Voluntad inquebrantable","Bastión viviente"],"effects":["health","defense","healing","health"]},
			{"key":"warrior_champion","branch":"Maestría","root":"sword_haste","names":["Ritmo perfecto","Mano experta","Presión constante","Héroe de guerra"],"effects":["haste","speed","damage_range","critical"]}
		],
		[
			{"key":"ranger_marksman","branch":"Tirador","root":"bow_damage","names":["Tensión precisa","Punta reforzada","Ojo inmóvil","Flecha de leyenda"],"effects":["critical","damage","range","damage"]},
			{"key":"ranger_greenthumb","branch":"Supervivencia","root":"ranger_vitality","names":["Savia reparadora","Instinto alerta","Piel de corteza","Vínculo salvaje"],"effects":["healing","speed","defense","health"]},
			{"key":"ranger_wayfarer","branch":"Explorador","root":"bow_haste","names":["Paso ligero","Pulso constante","Vista aguda","Caminante eterno"],"effects":["speed","haste","range","damage_range"]}
		],
		[
			{"key":"mage_emberheart","branch":"Destrucción","root":"spell_damage","names":["Eco ígneo","Núcleo ardiente","Estallido solar","Corazón de dragón"],"effects":["damage","area","critical","damage"]},
			{"key":"mage_lifeward","branch":"Protección","root":"mage_vitality","names":["Velo duradero","Reserva vital","Piel prismática","Santuario eterno"],"effects":["defense","health","healing","health"]},
			{"key":"mage_chronist","branch":"Arcano","root":"spell_haste","names":["Pensamiento veloz","Runa precisa","Flujo continuo","Maestro del tiempo"],"effects":["haste","critical","range","haste"]}
		],
		[
			{"key":"rogue_duelist","branch":"Asesino","root":"dagger_damage","names":["Punta certera","Filo gemelo","Ejecución limpia","Danza mortal"],"effects":["critical","damage","haste","damage"]},
			{"key":"rogue_nightstalker","branch":"Sombra","root":"rogue_vitality","names":["Manto ligero","Paso inasible","Humo denso","Sombra persistente"],"effects":["speed","defense","health","defense"]},
			{"key":"rogue_trickster","branch":"Trampero","root":"dagger_crit","names":["Trampa sutil","Mezcla tóxica","Red precisa","Maestro del engaño"],"effects":["area","damage","critical","area"]}
		]
	]
	for class_index in range(mastery_paths.size()):
		for path in mastery_paths[class_index]:
			var previous_id: String = path["root"]
			for step in range(4):
				var effect: String = path["effects"][step]
				var new_id := "%s_%d" % [path["key"], step + 2]
				CLASS_TALENTS[class_index].append({
					"id": new_id, "name": path["names"][step],
					"description": _passive_talent_description(effect, 12.0 if effect in ["range", "speed", "damage_range"] else 10.0),
					"branch": path["branch"], "tier": step + 2, "requires": previous_id,
					"effect": effect, "value": 0.12 if effect in ["range", "speed", "damage_range"] else 0.1,
					"passive": true,
				})
				previous_id = new_id
	var affinity_paths: Array[Array] = [
		[
			{"key":"warrior_ravager","branch":"Asalto","root":"sword_damage","names":["Pulso agresivo","Filo voraz","Golpe demoledor","Torbellino de acero"],"effects":["damage","critical","area","damage"]},
			{"key":"warrior_bloodedge","branch":"Asalto","root":"sword_damage","names":["Sed de combate","Herida abierta","Corte profundo","Verdugo implacable"],"effects":["critical","damage","damage_range","damage"]},
			{"key":"warrior_oathkeeper","branch":"BastiÃ³n","root":"warrior_vitality","names":["Juramento firme","Piel de granito","Resistencia heroica","Guardia eterna"],"effects":["defense","health","healing","health"]},
			{"key":"warrior_sentinel","branch":"BastiÃ³n","root":"warrior_vitality","names":["Tenacidad","Postura cerrada","Temple de hierro","Muralla indomable"],"effects":["health","defense","health","defense"]},
			{"key":"warrior_weaponmaster","branch":"MaestrÃ­a","root":"sword_haste","names":["Mano entrenada","Ritmo marcial","TÃ©cnica fluida","Maestro de armas"],"effects":["haste","critical","speed","damage_range"]},
			{"key":"warrior_windstep","branch":"MaestrÃ­a","root":"sword_haste","names":["Paso de combate","Iniciativa","Cadencia veloz","Duelista perfecto"],"effects":["speed","haste","damage","critical"]},
			{"key":"warrior_challenger","branch":"Asalto","root":"sword_damage","names":["Reto del campeÃ³n","Impacto brutal","RompelÃ­neas","Gladiador supremo"],"effects":["damage","area","critical","damage"]},
			{"key":"warrior_ironwill","branch":"BastiÃ³n","root":"warrior_vitality","names":["Voluntad de hierro","Aliento profundo","Piel impenetrable","Fortaleza absoluta"],"effects":["health","healing","defense","health"]},
			{"key":"warrior_bladestorm","branch":"MaestrÃ­a","root":"sword_haste","names":["Giro veloz","Filo resonante","Danza perfecta","Tormenta viviente"],"effects":["haste","area","speed","damage_range"]}
		],
		[
			{"key":"ranger_bullseye","branch":"Tirador","root":"bow_damage","names":["PunterÃ­a estable","Punta fina","Tiro certero","Ojo de Ã¡guila"],"effects":["critical","damage","range","damage"]},
			{"key":"ranger_piercer","branch":"Tirador","root":"bow_damage","names":["Flecha pesada","TensiÃ³n larga","Disparo perforante","Lluvia mortal"],"effects":["damage","range","damage_range","area"]},
			{"key":"ranger_barkskin","branch":"Supervivencia","root":"ranger_vitality","names":["Pulso natural","Hierbas curativas","Piel de roble","GuardiÃ¡n del bosque"],"effects":["healing","health","defense","health"]},
			{"key":"ranger_trailguard","branch":"Supervivencia","root":"ranger_vitality","names":["Alerta salvaje","Paso evasivo","Resistencia","CorazÃ³n indÃ³mito"],"effects":["speed","defense","health","healing"]},
			{"key":"ranger_swiftshot","branch":"Explorador","root":"bow_haste","names":["Tensar veloz","Flecha ligera","Paso del viento","Cazador del alba"],"effects":["haste","speed","range","critical"]},
			{"key":"ranger_farstrider","branch":"Explorador","root":"bow_haste","names":["Vista lejana","Zancada firme","Rastreador experto","Horizonte abierto"],"effects":["range","speed","damage_range","damage"]},
			{"key":"ranger_deadshot","branch":"Tirador","root":"bow_damage","names":["Pupila firme","Tiro calculado","Impacto certero","Francotirador maestro"],"effects":["critical","range","damage","damage"]},
			{"key":"ranger_wildheart","branch":"Supervivencia","root":"ranger_vitality","names":["RaÃ­z profunda","Sangre del bosque","Piel de guardiÃ¡n","EspÃ­ritu indomable"],"effects":["health","healing","defense","health"]},
			{"key":"ranger_stormbow","branch":"Explorador","root":"bow_haste","names":["Cadencia ligera","Viento cortante","Nube de flechas","Tormenta verde"],"effects":["haste","speed","area","damage_range"]}
		],
		[
			{"key":"mage_hellfire","branch":"DestrucciÃ³n","root":"spell_damage","names":["Ascua arcana","Fuego sostenido","ExplosiÃ³n rÃºnica","Llama apocalÃ­ptica"],"effects":["damage","haste","area","damage"]},
			{"key":"mage_stormcaller","branch":"DestrucciÃ³n","root":"spell_damage","names":["Chispa veloz","Sobrecarga","Tormenta de manÃ¡","Cataclismo astral"],"effects":["haste","critical","area","damage_range"]},
			{"key":"mage_warding","branch":"ProtecciÃ³n","root":"mage_vitality","names":["Velo tenue","Barrera firme","Escudo prismÃ¡tico","Santuario radiante"],"effects":["defense","health","healing","health"]},
			{"key":"mage_sustainer","branch":"ProtecciÃ³n","root":"mage_vitality","names":["Reserva arcana","Pulso restaurador","Resguardo vital","Voluntad eterna"],"effects":["healing","health","defense","healing"]},
			{"key":"mage_spellweaver","branch":"Arcano","root":"spell_haste","names":["Gestos precisos","Canal veloz","Convergencia arcana","Tejedor del tiempo"],"effects":["haste","critical","range","haste"]},
			{"key":"mage_starreader","branch":"Arcano","root":"spell_haste","names":["Mente despejada","Pulso astral","VisiÃ³n profunda","SabidurÃ­a estelar"],"effects":["critical","range","damage_range","damage"]},
			{"key":"mage_sunbinder","branch":"DestrucciÃ³n","root":"spell_damage","names":["Rayo dorado","NÃºcleo solar","ErupciÃ³n de luz","Sol encarnado"],"effects":["damage","critical","area","damage"]},
			{"key":"mage_aegisweaver","branch":"ProtecciÃ³n","root":"mage_vitality","names":["Sello protector","Barrera estable","Rebote mÃ­stico","CÃºpula eterna"],"effects":["defense","health","healing","defense"]},
			{"key":"mage_runeblade","branch":"Arcano","root":"spell_haste","names":["Glifo rÃ¡pido","Runa despierta","CÃ­rculo perfecto","Arquitecto arcano"],"effects":["haste","range","critical","damage_range"]}
		],
		[
			{"key":"rogue_executioner","branch":"Asesino","root":"dagger_damage","names":["Corte calculado","Filo afilado","Punto vulnerable","EjecuciÃ³n perfecta"],"effects":["critical","damage","damage_range","damage"]},
			{"key":"rogue_bloodletter","branch":"Asesino","root":"dagger_damage","names":["Apertura rÃ¡pida","Sangre frÃ­a","Herida profunda","Ãšltimo suspiro"],"effects":["haste","critical","damage","damage"]},
			{"key":"rogue_duskveil","branch":"Sombra","root":"rogue_vitality","names":["Manto tenue","Paso oculto","Velo persistente","Sombra protectora"],"effects":["defense","speed","health","defense"]},
			{"key":"rogue_phantom","branch":"Sombra","root":"rogue_vitality","names":["Reflejos oscuros","Esquiva instintiva","Cuerpo etÃ©reo","Fantasma inmortal"],"effects":["speed","defense","healing","health"]},
			{"key":"rogue_snaremaster","branch":"Trampero","root":"dagger_crit","names":["Trampa ligera","Resina tÃ³xica","Red acechante","Terreno mortal"],"effects":["area","damage","critical","area"]},
			{"key":"rogue_poisoner","branch":"Trampero","root":"dagger_crit","names":["Dosis precisa","Veneno lento","Toxina potente","Maestro alquimista"],"effects":["critical","damage","damage_range","damage"]},
			{"key":"rogue_blurstep","branch":"Asesino","root":"dagger_damage","names":["Paso cortante","Filo veloz","EjecuciÃ³n danzante","Asesino etÃ©reo"],"effects":["haste","critical","speed","damage"]},
			{"key":"rogue_ironshade","branch":"Sombra","root":"rogue_vitality","names":["Manto de ceniza","Piel umbrÃ­a","Refugio oscuro","Sombra inmortal"],"effects":["defense","health","healing","defense"]},
			{"key":"rogue_webspinner","branch":"Trampero","root":"dagger_crit","names":["Hilo invisible","Dardo tÃ³xico","Trampa en cadena","Maestro de la red"],"effects":["critical","area","damage","area"]}
		]
	]
	for class_index in range(affinity_paths.size()):
		for path in affinity_paths[class_index]:
			var previous_id: String = path["root"]
			for step in range(4):
				var effect: String = path["effects"][step]
				var new_id := "%s_%d" % [path["key"], step + 2]
				CLASS_TALENTS[class_index].append({
					"id": new_id, "name": path["names"][step],
					"description": _passive_talent_description(effect, 12.0 if effect in ["range", "speed", "damage_range"] else 10.0),
					"branch": path["branch"], "tier": step + 2, "requires": previous_id,
					"effect": effect, "value": 0.12 if effect in ["range", "speed", "damage_range"] else 0.1,
					"passive": true,
				})
				previous_id = new_id
			var late_tier_names: Array[String] = ["VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII"]
			for late_step in range(late_tier_names.size()):
				var late_tier := late_step + 6
				var late_effect: String = path["effects"][late_step % path["effects"].size()]
				var late_id := "%s_t%d" % [path["key"], late_tier]
				CLASS_TALENTS[class_index].append({
					"id": late_id,
					"name": "%s · %s" % [path["names"][late_step % path["names"].size()], late_tier_names[late_step]],
					"description": _passive_talent_description(late_effect, 6.0),
					"branch": path["branch"],
					"tier": late_tier,
					"requires": previous_id,
					"effect": late_effect,
					"value": 0.06,
					"passive": true,
				})
				previous_id = late_id


func _passive_talent_description(effect: String, bonus: float) -> String:
	var stat_name: String = str({
		"damage":"el daño infligido", "health":"la vida máxima", "haste":"la velocidad de habilidades",
		"speed":"la velocidad de movimiento", "critical":"la probabilidad de crítico",
		"defense":"la reducción del daño recibido", "healing":"la eficacia de curación",
		"area":"el daño de área", "range":"el alcance", "damage_range":"el daño y el alcance",
	}.get(effect, "tus atributos de combate"))
	return "Pasivo permanente: mejora %s un %.0f %% por rango." % [stat_name, bonus]


func _save_progression() -> void:
	var classes: Dictionary = _progression_data.get("classes", {})
	classes[str(_class_id)] = {
		"level": _level,
		"experience": _experience,
		"talent_points": _talent_points,
		"talent_ranks": _talent_ranks,
		"gold": _gold,
		"attribute_points": _attribute_points,
		"attributes": _attributes,
		"talents": _unlocked_talents,
		"hotbar": _hotbar_ids,
		"inventory": _inventory,
		"equipment": _equipment,
	}
	_progression_data["classes"] = classes
	var file := FileAccess.open(_progression_save_path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar la progresión (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(_progression_data, "\t"))
	file.close()


func _recalculate_combat_stats() -> void:
	var base_health: float = [140.0, 105.0, 95.0, 100.0][_class_id] * SPECIES_HEALTH[_species_id]
	var level_bonus := 1.0 + float(_level - 1) * 0.06
	var gear := _equipment_stats()
	var old_max_health := _max_health
	_max_health = base_health * level_bonus + float(gear["health"]) + float(_attributes["vitality"]) * 12.0
	if old_max_health > 0.0:
		_health = minf(_max_health, _health + maxf(0.0, _max_health - old_max_health))
	_damage_multiplier = (1.0 + float(_level - 1) * 0.04) * (1.0 + float(gear["attack"]) * 0.025)
	_damage_multiplier *= 1.0 + float(_attributes["strength"]) * 0.04 + float(_attributes["intellect"]) * 0.02
	_cooldown_multiplier = maxf(0.55, 1.0 - float(_attributes["intellect"]) * 0.01)
	_speed_multiplier = 1.0 + float(_attributes["agility"]) * 0.015
	_critical_chance = float(_attributes["agility"]) * 0.005
	_healing_multiplier = 1.0
	_area_multiplier = 1.0
	_range_multiplier = 1.0
	_damage_reduction = minf(float(gear["defense"]) * 0.015, 0.45)
	for talent in CLASS_TALENTS[_class_id]:
		var talent_id: String = talent["id"]
		var rank := int(_talent_ranks.get(talent_id, 0))
		if rank <= 0:
			continue
		var rank_scale := 1.0 + log(float(maxi(1, rank))) / log(10.0) * 0.5
		var value: float = float(talent.get("value", 0.0)) * rank_scale
		match talent["effect"]:
			"damage":
				_damage_multiplier += value
			"health":
				_max_health *= 1.0 + value
			"haste":
				_cooldown_multiplier *= 1.0 - value
			"speed":
				_speed_multiplier += value
			"critical":
				_critical_chance += value
			"healing":
				_healing_multiplier += value
			"area":
				_area_multiplier += value
			"range":
				_range_multiplier += value
			"damage_range":
				_damage_multiplier += value
				_range_multiplier += value
			"defense":
				_damage_reduction += value
	_critical_chance = minf(_critical_chance, 0.75)
	_damage_reduction = minf(_damage_reduction, 0.8)
	_cooldown_multiplier = maxf(_cooldown_multiplier, 0.25)
	_speed_multiplier = minf(_speed_multiplier, 4.0)
	_area_multiplier = minf(_area_multiplier, 4.0)
	_range_multiplier = minf(_range_multiplier, 3.0)


func _is_valid_talent(talent_id: String) -> bool:
	for talent in CLASS_TALENTS[_class_id]:
		if talent["id"] == talent_id:
			return true
	return false


func _can_unlock_talent(talent: Dictionary) -> bool:
	var talent_id: String = talent["id"]
	if _unlocked_talents.has(talent_id):
		return int(_talent_ranks.get(talent_id, 1)) < MAX_TALENT_RANK
	var tier := int(talent["tier"])
	if _level < 1 + (tier - 1) * 4:
		return false
	if tier == 1:
		return true
	return _unlocked_talents.has(talent.get("requires", ""))


func _available_talent_ids() -> Array[String]:
	var available: Array[String] = []
	for talent in CLASS_TALENTS[_class_id]:
		if _can_unlock_talent(talent):
			available.append(talent["id"])
	return available


func get_talent_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for talent in CLASS_TALENTS[_class_id]:
		options.append(talent)
	return options


func _load_hotbar(saved_hotbar: Variant) -> void:
	var abilities := CLASS_ABILITIES[_class_id]
	_hotbar_ids.clear()
	_skill_cooldowns.clear()
	for slot in range(6):
		var ability_id: String = str(saved_hotbar[slot]) if saved_hotbar is Array and slot < saved_hotbar.size() else ""
		if not _find_ability(ability_id).is_empty():
			_hotbar_ids.append(ability_id)
		else:
			_hotbar_ids.append(str(abilities[slot]["id"]))
		_skill_cooldowns.append(0.0)


func _find_ability(ability_id: String) -> Dictionary:
	for ability in _get_ability_options():
		if ability["id"] == ability_id:
			return ability
	return {}


func _get_ability_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for ability in CLASS_ABILITIES[_class_id]:
		options.append(ability)
	for skill in TALENT_SKILLS:
		if CLASS_TALENTS[_class_id].any(func(talent: Dictionary) -> bool: return talent["id"] == skill["talent"]) and _unlocked_talents.has(skill["talent"]):
			options.append(skill)
	return options


func _get_spellbook_skill_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for skill in TALENT_SKILLS:
		if CLASS_TALENTS[_class_id].any(func(talent: Dictionary) -> bool: return talent["id"] == skill["talent"]):
			options.append(skill)
	return options


func _ability_slot_for_key(keycode: Key) -> int:
	for index in range(6):
		if keycode == int(_keybinds["ability_%d" % (index + 1)]):
			return index
	return -1


func _is_action_key_pressed(action_name: String) -> bool:
	return Input.is_key_pressed(int(_keybinds.get(action_name, 0)))


func _load_game_settings() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_SAVE_PATH) != OK:
		return
	for action_name in _keybinds:
		_keybinds[action_name] = int(settings.get_value("controls", action_name, _keybinds[action_name]))
	var saved_resolution: Variant = settings.get_value("display", "resolution", Vector2i(1280, 720))
	if saved_resolution is Vector2i:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(saved_resolution)
		DisplayServer.window_set_position((DisplayServer.screen_get_size() - saved_resolution) / 2)


func _save_game_settings() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_SAVE_PATH)
	for action_name in _keybinds:
		settings.set_value("controls", action_name, int(_keybinds[action_name]))
	settings.set_value("display", "resolution", DisplayServer.window_get_size())
	var error := settings.save(SETTINGS_SAVE_PATH)
	if error != OK:
		push_warning("No se pudo guardar la configuración del juego (%d)." % error)


func _toggle_options_menu() -> void:
	if _combat_hud.call("is_options_open"):
		_resume_game()
		return
	_combat_hud.call("show_options", _keybinds, DisplayServer.window_get_size())
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	_combat_hud.call("close_options")
	get_tree().paused = false
	_rebinding_action = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_keybind_requested(action_name: String) -> void:
	if not _keybinds.has(action_name):
		return
	_rebinding_action = action_name
	_combat_hud.call("await_keybind", action_name)
	_combat_hud.call("set_message", "Pulsa una tecla para asignarla a esta acción.")


func _on_resolution_requested(width: int, height: int) -> void:
	var resolution := Vector2i(width, height)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_position((DisplayServer.screen_get_size() - resolution) / 2)
	_save_game_settings()


func _on_exit_requested() -> void:
	_save_game_settings()
	get_tree().quit()


func _create_combat_hud() -> void:
	_combat_hud = CanvasLayer.new()
	_combat_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_combat_hud.set_script(COMBAT_HUD_SCRIPT)
	add_child(_combat_hud)
	_combat_hud.call("configure")
	_combat_hud.connect("talent_selected", _on_talent_selected)
	_combat_hud.connect("ability_requested", _on_ability_requested)
	_combat_hud.connect("hotbar_change_requested", _on_hotbar_change_requested)
	_combat_hud.connect("equipment_requested", _on_equipment_requested)
	_combat_hud.connect("attribute_requested", _on_attribute_requested)
	_combat_hud.connect("unequip_requested", _on_unequip_requested)
	_combat_hud.connect("market_buy_requested", market_buy)
	_combat_hud.connect("market_sell_requested", market_sell)
	_combat_hud.connect("keybind_requested", _on_keybind_requested)
	_combat_hud.connect("resolution_requested", _on_resolution_requested)
	_combat_hud.connect("exit_requested", _on_exit_requested)
	_combat_hud.connect("resume_requested", _resume_game)
	_update_combat_hud()


func _update_combat_hud() -> void:
	if not is_instance_valid(_combat_hud):
		return
	var boss_name := ""
	var boss_health := 0.0
	var boss_max_health := 1.0
	var boss_portrait: PackedScene = null
	var closest_distance := 50.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("is_alive") or not enemy.call("is_alive"):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			boss_name = enemy.get("boss_name")
			boss_health = enemy.get("health")
			boss_max_health = enemy.get("max_health")
			var portrait_value: Variant = enemy.get("model_scene")
			if portrait_value is PackedScene:
				boss_portrait = portrait_value
	_combat_hud.call(
		"update_status",
		_health,
		_max_health,
		_level,
		_experience,
		_experience_required(),
		_talent_points,
		CLASS_NAMES[_class_id],
		boss_name,
		boss_health,
		boss_max_health,
		boss_portrait
	)
	_combat_hud.call(
		"update_hotbar",
		_get_ability_options(),
		_hotbar_ids,
		_skill_cooldowns
	)
	if not _death_message.is_empty():
		_combat_hud.call("set_message", _death_message)


func _experience_required() -> int:
	return _level * 100 if _level < MAX_LEVEL else 0


func grant_experience(amount: int) -> void:
	if amount <= 0 or _level >= MAX_LEVEL:
		return
	_experience += amount
	while _level < MAX_LEVEL and _experience >= _experience_required():
		_experience -= _experience_required()
		_level += 1
		_talent_points += 1
		_attribute_points += 1
	_recalculate_combat_stats()
	_save_progression()
	_update_combat_hud()


func grant_network_experience(amount: int) -> void:
	if MultiplayerSession.is_active() and multiplayer.is_server():
		sync_network_experience.rpc_id(get_multiplayer_authority(), amount)


@rpc("any_peer", "call_remote", "reliable")
func sync_network_experience(amount: int) -> void:
	if multiplayer.get_remote_sender_id() == 1 and is_multiplayer_authority():
		grant_experience(amount)


func grant_loot(source_name: String) -> bool:
	if _inventory.size() >= INVENTORY_CAPACITY:
		_combat_hud.call("set_message", "Mochila llena: espacio %d / %d" % [_inventory.size(), INVENTORY_CAPACITY])
		return false
	var rarity_roll := randi_range(1, 100)
	var rarity := "common"
	var rarity_name := "Común"
	var quality_multiplier := 1.0
	if rarity_roll > 99:
		rarity = "legendary"
		rarity_name = "Legendario"
		quality_multiplier = 2.7
	elif rarity_roll > 94:
		rarity = "epic"
		rarity_name = "Épico"
		quality_multiplier = 2.0
	elif rarity_roll > 81:
		rarity = "rare"
		rarity_name = "Raro"
		quality_multiplier = 1.55
	elif rarity_roll > 55:
		rarity = "uncommon"
		rarity_name = "Poco común"
		quality_multiplier = 1.25
	var roll := randi() % 5
	var item: Dictionary = {
		"name": "Colmillo de " + source_name,
		"type": "material",
		"slot": "bag",
		"icon_path": "res://assets/items/icon_material.svg",
		"rarity": rarity,
		"rarity_name": rarity_name,
		"attack": 0,
		"defense": 0,
		"health": 0,
	}
	if roll == 0:
		item.merge({
			"name": "Hoja del saqueador",
			"type": "weapon",
			"slot": "weapon",
			"icon_path": "res://assets/items/icon_sword.svg",
			"attack": roundi(float(randi_range(5, 10)) * quality_multiplier),
		}, true)
	elif roll == 1:
		item.merge({
			"name": "Coraza de cazador",
			"type": "armor",
			"slot": "chest",
			"icon_path": "res://assets/items/icon_armor.svg",
			"defense": roundi(float(randi_range(3, 7)) * quality_multiplier),
			"health": roundi(8.0 * quality_multiplier),
		}, true)
	elif roll == 2:
		item.merge({
			"name": "Casco reforzado",
			"type": "armor",
			"slot": "head",
			"icon_path": "res://assets/items/icon_helmet.svg",
			"defense": roundi(float(randi_range(2, 5)) * quality_multiplier),
			"health": roundi(4.0 * quality_multiplier),
		}, true)
	elif roll == 3:
		item.merge({
			"name": "Botas de viaje",
			"type": "armor",
			"slot": "legs",
			"icon_path": "res://assets/items/icon_boots.svg",
			"defense": roundi(float(randi_range(1, 3)) * quality_multiplier),
			"health": roundi(3.0 * quality_multiplier),
		}, true)
	if rarity != "common":
		item["name"] = "%s %s" % [rarity_name, item["name"]]
	_inventory.append(item)
	var coins_found := randi_range(4, 16) + int(rarity_roll / 20)
	_gold += coins_found
	_save_progression()
	_combat_hud.call("set_message", "Botín obtenido: %s" % item["name"])
	if _combat_hud.call("is_inventory_open"):
		_show_inventory()
	_update_combat_hud()
	return true


func _equipment_stats() -> Dictionary:
	var totals := {"attack": 0, "defense": 0, "health": 0}
	for item in _equipment.values():
		if item is Dictionary:
			for stat in totals:
				totals[stat] += int(item.get(stat, 0))
	return totals


func _toggle_inventory() -> void:
	if _combat_hud.call("is_inventory_open"):
		_combat_hud.call("close_inventory")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_combat_hud.call("close_talent_tree")
	_combat_hud.call("close_ability_picker")
	_combat_hud.call("close_spellbook")
	_show_inventory()
	_combat_hud.call("open_backpack_tab")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _toggle_spellbook() -> void:
	if _combat_hud.call("is_spellbook_open"):
		_combat_hud.call("close_spellbook")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_combat_hud.call("close_inventory")
	_combat_hud.call("close_market")
	_combat_hud.call("close_talent_tree")
	_combat_hud.call("close_ability_picker")
	_combat_hud.call("show_spellbook", _get_ability_options(), get_talent_options(), _unlocked_talents, _hotbar_ids, _get_spellbook_skill_options())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_interaction_prompt(prompt: String) -> void:
	if is_instance_valid(_combat_hud):
		_combat_hud.call("set_message", prompt)


func _try_dungeon_interaction() -> void:
	var nearest: Node3D
	var nearest_distance := 3.5
	for npc in get_tree().get_nodes_in_group("villager_npcs"):
		if not is_instance_valid(npc):
			continue
		var distance := global_position.distance_to(npc.global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	if nearest != null:
		if bool(nearest.get_meta("merchant", false)):
			_open_market(str(nearest.name))
		else:
			_combat_hud.call("set_message", "%s: ¡Bienvenido! Los comerciantes están en la plaza." % nearest.name)
		return
	for portal in get_tree().get_nodes_in_group("dungeon_entrances"):
		if portal.has_method("is_player_in_range") and portal.call("is_player_in_range"):
			portal.call("interact")
			return


func _open_market(merchant_name: String) -> void:
	_combat_hud.call("close_spellbook")
	var stock: Array[Dictionary] = [
		{"id":"potion", "name":"Poción de salud", "description":"Recupera 60 de vida.", "price":35, "type":"consumable"},
		{"id":"ore", "name":"Mineral de hierro", "description":"Material de artesanía.", "price":18, "type":"material"},
		{"id":"sword", "name":"Espada mercante", "description":"Arma equilibrada · ATQ +8", "price":120, "type":"weapon", "slot":"weapon", "attack":8, "defense":0, "health":0, "rarity":"common", "rarity_name":"Común", "icon_path":"res://assets/items/icon_sword.svg"},
		{"id":"armor", "name":"Túnica reforzada", "description":"Armadura ligera · DEF +5", "price":95, "type":"armor", "slot":"chest", "attack":0, "defense":5, "health":12, "rarity":"common", "rarity_name":"Común", "icon_path":"res://assets/items/icon_armor.svg"},
	]
	_combat_hud.call("show_market", merchant_name, _gold, stock, _inventory)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func market_buy(item_id: String) -> void:
	var prices := {"potion":35, "ore":18, "sword":120, "armor":95}
	if not prices.has(item_id): return
	var price := int(prices[item_id])
	if _gold < price:
		_combat_hud.call("set_message", "Te faltan monedas.")
		return
	if item_id == "potion":
		_health = minf(_max_health, _health + 60.0)
		_gold -= price
	else:
		if _inventory.size() >= INVENTORY_CAPACITY:
			_combat_hud.call("set_message", "Mochila llena.")
			return
		var item := {"name":"Mineral de hierro", "type":"material", "slot":"bag", "rarity":"common", "rarity_name":"Común", "attack":0,"defense":0,"health":0} if item_id == "ore" else ({"name":"Espada mercante", "type":"weapon", "slot":"weapon", "attack":8,"defense":0,"health":0,"rarity":"common","rarity_name":"Común","icon_path":"res://assets/items/icon_sword.svg"} if item_id == "sword" else {"name":"Túnica reforzada", "type":"armor", "slot":"chest", "attack":0,"defense":5,"health":12,"rarity":"common","rarity_name":"Común","icon_path":"res://assets/items/icon_armor.svg"})
		_inventory.append(item)
		_gold -= price
	_save_progression()
	_combat_hud.call("set_message", "Compra realizada por %d monedas." % price)
	_open_market("Mercader")
	_update_combat_hud()


func market_sell(item_index: int) -> void:
	if item_index < 0 or item_index >= _inventory.size(): return
	var item: Dictionary = _inventory[item_index]
	var value := maxi(4, int(item.get("attack", 0)) * 4 + int(item.get("defense", 0)) * 3 + int(item.get("health", 0)) + (12 if item.get("type") == "material" else 0))
	_gold += value
	_inventory.remove_at(item_index)
	_save_progression()
	_combat_hud.call("set_message", "Vendiste %s por %d monedas." % [item.get("name", "Objeto"), value])
	_open_market("Mercader")
	_update_combat_hud()


func _on_equipment_requested(item_index: int) -> void:
	if item_index < 0 or item_index >= _inventory.size():
		return
	var item: Dictionary = _inventory[item_index]
	var slot: String = item.get("slot", "bag")
	if not _equipment.has(slot):
		return
	var previous: Dictionary = _equipment[slot]
	_equipment[slot] = item
	_inventory.remove_at(item_index)
	if not previous.is_empty() and _inventory.size() < INVENTORY_CAPACITY:
		_inventory.append(previous)
	_recalculate_combat_stats()
	_save_progression()
	_show_inventory()
	_update_combat_hud()


func _on_attribute_requested(attribute_id: String) -> void:
	if _attribute_points <= 0 or not _attributes.has(attribute_id):
		return
	_attribute_points -= 1
	_attributes[attribute_id] += 1
	_recalculate_combat_stats()
	_save_progression()
	_show_inventory()
	_update_combat_hud()


func _on_unequip_requested(slot: String) -> void:
	if not _equipment.has(slot) or _inventory.size() >= INVENTORY_CAPACITY:
		return
	var item: Dictionary = _equipment[slot]
	if item.is_empty():
		return
	_inventory.append(item)
	_equipment[slot] = {}
	_recalculate_combat_stats()
	_save_progression()
	_show_inventory()
	_update_combat_hud()


func _show_inventory() -> void:
	_combat_hud.call(
		"show_inventory",
		_inventory,
		_equipment,
		_equipment_stats(),
		INVENTORY_CAPACITY,
		_attributes,
		_attribute_points,
		_avatar,
		_level,
		CLASS_NAMES[_class_id]
	)


func _toggle_talent_menu() -> void:
	if _is_dead:
		return
	if _combat_hud.call("is_talent_menu_open"):
		_combat_hud.call("close_talent_tree")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_combat_hud.call("close_ability_picker")
	_combat_hud.call("close_spellbook")
	_combat_hud.call(
		"show_talent_tree",
		_talent_points,
		get_talent_options(),
		_unlocked_talents,
		_level,
		_available_talent_ids(),
		_talent_ranks
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_talent_selected(talent_id: String, _requested_ranks: int = 1) -> void:
	if _talent_points <= 0 or not _is_valid_talent(talent_id):
		return
	var selected_talent: Dictionary = {}
	for talent in CLASS_TALENTS[_class_id]:
		if talent["id"] == talent_id:
			selected_talent = talent
			break
	if selected_talent.is_empty() or not _can_unlock_talent(selected_talent):
		return
	var current_rank := int(_talent_ranks.get(talent_id, 0))
	var ranks_to_buy := mini(1, mini(_talent_points, MAX_TALENT_RANK - current_rank))
	if ranks_to_buy <= 0:
		return
	_talent_points -= ranks_to_buy
	if current_rank == 0:
		_unlocked_talents.append(talent_id)
	_talent_ranks[talent_id] = current_rank + ranks_to_buy
	_recalculate_combat_stats()
	_save_progression()
	_combat_hud.call(
		"show_talent_tree",
		_talent_points,
		get_talent_options(),
		_unlocked_talents,
		_level,
		_available_talent_ids(),
		_talent_ranks
	)
	_update_combat_hud()


func _on_ability_requested(slot: int) -> void:
	_cast_ability(slot)


func _on_hotbar_change_requested(slot: int, ability_id: String) -> void:
	if slot < 0:
		var picker_slot := -slot - 1
		_combat_hud.call("close_spellbook")
		if picker_slot >= 0 and picker_slot < _hotbar_ids.size() and not _combat_hud.call("is_talent_menu_open"):
			_combat_hud.call("show_ability_picker", picker_slot, _get_ability_options())
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if slot < 0 or slot >= _hotbar_ids.size() or _find_ability(ability_id).is_empty():
		return
	_hotbar_ids[slot] = ability_id
	_save_progression()
	_combat_hud.call("close_ability_picker")
	_combat_hud.call("close_spellbook")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_combat_hud()


func _cast_ability(slot: int) -> void:
	if _is_dead or slot < 0 or slot >= _hotbar_ids.size() or _combat_hud.call("is_talent_menu_open") or _combat_hud.call("is_spellbook_open"):
		return
	if _combat_hud.call("is_ability_picker_open"):
		return
	if _skill_cooldowns[slot] > 0.0:
		return
	var ability := _find_ability(_hotbar_ids[slot])
	if ability.is_empty():
		push_error("La habilidad asignada a la ranura %d ya no existe." % (slot + 1))
		return

	var cooldown: float = ability["cooldown"] * _cooldown_multiplier
	_skill_cooldowns[slot] = cooldown
	var effect_type: String = ability["effect"]
	var ability_id: String = str(ability["id"])
	var ability_color := _ability_color(ability_id)
	if effect_type == "guard":
		_guard_charges = 1
		_combat_hud.call("set_message", "%s listo" % ability["name"])
		_spawn_combat_effect(global_position + Vector3.UP, "guard", ability_color)
		_spawn_ability_particles(global_position + Vector3.UP, ability_id, ability_color, Vector3.UP, 1.2)
	elif effect_type == "dash":
		_dash_direction = -camera.global_basis.z
		_dash_direction.y = 0.0
		_dash_direction = _dash_direction.normalized()
		_dash_remaining = 0.24
		var restored: float = minf(_max_health - _health, 18.0 * _healing_multiplier)
		_health += restored
		_combat_hud.call("set_message", "%s: +%d vida" % [ability["name"], roundi(restored)])
		_spawn_combat_effect(global_position + Vector3.UP * 0.75, "heal", ability_color)
		_spawn_ability_particles(global_position + Vector3.UP * 0.7, ability_id, ability_color, Vector3.UP, 1.4)
	elif effect_type == "heal":
		var restored: float = minf(
			_max_health - _health,
			35.0 * _healing_multiplier * (1.0 + float(_level - 1) * 0.025)
		)
		_health += restored
		_combat_hud.call("set_message", "%s: +%d vida" % [ability["name"], roundi(restored)])
		_spawn_combat_effect(global_position + Vector3.UP * 0.75, "heal", ability_color)
		_spawn_ability_particles(global_position + Vector3.UP * 0.7, ability_id, ability_color, Vector3.UP, 1.4)
	else:
		_attack_animation_remaining = 0.48
		_attack_animation_phase += 1.0
		_cast_attack_ability(ability, effect_type)
	_update_combat_hud()


func _cast_attack_ability(ability: Dictionary, effect_type: String) -> void:
	var attack_range: float = float(ability["range"]) * _range_multiplier
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * attack_range, 2, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var impact_position: Vector3 = hit["position"] if not hit.is_empty() else origin + direction * attack_range
	var target: Node = hit.get("collider") as Node if not hit.is_empty() else null
	var aim_target: Node3D = target as Node3D if target != null and target.is_in_group("enemies") else null
	if aim_target == null and effect_type == "area":
		var nearest_distance := INF
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy is Node3D or not enemy.has_method("is_alive") or not enemy.call("is_alive"):
				continue
			var distance_to_impact := (enemy as Node3D).global_position.distance_to(impact_position)
			if distance_to_impact < nearest_distance and distance_to_impact <= float(ability["radius"]) * _area_multiplier + 1.4:
				nearest_distance = distance_to_impact
				aim_target = enemy as Node3D
	_set_attack_aim_target(aim_target)
	var damage: float = float(ability["damage"]) * _damage_multiplier * (1.0 + float(_level - 1) * 0.02)
	if randf() < _critical_chance:
		damage *= 2.0
	_combat_hud.call("set_message", "%s: %d daño" % [ability["name"], roundi(damage)])
	var ability_id := str(ability["id"])
	var color := _ability_color(ability_id)
	var caster_forward := -global_basis.z
	var launch_origin := global_position + Vector3.UP * 1.2 + caster_forward * 0.85
	_spawn_projectile_effect(launch_origin, impact_position, color, ability_id)
	_spawn_ability_particles(launch_origin, ability_id, color, direction, 0.72)

	if effect_type == "area":
		var area_radius: float = float(ability["radius"]) * _area_multiplier
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(impact_position) <= area_radius + 1.4:
				if enemy.has_method("take_damage"):
					enemy.call("take_damage", damage, self)
		_spawn_combat_effect(impact_position, "area", color, area_radius)
		_spawn_ability_particles(impact_position, ability_id, color, Vector3.UP, 1.65)
	elif target != null and target.is_in_group("enemies") and target.has_method("take_damage"):
		target.call("take_damage", damage, self)
		_spawn_combat_effect(impact_position, "impact", color)
		_spawn_ability_particles(impact_position, ability_id, color, Vector3.UP, 1.0)


func _set_attack_aim_target(target: Node3D) -> void:
	_aim_target = target if is_instance_valid(target) and target.is_inside_tree() else null
	_aim_target_remaining = 0.72 if is_instance_valid(_aim_target) else 0.0
	if is_instance_valid(_avatar) and _avatar.has_method("set_attack_target"):
		_avatar.call("set_attack_target", _aim_target)


func _ability_color(ability_id: String = "") -> Color:
	var signature := ability_id
	if ability_id == "veneno" and _class_id == 3:
		signature = "veneno_rogue"
	match signature:
		"corte": return Color("#ffd27a")
		"golpe": return Color("#ff6438")
		"carga": return Color("#f4b942")
		"guardia": return Color("#91c6ff")
		"barrido": return Color("#fff0b3")
		"aliento": return Color("#7dffbd")
		"flecha": return Color("#aaff72")
		"multi": return Color("#ffe66d")
		"veneno": return Color("#aeff39")
		"voltereta": return Color("#73fff0")
		"trampa": return Color("#ff9f43")
		"marca": return Color("#fff4d6")
		"rayo": return Color("#66eaff")
		"fuego": return Color("#ff542e")
		"hielo": return Color("#9af5ff")
		"parpadeo": return Color("#a787ff")
		"tormenta": return Color("#fff36a")
		"sanacion": return Color("#ff9de1")
		"daga": return Color("#f7f0ff")
		"abanico": return Color("#d2a5ff")
		"veneno_rogue": return Color("#c4ff45")
		"sombra": return Color("#9f72ff")
		"emboscada": return Color("#ff4f91")
		"cura": return Color("#78ffc9")
		"golpe_dragon": return Color("#ff3d19")
		"flecha_perforante": return Color("#d7ff8a")
		"meteoro": return Color("#ff3b22")
		"paso_sombrio": return Color("#ed55ff")
	return [
		Color("#ff884c"),
		Color("#83d67d"),
		Color("#bd88ff"),
		Color("#e0e7fa"),
	][_class_id]


func _spawn_projectile_effect(start: Vector3, finish: Vector3, color: Color, ability_id: String = "") -> void:
	var projectile := MeshInstance3D.new()
	var mesh: Mesh
	match _class_id:
		0:
			var sword_streak := BoxMesh.new()
			sword_streak.size = Vector3(0.18, 0.12, 0.85)
			mesh = sword_streak
		1:
			var arrow_streak := BoxMesh.new()
			arrow_streak.size = Vector3(0.07, 0.07, 0.72)
			mesh = arrow_streak
		2:
			var magic_orb := SphereMesh.new()
			magic_orb.radius = 0.2
			magic_orb.height = 0.4
			mesh = magic_orb
		3:
			var dagger_streak := BoxMesh.new()
			dagger_streak.size = Vector3(0.09, 0.07, 0.48)
			mesh = dagger_streak
	projectile.mesh = mesh
	projectile.material_override = _effect_material(color)
	var sprite := Sprite3D.new()
	sprite.texture = _ability_particle_texture(ability_id)
	sprite.material_override = _ability_particle_material(ability_id, color)
	sprite.pixel_size = 0.00072
	projectile.add_child(sprite)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.6
	glow.omni_range = 3.5
	projectile.add_child(glow)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = start
	if start.distance_squared_to(finish) > 0.01:
		var up := Vector3.FORWARD if absf((finish - start).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		projectile.look_at(finish, up)
	var tween := create_tween()
	tween.set_parallel(true)
	var travel_time := clampf(start.distance_to(finish) / 42.0, 0.26, 0.9)
	tween.tween_property(projectile, "global_position", finish, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(projectile, "scale", Vector3(0.12, 0.12, 0.12), travel_time)
	tween.chain().tween_callback(projectile.queue_free)


func _spawn_spell_particles(position: Vector3, color: Color, direction: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "SpellParticles"
	particles.amount = 20
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.local_coords = false
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.22, 0.22)
	var particle_material := _ability_particle_material("meteoro", color)
	particle_mesh.material = particle_material
	particles.mesh = particle_mesh
	particles.direction = direction
	particles.spread = 38.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 2.4
	particles.gravity = Vector3(0.0, 0.3, 0.0)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.82
	particles.color = color.lightened(0.3)
	var color_ramp := Gradient.new()
	color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = color_ramp
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.25).timeout.connect(particles.queue_free)


func _spawn_ability_particles(position: Vector3, ability_id: String, color: Color, direction: Vector3, intensity: float) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "AbilityParticles_%s" % ability_id
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.local_coords = false
	particles.lifetime = 0.62
	particles.amount = roundi(34.0 * intensity)
	particles.direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.UP
	particles.spread = 42.0
	particles.initial_velocity_min = 1.7 * intensity
	particles.initial_velocity_max = 4.4 * intensity
	particles.gravity = Vector3(0.0, -1.1, 0.0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.14
	particles.scale_amount_min = 0.28
	particles.scale_amount_max = 0.82
	match ability_id:
		"fuego", "meteoro", "golpe_dragon", "trampa":
			particles.direction = Vector3.UP
			particles.spread = 30.0
			particles.gravity = Vector3(0.0, -0.25, 0.0)
			particles.initial_velocity_min = 2.8 * intensity
			particles.initial_velocity_max = 6.0 * intensity
		"hielo":
			particles.spread = 68.0
			particles.gravity = Vector3(0.0, 0.35, 0.0)
			particles.scale_amount_min = 0.42
			particles.scale_amount_max = 0.95
		"tormenta", "rayo", "flecha_perforante":
			particles.spread = 14.0
			particles.initial_velocity_min = 4.0 * intensity
			particles.initial_velocity_max = 8.0 * intensity
		"veneno", "veneno_rogue", "abanico":
			particles.spread = 76.0
			particles.gravity = Vector3(0.0, 0.55, 0.0)
		"sombra", "paso_sombrio", "emboscada", "parpadeo":
			particles.spread = 58.0
			particles.gravity = Vector3(0.0, 1.0, 0.0)
		"corte", "barrido", "daga", "golpe", "carga":
			particles.spread = 82.0
			particles.initial_velocity_min = 3.0 * intensity
			particles.initial_velocity_max = 5.5 * intensity
		"aliento", "sanacion", "cura", "guardia":
			particles.direction = Vector3.UP
			particles.spread = 24.0
			particles.gravity = Vector3(0.0, 0.8, 0.0)
	particles.color = color.lightened(0.42)
	var particle_mesh := QuadMesh.new()
	particle_mesh.size = Vector2(0.28, 0.28)
	var material := _ability_particle_material(ability_id, color)
	particle_mesh.material = material
	particles.mesh = particle_mesh
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.65))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = gradient
	get_tree().current_scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)
	_spawn_arcane_sparks(position, ability_id, color, direction, intensity)


func _spawn_arcane_sparks(position: Vector3, ability_id: String, color: Color, direction: Vector3, intensity: float) -> void:
	var sparks := CPUParticles3D.new()
	sparks.name = "ArcaneSparks_%s" % ability_id
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.amount = roundi(22.0 * intensity)
	sparks.lifetime = 0.48
	sparks.direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.UP
	sparks.spread = 150.0
	sparks.initial_velocity_min = 3.2 * intensity
	sparks.initial_velocity_max = 7.2 * intensity
	sparks.gravity = Vector3(0.0, -0.35, 0.0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.12
	sparks.scale_amount_min = 0.08
	sparks.scale_amount_max = 0.34
	sparks.color = color.lightened(0.55)
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.16, 0.16)
	spark_mesh.material = _ability_particle_material("impact", color.lightened(0.5))
	sparks.mesh = spark_mesh
	var spark_fade := Gradient.new()
	spark_fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	spark_fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	sparks.color_ramp = spark_fade
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = position
	sparks.emitting = true
	get_tree().create_timer(sparks.lifetime + 0.2).timeout.connect(sparks.queue_free)


func _ability_particle_texture(ability_id: String) -> Texture2D:
	var texture_name := "flare_01.png"
	match ability_id:
		"fuego", "meteoro", "golpe_dragon", "trampa": texture_name = "fire_02.png"
		"hielo", "tormenta", "rayo", "flecha_perforante": texture_name = "magic_04.png"
		"veneno", "veneno_rogue": texture_name = "smoke_08.png"
		"sombra", "paso_sombrio", "emboscada", "parpadeo": texture_name = "twirl_03.png"
		"aliento", "sanacion", "cura", "guardia": texture_name = "star_07.png"
		"corte", "barrido", "daga", "golpe", "carga", "abanico": texture_name = "slash_04.png"
		"impact", "area": texture_name = "spark_03.png"
	return load("res://assets/kenney_particle_pack/PNG/" + texture_name) as Texture2D


func _ability_particle_material(ability_id: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _ability_particle_texture(ability_id)
	material.albedo_color = color.lightened(0.45)
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


func _spawn_combat_effect(position: Vector3, effect_type: String, color: Color, radius: float = 1.0) -> void:
	var effect := Node3D.new()
	effect.name = "CombatEffect"
	get_tree().current_scene.add_child(effect)
	effect.global_position = position

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.42
	core_mesh.height = 0.84
	core.mesh = core_mesh
	core.material_override = _effect_material(color)
	effect.add_child(core)

	var pulse := MeshInstance3D.new()
	var pulse_mesh := CylinderMesh.new()
	pulse_mesh.top_radius = 0.44
	pulse_mesh.bottom_radius = 0.52
	pulse_mesh.height = 0.06
	pulse_mesh.radial_segments = 24
	pulse.mesh = pulse_mesh
	pulse.position.y = -position.y + 0.06
	pulse.material_override = _effect_material(color.darkened(0.1), 0.52)
	effect.add_child(pulse)
	var impact_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.52
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 40
	impact_ring.mesh = ring_mesh
	impact_ring.position.y = -position.y + 0.08
	impact_ring.material_override = _effect_material(color, 0.28)
	effect.add_child(impact_ring)
	var flash := Sprite3D.new()
	flash.texture = _ability_particle_texture("fuego" if effect_type == "area" else "impact")
	flash.material_override = _ability_particle_material("fuego" if effect_type == "area" else "impact", color)
	flash.position.y = -position.y + 0.75
	flash.pixel_size = 0.00082
	effect.add_child(flash)
	if effect_type == "guard":
		core.scale = Vector3(1.9, 1.9, 1.9)
	elif effect_type == "heal":
		core.scale = Vector3(1.6, 1.6, 1.6)
		pulse.position.y = 0.0
		pulse.rotation.x = deg_to_rad(90.0)
	else:
		pulse.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, "scale", core.scale * 1.7, 0.36)
	tween.tween_property(core, "transparency", 1.0, 0.36)
	tween.tween_property(pulse, "scale", pulse.scale * 1.25, 0.36)
	tween.tween_property(pulse, "transparency", 1.0, 0.36)
	tween.tween_property(impact_ring, "scale", Vector3.ONE * maxf(0.72, radius * 0.82), 0.42)
	tween.tween_property(impact_ring, "transparency", 1.0, 0.42)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.2, 0.3)
	tween.tween_property(flash, "transparency", 1.0, 0.3)
	tween.chain().tween_callback(effect.queue_free)


func _effect_material(color: Color, transparency: float = 0.12) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 1.0 - transparency)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


func receive_damage(amount: float, _attacker: Node = null) -> void:
	if MultiplayerSession.is_active() and multiplayer.is_server() and not is_multiplayer_authority():
		apply_network_damage.rpc_id(get_multiplayer_authority(), amount)
		return
	_apply_received_damage(amount)


@rpc("any_peer", "call_remote", "reliable")
func apply_network_damage(amount: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_apply_received_damage(amount)


func _apply_received_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	var mitigated_damage := amount * (1.0 - _damage_reduction)
	if _guard_charges > 0:
		mitigated_damage *= 1.0 - _guard_reduction
		_guard_charges -= 1
		_spawn_combat_effect(global_position + Vector3.UP, "guard", _ability_color())
	_hit_flash_remaining = 0.2
	_spawn_combat_effect(global_position + Vector3.UP * 0.8, "impact", Color("#ff4545"))
	_health = maxf(0.0, _health - mitigated_damage)
	if _health <= 0.0:
		_is_dead = true
		_death_message = "Has caído en combate. Reapareces en 3 segundos."
		_combat_hud.call("set_message", _death_message)
		_respawn_after_delay()
	_update_combat_hud()


func _respawn_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree() and _is_dead:
		_respawn()


func _respawn() -> void:
	_is_dead = false
	_health = _max_health
	velocity = Vector3.ZERO
	global_position = _spawn_position
	_death_message = "Has reaparecido."
	_update_combat_hud()


func _toggle_camera() -> void:
	_third_person = not _third_person
	_avatar.visible = _third_person
	_base_camera_position = Vector3(0.0, 0.15, 3.3) if _third_person else Vector3.ZERO
	camera.position = _base_camera_position
