extends Area3D

var source_name := "monstruo"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.7
	shape.shape = sphere
	add_child(shape)
	var gem := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 0.42, 0.42)
	gem.mesh = mesh
	gem.rotation_degrees = Vector3(0.0, 45.0, 45.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#ffd36c")
	material.emission_enabled = true
	material.emission = Color("#ffad38")
	material.emission_energy_multiplier = 1.6
	gem.material_override = material
	add_child(gem)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotation.y += delta * 1.2
	position.y = 0.35 + sin(Time.get_ticks_msec() * 0.003) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if MultiplayerSession.is_active() and not body.is_multiplayer_authority():
		return
	if body.has_method("grant_loot"):
		if body.call("grant_loot", source_name):
			queue_free()
