import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "custom_equipment"
GLB_OUTPUT = OUTPUT / "class_gear"


def make_material(name, color, metallic=0.0, roughness=0.55):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is None:
        shader = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = material.node_tree.nodes.get("Material Output")
        if output is None:
            output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
        material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return material


STEEL = None
EDGE = None
GOLD = None
LEATHER = None
LEATHER_DARK = None
WOOD = None
WOOD_LIGHT = None
BLUE = None


def create_materials():
    global STEEL, EDGE, GOLD, LEATHER, LEATHER_DARK, WOOD, WOOD_LIGHT, BLUE
    STEEL = make_material("Steel | brushed", (0.52, 0.61, 0.68), 0.78, 0.28)
    EDGE = make_material("Steel | bright edge", (0.82, 0.87, 0.88), 0.84, 0.2)
    GOLD = make_material("Brass | warm", (0.67, 0.39, 0.12), 0.72, 0.3)
    LEATHER = make_material("Leather | oxblood", (0.19, 0.075, 0.047), 0.0, 0.72)
    LEATHER_DARK = make_material("Leather | dark", (0.075, 0.045, 0.035), 0.0, 0.76)
    WOOD = make_material("Wood | walnut", (0.21, 0.105, 0.048), 0.0, 0.6)
    WOOD_LIGHT = make_material("Wood | carved detail", (0.44, 0.25, 0.11), 0.0, 0.55)
    BLUE = make_material("Arcane crystal | blue", (0.12, 0.42, 0.88), 0.25, 0.24)


def move_to_collection(obj, collection):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def make_beveled_box(collection, name, location, dimensions, material, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft forged edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.profile = 0.5
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    obj.data.materials.append(material)
    return obj


def make_cylinder(collection, name, location, radius, depth, material, vertices=16, axis=None):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    if axis is not None:
        direction = Vector(axis).normalized()
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Edge glints", "BEVEL")
    bevel.width = min(radius * 0.16, 0.008)
    bevel.segments = 2
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def make_uv_sphere(collection, name, location, scale, material, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdivisions,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def make_extruded_profile(collection, name, points, depth, material, bevel=0.004):
    count = len(points)
    verts = [(x, -depth * 0.5, z) for x, z in points]
    verts += [(x, depth * 0.5, z) for x, z in points]
    faces = [tuple(range(count)), tuple(range(count, count * 2))]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, following + count, index + count))
    mesh = bpy.data.meshes.new(name + " | mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("Rounded silhouette", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def make_rod(collection, name, start, end, radius, material, vertices=10):
    delta = Vector(end) - Vector(start)
    return make_cylinder(
        collection,
        name,
        (Vector(start) + Vector(end)) * 0.5,
        radius,
        delta.length,
        material,
        vertices,
        delta,
    )


def make_root(collection, name, display_x):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.12
    collection.objects.link(root)
    root.location.x = display_x
    return root


def parent_parts(parts, root):
    for obj in parts:
        if obj == root:
            continue
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()


def build_sword(collection):
    parts = []
    parts.append(make_beveled_box(collection, "Sword | leather grip", (0.0, 0.0, 0.0), (0.062, 0.06, 0.19), LEATHER, 0.009))
    parts.append(make_cylinder(collection, "Sword | pommel", (0.0, 0.0, -0.105), 0.047, 0.055, GOLD, 12))
    parts.append(make_beveled_box(collection, "Sword | pommel inset", (0.0, -0.032, -0.105), (0.023, 0.008, 0.023), BLUE, 0.004))
    parts.append(make_beveled_box(collection, "Sword | guard", (0.0, 0.0, 0.12), (0.29, 0.066, 0.052), GOLD, 0.017))
    parts.append(make_extruded_profile(
        collection,
        "Sword | tapered blade",
        [(-0.075, 0.14), (-0.064, 0.36), (0.0, 0.89), (0.064, 0.36), (0.075, 0.14)],
        0.036,
        STEEL,
        0.007,
    ))
    parts.append(make_extruded_profile(
        collection,
        "Sword | bright edge",
        [(-0.011, 0.18), (-0.006, 0.36), (0.0, 0.8), (0.006, 0.36), (0.011, 0.18)],
        0.039,
        EDGE,
        0.002,
    ))
    for offset in [-0.035, 0.035]:
        parts.append(make_beveled_box(collection, "Sword | grip wire", (offset, -0.034, 0.0), (0.012, 0.008, 0.15), GOLD, 0.003))
    return parts


def build_shield(collection):
    parts = [
        make_extruded_profile(
            collection,
            "Shield | steel-rimmed body",
            [(-0.205, 0.235), (0.205, 0.235), (0.19, 0.035), (0.13, -0.17), (0.0, -0.32), (-0.13, -0.17), (-0.19, 0.035)],
            0.075,
            LEATHER_DARK,
            0.012,
        ),
        make_extruded_profile(
            collection,
            "Shield | raised steel rim",
            [(-0.185, 0.205), (0.185, 0.205), (0.17, 0.035), (0.115, -0.15), (0.0, -0.275), (-0.115, -0.15), (-0.17, 0.035)],
            0.025,
            STEEL,
            0.008,
        ),
        make_extruded_profile(
            collection,
            "Shield | inset",
            [(-0.15, 0.17), (0.15, 0.17), (0.135, 0.025), (0.09, -0.12), (0.0, -0.225), (-0.09, -0.12), (-0.135, 0.025)],
            0.018,
            LEATHER,
            0.006,
        ),
        make_uv_sphere(collection, "Shield | boss", (0.0, -0.055, 0.025), (0.068, 0.035, 0.078), GOLD),
        make_extruded_profile(
            collection,
            "Shield | crest",
            [(-0.067, 0.13), (0.0, 0.19), (0.067, 0.13), (0.0, -0.035)],
            0.025,
            GOLD,
            0.005,
        ),
    ]
    for side in [-1.0, 1.0]:
        parts.append(make_beveled_box(collection, "Shield | back arm strap", (side * 0.085, 0.047, 0.0), (0.035, 0.04, 0.31), LEATHER, 0.008))
    return parts


def build_bow(collection):
    points = [
        (0.0, -0.03, -0.49),
        (0.17, -0.03, -0.34),
        (0.245, -0.03, -0.1),
        (0.255, -0.03, 0.1),
        (0.17, -0.03, 0.34),
        (0.0, -0.03, 0.49),
    ]
    parts = []
    for index in range(len(points) - 1):
        parts.append(make_rod(collection, "Bow | carved limb", points[index], points[index + 1], 0.026, WOOD_LIGHT, 10))
    parts.append(make_rod(collection, "Bow | taut string", points[0], points[-1], 0.004, EDGE, 8))
    parts.append(make_beveled_box(collection, "Bow | leather grip", (0.0, -0.055, 0.0), (0.09, 0.045, 0.16), LEATHER, 0.014))
    parts.append(make_beveled_box(collection, "Bow | upper ferrule", (0.0, -0.03, 0.18), (0.06, 0.045, 0.055), GOLD, 0.01))
    parts.append(make_beveled_box(collection, "Bow | lower ferrule", (0.0, -0.03, -0.18), (0.06, 0.045, 0.055), GOLD, 0.01))
    return parts


def build_quiver(collection):
    parts = [
        make_cylinder(collection, "Quiver | leather tube", (0.0, 0.0, 0.0), 0.085, 0.49, LEATHER, 12),
        make_cylinder(collection, "Quiver | base cap", (0.0, 0.0, -0.24), 0.09, 0.035, GOLD, 12),
        make_cylinder(collection, "Quiver | rim", (0.0, 0.0, 0.235), 0.092, 0.035, GOLD, 12),
        make_beveled_box(collection, "Quiver | shoulder strap", (0.105, 0.015, 0.0), (0.035, 0.025, 0.48), LEATHER_DARK, 0.008),
    ]
    for index in range(3):
        x = (index - 1) * 0.038
        parts.append(make_rod(collection, "Quiver | arrow shaft", (x, 0.0, 0.16), (x, 0.0, 0.56), 0.006, WOOD_LIGHT, 8))
        parts.append(make_extruded_profile(
            collection,
            "Quiver | arrow fletching",
            [(x - 0.021, 0.39), (x + 0.021, 0.39), (x, 0.49)],
            0.008,
            EDGE,
            0.002,
        ))
    return parts


def build_staff(collection):
    parts = [
        make_cylinder(collection, "Staff | ash shaft", (0.0, 0.0, 0.02), 0.033, 1.5, WOOD, 12),
        make_cylinder(collection, "Staff | lower ferrule", (0.0, 0.0, -0.69), 0.051, 0.12, GOLD, 12),
        make_cylinder(collection, "Staff | upper ferrule", (0.0, 0.0, 0.67), 0.05, 0.1, GOLD, 12),
        make_uv_sphere(collection, "Staff | arcane crystal", (0.0, 0.0, 0.83), (0.105, 0.088, 0.15), BLUE, 2),
    ]
    for height in [-0.54, -0.45, 0.48, 0.57]:
        parts.append(make_cylinder(collection, "Staff | grip binding", (0.0, 0.0, height), 0.042, 0.035, LEATHER, 12))
    for side in [-1.0, 1.0]:
        start = (0.0, 0.0, 0.68)
        finish = (side * 0.105, 0.0, 0.78)
        parts.append(make_rod(collection, "Staff | crystal prong", start, finish, 0.016, GOLD, 10))
    return parts


def build_dagger(collection):
    parts = [
        make_beveled_box(collection, "Dagger | leather grip", (0.0, 0.0, 0.0), (0.048, 0.048, 0.15), LEATHER, 0.007),
        make_uv_sphere(collection, "Dagger | pommel", (0.0, 0.0, -0.09), (0.037, 0.034, 0.036), GOLD, 2),
        make_beveled_box(collection, "Dagger | guard", (0.0, 0.0, 0.09), (0.17, 0.046, 0.035), GOLD, 0.01),
        make_extruded_profile(
            collection,
            "Dagger | tapered blade",
            [(-0.052, 0.11), (-0.046, 0.25), (0.0, 0.49), (0.046, 0.25), (0.052, 0.11)],
            0.028,
            STEEL,
            0.005,
        ),
        make_extruded_profile(
            collection,
            "Dagger | bright edge",
            [(-0.008, 0.13), (-0.005, 0.26), (0.0, 0.45), (0.005, 0.26), (0.008, 0.13)],
            0.031,
            EDGE,
            0.002,
        ),
    ]
    return parts


def create_stage():
    stage = bpy.data.collections.new("Presentation | not exported")
    bpy.context.scene.collection.children.link(stage)
    floor_mat = make_material("Stage | charcoal", (0.025, 0.04, 0.052), 0.1, 0.82)
    bpy.ops.mesh.primitive_plane_add(size=16.0, location=(2.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Display plinth"
    move_to_collection(floor, stage)
    floor.data.materials.append(floor_mat)

    camera_data = bpy.data.cameras.new("Equipment showcase camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 10.8
    camera = bpy.data.objects.new("Equipment showcase camera", camera_data)
    stage.objects.link(camera)
    camera.location = (4.0, -9.0, 4.6)
    camera.rotation_euler = (Vector((4.0, 0.0, 0.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    for name, location, power, size in [
        ("Key softbox", (1.0, -4.0, 6.0), 1100.0, 5.0),
        ("Rim softbox", (7.0, 2.5, 4.5), 1450.0, 4.0),
    ]:
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = power
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        stage.objects.link(light)
        light.location = location
        light.rotation_euler = (Vector((4.0, 0.0, 0.75)) - light.location).to_track_quat("-Z", "Y").to_euler()

    world = bpy.data.worlds.new("Equipment showcase world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.035, 0.05, 0.075, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    bpy.context.scene.world = world
    bpy.context.scene.render.resolution_x = 1600
    bpy.context.scene.render.resolution_y = 800
    bpy.context.scene.render.resolution_percentage = 100
    return stage


def export_model(root, collection, output_path):
    saved_location = root.location.copy()
    root.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
        export_lights=False,
        export_cameras=False,
    )
    root.location = saved_location


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    GLB_OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    create_materials()

    models = [
        ("Fitted_Sword", build_sword),
        ("Fitted_Shield", build_shield),
        ("Fitted_Bow", build_bow),
        ("Fitted_Quiver", build_quiver),
        ("Fitted_Staff", build_staff),
        ("Fitted_Dagger", build_dagger),
    ]
    for index, (name, builder) in enumerate(models):
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        root = make_root(collection, name, 0.0)
        parts = builder(collection)
        parent_parts(parts, root)
        for obj in parts:
            for modifier in list(obj.modifiers):
                bpy.context.view_layer.objects.active = obj
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        output_path = GLB_OUTPUT / (name.lower() + ".glb")
        export_model(root, collection, output_path)
        if not output_path.exists() or output_path.stat().st_size < 1024:
            raise RuntimeError("Export failed or produced an empty model: " + str(output_path))
        print("Exported", output_path, output_path.stat().st_size, "bytes")
        display_heights = [0.9, 0.33, 0.51, 0.25, 0.74, 0.51]
        root.location = (index * 1.65, 0.0, display_heights[index])
        if name in ["Fitted_Sword", "Fitted_Dagger"]:
            root.rotation_euler.x = math.pi

    create_stage()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "class_equipment.blend"))
    print("Saved Blender source:", OUTPUT / "class_equipment.blend")


if __name__ == "__main__":
    main()
