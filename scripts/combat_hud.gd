extends CanvasLayer

signal talent_selected(talent_id: String, amount: int)
signal ability_requested(slot: int)
signal hotbar_change_requested(slot: int, ability_id: String)
signal equipment_requested(item_index: int)
signal attribute_requested(attribute_id: String)
signal unequip_requested(slot: String)
signal market_buy_requested(item_id: String)
signal market_sell_requested(item_index: int)
signal keybind_requested(action_name: String)
signal resolution_requested(width: int, height: int)
signal exit_requested
signal resume_requested

const SLOT_KEYS := ["1", "2", "3", "4", "5", "6"]

var _health_bar: ProgressBar
var _health_label: Label
var _xp_bar: ProgressBar
var _progress_label: Label
var _boss_panel: PanelContainer
var _boss_name_label: Label
var _boss_health_bar: ProgressBar
var _boss_portrait_viewport: SubViewport
var _boss_portrait_root: Node3D
var _boss_model_root: Node3D
var _boss_portrait_key := ""
var _talent_panel: PanelContainer
var _talent_points_label: Label
var _talent_grid: Control
var _talent_scroll: ScrollContainer
var _talent_level_label: Label
var _talent_view_data: Dictionary = {}
var _spellbook_panel: PanelContainer
var _spellbook_list: VBoxContainer
var _spellbook_slot_selector: OptionButton
var _spellbook_assign_button: Button
var _selected_spell_id := ""
var _ability_picker: PanelContainer
var _ability_picker_title: Label
var _ability_picker_list: VBoxContainer
var _hotbar_buttons: Array[Button] = []
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_names: Array[Label] = []
var _message_label: Label
var _selected_picker_slot := -1
var _talent_menu_open := false
var _inventory_panel: PanelContainer
var _inventory_list: GridContainer
var _inventory_summary: Label
var _backpack_summary: Label
var _attributes_summary: Label
var _attribute_list: VBoxContainer
var _inventory_open := false
var _equipment_list: VBoxContainer
var _inventory_tabs: TabContainer
var _inventory_viewport: SubViewport
var _inventory_avatar_root: Node3D
var _inventory_character_label: Label
var _backpack_item_detail: Label
var _backpack_equip_button: Button
var _selected_inventory_index := -1
var _selected_inventory_button: Button
var _market_panel: PanelContainer
var _market_content: VBoxContainer
var _options_panel: PanelContainer
var _options_key_buttons: Dictionary = {}
var _options_resolution: OptionButton


func configure() -> void:
	_build_status_panel()
	_build_boss_panel()
	_build_talent_panel()
	_build_spellbook_panel()
	_build_ability_picker()
	_build_hotbar()
	_build_inventory_panel()
	_build_market_panel()
	_build_options_panel()


func update_status(
		current_health: float,
		maximum_health: float,
		level: int,
		experience: int,
		experience_to_next: int,
		talent_points: int,
		selected_class: String,
		boss_name: String,
		boss_health: float,
		boss_maximum_health: float,
		portrait_scene: PackedScene = null
) -> void:
	_health_bar.max_value = maxf(1.0, maximum_health)
	_health_bar.value = current_health
	_health_label.text = "%s     VIDA  %d / %d" % [
		selected_class.to_upper(), roundi(current_health), roundi(maximum_health)
	]
	if experience_to_next <= 0:
		_progress_label.text = "NIVEL %d · MÁXIMO     TALENTOS %d" % [level, talent_points]
	else:
		_progress_label.text = "NIVEL %d     XP %d / %d     TALENTOS %d" % [
			level, experience, experience_to_next, talent_points
		]
	_xp_bar.max_value = maxf(1.0, float(experience_to_next))
	_xp_bar.value = 1.0 if experience_to_next <= 0 else experience
	_boss_panel.visible = not boss_name.is_empty()
	if not boss_name.is_empty():
		_boss_name_label.text = boss_name
		_boss_health_bar.max_value = maxf(1.0, boss_maximum_health)
		_boss_health_bar.value = boss_health
		_set_boss_portrait(portrait_scene)
	if _talent_menu_open:
		_talent_points_label.text = "Puntos disponibles: %s" % _format_talent_points(talent_points)


func update_hotbar(
		abilities: Array[Dictionary],
		hotbar_ids: Array[String],
		cooldowns: Array[float]
) -> void:
	for slot in range(_hotbar_buttons.size()):
		var ability: Dictionary = _find_ability(abilities, hotbar_ids[slot])
		if ability.is_empty():
			_hotbar_icons[slot].texture = null
			_hotbar_names[slot].text = "Vacía · clic derecho"
			_hotbar_buttons[slot].tooltip_text = "Clic derecho para asignar una habilidad"
			_hotbar_buttons[slot].modulate = Color.WHITE
			continue
		var cooldown: float = cooldowns[slot]
		var cooldown_label := "%0.1f s" % cooldown if cooldown > 0.0 else "LISTA"
		_hotbar_icons[slot].texture = _spell_icon_texture(str(ability["id"]))
		_hotbar_names[slot].text = "%s\n%s" % [ability["name"], cooldown_label]
		_hotbar_buttons[slot].tooltip_text = "%s\n%s\nAlcance: %s m" % [
			ability["name"], ability["description"], ability["range"]
		]
		_hotbar_buttons[slot].modulate = Color(0.72, 0.75, 0.8) if cooldown > 0.0 else Color.WHITE


func _spell_icon_texture(ability_id: String) -> Texture2D:
	var texture_name := "flare_01.png"
	match ability_id:
		"fuego", "meteoro", "golpe_dragon", "trampa": texture_name = "fire_02.png"
		"hielo", "tormenta", "rayo", "flecha_perforante", "flecha", "multi", "marca": texture_name = "magic_04.png"
		"veneno": texture_name = "smoke_08.png"
		"sombra", "paso_sombrio", "emboscada", "parpadeo", "voltereta": texture_name = "twirl_03.png"
		"aliento", "sanacion", "cura", "guardia": texture_name = "star_07.png"
		"corte", "barrido", "daga", "golpe", "carga", "abanico": texture_name = "slash_04.png"
		"impact", "area": texture_name = "spark_03.png"
	var path := "res://assets/kenney_particle_pack/PNG/" + texture_name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func show_talent_tree(points: int, talents: Array[Dictionary], unlocked: Array[String], level: int, available: Array[String], ranks: Dictionary = {}) -> void:
	_talent_view_data = {"points":points, "talents":talents, "unlocked":unlocked, "level":level, "available":available, "ranks":ranks}
	_talent_points_label.text = "PUNTOS DISPONIBLES: %s" % _format_talent_points(points)
	_talent_level_label.text = "NIVEL %d  ·  %d TALENTOS  ·  1 punto por nivel" % [level, talents.size()]
	_render_talent_tree()
	call_deferred("_center_talent_view")
	_talent_menu_open = true
	_talent_panel.visible = true
	_ability_picker.visible = false
	_inventory_panel.visible = false
	_inventory_open = false
	_market_panel.visible = false


func _render_talent_tree() -> void:
	var data := _talent_view_data
	var points := int(data.get("points", 0))
	var talents: Array = data.get("talents", [])
	var unlocked: Array = data.get("unlocked", [])
	var available: Array = data.get("available", [])
	for child in _talent_grid.get_children():
		child.queue_free()
	var branches: Array[String] = []
	var tier_groups: Dictionary = {}
	var max_tier := 1
	for talent in talents:
		var branch := str(talent.get("branch", "Camino"))
		max_tier = maxi(max_tier, int(talent.get("tier", 1)))
		if not branches.has(branch):
			branches.append(branch)
		var group_key := "%s:%d" % [branch, int(talent.get("tier", 1))]
		if not tier_groups.has(group_key): tier_groups[group_key] = []
		tier_groups[group_key].append(talent)
	var node_positions: Dictionary = {}
	var branch_colors: Array[Color] = [Color("#e6a35d"), Color("#7fd1b5"), Color("#91b5f2"), Color("#c28ae8"), Color("#e88686"), Color("#94c96c")]
	var branch_angles: Dictionary = {}
	for branch_index in range(branches.size()):
		branch_angles[branches[branch_index]] = -PI * 0.5 + TAU * float(branch_index) / float(maxi(1, branches.size()))
	var outer_radius := 54.0 + float(max_tier - 1) * 64.0
	var graph_size := maxf(1120.0, (outer_radius + 100.0) * 2.0)
	_talent_grid.custom_minimum_size = Vector2.ONE * graph_size
	_talent_grid.size = _talent_grid.custom_minimum_size
	var center := Vector2.ONE * graph_size * 0.5
	for ring_tier in range(1, max_tier + 1):
		_add_talent_line(_circle_points(center, 54.0 + float(ring_tier - 1) * 64.0), Color(0.42, 0.48, 0.55, 0.3), 1.0, true)
	for branch_index in range(branches.size()):
		var branch: String = branches[branch_index]
		var angle: float = branch_angles[branch]
		var endpoint := center + Vector2(cos(angle), sin(angle)) * (outer_radius + 18.0)
		_add_talent_line([center, endpoint], Color(branch_colors[branch_index % branch_colors.size()].r, branch_colors[branch_index % branch_colors.size()].g, branch_colors[branch_index % branch_colors.size()].b, 0.18), 1.5)
	for talent in talents:
		var branch := str(talent.get("branch", "Camino"))
		var tier := int(talent.get("tier", 1))
		var group_key := "%s:%d" % [branch, tier]
		var same_tier: Array = tier_groups[group_key]
		var option_index := same_tier.find(talent)
		var spread := minf(0.98, 0.13 * float(maxi(0, same_tier.size() - 1)))
		var offset_angle := 0.0 if same_tier.size() == 1 else lerpf(-spread, spread, float(option_index) / float(same_tier.size() - 1))
		var angle: float = branch_angles.get(branch, -PI * 0.5) + offset_angle
		var radius := 54.0 + float(tier - 1) * 64.0
		node_positions[str(talent["id"])] = center + Vector2(cos(angle), sin(angle)) * radius
	for talent in talents:
		var parent_id := str(talent.get("requires", ""))
		if not parent_id.is_empty() and node_positions.has(parent_id):
			var line_color := Color("#67dcae") if unlocked.has(parent_id) else Color("#65717c")
			_add_talent_line([node_positions[parent_id], node_positions[str(talent["id"])]], line_color, 1.6)
	var core := Panel.new()
	core.position = center - Vector2(18.0, 18.0)
	core.size = Vector2(36.0, 36.0)
	var core_style := StyleBoxFlat.new()
	core_style.bg_color = Color("#22283a")
	core_style.border_color = Color("#e7c17d")
	core_style.set_border_width_all(2)
	core_style.set_corner_radius_all(18)
	core.add_theme_stylebox_override("panel", core_style)
	_talent_grid.add_child(core)
	var core_label := Label.new()
	core_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	core_label.text = "✦"
	core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_label.add_theme_font_size_override("font_size", 14)
	core.add_child(core_label)
	for branch_index in range(branches.size()):
		var branch_name: String = branches[branch_index]
		var branch_label := Label.new()
		var branch_angle: float = branch_angles[branch_name]
		var label_position := center + Vector2(cos(branch_angle), sin(branch_angle)) * (outer_radius + 60.0) - Vector2(74.0, 14.0)
		label_position.x = clampf(label_position.x, 0.0, graph_size - 148.0)
		label_position.y = clampf(label_position.y, 2.0, graph_size - 28.0)
		branch_label.position = label_position
		branch_label.size = Vector2(148.0, 28.0)
		branch_label.text = branch_name.to_upper()
		branch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		branch_label.add_theme_font_size_override("font_size", 11)
		branch_label.add_theme_color_override("font_color", branch_colors[branch_index % branch_colors.size()])
		_talent_grid.add_child(branch_label)
	for talent in talents:
		var talent_id: String = talent["id"]
		var is_unlocked := unlocked.has(talent_id)
		var can_unlock := available.has(talent_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(24.0, 24.0)
		button.size = button.custom_minimum_size
		button.position = node_positions[talent_id] - button.size * 0.5
		var is_passive := bool(talent.get("passive", str(talent.get("effect", "")) != "learn_skill"))
		button.text = "✦" if is_unlocked else ("◇" if can_unlock else "·")
		button.tooltip_text = "%s · %s [%s]\n%s\n\nCuesta 1 punto · Requiere nivel %d%s" % [talent["branch"], talent["name"], "PASIVO" if is_passive else "HABILIDAD", talent["description"], 1 + (int(talent["tier"]) - 1) * 4, " y el talento conectado" if not str(talent.get("requires", "")).is_empty() else ""]
		button.disabled = not can_unlock or points <= 0
		button.add_theme_font_size_override("font_size", 9)
		var style := StyleBoxFlat.new()
		var talent_branch_index := branches.find(str(talent.get("branch", "")))
		var branch_color: Color = branch_colors[talent_branch_index % branch_colors.size()]
		style.bg_color = Color("#22644e") if is_unlocked else (Color("#263746") if can_unlock else Color("#1b2028"))
		style.border_color = Color("#b2ffe0") if is_unlocked else (branch_color if can_unlock else Color(branch_color.r, branch_color.g, branch_color.b, 0.45))
		style.set_border_width_all(2 if can_unlock or is_unlocked else 1)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#385573")
		hover.border_color = Color("#f1ce88")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("disabled", style)
		button.pressed.connect(_emit_talent_selected.bind(talent_id))
		_talent_grid.add_child(button)
	_talent_menu_open = true
	_talent_panel.visible = true
	_ability_picker.visible = false
	_inventory_panel.visible = false
	_inventory_open = false
	_market_panel.visible = false
	_spellbook_panel.visible = false


func show_spellbook(abilities: Array[Dictionary], talents: Array[Dictionary], unlocked: Array[String], hotbar_ids: Array[String], talent_skills: Array[Dictionary]) -> void:
	_selected_spell_id = ""
	_spellbook_assign_button.disabled = true
	_spellbook_slot_selector.clear()
	for slot in range(hotbar_ids.size()):
		var equipped := _find_ability(abilities, hotbar_ids[slot])
		var spell_name := str(equipped.get("name", "Vacía"))
		_spellbook_slot_selector.add_item("Ranura %d · %s" % [slot + 1, spell_name])
		_spellbook_slot_selector.set_item_metadata(slot, slot)
	if _spellbook_slot_selector.item_count > 0:
		_spellbook_slot_selector.select(0)
	for child in _spellbook_list.get_children():
		child.queue_free()
	_add_spellbook_heading("HECHIZOS Y HABILIDADES ACTIVAS")
	for ability in abilities:
		var spell_button := Button.new()
		spell_button.custom_minimum_size.y = 58.0
		spell_button.text = "%s\n%s · alcance %.1f m · recarga %.1f s" % [ability["name"], ability["description"], float(ability["range"]), float(ability["cooldown"])]
		spell_button.tooltip_text = "%s\n%s" % [ability["name"], ability["description"]]
		spell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spell_button.pressed.connect(_select_spellbook_ability.bind(str(ability["id"])))
		_spellbook_list.add_child(spell_button)
	_add_spellbook_heading("HABILIDADES POR DESBLOQUEAR")
	var locked_count := 0
	for skill in talent_skills:
		var required_talent_id := str(skill.get("talent", ""))
		if unlocked.has(required_talent_id):
			continue
		locked_count += 1
		var required_talent: Dictionary = {}
		for talent in talents:
			if str(talent.get("id", "")) == required_talent_id:
				required_talent = talent
				break
		var locked_spell := Button.new()
		locked_spell.disabled = true
		locked_spell.custom_minimum_size.y = 54.0
		locked_spell.text = "CANDADO · %s\nDesbloquea «%s» (nivel %d)" % [skill.get("name", "Habilidad"), required_talent.get("name", "Talento"), 1 + (int(required_talent.get("tier", 1)) - 1) * 4]
		locked_spell.tooltip_text = str(skill.get("description", ""))
		_spellbook_list.add_child(locked_spell)
	if locked_count == 0:
		var none_locked := Label.new()
		none_locked.text = "Has desbloqueado todas las habilidades de talento de esta clase."
		_spellbook_list.add_child(none_locked)
	_add_spellbook_heading("TALENTOS PASIVOS ACTIVOS")
	var passive_count := 0
	for talent in talents:
		var is_passive := bool(talent.get("passive", str(talent.get("effect", "")) != "learn_skill"))
		if not unlocked.has(str(talent["id"])) or not is_passive:
			continue
		passive_count += 1
		var passive_label := Label.new()
		passive_label.text = "✦ %s — %s" % [talent["name"], talent["description"]]
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_spellbook_list.add_child(passive_label)
	if passive_count == 0:
		var no_passives := Label.new()
		no_passives.text = "Aún no has aprendido talentos pasivos."
		_spellbook_list.add_child(no_passives)
	_spellbook_panel.visible = true
	_talent_panel.visible = false
	_talent_menu_open = false
	_ability_picker.visible = false
	_inventory_panel.visible = false
	_inventory_open = false
	_market_panel.visible = false


func _add_spellbook_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_color_override("font_color", Color("#f1d59e"))
	heading.add_theme_font_size_override("font_size", 16)
	_spellbook_list.add_child(heading)


func _select_spellbook_ability(ability_id: String) -> void:
	_selected_spell_id = ability_id
	_spellbook_assign_button.disabled = false
	_spellbook_assign_button.text = "Asignar habilidad seleccionada"


func _assign_spellbook_ability() -> void:
	if _selected_spell_id.is_empty() or _spellbook_slot_selector.item_count == 0:
		return
	hotbar_change_requested.emit(int(_spellbook_slot_selector.get_item_metadata(_spellbook_slot_selector.selected)), _selected_spell_id)


func close_spellbook() -> void:
	_spellbook_panel.visible = false


func is_spellbook_open() -> bool:
	return _spellbook_panel.visible


func _build_spellbook_panel() -> void:
	_spellbook_panel = PanelContainer.new()
	_spellbook_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_spellbook_panel.position = Vector2(-430.0, -315.0)
	_spellbook_panel.size = Vector2(860.0, 630.0)
	_spellbook_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#141a25")
	style.border_color = Color("#977acb")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 10.0
	_spellbook_panel.add_theme_stylebox_override("panel", style)
	add_child(_spellbook_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_spellbook_panel.add_child(content)
	var title := Label.new()
	title.text = "LIBRO DE HECHIZOS Y HABILIDADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#d7c4ff"))
	content.add_child(title)
	var assign_row := HBoxContainer.new()
	_spellbook_slot_selector = OptionButton.new()
	_spellbook_slot_selector.custom_minimum_size.x = 300.0
	assign_row.add_child(_spellbook_slot_selector)
	_spellbook_assign_button = Button.new()
	_spellbook_assign_button.text = "Selecciona una habilidad"
	_spellbook_assign_button.disabled = true
	_spellbook_assign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spellbook_assign_button.pressed.connect(_assign_spellbook_ability)
	assign_row.add_child(_spellbook_assign_button)
	content.add_child(assign_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 490.0
	content.add_child(scroll)
	_spellbook_list = VBoxContainer.new()
	_spellbook_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spellbook_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_spellbook_list)
	var close_button := Button.new()
	close_button.text = "Cerrar libro · B"
	close_button.pressed.connect(close_spellbook)
	content.add_child(close_button)


func _circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(65):
		var angle := TAU * float(step) / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _format_talent_points(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += "."
		formatted += digits[index]
	return formatted


func _add_talent_line(points: Variant, color: Color, width: float, closed: bool = false) -> void:
	var line := Line2D.new()
	var packed_points := PackedVector2Array()
	for point in points:
		packed_points.append(point)
	line.points = packed_points
	line.default_color = color
	line.width = width
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	if closed and points.size() > 0:
		line.add_point(points[0])
	_talent_grid.add_child(line)


func show_inventory(
		items: Array[Dictionary], equipment: Dictionary, stats: Dictionary, capacity: int,
		attributes: Dictionary, attribute_points: int, avatar: Node3D = null,
		level: int = 1, character_class: String = "Aventurero"
) -> void:
	_selected_inventory_index = -1
	_selected_inventory_button = null
	_backpack_item_detail.text = "Selecciona un objeto para ver sus detalles y calidad."
	_backpack_equip_button.disabled = true
	_backpack_equip_button.text = "Selecciona un objeto"
	_inventory_character_label.text = "%s  ·  NIVEL %d" % [character_class.to_upper(), level]
	_inventory_summary.text = "ATQ %d  ·  DEF %d\nVIDA ADICIONAL +%d" % [stats.get("attack", 0), stats.get("defense", 0), stats.get("health", 0)]
	_backpack_summary.text = "%d / %d espacios ocupados" % [items.size(), capacity]
	if is_instance_valid(avatar):
		_show_inventory_avatar(avatar)
	for child in _equipment_list.get_children():
		child.queue_free()
	for slot in ["head", "chest", "legs", "weapon"]:
		var item: Dictionary = equipment.get(slot, {})
		var slot_names := {"weapon":"ARMA", "head":"CASCO", "chest":"PECHO", "legs":"PIERNAS"}
		var slot_icons := {"weapon":"⚔", "head":"♜", "chest":"▣", "legs":"◈"}
		var button := Button.new()
		button.custom_minimum_size = Vector2(132.0, 66.0)
		button.text = "%s\n%s" % [slot_icons[slot], item.get("name", slot_names[slot]) if not item.is_empty() else slot_names[slot]]
		button.disabled = item.is_empty()
		if item.is_empty():
			button.tooltip_text = "Ranura vacía"
			_style_inventory_slot(button, false)
		else:
			button.tooltip_text = "Clic para quitar: %s\nCalidad: %s\nATQ +%d  DEF +%d  VIDA +%d" % [item.get("name", "Objeto"), item.get("rarity_name", "Común"), item.get("attack", 0), item.get("defense", 0), item.get("health", 0)]
			button.pressed.connect(unequip_requested.emit.bind(slot))
			button.text = ""
			_add_item_image(button, item, 8.0)
			_style_inventory_item(button, item.get("type", "armor"), item.get("rarity", "common"))
		_equipment_list.add_child(button)
	_attributes_summary.text = "ATRIBUTOS  ·  %d PUNTOS DISPONIBLES" % attribute_points
	for child in _attribute_list.get_children():
		child.queue_free()
	var names := {"strength":"Fuerza", "vitality":"Vitalidad", "agility":"Agilidad", "intellect":"Intelecto"}
	var descriptions := {"strength":"Daño +4 %", "vitality":"Vida +12", "agility":"Velocidad +1.5 % · crítico +0.5 %", "intellect":"Daño +2 % · recarga +1 %"}
	for attribute_id in ["strength", "vitality", "agility", "intellect"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  %d\n%s" % [names[attribute_id], attributes.get(attribute_id, 0), descriptions[attribute_id]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "+"
		button.custom_minimum_size = Vector2(40.0, 42.0)
		button.disabled = attribute_points <= 0
		button.pressed.connect(attribute_requested.emit.bind(attribute_id))
		row.add_child(button)
		_attribute_list.add_child(row)
	for child in _inventory_list.get_children():
		child.queue_free()
	for index in range(capacity):
		var button := Button.new()
		button.custom_minimum_size = Vector2(60.0, 58.0)
		if index < items.size():
			var item: Dictionary = items[index]
			var item_type: String = item.get("type", "material")
			_add_item_image(button, item, 5.0)
			var rarity_name: String = item.get("rarity_name", "Común")
			button.tooltip_text = "%s\nCalidad: %s\nATQ +%d  DEF +%d  VIDA +%d" % [item.get("name", "Objeto"), rarity_name, item.get("attack", 0), item.get("defense", 0), item.get("health", 0)]
			if _equipment_slot_exists(item.get("slot", "bag")):
				button.tooltip_text += "\nClic para equipar"
			else:
				button.tooltip_text += "\nMaterial guardado en la mochila"
			button.pressed.connect(_on_backpack_item_selected.bind(index, item, button))
			_style_inventory_item(button, item_type, item.get("rarity", "common"))
		else:
			button.text = ""
			button.disabled = true
			_style_inventory_slot(button, false)
		_inventory_list.add_child(button)
	_inventory_panel.visible = true
	_inventory_open = true
	_talent_panel.visible = false
	_talent_menu_open = false
	_ability_picker.visible = false
	_spellbook_panel.visible = false


func _on_backpack_item_selected(index: int, item: Dictionary, button: Button) -> void:
	if is_instance_valid(_selected_inventory_button):
		_style_inventory_item(
			_selected_inventory_button,
			str(_selected_inventory_button.get_meta("item_type", "material")),
			str(_selected_inventory_button.get_meta("rarity", "common"))
		)
	_selected_inventory_index = index
	_selected_inventory_button = button
	_style_inventory_item(button, str(item.get("type", "material")), str(item.get("rarity", "common")), true)
	var rarity_name: String = item.get("rarity_name", "Común")
	_backpack_item_detail.text = "%s  ·  %s\nATQ +%d    DEF +%d    VIDA +%d" % [item.get("name", "Objeto"), rarity_name, item.get("attack", 0), item.get("defense", 0), item.get("health", 0)]
	var can_equip := _equipment_slot_exists(str(item.get("slot", "bag")))
	_backpack_equip_button.disabled = not can_equip
	_backpack_equip_button.text = "Equipar objeto" if can_equip else "Material"


func _equip_selected_backpack_item() -> void:
	if _selected_inventory_index >= 0:
		equipment_requested.emit(_selected_inventory_index)


func close_inventory() -> void:
	_inventory_open = false
	_inventory_panel.visible = false


func is_inventory_open() -> bool:
	return _inventory_open


func open_backpack_tab() -> void:
	_inventory_tabs.current_tab = 1


func _show_inventory_avatar(source: Node3D) -> void:
	if is_instance_valid(_inventory_avatar_root):
		_inventory_avatar_root.queue_free()
	_inventory_avatar_root = source.duplicate() as Node3D
	if _inventory_avatar_root == null:
		return
	_inventory_avatar_root.visible = true
	_inventory_avatar_root.position = Vector3(0.0, -0.95, 0.0)
	_inventory_avatar_root.rotation = Vector3(0.0, PI, 0.0)
	_inventory_avatar_root.scale = Vector3.ONE * 0.88
	if _inventory_avatar_root.has_method("set_spinning"):
		_inventory_avatar_root.call("set_spinning", true)
	_inventory_viewport.add_child(_inventory_avatar_root)


func _style_inventory_slot(button: Button, occupied: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202a36") if not occupied else Color("#3b3024")
	style.border_color = Color("#536477") if not occupied else Color("#d7ad61")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", 17)


func _item_texture(item: Dictionary) -> Texture2D:
	var icon_path: String = item.get("icon_path", "")
	if icon_path.is_empty():
		var slot: String = item.get("slot", "bag")
		var legacy_icons := {"weapon":"res://assets/items/icon_sword.svg", "chest":"res://assets/items/icon_armor.svg", "head":"res://assets/items/icon_helmet.svg", "legs":"res://assets/items/icon_boots.svg", "bag":"res://assets/items/icon_material.svg"}
		icon_path = legacy_icons.get(slot, "res://assets/items/icon_material.svg")
	return load(icon_path) as Texture2D


func _add_item_image(button: Button, item: Dictionary, inset: float) -> void:
	var image := TextureRect.new()
	image.texture = _item_texture(item)
	if image.texture == null:
		var fallback := Label.new()
		fallback.text = str(item.get("type", "item")).left(3).to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.add_theme_font_size_override("font_size", 16)
		button.add_child(fallback)
		return
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = inset
	image.offset_top = inset
	image.offset_right = -inset
	image.offset_bottom = -inset
	button.add_child(image)


func _rarity_color(rarity: String) -> Color:
	var colors := {
		"common": Color("#a7afb9"),
		"uncommon": Color("#62d881"),
		"rare": Color("#5bb4ff"),
		"epic": Color("#cb78ff"),
		"legendary": Color("#ffc653"),
	}
	return colors.get(rarity, colors["common"])


func _style_inventory_item(button: Button, item_type: String, rarity: String, selected: bool = false) -> void:
	var colors := {"weapon":Color("#78434b"), "armor":Color("#405e73"), "material":Color("#596044")}
	var style := StyleBoxFlat.new()
	style.bg_color = colors.get(item_type, Color("#3b4651"))
	style.border_color = Color.WHITE if selected else _rarity_color(rarity)
	var border_width := 1
	if rarity in ["uncommon", "rare"]:
		border_width = 2
	elif rarity == "epic":
		border_width = 3
	elif rarity == "legendary":
		border_width = 4
	if selected:
		border_width = 4
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.set_meta("item_type", item_type)
	button.set_meta("rarity", rarity)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = style.bg_color.lightened(0.18)
	button.add_theme_stylebox_override("hover", hover_style)


func _equipment_slot_exists(slot: String) -> bool:
	return slot in ["weapon", "head", "chest", "legs"]


func _build_inventory_panel() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_inventory_panel.position = Vector2(-520.0, -345.0)
	_inventory_panel.size = Vector2(1040.0, 690.0)
	_inventory_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#111820")
	panel_style.border_color = Color("#c49a52")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	_inventory_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_inventory_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_inventory_panel.add_child(content)
	var title := Label.new()
	title.text = "PERSONAJE  ·  EQUIPO  ·  MOCHILA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	content.add_child(title)
	_inventory_character_label = Label.new()
	_inventory_character_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_inventory_character_label)
	_inventory_tabs = TabContainer.new()
	_inventory_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_tabs.custom_minimum_size.y = 500.0
	content.add_child(_inventory_tabs)
	var equipment_page := VBoxContainer.new()
	equipment_page.name = "Equipamiento"
	_inventory_tabs.add_child(equipment_page)
	var upper := HBoxContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.add_theme_constant_override("separation", 12)
	equipment_page.add_child(upper)
	_equipment_list = VBoxContainer.new()
	_equipment_list.custom_minimum_size.x = 145.0
	_equipment_list.add_theme_constant_override("separation", 7)
	upper.add_child(_equipment_list)
	_inventory_viewport = SubViewport.new()
	_inventory_viewport.size = Vector2i(340, 330)
	_inventory_viewport.own_world_3d = true
	_inventory_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(340.0, 330.0)
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.add_child(_inventory_viewport)
	upper.add_child(preview_container)
	var preview_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111923")
	_inventory_viewport.add_child(preview_environment)
	preview_environment.environment = environment
	var preview_camera := Camera3D.new()
	preview_camera.position = Vector3(0.0, 1.05, 3.9)
	preview_camera.current = true
	_inventory_viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)
	var preview_light := DirectionalLight3D.new()
	preview_light.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	preview_light.light_energy = 1.8
	_inventory_viewport.add_child(preview_light)
	var stats_panel := PanelContainer.new()
	stats_panel.custom_minimum_size.x = 300.0
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper.add_child(stats_panel)
	var stats_content := VBoxContainer.new()
	stats_content.add_theme_constant_override("separation", 7)
	stats_panel.add_child(stats_content)
	_inventory_summary = Label.new()
	_inventory_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_content.add_child(_inventory_summary)
	_attributes_summary = Label.new()
	_attributes_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_content.add_child(_attributes_summary)
	_attribute_list = VBoxContainer.new()
	_attribute_list.add_theme_constant_override("separation", 8)
	stats_content.add_child(_attribute_list)
	var backpack_header := Label.new()
	backpack_header.text = "MOCHILA  ·  Selecciona un objeto para equiparlo"
	backpack_header.add_theme_font_size_override("font_size", 15)
	var backpack_page := VBoxContainer.new()
	backpack_page.name = "Mochila"
	backpack_page.add_theme_constant_override("separation", 10)
	_inventory_tabs.add_child(backpack_page)
	backpack_page.add_child(backpack_header)
	_backpack_summary = Label.new()
	_backpack_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_page.add_child(_backpack_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack_page.add_child(scroll)
	_inventory_list = GridContainer.new()
	_inventory_list.columns = 8
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("h_separation", 6)
	_inventory_list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_inventory_list)
	var selected_item_row := HBoxContainer.new()
	selected_item_row.add_theme_constant_override("separation", 10)
	backpack_page.add_child(selected_item_row)
	_backpack_item_detail = Label.new()
	_backpack_item_detail.text = "Selecciona un objeto para ver sus detalles y calidad."
	_backpack_item_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_item_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_item_row.add_child(_backpack_item_detail)
	_backpack_equip_button = Button.new()
	_backpack_equip_button.text = "Selecciona un objeto"
	_backpack_equip_button.disabled = true
	_backpack_equip_button.custom_minimum_size = Vector2(170.0, 48.0)
	_backpack_equip_button.pressed.connect(_equip_selected_backpack_item)
	selected_item_row.add_child(_backpack_equip_button)
	var close_button := Button.new()
	close_button.text = "Cerrar · M"
	close_button.pressed.connect(close_inventory)
	content.add_child(close_button)


func _emit_talent_selected(talent_id: String) -> void:
	talent_selected.emit(talent_id, 1)


func close_talent_tree() -> void:
	_talent_menu_open = false
	_talent_panel.visible = false


func is_talent_menu_open() -> bool:
	return _talent_menu_open


func is_ability_picker_open() -> bool:
	return _ability_picker.visible


func close_ability_picker() -> void:
	_ability_picker.visible = false
	_selected_picker_slot = -1


func _find_ability(abilities: Array[Dictionary], ability_id: String) -> Dictionary:
	for ability in abilities:
		if ability["id"] == ability_id:
			return ability
	return {}


func _request_ability(slot: int) -> void:
	ability_requested.emit(slot)


func _show_ability_picker(slot: int, abilities: Array[Dictionary]) -> void:
	_selected_picker_slot = slot
	_ability_picker_title.text = "ASIGNAR HABILIDAD · RANURA %d" % (slot + 1)
	for child in _ability_picker_list.get_children():
		child.queue_free()
	for ability in abilities:
		var button := Button.new()
		button.custom_minimum_size.y = 48.0
		button.text = "%s  ·  %s\n%s  |  Reutilización: %d s" % [
			ability["name"],
			ability["description"],
			"Área: %.1f m" % ability["radius"] if ability["effect"] == "area" else "Alcance: %.1f m" % ability["range"],
			ceili(float(ability["cooldown"])),
		]
		button.pressed.connect(_assign_ability.bind(str(ability["id"])))
		_ability_picker_list.add_child(button)
	_ability_picker.visible = true
	_spellbook_panel.visible = false


func _assign_ability(ability_id: String) -> void:
	if _selected_picker_slot >= 0:
		hotbar_change_requested.emit(_selected_picker_slot, ability_id)


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20.0, 18.0)
	panel.size = Vector2(390.0, 140.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)

	_health_label = Label.new()
	_health_label.add_theme_color_override("font_color", Color("#ffe5d6"))
	content.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size.y = 17.0
	_health_bar.show_percentage = false
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("#d52e43")
	health_fill.corner_radius_top_left = 4
	health_fill.corner_radius_top_right = 4
	health_fill.corner_radius_bottom_left = 4
	health_fill.corner_radius_bottom_right = 4
	_health_bar.add_theme_stylebox_override("fill", health_fill)
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("#351e27")
	health_background.corner_radius_top_left = 4
	health_background.corner_radius_top_right = 4
	health_background.corner_radius_bottom_left = 4
	health_background.corner_radius_bottom_right = 4
	_health_bar.add_theme_stylebox_override("background", health_background)
	content.add_child(_health_bar)
	_progress_label = Label.new()
	_progress_label.add_theme_color_override("font_color", Color("#f0ddb0"))
	content.add_child(_progress_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size.y = 12.0
	_xp_bar.show_percentage = false
	content.add_child(_xp_bar)

	var instructions := Label.new()
	instructions.text = "1-6: HABILIDADES     B: HECHIZOS     M: MOCHILA     T: TALENTOS     E: PORTAL"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color("#d5e0dc"))
	content.add_child(instructions)
	_message_label = Label.new()
	_message_label.add_theme_color_override("font_color", Color("#ffe0a8"))
	content.add_child(_message_label)


func _build_boss_panel() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.anchor_left = 0.5
	_boss_panel.anchor_right = 0.5
	_boss_panel.offset_left = -190.0
	_boss_panel.offset_right = 190.0
	_boss_panel.offset_top = 20.0
	_boss_panel.offset_bottom = 100.0
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	add_child(_boss_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_boss_panel.add_child(row)
	var portrait_container := SubViewportContainer.new()
	portrait_container.custom_minimum_size = Vector2(68.0, 68.0)
	portrait_container.stretch = true
	portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_container)
	_boss_portrait_viewport = SubViewport.new()
	_boss_portrait_viewport.size = Vector2i(128, 128)
	_boss_portrait_viewport.transparent_bg = false
	_boss_portrait_viewport.world_3d = World3D.new()
	portrait_container.add_child(_boss_portrait_viewport)
	_boss_portrait_root = Node3D.new()
	_boss_portrait_root.name = "PortraitScene"
	_boss_portrait_viewport.add_child(_boss_portrait_root)
	var portrait_environment := WorldEnvironment.new()
	var portrait_world := Environment.new()
	portrait_world.background_mode = Environment.BG_COLOR
	portrait_world.background_color = Color("#242a32")
	portrait_world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	portrait_world.ambient_light_color = Color("#d3d9e2")
	portrait_world.ambient_light_energy = 1.0
	portrait_environment.environment = portrait_world
	_boss_portrait_root.add_child(portrait_environment)
	var portrait_camera := Camera3D.new()
	portrait_camera.position = Vector3(0.0, 0.0, 3.4)
	portrait_camera.fov = 35.0
	portrait_camera.current = true
	_boss_portrait_root.add_child(portrait_camera)
	portrait_camera.look_at(Vector3.ZERO)
	var portrait_light := DirectionalLight3D.new()
	portrait_light.rotation_degrees = Vector3(-25.0, -25.0, 0.0)
	portrait_light.light_energy = 1.4
	_boss_portrait_root.add_child(portrait_light)
	_boss_model_root = Node3D.new()
	_boss_model_root.name = "MonsterPortrait"
	_boss_portrait_root.add_child(_boss_model_root)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(content)
	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_color_override("font_color", Color("#ffe0c1"))
	content.add_child(_boss_name_label)
	_boss_health_bar = ProgressBar.new()
	_boss_health_bar.custom_minimum_size.y = 20.0
	_boss_health_bar.show_percentage = false
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("#cf3042")
	_boss_health_bar.add_theme_stylebox_override("fill", boss_fill)
	content.add_child(_boss_health_bar)


func _set_boss_portrait(portrait_scene: PackedScene) -> void:
	var scene_key := ""
	if portrait_scene != null:
		scene_key = portrait_scene.resource_path
	if scene_key == _boss_portrait_key:
		return
	_boss_portrait_key = scene_key
	for child in _boss_model_root.get_children():
		child.queue_free()
	if portrait_scene == null:
		return
	var model := portrait_scene.instantiate() as Node3D
	if model == null:
		return
	_boss_model_root.add_child(model)
	var bounds := _find_model_bounds(model, Transform3D.IDENTITY)
	if bounds.size.length() <= 0.001:
		return
	var largest_axis := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit_scale := 2.1 / maxf(largest_axis, 0.001)
	model.scale = Vector3.ONE * fit_scale
	model.position = -bounds.get_center() * fit_scale
	model.rotation.y = deg_to_rad(25.0)


func _find_model_bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var node_transform := parent_transform
	if node is Node3D:
		node_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		bounds = node_transform * (node as MeshInstance3D).get_aabb()
		has_bounds = true
	for child in node.get_children():
		var child_bounds := _find_model_bounds(child, node_transform)
		if child_bounds.size.length() > 0.001:
			bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
			has_bounds = true
	return bounds


func _build_hotbar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -318.0
	panel.offset_right = 318.0
	panel.offset_top = -88.0
	panel.offset_bottom = -8.0
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	for slot in range(6):
		var button := Button.new()
		button.custom_minimum_size = Vector2(100.0, 67.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = ""
		button.pressed.connect(_request_ability.bind(slot))
		button.gui_input.connect(_on_hotbar_input.bind(slot))
		row.add_child(button)
		var icon := TextureRect.new()
		icon.position = Vector2(31.0, 3.0)
		icon.size = Vector2(38.0, 38.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_hotbar_icons.append(icon)
		var key_label := Label.new()
		key_label.position = Vector2(4.0, 1.0)
		key_label.size = Vector2(18.0, 18.0)
		key_label.text = SLOT_KEYS[slot]
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color("#f4d49b"))
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key_label)
		var name_label := Label.new()
		name_label.position = Vector2(2.0, 42.0)
		name_label.size = Vector2(96.0, 23.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color", Color("#ffffff"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		_hotbar_names.append(name_label)
		_hotbar_buttons.append(button)


func _on_hotbar_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		hotbar_change_requested.emit(-slot - 1, "")
		get_viewport().set_input_as_handled()


func show_ability_picker(slot: int, abilities: Array[Dictionary]) -> void:
	_show_ability_picker(slot, abilities)


func _build_ability_picker() -> void:
	_ability_picker = PanelContainer.new()
	_ability_picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ability_picker.position = Vector2(-270.0, -245.0)
	_ability_picker.size = Vector2(540.0, 490.0)
	_ability_picker.visible = false
	add_child(_ability_picker)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_ability_picker.add_child(content)
	_ability_picker_title = Label.new()
	_ability_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_picker_title.add_theme_font_size_override("font_size", 19)
	content.add_child(_ability_picker_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_ability_picker_list = VBoxContainer.new()
	_ability_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ability_picker_list)


func _build_talent_panel() -> void:
	_talent_panel = PanelContainer.new()
	_talent_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_talent_panel.position = Vector2(-590.0, -340.0)
	_talent_panel.size = Vector2(1180.0, 680.0)
	_talent_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#111923")
	panel_style.border_color = Color("#657c8b")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 8.0
	_talent_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_talent_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_talent_panel.add_child(content)

	var title := Label.new()
	title.text = "ÁRBOL DE TALENTOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f1d59e"))
	content.add_child(title)
	_talent_points_label = Label.new()
	_talent_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_talent_points_label)
	_talent_level_label = Label.new()
	_talent_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_talent_level_label)
	var explore_label := Label.new()
	explore_label.text = "Rueda del ratón o barras para recorrer las 13 etapas del anillo"
	explore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explore_label.add_theme_font_size_override("font_size", 11)
	content.add_child(explore_label)
	_talent_scroll = ScrollContainer.new()
	_talent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_talent_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_talent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_talent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(_talent_scroll)
	_talent_grid = Control.new()
	_talent_scroll.add_child(_talent_grid)
	var close_button := Button.new()
	close_button.text = "Cerrar · T"
	close_button.pressed.connect(close_talent_tree)
	content.add_child(close_button)


func _center_talent_view() -> void:
	if not is_instance_valid(_talent_scroll) or not is_instance_valid(_talent_grid):
		return
	_talent_scroll.scroll_horizontal = maxi(0, int((_talent_grid.size.x - _talent_scroll.size.x) * 0.5))
	_talent_scroll.scroll_vertical = maxi(0, int((_talent_grid.size.y - _talent_scroll.size.y) * 0.5))


func set_message(message: String) -> void:
	_message_label.text = message


func _build_market_panel() -> void:
	_market_panel = PanelContainer.new()
	_market_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_market_panel.position = Vector2(-300, -240)
	_market_panel.size = Vector2(600, 480)
	_market_panel.visible = false
	add_child(_market_panel)
	_market_content = VBoxContainer.new()
	_market_content.add_theme_constant_override("separation", 10)
	_market_panel.add_child(_market_content)


func _build_options_panel() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_options_panel.position = Vector2(-390.0, -320.0)
	_options_panel.size = Vector2(780.0, 640.0)
	_options_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#151c27")
	panel_style.border_color = Color("#b9975c")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 16.0
	panel_style.content_margin_bottom = 16.0
	_options_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_options_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_options_panel.add_child(layout)
	var title := Label.new()
	title.text = "OPCIONES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f1d59e"))
	layout.add_child(title)
	var resolution_row := HBoxContainer.new()
	var resolution_label := Label.new()
	resolution_label.text = "Resolución de ventana"
	resolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution_row.add_child(resolution_label)
	_options_resolution = OptionButton.new()
	_options_resolution.custom_minimum_size.x = 210.0
	var resolutions: Array[Vector2i] = [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]
	for resolution in resolutions:
		_options_resolution.add_item("%d × %d" % [resolution.x, resolution.y])
		_options_resolution.set_item_metadata(_options_resolution.item_count - 1, resolution)
	_options_resolution.item_selected.connect(_on_options_resolution_selected)
	resolution_row.add_child(_options_resolution)
	layout.add_child(resolution_row)
	var key_heading := Label.new()
	key_heading.text = "ASIGNACIÓN DE TECLAS · selecciona una acción y pulsa su nueva tecla"
	key_heading.add_theme_color_override("font_color", Color("#9bc6db"))
	layout.add_child(key_heading)
	var key_scroll := ScrollContainer.new()
	key_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(key_scroll)
	var key_list := VBoxContainer.new()
	key_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_list.add_theme_constant_override("separation", 3)
	key_scroll.add_child(key_list)
	var actions := [
		["move_forward", "Avanzar"], ["move_back", "Retroceder"], ["move_left", "Mover a la izquierda"], ["move_right", "Mover a la derecha"],
		["sprint", "Correr"], ["jump", "Saltar"], ["interact", "Interactuar"], ["camera", "Cambiar cámara"],
		["talents", "Árbol de talentos"], ["spellbook", "Libro de hechizos"], ["inventory", "Inventario"], ["pause", "Abrir opciones"],
		["ability_1", "Habilidad 1"], ["ability_2", "Habilidad 2"], ["ability_3", "Habilidad 3"],
		["ability_4", "Habilidad 4"], ["ability_5", "Habilidad 5"], ["ability_6", "Habilidad 6"],
		["respawn", "Reaparecer"],
	]
	for action in actions:
		var action_id: String = action[0]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = action[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(150.0, 32.0)
		bind_button.pressed.connect(keybind_requested.emit.bind(action_id))
		row.add_child(bind_button)
		key_list.add_child(row)
		_options_key_buttons[action_id] = bind_button
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 14)
	var resume := Button.new()
	resume.text = "Volver al juego"
	resume.custom_minimum_size = Vector2(190.0, 42.0)
	resume.pressed.connect(resume_requested.emit)
	button_row.add_child(resume)
	var exit := Button.new()
	exit.text = "Salir del juego"
	exit.custom_minimum_size = Vector2(190.0, 42.0)
	exit.pressed.connect(exit_requested.emit)
	button_row.add_child(exit)
	layout.add_child(button_row)


func show_options(keybinds: Dictionary, current_resolution: Vector2i) -> void:
	for action_name in _options_key_buttons:
		update_options_key(str(action_name), int(keybinds.get(action_name, 0)))
	var has_current_resolution := false
	for index in range(_options_resolution.item_count):
		if _options_resolution.get_item_metadata(index) == current_resolution:
			_options_resolution.select(index)
			has_current_resolution = true
			break
	if not has_current_resolution:
		_options_resolution.add_item("%d × %d (actual)" % [current_resolution.x, current_resolution.y])
		_options_resolution.set_item_metadata(_options_resolution.item_count - 1, current_resolution)
		_options_resolution.select(_options_resolution.item_count - 1)
	_options_panel.visible = true
	_talent_panel.visible = false
	_talent_menu_open = false
	_inventory_panel.visible = false
	_inventory_open = false
	_ability_picker.visible = false
	_market_panel.visible = false
	_spellbook_panel.visible = false


func update_options_key(action_name: String, keycode: int) -> void:
	if _options_key_buttons.has(action_name):
		(_options_key_buttons[action_name] as Button).text = OS.get_keycode_string(keycode)


func await_keybind(action_name: String) -> void:
	if _options_key_buttons.has(action_name):
		(_options_key_buttons[action_name] as Button).text = "Pulsa una tecla..."


func is_options_open() -> bool:
	return _options_panel.visible


func close_options() -> void:
	_options_panel.visible = false


func _on_options_resolution_selected(index: int) -> void:
	var resolution: Vector2i = _options_resolution.get_item_metadata(index)
	resolution_requested.emit(resolution.x, resolution.y)


func show_market(merchant: String, gold: int, stock: Array[Dictionary], items: Array[Dictionary]) -> void:
	for child in _market_content.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "MERCADO · %s · %d monedas" % [merchant, gold]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	_market_content.add_child(title)
	var goods := Label.new()
	goods.text = "COMPRAR"
	_market_content.add_child(goods)
	for item in stock:
		var button := Button.new()
		button.text = "%s  ·  %d monedas\n%s" % [item["name"], item["price"], item["description"]]
		button.custom_minimum_size.y = 54
		button.pressed.connect(market_buy_requested.emit.bind(str(item["id"])))
		_market_content.add_child(button)
	var sell_title := Label.new()
	sell_title.text = "VENDER · mochila"
	_market_content.add_child(sell_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 80
	_market_content.add_child(scroll)
	var sell_list := VBoxContainer.new()
	scroll.add_child(sell_list)
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var value := maxi(4, int(item.get("attack",0))*4 + int(item.get("defense",0))*3 + int(item.get("health",0)) + (12 if item.get("type")=="material" else 0))
		var button := Button.new()
		button.text = "%s  ·  vender por %d" % [item.get("name", "Objeto"), value]
		button.pressed.connect(market_sell_requested.emit.bind(i))
		sell_list.add_child(button)
	var close := Button.new()
	close.text = "Cerrar · Esc"
	close.pressed.connect(close_market)
	_market_content.add_child(close)
	_market_panel.visible = true
	_spellbook_panel.visible = false
	_inventory_panel.visible = false
	_talent_panel.visible = false
	_ability_picker.visible = false


func close_market() -> void:
	_market_panel.visible = false


func is_market_open() -> bool:
	return _market_panel.visible
