extends Control

const AVATAR_SCRIPT := preload("res://scripts/character_avatar.gd")
const WORLD_SCENE := "res://scenes/main.tscn"
const SAVE_PATH := "user://character.json"
const CLASS_NAMES := ["Guerrera/o", "Exploradora/or", "Hechicera/o", "Pícara/o"]
const SPECIES_NAMES := ["Humana/o", "Elfa/o", "Orca/o", "Enana/o", "Imp", "Puglin"]
const SPECIES_DESCRIPTIONS := [
	"Proporciones humanas; cuerpo completo con cara modelada.",
	"Humanoide esbelta/o con orejas élficas.",
	"Humanoide robusta/o con piel verde y colmillos.",
	"Humanoide compacta/o, robusta/o y barbuda/o.",
	"Modelo fantástico completo; apariencia y peinado propios de la especie.",
	"Modelo fantástico completo; proporciones y apariencia propias de la especie.",
]
const CLASS_DESCRIPTIONS := [
	"Armadura y escudo; menor velocidad y salto equilibrado.",
	"Arco y aljaba; mayor velocidad al correr.",
	"Bastón y capa; mayor altura de salto.",
	"Daga y equipo ligero; mayor velocidad al caminar y correr.",
]
const SKIN_NAMES := ["Marfil", "Arena", "Miel", "Bronce", "Caoba", "Ébano", "Durazno", "Cobre"]
const HAIR_NAMES := ["Corto", "Largo", "Rizado", "Puntas", "Coletas", "De lado"]
const HAIR_COLOR_NAMES := ["Negro", "Castaño", "Castaño claro", "Rubio", "Plateado", "Rojo", "Violeta", "Blanco"]
const EYE_NAMES := ["Marrón", "Verde", "Azul", "Ámbar", "Gris", "Violeta"]
const FACE_NAMES := ["Ovalado", "Cuadrado", "Redondo", "Alargado"]
const BUILD_NAMES := ["Delgada", "Atlética", "Robusta"]
var _avatar: Node3D
var _viewport: SubViewport
var _preview_camera: Camera3D
var _options: Dictionary = {}
var _height_slider: HSlider
var _name_input: LineEdit
var _status_label: Label
var _class_description: Label
var _species_description: Label
var _category_count := 10
var _suppress_updates := false
var _preview_dragging := false
var _network_address: LineEdit
var _network_status: Label


func _ready() -> void:
	_build_interface()
	_build_preview()
	_load_saved_profile()
	_update_preview()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#10191d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var glow := ColorRect.new()
	glow.color = Color("#29332d")
	glow.position = Vector2(520.0, 0.0)
	glow.size = Vector2(760.0, 720.0)
	add_child(glow)

	var eyebrow := _label("MUNDO ABIERTO  /  ESTUDIO DE PERSONAJES", 30, 18, 480, 24, 12, Color("#dfbd94"))
	add_child(eyebrow)
	var title := _label("Creador de aventureros", 30, 42, 520, 50, 30, Color("#fff1f7"))
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	var subtitle := _label("Personaliza su apariencia, equipo y clase.", 32, 89, 510, 28, 15, Color("#c4b7d0"))
	add_child(subtitle)

	var panel := PanelContainer.new()
	panel.position = Vector2(30.0, 132.0)
	panel.size = Vector2(465.0, 510.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#211e35")
	panel_style.border_color = Color("#534263")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)

	var heading := _label("IDENTIDAD", 0, 0, 0, 24, 12, Color("#d8b57a"))
	content.add_child(heading)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Nombre del personaje"
	_name_input.text = "Viajero"
	_name_input.max_length = 24
	_name_input.custom_minimum_size.y = 38
	_name_input.add_theme_color_override("font_color", Color("#fff1f7"))
	_name_input.add_theme_color_override("font_placeholder_color", Color("#a998b5"))
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("#302943")
	input_style.border_color = Color("#594663")
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(7)
	_name_input.add_theme_stylebox_override("normal", input_style)
	var input_focus := input_style.duplicate()
	input_focus.border_color = Color("#d8b57a")
	_name_input.add_theme_stylebox_override("focus", input_focus)
	_name_input.text_changed.connect(_on_name_changed)
	content.add_child(_name_input)
	_add_option(content, "Especie", "species", SPECIES_NAMES)
	_species_description = Label.new()
	_species_description.custom_minimum_size = Vector2(0.0, 34.0)
	_species_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_species_description.add_theme_color_override("font_color", Color("#c4b7d0"))
	_species_description.add_theme_font_size_override("font_size", 12)
	content.add_child(_species_description)
	_add_option(content, "Cuerpo humanoide", "body_type", ["Femenino", "Masculino"])
	_add_option(content, "Clase", "class", CLASS_NAMES)
	_class_description = Label.new()
	_class_description.custom_minimum_size = Vector2(0.0, 34.0)
	_class_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_description.add_theme_color_override("font_color", Color("#c4b7d0"))
	_class_description.add_theme_font_size_override("font_size", 12)
	content.add_child(_class_description)
	_add_option(content, "Silueta", "build", BUILD_NAMES, 1)
	_add_option(content, "Estatura", "height_preset", ["Baja", "Media", "Alta"], 1)
	_height_slider = HSlider.new()
	_height_slider.min_value = 0.85
	_height_slider.max_value = 1.15
	_height_slider.step = 0.01
	_height_slider.value = 1.0
	_height_slider.custom_minimum_size.y = 22
	_height_slider.value_changed.connect(_on_height_changed)
	content.add_child(_height_slider)

	var appearance_heading := _label("APARIENCIA", 0, 0, 0, 24, 12, Color("#d8b57a"))
	appearance_heading.add_theme_constant_override("margin_top", 8)
	content.add_child(appearance_heading)
	_add_option(content, "Tono de piel", "skin", SKIN_NAMES)
	_add_option(content, "Forma del rostro", "face", FACE_NAMES)
	_add_option(content, "Color de ojos", "eyes", EYE_NAMES)
	_add_option(content, "Peinado", "hairstyle", HAIR_NAMES, 1)
	_add_option(content, "Color de cabello", "hair_color", HAIR_COLOR_NAMES, 1)

	var preview_caption := _label("VISTA PREVIA  ·  GIRO AUTOMÁTICO", 535, 137, 360, 22, 12, Color("#dfbd94"))
	add_child(preview_caption)
	var preview_panel := PanelContainer.new()
	preview_panel.position = Vector2(530.0, 166.0)
	preview_panel.size = Vector2(720.0, 450.0)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color("#242d2a")
	preview_style.border_color = Color("#596859")
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(16)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	add_child(preview_panel)

	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.gui_input.connect(_on_preview_input)
	preview_panel.add_child(viewport_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(720, 450)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_viewport)

	var preview_note := _label("ARRASTRA PARA GIRAR  ·  RUEDA PARA ACERCAR", 550, 626, 450, 20, 11, Color("#c0a9c6"))
	add_child(preview_note)

	_status_label = _label("Los cambios se muestran al instante.", 30, 651, 510, 24, 13, Color("#a8b9b3"))
	add_child(_status_label)
	_add_button("Aleatorio", Vector2(530.0, 654.0), Vector2(130.0, 42.0), _on_randomize, false)
	_add_button("Restablecer", Vector2(670.0, 654.0), Vector2(140.0, 42.0), _on_reset, false)
	_add_button("Guardar", Vector2(820.0, 654.0), Vector2(140.0, 42.0), _on_save, false)
	_add_button("Entrar al mundo  →", Vector2(970.0, 654.0), Vector2(280.0, 42.0), _on_enter_world, true)
	_build_network_panel()


func _build_network_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(1000.0, 190.0)
	panel.size = Vector2(250.0, 190.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#211e35", 0.94)
	style.border_color = Color("#d8b57a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "COOPERATIVO · RED LOCAL"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("#dfbd94"))
	content.add_child(heading)
	_network_address = LineEdit.new()
	_network_address.text = "127.0.0.1"
	_network_address.placeholder_text = "IP del anfitrión"
	_network_address.custom_minimum_size.y = 34
	content.add_child(_network_address)
	var host_button := Button.new()
	host_button.text = "Crear partida"
	host_button.pressed.connect(_on_host_game)
	content.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "Unirse a partida"
	join_button.pressed.connect(_on_join_game)
	content.add_child(join_button)
	_network_status = Label.new()
	_network_status.text = "Hasta 8 jugadores · puerto 24567"
	_network_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_status.custom_minimum_size.y = 30
	_network_status.add_theme_font_size_override("font_size", 11)
	_network_status.add_theme_color_override("font_color", Color("#c4b7d0"))
	content.add_child(_network_status)
	MultiplayerSession.connection_status_changed.connect(_on_network_status_changed)


func _on_host_game() -> void:
	if not _save_profile():
		return
	if MultiplayerSession.host_game() == OK:
		get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join_game() -> void:
	if not _save_profile():
		return
	MultiplayerSession.join_game(_network_address.text)


func _on_network_status_changed(message: String) -> void:
	if is_instance_valid(_network_status):
		_network_status.text = message


func _build_preview() -> void:
	var environment := WorldEnvironment.new()
	var preview_environment := Environment.new()
	preview_environment.background_mode = Environment.BG_COLOR
	preview_environment.background_color = Color("#343b35")
	preview_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	preview_environment.ambient_light_color = Color("#f2cbe0")
	preview_environment.ambient_light_energy = 0.95
	preview_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	preview_environment.glow_enabled = true
	preview_environment.glow_intensity = 0.25
	environment.environment = preview_environment
	_viewport.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-26.0, -28.0, 0.0)
	key_light.light_color = Color("#ffe5ee")
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.0, 2.5)
	fill_light.light_color = Color("#a9a2ff")
	fill_light.light_energy = 0.55
	fill_light.omni_range = 8.0
	_viewport.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(1.8, 2.8, -1.8)
	rim_light.light_color = Color("#ffb6d6")
	rim_light.light_energy = 0.75
	rim_light.omni_range = 6.0
	_viewport.add_child(rim_light)

	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(0.0, 1.47, 5.1)
	_preview_camera.fov = 34.0
	_preview_camera.current = true
	_viewport.add_child(_preview_camera)
	_preview_camera.look_at(Vector3(0.0, 1.12, 0.0), Vector3.UP)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200.0, 200.0)
	floor.mesh = floor_mesh
	floor.position.y = -0.02
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#343b35")
	floor_material.metallic = 0.0
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	_viewport.add_child(floor)

	_avatar = Node3D.new()
	_avatar.set_script(AVATAR_SCRIPT)
	_viewport.add_child(_avatar)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_preview_dragging = event.pressed
			_avatar.call("set_spinning", not _preview_dragging)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_preview_camera.position.z = maxf(3.7, _preview_camera.position.z - 0.3)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_preview_camera.position.z = minf(6.5, _preview_camera.position.z + 0.3)
	elif event is InputEventMouseMotion and _preview_dragging:
		_avatar.rotation.y += event.relative.x * 0.01


func _add_option(parent: VBoxContainer, label_text: String, key: String, choices: Array, selected: int = 0) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 156
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#e4d8e8"))
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(245.0, 32.0)
	option.add_theme_color_override("font_color", Color("#f7ebf4"))
	option.add_theme_color_override("font_hover_color", Color("#ffffff"))
	option.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	option.add_theme_color_override("font_focus_color", Color("#ffffff"))
	var option_style := StyleBoxFlat.new()
	option_style.bg_color = Color("#302943")
	option_style.border_color = Color("#594663")
	option_style.set_border_width_all(1)
	option_style.set_corner_radius_all(6)
	option.add_theme_stylebox_override("normal", option_style)
	var option_hover := option_style.duplicate()
	option_hover.bg_color = Color("#403452")
	option.add_theme_stylebox_override("hover", option_hover)
	var option_pressed := option_style.duplicate()
	option_pressed.bg_color = Color("#594263")
	option.add_theme_stylebox_override("pressed", option_pressed)
	for choice in choices:
		option.add_item(choice)
	option.select(clampi(selected, 0, choices.size() - 1))
	option.item_selected.connect(_on_option_selected.bind(key))
	row.add_child(option)
	parent.add_child(row)
	_options[key] = option


func _add_button(text: String, position: Vector2, size: Vector2, callback: Callable, primary: bool) -> void:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#d9b87c") if primary else Color("#302943")
	normal.border_color = Color("#f1d7a5") if primary else Color("#596859")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#e7c990") if primary else Color("#403b39")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("#38243a") if primary else Color("#f2eaf4"))
	button.pressed.connect(callback)
	add_child(button)


func _label(text: String, x: float, y: float, width: float, height: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(width, height)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_option_selected(index: int, key: String) -> void:
	if _suppress_updates:
		return
	if key == "height_preset":
		_height_slider.value = [0.9, 1.0, 1.1][index]
	else:
		if key == "class":
			_class_description.text = CLASS_DESCRIPTIONS[index]
		elif key == "species":
			_species_description.text = SPECIES_DESCRIPTIONS[index]
		_update_preview()


func _on_height_changed(value: float) -> void:
	if _suppress_updates:
		return
	var preset_index := clampi(roundi((value - 0.9) / 0.1), 0, 2)
	(_options["height_preset"] as OptionButton).select(preset_index)
	_update_preview()


func _on_name_changed(_text: String) -> void:
	if not _suppress_updates:
		_update_preview()


func _update_preview() -> void:
	if is_instance_valid(_avatar):
		var preview_profile := _get_profile()
		preview_profile["clean_preview"] = true
		_avatar.call("apply_profile", preview_profile)
	if is_instance_valid(_class_description):
		var class_index := clampi((_options["class"] as OptionButton).selected, 0, CLASS_DESCRIPTIONS.size() - 1)
		_class_description.text = CLASS_DESCRIPTIONS[class_index]
	if is_instance_valid(_species_description):
		var species_index := clampi((_options["species"] as OptionButton).selected, 0, SPECIES_DESCRIPTIONS.size() - 1)
		_species_description.text = SPECIES_DESCRIPTIONS[species_index]
		var uses_humanoid_appearance := species_index < 4
		for key in ["body_type", "skin", "face", "eyes", "hairstyle", "hair_color"]:
			(_options[key] as OptionButton).disabled = not uses_humanoid_appearance
	if is_instance_valid(_status_label):
		_status_label.text = "%d categorías · Vista previa actualizada" % _category_count


func _get_profile() -> Dictionary:
	var profile := {"name": _name_input.text.strip_edges(), "height": _height_slider.value}
	for key in _options:
		if key != "height_preset":
			profile[key] = (_options[key] as OptionButton).selected
	return profile


func _apply_profile(profile: Dictionary) -> void:
	_suppress_updates = true
	if profile.has("name") and profile["name"] is String:
		_name_input.text = profile["name"].substr(0, 24)
	for key in _options:
		if key == "height_preset":
			continue
		var option: OptionButton = _options[key]
		if profile.has(key) and profile[key] is int:
			option.select(clampi(profile[key], 0, option.item_count - 1))
	if profile.has("height") and (profile["height"] is float or profile["height"] is int):
		_height_slider.value = clampf(float(profile["height"]), 0.85, 1.15)
	var preset_index := clampi(roundi((_height_slider.value - 0.9) / 0.1), 0, 2)
	(_options["height_preset"] as OptionButton).select(preset_index)
	_suppress_updates = false
	_update_preview()


func _save_profile() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_set_status("No se pudo guardar el personaje (error %d)." % FileAccess.get_open_error(), true)
		return false
	file.store_string(JSON.stringify(_get_profile(), "\t"))
	file.close()
	_set_status("Personaje guardado correctamente.", false)
	return true


func _load_saved_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_set_status("No se pudo leer el personaje guardado (error %d)." % FileAccess.get_open_error(), true)
		return
	var text := file.get_as_text()
	file.close()
	var profile: Variant = JSON.parse_string(text)
	if not profile is Dictionary:
		_set_status("El archivo de personaje guardado no contiene un perfil válido.", true)
		return
	_apply_profile(profile)
	_set_status("Diseño guardado cargado.", false)


func _set_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color("#e99a8d") if is_error else Color("#a8b9b3"))


func _on_randomize() -> void:
	var profile := {"name": "Viajero %02d" % randi_range(1, 99), "height": snappedf(randf_range(0.85, 1.15), 0.01)}
	for key in _options:
		if key == "height_preset":
			continue
		profile[key] = randi_range(0, (_options[key] as OptionButton).item_count - 1)
	_apply_profile(profile)


func _on_reset() -> void:
	_apply_profile({
		"name": "Viajero",
		"species": 0,
		"body_type": 0,
		"class": 0,
		"build": 1,
		"height": 1.0,
		"skin": 0,
		"face": 0,
		"eyes": 0,
		"hairstyle": 1,
		"hair_color": 1,
	})
	_set_status("Diseño restablecido.", false)


func _on_save() -> void:
	_save_profile()


func _on_enter_world() -> void:
	if _save_profile():
		var error := get_tree().change_scene_to_file(WORLD_SCENE)
		if error != OK:
			_set_status("No se pudo abrir el mundo (error %d)." % error, true)
