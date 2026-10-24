extends Node3D

const SKIN_TONES: Array[Color] = [
	Color("#f3cfb3"), Color("#dfad88"), Color("#bd805e"), Color("#966044"),
	Color("#70452f"), Color("#4b3027"), Color("#e8c4a5"), Color("#c99472"),
]
const HAIR_COLORS: Array[Color] = [
	Color("#211c1a"), Color("#493126"), Color("#865334"), Color("#c18b51"),
	Color("#d5c49c"), Color("#9f3437"), Color("#593f8c"), Color("#e0e5eb"),
]
const EYE_COLORS: Array[Color] = [
	Color("#453126"), Color("#6d8a46"), Color("#4b83a6"), Color("#8b6746"),
	Color("#58616d"), Color("#6e4e7f"),
]
const OUTFIT_COLORS: Array[Color] = [
	Color("#406b82"), Color("#a94d43"), Color("#4d7659"), Color("#c28c43"),
	Color("#514b78"), Color("#343d49"), Color("#d0c4a6"), Color("#8a5576"),
]
const CLASS_PROP_SCENES := {
	"sword": preload("res://assets/custom_equipment/class_gear/fitted_sword.glb"),
	"shield": preload("res://assets/custom_equipment/class_gear/fitted_shield.glb"),
	"bow": preload("res://assets/custom_equipment/class_gear/fitted_bow.glb"),
	"quiver": preload("res://assets/custom_equipment/class_gear/fitted_quiver.glb"),
	"staff": preload("res://assets/custom_equipment/class_gear/fitted_staff.glb"),
	"dagger": preload("res://assets/custom_equipment/class_gear/fitted_dagger.glb"),
}
const LEATHER_ALBEDO := preload("res://assets/polyhaven/fabric_leather_01/textures/fabric_leather_01_diff_1k.jpg")
const LEATHER_NORMAL := preload("res://assets/polyhaven/fabric_leather_01/textures/fabric_leather_01_nor_gl_1k.jpg")
const LEATHER_ARM := preload("res://assets/polyhaven/fabric_leather_01/textures/fabric_leather_01_arm_1k.jpg")
const HUMAN_BODY_SCENES := [
	preload("res://assets/quaternius/human_characters/Superhero_Female_FullBody.gltf"),
	preload("res://assets/quaternius/human_characters/Superhero_Male_FullBody.gltf"),
]
const HUMAN_HAIR_SCENES := [
	preload("res://assets/quaternius/human_hairstyles/Hair_Buzzed.gltf"),
	preload("res://assets/quaternius/human_hairstyles/Hair_Long.gltf"),
	preload("res://assets/quaternius/human_hairstyles/Hair_Buns.gltf"),
	preload("res://assets/quaternius/human_hairstyles/Hair_SimpleParted.gltf"),
	preload("res://assets/quaternius/human_hairstyles/Hair_Buns.gltf"),
	preload("res://assets/quaternius/human_hairstyles/Hair_Long.gltf"),
]
const SPECIES_SCENES := {
	4: preload("res://assets/quaternius/species/Imp.glb"),
	5: preload("res://assets/quaternius/species/Puglin.glb"),
}
const HUMAN_LIGHT_TEXTURES := [
	preload("res://assets/quaternius/human_characters/T_Superhero_Female_Light_BaseColor.png"),
	preload("res://assets/quaternius/human_characters/T_Superhero_Male_Ligh.png"),
]
const HUMAN_DARK_TEXTURES := [
	preload("res://assets/quaternius/human_characters/T_Superhero_Female_Dark_BaseColor.png"),
	preload("res://assets/quaternius/human_characters/T_Superhero_Male_Dark.png"),
]
const HUMAN_EYE_TEXTURE := preload("res://assets/quaternius/human_characters/T_Eye_Brown.png")
const RELAXED_ARM_ANGLE := 0.58

var _profile: Dictionary = {}
var _spin := true
var _motion_phase := 0.0
var _motion_intensity := 0.0
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D
var _left_elbow_pivot: Node3D
var _right_elbow_pivot: Node3D
var _left_knee_pivot: Node3D
var _right_knee_pivot: Node3D
var _torso_pivot: Node3D
var _head_pivot: Node3D
var _species_skeleton: Skeleton3D
var _hair_skeleton: Skeleton3D
var _species_bone_ids: Dictionary[String, int] = {}
var _species_bone_rest_rotations: Dictionary[String, Quaternion] = {}
var _hair_bone_pairs: Array[Vector2i] = []
var _attack_pose := 0.0
var _pose_blend := 1.0
var _attack_target: Node3D


func _ready() -> void:
	_build_avatar()


func apply_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	if is_inside_tree():
		_build_avatar()


func _process(delta: float) -> void:
	if _spin:
		rotate_y(delta * 0.22)


func set_spinning(enabled: bool) -> void:
	_spin = enabled


func set_attack_target(target: Node3D) -> void:
	_attack_target = target if is_instance_valid(target) else null


func set_motion(speed_ratio: float, grounded: bool, vertical_speed: float, sprinting: bool, delta: float) -> void:
	_pose_blend = 1.0 - exp(-delta * 12.0)
	var intensity := clampf(speed_ratio, 0.0, 1.0)
	_motion_intensity = lerpf(_motion_intensity, intensity, 1.0 - exp(-delta * (10.0 if grounded else 4.5)))
	if grounded and _motion_intensity > 0.025:
		_motion_phase += delta * lerpf(7.0, 12.5, _motion_intensity)
	var stride := sin(_motion_phase) * _motion_intensity
	var airborne := not grounded
	if is_instance_valid(_left_leg_pivot):
		_left_leg_pivot.rotation.x = stride * (0.48 if not sprinting else 0.58) if grounded else (0.12 if vertical_speed > 0.0 else -0.3)
		_right_leg_pivot.rotation.x = -stride * (0.48 if not sprinting else 0.58) if grounded else (0.12 if vertical_speed > 0.0 else -0.3)
	if is_instance_valid(_left_knee_pivot):
		_left_knee_pivot.rotation.x = maxf(0.0, sin(_motion_phase + PI * 0.5)) * _motion_intensity * (0.42 if sprinting else 0.28) if grounded else (0.2 if vertical_speed > 0.0 else 0.48)
		_right_knee_pivot.rotation.x = maxf(0.0, sin(_motion_phase - PI * 0.5)) * _motion_intensity * (0.42 if sprinting else 0.28) if grounded else (0.2 if vertical_speed > 0.0 else 0.48)
	if is_instance_valid(_left_arm_pivot):
		_left_arm_pivot.rotation.x = -stride * 0.36 if grounded else (0.48 if vertical_speed > 0.0 else 0.68)
		_right_arm_pivot.rotation.x = stride * 0.36 if grounded else (0.48 if vertical_speed > 0.0 else 0.68)
	if is_instance_valid(_left_elbow_pivot):
		_left_elbow_pivot.rotation.x = -0.16 - absf(stride) * 0.22 if grounded else -0.3
		_right_elbow_pivot.rotation.x = -0.16 - absf(stride) * 0.22 if grounded else -0.3
	if is_instance_valid(_torso_pivot):
		_torso_pivot.rotation.x = (-0.06 if sprinting else -0.025) * _motion_intensity if grounded else (-0.12 if vertical_speed > 0.0 else 0.16)
		_torso_pivot.rotation.z = sin(_motion_phase * 0.5) * 0.025 * _motion_intensity if grounded else 0.0
		_torso_pivot.position.y = lerpf(
			_torso_pivot.position.y,
			0.72 + (0.035 * absf(sin(_motion_phase * 2.0)) * _motion_intensity if grounded else 0.045),
			1.0 - exp(-delta * 9.0)
		)
	if is_instance_valid(_head_pivot):
		_head_pivot.rotation.x = lerpf(_head_pivot.rotation.x, 0.0 if grounded else 0.08, 1.0 - exp(-delta * 8.0))
	elif is_instance_valid(_species_skeleton):
		_animate_species_skeleton(stride, grounded, sprinting, vertical_speed, delta)
	if airborne and vertical_speed < -5.0 and is_instance_valid(_torso_pivot):
		_torso_pivot.rotation.x = -0.18


func set_activity_motion(activity_id: int, phase: float) -> void:
	var gesture := sin(phase * 2.4)
	var right_arm := 0.0
	var left_arm := 0.0
	var lean := 0.0
	match activity_id:
		1: # Market: greet and gesture to visitors.
			right_arm = -0.55 - absf(gesture) * 0.55
			left_arm = -0.28 + gesture * 0.22
		2: # Well: reach down and lift the bucket.
			right_arm = 0.5 + gesture * 0.42
			lean = 0.12 + absf(gesture) * 0.07
		3: # Garden: tend plants with a repeated low reach.
			right_arm = 0.72 + gesture * 0.3
			left_arm = 0.28 - gesture * 0.18
			lean = 0.2 + absf(gesture) * 0.08
	if is_instance_valid(_species_skeleton):
		_rotate_species_bone("upperarm_r", right_arm, Vector3.BACK)
		_rotate_species_bone("upperarm_l", left_arm, Vector3.BACK)
		_rotate_species_bone("lowerarm_r", maxf(0.0, right_arm) * 0.5, Vector3.BACK)
		_rotate_species_bone("spine_03", lean)
	else:
		if is_instance_valid(_right_arm_pivot):
			_right_arm_pivot.rotation.x = lerpf(_right_arm_pivot.rotation.x, right_arm, 0.35)
		if is_instance_valid(_left_arm_pivot):
			_left_arm_pivot.rotation.x = lerpf(_left_arm_pivot.rotation.x, left_arm, 0.35)
		if is_instance_valid(_torso_pivot):
			_torso_pivot.rotation.x = lerpf(_torso_pivot.rotation.x, lean, 0.25)


func set_attack_motion(intensity: float, phase: float, class_id: int) -> void:
	if intensity <= 0.01:
		if _attack_pose > 0.01:
			_attack_pose = 0.0
			_animate_species_skeleton(0.0, true, false, 0.0, 0.0)
		if is_instance_valid(_left_arm_pivot):
			_left_arm_pivot.rotation.x = lerpf(_left_arm_pivot.rotation.x, 0.0, 0.35)
			_left_arm_pivot.rotation.y = lerpf(_left_arm_pivot.rotation.y, 0.0, 0.35)
			_left_arm_pivot.rotation.z = lerpf(_left_arm_pivot.rotation.z, 0.0, 0.35)
		if is_instance_valid(_right_arm_pivot):
			_right_arm_pivot.rotation.x = lerpf(_right_arm_pivot.rotation.x, 0.0, 0.35)
			_right_arm_pivot.rotation.y = lerpf(_right_arm_pivot.rotation.y, 0.0, 0.35)
			_right_arm_pivot.rotation.z = lerpf(_right_arm_pivot.rotation.z, 0.0, 0.35)
		return

	_attack_pose = intensity
	var progress := clampf(1.0 - intensity, 0.0, 1.0)
	var strike := sin(clampf((progress - 0.16) / 0.62, 0.0, 1.0) * PI)
	var windup := 1.0 - smoothstep(0.0, 0.38, progress)
	var alternating_strike := strike * (1.0 if int(phase) % 2 == 0 else -1.0)
	var aim_pitch := 0.0
	if is_instance_valid(_attack_target) and _attack_target.is_inside_tree():
		var aim_vector := _attack_target.global_position + Vector3.UP * 0.85 - global_position
		var local_aim := global_basis.inverse() * aim_vector
		aim_pitch = clampf(atan2(local_aim.y, Vector2(local_aim.x, local_aim.z).length()), -0.62, 0.62)
	if is_instance_valid(_species_skeleton):
		match class_id:
			0:
				_rotate_species_bone("upperarm_r", 0.72 + windup * 0.3 - strike * 1.35 + aim_pitch * 0.5, Vector3.BACK)
				_rotate_species_bone("upperarm_l", -0.72 + strike * 0.18, Vector3.BACK)
				_rotate_species_bone("lowerarm_r", -0.3 - strike * 0.85, Vector3.BACK)
				_rotate_species_bone("lowerarm_l", -0.24 - windup * 0.16, Vector3.BACK)
				_rotate_species_bone("hand_r", strike * 0.72, Vector3.UP)
				_rotate_species_bone("spine_03", -strike * 0.16, Vector3.UP)
			1:
				_rotate_species_bone("upperarm_l", -0.24 - windup * 0.14 + aim_pitch * 0.35, Vector3.BACK)
				_rotate_species_bone("upperarm_r", 0.2 - windup * 0.72 + strike * 0.38 + aim_pitch * 0.6, Vector3.BACK)
				_rotate_species_bone("lowerarm_l", -0.3, Vector3.BACK)
				_rotate_species_bone("lowerarm_r", -0.18 - windup * 0.58 + strike * 0.32, Vector3.BACK)
				_rotate_species_bone("hand_r", -windup * 0.24 + strike * 0.18, Vector3.RIGHT)
			2:
				_rotate_species_bone("upperarm_r", 0.78 + windup * 0.28 - strike * 0.72 + aim_pitch * 0.65, Vector3.BACK)
				_rotate_species_bone("upperarm_l", -0.48 - windup * 0.3 + aim_pitch * 0.35, Vector3.BACK)
				_rotate_species_bone("lowerarm_r", -0.4 - strike * 0.45, Vector3.BACK)
				_rotate_species_bone("lowerarm_l", -0.32 - strike * 0.18, Vector3.BACK)
				_rotate_species_bone("hand_r", strike * 0.32, Vector3.RIGHT)
			3:
				_rotate_species_bone("upperarm_r", 0.22 + windup * 0.5 - alternating_strike * 1.05 + aim_pitch * 0.5, Vector3.BACK)
				_rotate_species_bone("upperarm_l", -0.28 + alternating_strike * 0.22, Vector3.BACK)
				_rotate_species_bone("lowerarm_r", -0.3 - strike * 0.42, Vector3.BACK)
				_rotate_species_bone("hand_r", alternating_strike * 0.6, Vector3.UP)
		_rotate_species_bone("spine_03", -alternating_strike * 0.12, Vector3.UP)
	else:
		if not is_instance_valid(_right_arm_pivot):
			return
		match class_id:
			0:
				_right_arm_pivot.rotation.x = 0.65 + windup * 0.25 - strike * 1.45 + aim_pitch * 0.5
				_right_arm_pivot.rotation.y = -strike * 0.42
				_right_arm_pivot.rotation.z = strike * 0.6
				if is_instance_valid(_left_arm_pivot):
					_left_arm_pivot.rotation.x = 0.18 + strike * 0.22
			1:
				if is_instance_valid(_left_arm_pivot):
					_left_arm_pivot.rotation.x = -0.3 - windup * 0.14 + aim_pitch * 0.35
				_right_arm_pivot.rotation.x = 0.2 - windup * 0.8 + strike * 0.38 + aim_pitch * 0.6
			2:
				_right_arm_pivot.rotation.x = 0.75 + windup * 0.25 - strike * 0.7 + aim_pitch * 0.65
				if is_instance_valid(_left_arm_pivot):
					_left_arm_pivot.rotation.x = 0.35 + windup * 0.18 + aim_pitch * 0.35
			3:
				_right_arm_pivot.rotation.x = 0.2 + windup * 0.45 - alternating_strike * 1.2 + aim_pitch * 0.5
				_right_arm_pivot.rotation.y = alternating_strike * 0.35
				if is_instance_valid(_left_arm_pivot):
					_left_arm_pivot.rotation.x = alternating_strike * 0.55
		if is_instance_valid(_right_elbow_pivot):
			_right_elbow_pivot.rotation.x = (-0.2 - windup * 0.7 + strike * 0.3) if class_id == 1 else (-0.2 - strike * 0.8)
		if is_instance_valid(_left_elbow_pivot):
			_left_elbow_pivot.rotation.x = -0.18 - strike * 0.35


func _build_avatar() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_left_arm_pivot = null
	_right_arm_pivot = null
	_left_leg_pivot = null
	_right_leg_pivot = null
	_left_elbow_pivot = null
	_right_elbow_pivot = null
	_left_knee_pivot = null
	_right_knee_pivot = null
	_torso_pivot = null
	_head_pivot = null
	_species_skeleton = null
	_hair_skeleton = null
	_species_bone_ids.clear()
	_species_bone_rest_rotations.clear()
	_hair_bone_pairs.clear()

	var height_scale := float(_profile.get("height", 1.0))
	var build_index := int(_profile.get("build", 1))
	var body_widths := [0.97, 1.0, 1.03]
	var body_width: float = body_widths[clampi(build_index, 0, body_widths.size() - 1)]
	var species_id := clampi(int(_profile.get("species", 0)), 0, 5)
	var class_id := clampi(int(_profile.get("class", 0)), 0, 3)
	var clean_preview := bool(_profile.get("clean_preview", false))
	var skin := SKIN_TONES[clampi(int(_profile.get("skin", 0)), 0, SKIN_TONES.size() - 1)]
	var hair_color := HAIR_COLORS[clampi(int(_profile.get("hair_color", 0)), 0, HAIR_COLORS.size() - 1)]
	var eye_color := EYE_COLORS[clampi(int(_profile.get("eyes", 0)), 0, EYE_COLORS.size() - 1)]
	var outfit_color := OUTFIT_COLORS[clampi(int(_profile.get("outfit_color", 0)), 0, OUTFIT_COLORS.size() - 1)]
	var trim_color := outfit_color.lightened(0.22)
	var face_index := int(_profile.get("face", 0))
	var face_shapes := [
		Vector3(0.3, 0.37, 0.29),
		Vector3(0.32, 0.35, 0.3),
		Vector3(0.33, 0.36, 0.31),
		Vector3(0.28, 0.39, 0.28),
	]
	var face_shape: Vector3 = face_shapes[clampi(face_index, 0, face_shapes.size() - 1)]
	var avatar := Node3D.new()
	avatar.name = "Avatar"
	var species_height := [1.0, 1.04, 0.98, 0.92, 1.08, 1.9]
	var species_width := [1.0, 0.96, 1.16, 1.05, 0.76, 1.12]
	avatar.scale = Vector3(
		body_width * species_width[species_id],
		height_scale * species_height[species_id],
		species_width[species_id]
	)
	add_child(avatar)
	if _build_species_avatar(
			avatar,
			species_id,
			int(_profile.get("body_type", 0)),
			skin,
			hair_color,
			eye_color,
			outfit_color,
			trim_color,
			class_id,
			clean_preview
	):
		return
	if clean_preview:
		return
	_torso_pivot = Node3D.new()
	_torso_pivot.name = "TorsoPivot"
	_torso_pivot.position.y = 0.72
	avatar.add_child(_torso_pivot)
	var torso := _torso_pivot
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position.y = 1.48
	avatar.add_child(_head_pivot)
	var head := _head_pivot

	var pants_color := outfit_color.darkened(0.24)
	_add_capsule(torso, "Hip section", Vector3(0.0, -0.03, 0.0), Vector3(0.3 * body_width, 0.23, 0.24), pants_color)
	var jacket := _add_capsule(torso, "Jacket body", Vector3(0.0, 0.28, 0.0), Vector3(0.4 * body_width, 0.49, 0.25), outfit_color)
	_apply_leather_material(jacket, outfit_color)
	_add_sphere(torso, "Shoulders", Vector3(0.0, 0.56, 0.0), Vector3(0.43 * body_width, 0.2, 0.25), outfit_color)
	_add_sphere(torso, "Chest panel", Vector3(0.0, 0.34, 0.222), Vector3(0.23 * body_width, 0.26, 0.045), trim_color.darkened(0.12))
	_add_capsule(torso, "Jacket seam", Vector3(0.0, 0.25, 0.264), Vector3(0.012, 0.3, 0.012), outfit_color.darkened(0.28))
	_add_capsule(torso, "Neck", Vector3(0.0, 0.76, 0.0), Vector3(0.11, 0.18, 0.11), skin)
	_add_sphere(head, "Head", Vector3(0.0, 0.28, 0.0), face_shape, skin)

	for side in [-1.0, 1.0]:
		var leg_pivot := Node3D.new()
		leg_pivot.name = "LeftLegPivot" if side < 0.0 else "RightLegPivot"
		leg_pivot.position = Vector3(side * 0.16, 0.62, 0.0)
		avatar.add_child(leg_pivot)
		if side < 0.0:
			_left_leg_pivot = leg_pivot
		else:
			_right_leg_pivot = leg_pivot
		_add_capsule(leg_pivot, "Trouser thigh", Vector3(0.0, -0.19, 0.0), Vector3(0.13 * body_width, 0.36, 0.14), pants_color)
		_add_sphere(leg_pivot, "Knee", Vector3(0.0, -0.3, 0.065), Vector3(0.12, 0.12, 0.09), pants_color.lightened(0.08))
		var knee_pivot := Node3D.new()
		knee_pivot.position = Vector3(0.0, -0.3, 0.0)
		leg_pivot.add_child(knee_pivot)
		if side < 0.0:
			_left_knee_pivot = knee_pivot
		else:
			_right_knee_pivot = knee_pivot
		_add_capsule(knee_pivot, "Shin guard", Vector3(0.0, -0.12, 0.0), Vector3(0.115, 0.25, 0.13), pants_color.lightened(0.035))
		_add_capsule(knee_pivot, "Boot", Vector3(0.0, -0.235, 0.04), Vector3(0.145, 0.12, 0.24), Color("#36333b"))
		_add_sphere(knee_pivot, "Boot sole", Vector3(0.0, -0.29, 0.07), Vector3(0.15, 0.035, 0.23), Color("#24232c"))
		_add_sphere(torso, "Shoulder", Vector3(side * 0.37, 0.55, 0.0), Vector3(0.17, 0.18, 0.18), outfit_color)
		var arm_pivot := Node3D.new()
		arm_pivot.name = "LeftArmPivot" if side < 0.0 else "RightArmPivot"
		arm_pivot.position = Vector3(side * 0.4, 0.54, 0.0)
		torso.add_child(arm_pivot)
		if side < 0.0:
			_left_arm_pivot = arm_pivot
		else:
			_right_arm_pivot = arm_pivot
		_add_capsule(arm_pivot, "Upper sleeve", Vector3(0.0, -0.17, 0.0), Vector3(0.13, 0.23, 0.14), outfit_color)
		var elbow_pivot := Node3D.new()
		elbow_pivot.position = Vector3(0.0, -0.34, 0.0)
		arm_pivot.add_child(elbow_pivot)
		if side < 0.0:
			_left_elbow_pivot = elbow_pivot
		else:
			_right_elbow_pivot = elbow_pivot
		_add_sphere(elbow_pivot, "Elbow joint", Vector3.ZERO, Vector3(0.105, 0.105, 0.105), outfit_color.darkened(0.06))
		_add_capsule(elbow_pivot, "Forearm", Vector3(0.0, -0.16, 0.025), Vector3(0.105, 0.19, 0.11), outfit_color.lightened(0.04))
		_add_sphere(elbow_pivot, "Cuff", Vector3(0.0, -0.31, 0.025), Vector3(0.115, 0.05, 0.12), trim_color)
		_add_sphere(elbow_pivot, "Hand", Vector3(0.0, -0.42, 0.035), Vector3(0.085, 0.12, 0.07), skin)
		_add_sphere(head, "Ear", Vector3(side * 0.345, 0.28, -0.005), Vector3(0.065, 0.105, 0.07), skin)
		_add_sphere(head, "Eye socket", Vector3(side * 0.115, 0.31, 0.231), Vector3(0.071, 0.076, 0.028), skin.darkened(0.045))
		_add_sphere(head, "Eye white", Vector3(side * 0.115, 0.31, 0.249), Vector3(0.059, 0.064, 0.025), Color("#fffaf5"))
		_add_sphere(head, "Iris", Vector3(side * 0.115, 0.307, 0.27), Vector3(0.038, 0.047, 0.019), eye_color)
		_add_sphere(head, "Pupil", Vector3(side * 0.115, 0.304, 0.284), Vector3(0.022, 0.034, 0.012), Color("#292331"))
		_add_sphere(head, "Eye highlight", Vector3(side * 0.126, 0.32, 0.296), Vector3(0.009, 0.012, 0.006), Color.WHITE)
		_add_capsule(head, "Upper eyelid", Vector3(side * 0.115, 0.383, 0.248), Vector3(0.062, 0.011, 0.011), hair_color.darkened(0.18))
		_add_capsule(head, "Eyebrow", Vector3(side * 0.115, 0.414, 0.236), Vector3(0.061, 0.009, 0.009), hair_color.darkened(0.1))

	_add_sphere(head, "Nose bridge", Vector3(0.0, 0.24, 0.254), Vector3(0.018, 0.065, 0.018), skin.lightened(0.035))
	_add_sphere(head, "Nose tip", Vector3(0.0, 0.195, 0.276), Vector3(0.024, 0.018, 0.018), skin)
	_add_capsule(head, "Mouth", Vector3(0.0, 0.095, 0.25), Vector3(0.036, 0.009, 0.007), Color("#a94f5d"))
	_add_capsule(torso, "Collar", Vector3(0.0, 0.67, 0.08), Vector3(0.17, 0.065, 0.15), trim_color)
	_add_capsule(torso, "Belt", Vector3(0.0, -0.04, 0.0), Vector3(0.3 * body_width, 0.045, 0.25), Color("#554438"))
	_add_sphere(torso, "Belt buckle", Vector3(0.0, -0.04, 0.255), Vector3(0.045, 0.04, 0.018), Color("#d5b56f"))
	var outfit_details := _add_offset_group(torso, "OutfitDetails", -0.72)
	_add_outfit_detail(outfit_details, int(_profile.get("outfit", 0)), outfit_color)
	var hair := _add_offset_group(head, "Hair", -1.48)
	_add_hair(hair, int(_profile.get("hairstyle", 0)), hair_color)
	var accessories := _add_offset_group(head, "Accessories", -1.48)
	_add_accessory(accessories, int(_profile.get("accessory", 0)), outfit_color, hair_color)
	_add_class_loadout(avatar, torso, class_id, outfit_color, trim_color, false, false)


func _build_species_avatar(
		avatar: Node3D,
		species_id: int,
		body_type: int,
		skin: Color,
		hair_color: Color,
		eye_color: Color,
		outfit_color: Color,
		trim_color: Color,
		class_id: int,
		clean_preview: bool
) -> bool:
	var character_scene: PackedScene
	if species_id < 4:
		character_scene = HUMAN_BODY_SCENES[clampi(body_type, 0, HUMAN_BODY_SCENES.size() - 1)]
	else:
		character_scene = SPECIES_SCENES[species_id]
	var model := character_scene.instantiate() as Node3D
	if model == null:
		push_error("El modelo de la especie seleccionada no tiene una raíz Node3D.")
		return false
	model.name = ["HumanBody", "ElfBody", "OrcBody", "DwarfBody", "ImpBody", "PuglinBody"][species_id]
	avatar.add_child(model)
	if species_id < 4:
		_customize_species_materials(model, species_id, skin, hair_color, eye_color)
	_species_skeleton = _find_skeleton(model)
	if is_instance_valid(_species_skeleton):
		for bone_name in [
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
			"hand_l", "hand_r", "thigh_l", "thigh_r", "calf_l", "calf_r",
			"spine_01", "spine_02", "spine_03", "Head"
		]:
			var bone_id := _species_skeleton.find_bone(bone_name)
			if bone_id >= 0:
				_species_bone_ids[bone_name] = bone_id
				_species_bone_rest_rotations[bone_name] = _species_skeleton.get_bone_pose_rotation(bone_id)
		if _species_bone_ids.has("Head") and species_id < 4:
			var face_scales := [
				Vector3(1.0, 1.06, 0.97),
				Vector3(1.06, 0.96, 1.0),
				Vector3(1.08, 1.04, 1.03),
				Vector3(0.96, 1.1, 0.96),
			]
			_species_skeleton.set_bone_pose_scale(
				_species_bone_ids["Head"],
				face_scales[clampi(int(_profile.get("face", 0)), 0, face_scales.size() - 1)]
			)
	if species_id < 4:
		var hair_scene: PackedScene = HUMAN_HAIR_SCENES[clampi(int(_profile.get("hairstyle", 0)), 0, HUMAN_HAIR_SCENES.size() - 1)]
		var hair := hair_scene.instantiate() as Node3D
		if hair == null:
			push_error("El modelo de peinado seleccionado no tiene una raíz Node3D.")
			return false
		hair.name = "CharacterHair"
		avatar.add_child(hair)
		_customize_hair_materials(hair, hair_color)
		_hair_skeleton = _find_skeleton(hair)
		_link_hair_skeleton()

	if not clean_preview:
		_add_species_features(avatar, species_id, skin, hair_color)
	var outfit_torso := Node3D.new()
	outfit_torso.name = "SpeciesOutfit"
	outfit_torso.position.y = 0.72 if species_id < 4 else (0.92 if species_id == 4 else 0.52)
	avatar.add_child(outfit_torso)
	if species_id < 4 and not clean_preview:
		var body_width := 0.38 if species_id != 2 else 0.43
		_add_leather_capsule(
			outfit_torso,
			"Leather tunic",
			Vector3(0.0, 0.28, 0.0),
			Vector3(body_width, 0.42, 0.23),
			outfit_color
		)
		for side in [-1.0, 1.0]:
			_add_capsule(
				avatar,
				"Class trouser leg",
				Vector3(side * 0.16, 0.38, 0.0),
				Vector3(0.14, 0.4, 0.14),
				outfit_color.darkened(0.28)
			)
			_add_capsule(
				avatar,
				"Class boot",
				Vector3(side * 0.16, 0.08, 0.035),
				Vector3(0.14, 0.12, 0.22),
				Color("#36333b")
			)
		var outfit_details := _add_offset_group(
			outfit_torso,
			"OutfitDetails",
			-outfit_torso.position.y
		)
		_add_outfit_detail(outfit_details, int(_profile.get("outfit", 0)), outfit_color)
		_add_species_accessory(
			avatar,
			int(_profile.get("accessory", 0)),
			outfit_color,
			hair_color,
			species_id
		)
	_add_class_loadout(avatar, outfit_torso, class_id, outfit_color, trim_color, true, clean_preview)
	return true


func _add_species_accessory(
		avatar: Node3D,
		accessory_id: int,
		outfit_color: Color,
		hair_color: Color,
		species_id: int
) -> void:
	var eye_height := 1.55 if species_id != 3 else 1.38
	match accessory_id:
		1:
			var glasses_color := Color("#293640")
			for side in [-1.0, 1.0]:
				_add_capsule(
					avatar,
					"Glasses frame",
					Vector3(side * 0.12, eye_height, 0.16),
					Vector3(0.075, 0.012, 0.012),
					glasses_color
				)
			_add_capsule(
				avatar,
				"Glasses bridge",
				Vector3(0.0, eye_height, 0.17),
				Vector3(0.025, 0.009, 0.009),
				glasses_color
			)
		2:
			_add_sphere(
				avatar,
				"Earring",
				Vector3(0.33, eye_height - 0.14, 0.02),
				Vector3(0.035, 0.055, 0.035),
				Color("#e5c16e")
			)
		3:
			_add_capsule(
				avatar,
				"Headband",
				Vector3(0.0, eye_height + 0.19, 0.0),
				Vector3(0.28, 0.045, 0.2),
				outfit_color.lightened(0.18)
			)
		4:
			_add_leather_capsule(
				avatar,
				"Beard",
				Vector3(0.0, eye_height - 0.2, 0.13),
				Vector3(0.17, 0.12, 0.1),
				hair_color.darkened(0.16)
			)
		5:
			_add_capsule(
				avatar,
				"Headphone band",
				Vector3(0.0, eye_height + 0.22, -0.01),
				Vector3(0.27, 0.1, 0.055),
				Color("#313b47")
			)
			for side in [-1.0, 1.0]:
				_add_sphere(
					avatar,
					"Headphone",
					Vector3(side * 0.3, eye_height, 0.0),
					Vector3(0.055, 0.09, 0.07),
					Color("#313b47")
				)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var skeleton := _find_skeleton(child)
		if is_instance_valid(skeleton):
			return skeleton
	return null


func _customize_species_materials(model: Node, species_id: int, skin: Color, hair_color: Color, eye_color: Color) -> void:
	if model is MeshInstance3D:
		var mesh_instance := model as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				if not source_material is StandardMaterial3D:
					continue
				var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
				var material_name := (source_material.resource_name + " " + mesh_instance.name).to_lower()
				if material_name.contains("eyes"):
					material.albedo_texture = HUMAN_EYE_TEXTURE
					material.albedo_color = eye_color.lightened(0.46)
				elif material_name.contains("superhero"):
					var body_type := clampi(int(_profile.get("body_type", 0)), 0, 1)
					var skin_index := clampi(int(_profile.get("skin", 0)), 0, SKIN_TONES.size() - 1)
					material.albedo_texture = HUMAN_LIGHT_TEXTURES[body_type] if skin_index < 4 else HUMAN_DARK_TEXTURES[body_type]
					var base_tone := SKIN_TONES[0] if skin_index < 4 else SKIN_TONES[4]
					material.albedo_color = Color(
						clampf(skin.r / base_tone.r, 0.72, 1.2),
						clampf(skin.g / base_tone.g, 0.72, 1.2),
						clampf(skin.b / base_tone.b, 0.72, 1.2)
					)
					if species_id == 2:
						material.albedo_color = Color("#a1aa63").lerp(
							Color(skin.r * 0.55, skin.g * 0.82, skin.b * 0.48),
							0.18
						)
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in model.get_children():
		_customize_species_materials(child, species_id, skin, hair_color, eye_color)


func _customize_hair_materials(hair: Node, color: Color) -> void:
	if hair is MeshInstance3D:
		var mesh_instance := hair as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				if source_material is StandardMaterial3D:
					var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
					material.albedo_color = color
					mesh_instance.set_surface_override_material(surface_index, material)
	for child in hair.get_children():
		_customize_hair_materials(child, color)


func _link_hair_skeleton() -> void:
	if not is_instance_valid(_species_skeleton) or not is_instance_valid(_hair_skeleton):
		return
	for hair_bone_index in range(_hair_skeleton.get_bone_count()):
		var body_bone_index := _species_skeleton.find_bone(_hair_skeleton.get_bone_name(hair_bone_index))
		if body_bone_index >= 0:
			_hair_bone_pairs.append(Vector2i(hair_bone_index, body_bone_index))


func _add_species_features(avatar: Node3D, species_id: int, skin: Color, hair_color: Color) -> void:
	match species_id:
		1:
			for side in [-1.0, 1.0]:
				var ear := _add_cone(
					avatar,
					"Elf pointed ear",
					Vector3(side * 0.33, 1.67, 0.015),
					0.052,
					0.25,
					skin
				)
				ear.rotation.z = deg_to_rad(-side * 77.0)
		2:
			for side in [-1.0, 1.0]:
				var tusk := _add_cone(
					avatar,
					"Orc tusk",
					Vector3(side * 0.105, 1.52, 0.27),
					0.042,
					0.12,
					Color("#f0e4c7")
				)
				tusk.rotation_degrees.x = 180.0
				var ear := _add_cone(
					avatar,
					"Orc ear",
					Vector3(side * 0.35, 1.65, 0.0),
					0.065,
					0.18,
					Color("#a1aa63")
				)
				ear.rotation.z = deg_to_rad(-side * 70.0)
		3:
			_add_leather_capsule(
				avatar,
				"Dwarf braided beard",
				Vector3(0.0, 1.4, 0.2),
				Vector3(0.18, 0.24, 0.13),
				hair_color.darkened(0.12)
			)


func _add_cone(parent: Node3D, label: String, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var feature := MeshInstance3D.new()
	feature.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	feature.mesh = mesh
	feature.position = position
	feature.material_override = _material(color)
	parent.add_child(feature)
	return feature


func _animate_species_skeleton(stride: float, grounded: bool, sprinting: bool, vertical_speed: float, delta: float) -> void:
	if not is_instance_valid(_species_skeleton):
		return
	_pose_blend = 1.0 - exp(-delta * 12.0)
	var arm_swing := -stride * (0.4 if sprinting else 0.32) if grounded else (0.44 if vertical_speed > 0.0 else 0.62)
	var leg_swing := stride * (0.24 if sprinting else 0.2) if grounded else 0.0
	_rotate_species_bone("upperarm_l", -RELAXED_ARM_ANGLE - arm_swing, Vector3.BACK)
	_rotate_species_bone("upperarm_r", RELAXED_ARM_ANGLE + arm_swing, Vector3.BACK)
	_rotate_species_bone("lowerarm_l", -0.18 - absf(arm_swing) * 0.32, Vector3.BACK)
	_rotate_species_bone("lowerarm_r", -0.18 - absf(arm_swing) * 0.32, Vector3.BACK)
	_rotate_species_bone("thigh_l", leg_swing)
	_rotate_species_bone("thigh_r", -leg_swing)
	_rotate_species_bone("calf_l", maxf(0.0, sin(_motion_phase + PI * 0.5)) * _motion_intensity * 0.14 if grounded else 0.0)
	_rotate_species_bone("calf_r", maxf(0.0, sin(_motion_phase - PI * 0.5)) * _motion_intensity * 0.14 if grounded else 0.0)
	_rotate_species_bone("spine_01", -0.025 * _motion_intensity if grounded else -0.08)
	_rotate_species_bone("spine_03", -0.075 if sprinting and grounded else (-0.1 if vertical_speed > 0.0 else (0.12 if vertical_speed < -2.0 else 0.0)))
	_rotate_species_bone("Head", 0.08 if vertical_speed < -4.0 else 0.0)
	if is_instance_valid(_hair_skeleton):
		for bone_pair in _hair_bone_pairs:
			_hair_skeleton.set_bone_pose_position(
				bone_pair.x,
				_species_skeleton.get_bone_pose_position(bone_pair.y)
			)
			_hair_skeleton.set_bone_pose_rotation(
				bone_pair.x,
				_species_skeleton.get_bone_pose_rotation(bone_pair.y)
			)
			_hair_skeleton.set_bone_pose_scale(
				bone_pair.x,
				_species_skeleton.get_bone_pose_scale(bone_pair.y)
			)


func _rotate_species_bone(
		bone_name: String,
		angle: float,
		axis: Vector3 = Vector3.RIGHT
) -> void:
	if _species_bone_ids.has(bone_name):
		var bone_id := _species_bone_ids[bone_name]
		# Bone pose rotations are local offsets from the imported rest pose.
		var rest_rotation: Quaternion = _species_bone_rest_rotations.get(bone_name, Quaternion.IDENTITY)
		var target_rotation := rest_rotation * Quaternion(axis, angle)
		var current_rotation := _species_skeleton.get_bone_pose_rotation(bone_id)
		_species_skeleton.set_bone_pose_rotation(bone_id, current_rotation.slerp(target_rotation, _pose_blend))


func _add_offset_group(parent: Node3D, label: String, vertical_offset: float) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.position.y = vertical_offset
	parent.add_child(group)
	return group


func _add_hair(parent: Node3D, style: int, color: Color) -> void:
	_add_sphere(parent, "Hair cap", Vector3(0.0, 2.005, -0.035), Vector3(0.31, 0.16, 0.29), color)
	match style:
		1:
			_add_sphere(parent, "Long hair back", Vector3(0.0, 1.77, -0.2), Vector3(0.34, 0.38, 0.18), color)
			for side in [-1.0, 1.0]:
				_add_capsule(parent, "Long hair side", Vector3(side * 0.29, 1.76, 0.0), Vector3(0.09, 0.35, 0.11), color)
		2:
			_add_sphere(parent, "Curly hair", Vector3(0.0, 2.08, -0.02), Vector3(0.39, 0.25, 0.36), color)
			for side in [-1.0, 1.0]:
				_add_sphere(parent, "Curl", Vector3(side * 0.28, 2.0, 0.12), Vector3(0.15, 0.15, 0.15), color)
		3:
			for side in [-1.0, 0.0, 1.0]:
				_add_sphere(parent, "Anime hair spike", Vector3(side * 0.17, 2.13 + absf(side) * 0.02, 0.0), Vector3(0.12, 0.27, 0.13), color)
		4:
			for side in [-1.0, 1.0]:
				_add_sphere(parent, "Twin tail", Vector3(side * 0.34, 1.91, -0.18), Vector3(0.15, 0.35, 0.16), color)
				_add_sphere(parent, "Hair ribbon", Vector3(side * 0.31, 2.04, -0.12), Vector3(0.11, 0.08, 0.12), color.lightened(0.28))
			_add_sphere(parent, "Long hair back", Vector3(0.0, 1.77, -0.2), Vector3(0.34, 0.38, 0.18), color)
		5:
			_add_sphere(parent, "Side swept hair", Vector3(-0.13, 2.04, 0.1), Vector3(0.25, 0.16, 0.26), color)

	var bang_color := color.lightened(0.06)
	for bang_index in range(3):
		var side := float(bang_index - 1)
		var bang := _add_capsule(
			parent,
			"Anime fringe",
			Vector3(side * 0.17, 1.94 + absf(side) * 0.035, 0.235),
			Vector3(0.075, 0.145, 0.07),
			bang_color
		)
		bang.rotation.z = -side * 0.34

	_add_sphere(parent, "Hair shine", Vector3(-0.1, 2.065, 0.14), Vector3(0.06, 0.009, 0.007), color.lightened(0.16))


func _add_class_loadout(
		avatar: Node3D,
		torso: Node3D,
		class_id: int,
		outfit_color: Color,
		trim_color: Color,
		use_bone_attachments: bool,
		clean_preview: bool
) -> void:
	match class_id:
		0:
			if not clean_preview:
				var breastplate := _add_capsule(torso, "Breastplate", Vector3(0.0, 0.34, 0.265), Vector3(0.27, 0.3, 0.055), Color("#777d83"))
				var metal_material := _material(Color("#777d83"))
				metal_material.metallic = 0.58
				metal_material.roughness = 0.38
				breastplate.material_override = metal_material
				_add_capsule(torso, "Plate edge", Vector3(0.0, 0.34, 0.315), Vector3(0.18, 0.022, 0.012), trim_color)
			_add_class_prop(
				avatar, "sword", "hand_r", Vector3(0.0, -0.025, 0.0),
				Vector3(0.0, 0.0, 90.0), Vector3(0.42, 1.0, -0.23),
				Vector3(90.0, 0.0, 18.0), use_bone_attachments
			)
			_add_class_prop(
				avatar, "shield", "hand_l", Vector3(0.0, 0.025, 0.0),
				Vector3(180.0, 0.0, 90.0), Vector3(-0.32, 1.03, -0.24),
				Vector3(0.0, 180.0, -12.0), use_bone_attachments
			)
		1:
			if not clean_preview:
				_add_leather_capsule(torso, "Leather chest guard", Vector3(0.0, 0.31, 0.265), Vector3(0.23, 0.34, 0.045), Color("#704c35"))
				_add_leather_capsule(torso, "Cross-body strap", Vector3(0.11, 0.31, 0.307), Vector3(0.04, 0.39, 0.018), trim_color)
			_add_class_prop(
				avatar, "bow", "hand_l", Vector3(0.0, 0.025, 0.0),
				Vector3(0.0, 0.0, 90.0), Vector3(0.0, 1.05, -0.28),
				Vector3(0.0, 0.0, -8.0), use_bone_attachments
			)
			_add_asset_prop(avatar, "quiver", Vector3(0.0, 1.02, 0.22), Vector3(0.0, 0.0, -12.0), Vector3.ONE)
		2:
			if not clean_preview:
				_add_capsule(torso, "Mage mantle", Vector3(0.0, 0.22, -0.17), Vector3(0.39, 0.57, 0.12), outfit_color.darkened(0.2))
			_add_class_prop(
				avatar, "staff", "hand_r", Vector3(0.0, -0.025, 0.0),
				Vector3(0.0, 0.0, -90.0), Vector3(-0.48, 0.72, -0.24),
				Vector3(0.0, 0.0, -12.0), use_bone_attachments
			)
		3:
			if not clean_preview:
				_add_leather_capsule(torso, "Rogue leather vest", Vector3(0.0, 0.29, 0.27), Vector3(0.24, 0.36, 0.045), Color("#353942"))
				_add_capsule(torso, "Rogue hood", Vector3(0.0, 0.7, -0.15), Vector3(0.32, 0.2, 0.25), outfit_color.darkened(0.28))
			_add_class_prop(
				avatar, "dagger", "hand_r", Vector3(0.0, -0.025, 0.0),
				Vector3(0.0, 0.0, 90.0), Vector3(0.3, 0.54, 0.24),
				Vector3(0.0, 0.0, -78.0), use_bone_attachments
			)


func _add_class_prop(
		avatar: Node3D,
		asset_name: String,
		bone_name: String,
		attachment_position: Vector3,
		attachment_rotation: Vector3,
		fallback_position: Vector3,
		fallback_rotation: Vector3,
		use_bone_attachments: bool
) -> void:
	if use_bone_attachments and is_instance_valid(_species_skeleton):
		var bone_index := _species_skeleton.find_bone(bone_name)
		if bone_index >= 0:
			var prop_scene: PackedScene = CLASS_PROP_SCENES[asset_name]
			var prop := prop_scene.instantiate() as Node3D
			if prop == null:
				push_error("El modelo de equipo '%s' no tiene una raíz Node3D." % asset_name)
				return
			var attachment := BoneAttachment3D.new()
			attachment.name = "EquipmentAttachment_" + asset_name
			attachment.bone_name = bone_name
			_species_skeleton.add_child(attachment)
			attachment.position = attachment_position
			attachment.rotation_degrees = attachment_rotation
			prop.name = "ClassProp_" + asset_name
			attachment.add_child(prop)
			return
		push_error("El esqueleto no contiene el hueso '%s' para el equipo '%s'." % [bone_name, asset_name])
		return
	var hand_pivot: Node3D = _right_elbow_pivot if bone_name.ends_with("_r") else _left_elbow_pivot
	if is_instance_valid(hand_pivot):
		var holder_transform := avatar.global_transform.affine_inverse() * hand_pivot.global_transform
		var desired_transform := Transform3D(
			Basis.from_euler(Vector3(
				deg_to_rad(fallback_rotation.x),
				deg_to_rad(fallback_rotation.y),
				deg_to_rad(fallback_rotation.z)
			)),
			fallback_position
		)
		var attachment := Node3D.new()
		attachment.name = "EquipmentAttachment_" + asset_name
		hand_pivot.add_child(attachment)
		attachment.transform = holder_transform.affine_inverse() * desired_transform
		_add_asset_prop(attachment, asset_name, Vector3.ZERO, Vector3.ZERO, Vector3.ONE)
		return
	_add_asset_prop(avatar, asset_name, fallback_position, fallback_rotation, Vector3.ONE)


func _add_asset_prop(
		parent: Node3D,
		asset_name: String,
		position: Vector3,
		rotation_degrees: Vector3,
		prop_scale: Vector3
) -> void:
	var prop_scene: PackedScene = CLASS_PROP_SCENES[asset_name]
	var prop := prop_scene.instantiate() as Node3D
	if prop == null:
		push_error("El modelo de equipo '%s' no tiene una raíz Node3D." % asset_name)
		return
	prop.name = "ClassProp_" + asset_name
	prop.position = position
	prop.rotation_degrees = rotation_degrees
	prop.scale = prop_scale
	parent.add_child(prop)


func _add_leather_capsule(parent: Node3D, label: String, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := _add_capsule(parent, label, position, dimensions, color)
	_apply_leather_material(mesh_instance, color)
	return mesh_instance


func _apply_leather_material(mesh_instance: MeshInstance3D, color: Color) -> void:
	var material := _material(color)
	material.albedo_texture = LEATHER_ALBEDO
	material.normal_enabled = true
	material.normal_texture = LEATHER_NORMAL
	material.ao_enabled = true
	material.ao_texture = LEATHER_ARM
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness_texture = LEATHER_ARM
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	mesh_instance.material_override = material


func _add_outfit_detail(parent: Node3D, style: int, color: Color) -> void:
	match style:
		0:
			_add_capsule(parent, "Jacket collar", Vector3(0.0, 1.3, 0.0), Vector3(0.22, 0.12, 0.2), color.lightened(0.2))
		1:
			_add_capsule(parent, "Hood", Vector3(0.0, 1.39, -0.15), Vector3(0.2, 0.18, 0.13), color.darkened(0.12))
			_add_capsule(parent, "Scarf", Vector3(0.0, 1.37, 0.15), Vector3(0.13, 0.2, 0.08), Color("#d3b26e"))
		2:
			_add_capsule(parent, "Vest", Vector3(0.0, 1.0, 0.22), Vector3(0.2, 0.36, 0.06), color.lightened(0.22))
		3:
			_add_capsule(parent, "Armor", Vector3(0.0, 1.0, 0.22), Vector3(0.27, 0.31, 0.09), color.darkened(0.16))
			_add_capsule(parent, "Shoulder pad", Vector3(0.38, 1.3, 0.0), Vector3(0.17, 0.12, 0.17), color.lightened(0.15))
			_add_capsule(parent, "Shoulder pad", Vector3(-0.38, 1.3, 0.0), Vector3(0.17, 0.12, 0.17), color.lightened(0.15))
		4:
			_add_capsule(parent, "Travel strap", Vector3(0.0, 0.98, 0.28), Vector3(0.055, 0.38, 0.05), Color("#dbc496"))


func _add_accessory(parent: Node3D, style: int, outfit_color: Color, hair_color: Color) -> void:
	match style:
		1:
			for side in [-1.0, 1.0]:
				_add_capsule(parent, "Glasses lens", Vector3(side * 0.12, 1.81, 0.32), Vector3(0.09, 0.065, 0.025), Color("#293640"))
			_add_capsule(parent, "Glasses bridge", Vector3(0.0, 1.81, 0.34), Vector3(0.06, 0.018, 0.02), Color("#293640"))
		2:
			_add_sphere(parent, "Earring", Vector3(0.34, 1.67, 0.08), Vector3(0.045, 0.07, 0.045), Color("#e5c16e"))
		3:
			_add_capsule(parent, "Bandana", Vector3(0.0, 1.94, 0.16), Vector3(0.35, 0.09, 0.26), outfit_color.lightened(0.18))
		4:
			_add_capsule(parent, "Beard", Vector3(0.0, 1.55, 0.2), Vector3(0.2, 0.14, 0.14), hair_color.darkened(0.16))
		5:
			_add_capsule(parent, "Headphones band", Vector3(0.0, 2.07, -0.02), Vector3(0.38, 0.13, 0.07), Color("#313b47"))
			for side in [-1.0, 1.0]:
				_add_sphere(parent, "Headphone", Vector3(side * 0.34, 1.86, 0.0), Vector3(0.07, 0.12, 0.1), Color("#313b47"))


func _add_sphere(parent: Node3D, label: String, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 32
	mesh.rings = 24
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = dimensions
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_capsule(parent: Node3D, label: String, position: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.scale = dimensions
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	material.metallic = 0.0
	return material
