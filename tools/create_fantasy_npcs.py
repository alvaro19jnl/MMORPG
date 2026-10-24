from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "custom_equipment" / "fantasy_npcs"
CHARACTERS = ROOT / "assets" / "quaternius"


def make_material(name, color, metallic=0.0, roughness=0.55, emission=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    material.node_tree.nodes.clear()
    shader = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = emission
    return material


def make_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def make_empty(name, collection, location=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.18
    obj.location = location
    collection.objects.link(obj)
    return obj


def make_mesh(name, vertices, faces, material, collection, parent=None):
    mesh = bpy.data.meshes.new(name + " | mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def make_cylinder(name, location, radius, depth, material, collection, parent=None, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Soft edges", "BEVEL")
    bevel.width = min(radius * 0.12, 0.025)
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    if parent is not None:
        obj.parent = parent
    return obj


def make_sphere(name, location, scale, material, collection, parent=None, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.scale = scale
    obj.data.materials.append(material)
    if parent is not None:
        obj.parent = parent
    return obj


def make_cone(name, location, radius, depth, material, collection, parent=None):
    bpy.ops.mesh.primitive_cone_add(
        vertices=32,
        radius1=radius,
        radius2=0.015,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Soft edges", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    if parent is not None:
        obj.parent = parent
    return obj


def make_text(name, body, location, size, material, collection):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.extrude = 0.002
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler.x = 1.5708
    obj.data.materials.append(material)
    return obj


def import_character(name, filepath, x, scale, arm_pose):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(filepath))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    character_collection = make_collection(name)
    root = make_empty(name + " | root", character_collection, (x, 0.0, 0.16))
    root.scale = (scale, scale, scale)

    for obj in imported:
        move_to_collection(obj, character_collection)
        if obj.name.startswith("Esfera geodésica"):
            obj.hide_render = True
            obj.hide_viewport = True
        if obj.parent is None:
            obj.parent = root
        if obj.type == "ARMATURE":
            for bone_name, angle in arm_pose.items():
                bone = obj.pose.bones.get(bone_name)
                if bone is not None:
                    bone.rotation_mode = "XYZ"
                    bone.rotation_euler.z = angle
    for obj in imported:
        obj.select_set(False)
    return root, character_collection


def make_cape(root, collection, material):
    vertices = [
        (-0.25, 0.17, 1.48),
        (0.25, 0.17, 1.48),
        (-0.48, 0.30, 0.22),
        (0.48, 0.30, 0.22),
        (0.0, 0.34, 0.12),
    ]
    obj = make_mesh(
        "Travel cloak",
        vertices,
        [(0, 2, 4), (2, 3, 4), (4, 3, 1), (4, 1, 0)],
        material,
        collection,
        root,
    )
    solidify = obj.modifiers.new("Cloak thickness", "SOLIDIFY")
    solidify.thickness = 0.035
    obj.modifiers.new("Cloak smooth edge", "BEVEL").width = 0.018
    return obj


def setup_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)

    scene = bpy.context.scene
    stage = make_collection("Stage | presentation")
    props = make_collection("Props | fantasy gear")

    midnight = make_material("Midnight blue", (0.018, 0.035, 0.075), roughness=0.82)
    stone = make_material("Dark slate", (0.12, 0.17, 0.22), roughness=0.72)
    gold = make_material("Warm brass", (0.72, 0.43, 0.12), metallic=0.72, roughness=0.28)
    cream = make_material("Warm ivory", (0.92, 0.82, 0.61), roughness=0.48)
    lettering = make_material("Illuminated lettering", (0.95, 0.84, 0.62), roughness=0.42, emission=0.65)
    teal = make_material("Mage teal", (0.08, 0.42, 0.5), metallic=0.1, roughness=0.44)
    violet = make_material("Imp violet", (0.3, 0.12, 0.49), metallic=0.05, roughness=0.48)
    amber = make_material("Potion amber", (0.95, 0.31, 0.055), roughness=0.25, emission=0.18)
    green = make_material("Potion green", (0.12, 0.65, 0.3), roughness=0.25, emission=0.12)
    glow = make_material("Crystal glow", (0.15, 0.66, 0.95), roughness=0.2, emission=1.4)

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0.0, 0.0, -0.045))
    floor = bpy.context.object
    floor.name = "Infinite midnight floor"
    move_to_collection(floor, stage)
    floor.data.materials.append(midnight)

    characters = [
        ("01 | Elara the wanderer", CHARACTERS / "human_characters" / "Superhero_Female_FullBody.gltf", -2.45, 1.0, {"upperarm_l": -0.8, "upperarm_r": 0.65}),
        ("02 | Nix the alchemist", CHARACTERS / "species" / "Imp.glb", 0.0, 1.0, {"upperarm_l": -0.8, "upperarm_r": 0.8}),
        ("03 | Bruk the trader", CHARACTERS / "species" / "Puglin.glb", 2.45, 1.78, {"upperarm_l": -0.8, "upperarm_r": 0.8}),
    ]
    roots = []
    for name, filepath, x, scale, arm_pose in characters:
        root, collection = import_character(name, filepath, x, scale, arm_pose)
        roots.append((root, collection))
        make_cylinder(
            name + " | plinth",
            (x, 0.0, 0.06),
            0.78,
            0.16,
            stone,
            stage,
            vertices=64,
        )
        make_cylinder(
            name + " | brass trim",
            (x, 0.0, 0.145),
            0.75,
            0.025,
            gold,
            stage,
            vertices=64,
        )

    elara, elara_collection = roots[0]
    make_cape(elara, elara_collection, teal)
    make_mesh(
        "Elara | travel tunic",
        [
            (-0.25, -0.23, 1.48), (0.25, -0.23, 1.48),
            (-0.25, -0.22, 1.02), (0.25, -0.22, 1.02),
            (-0.4, -0.13, 0.52), (0.4, -0.13, 0.52),
            (-0.25, 0.18, 1.48), (0.25, 0.18, 1.48),
            (-0.25, 0.17, 1.02), (0.25, 0.17, 1.02),
            (-0.4, 0.12, 0.52), (0.4, 0.12, 0.52),
        ],
        [(0, 1, 3, 2), (2, 3, 5, 4), (6, 8, 9, 7), (8, 10, 11, 9),
         (0, 2, 8, 6), (1, 7, 9, 3), (2, 4, 10, 8), (3, 9, 11, 5)],
        teal,
        elara_collection,
        elara,
    )
    make_cylinder("Elara | belt", (0.0, -0.23, 0.94), 0.24, 0.055, gold, props, elara)
    make_cylinder(
        "Elara | staff shaft",
        (-0.68, -0.16, 1.02),
        0.035,
        1.72,
        gold,
        props,
        elara,
        vertices=12,
    )
    make_sphere(
        "Elara | staff crystal",
        (-0.68, -0.16, 1.95),
        (0.12, 0.12, 0.19),
        glow,
        props,
        elara,
    )
    make_cylinder(
        "Elara | hat brim",
        (0.0, 0.0, 1.78),
        0.31,
        0.055,
        violet,
        props,
        elara,
    )
    make_cone(
        "Elara | pointed hat",
        (0.0, 0.0, 2.02),
        0.23,
        0.48,
        violet,
        props,
        elara,
    )

    nix, nix_collection = roots[1]
    make_cape(nix, nix_collection, violet)
    make_sphere("Nix | satchel", (0.42, 0.27, 0.67), (0.22, 0.16, 0.27), gold, props, nix)
    make_sphere("Nix | potion amber", (0.42, -0.13, 0.77), (0.08, 0.08, 0.14), amber, props, nix)
    make_sphere("Nix | potion green", (0.58, -0.12, 0.52), (0.07, 0.07, 0.12), green, props, nix)

    bruk, _ = roots[2]
    make_sphere("Bruk | merchant pack", (0.0, 0.32, 0.55), (0.33, 0.24, 0.32), gold, props, bruk)
    make_cylinder("Bruk | pack strap", (0.0, 0.06, 0.56), 0.035, 0.7, cream, props, bruk, vertices=10)
    make_sphere("Bruk | pack gem", (0.0, 0.04, 0.69), (0.09, 0.045, 0.1), glow, props, bruk)

    make_text("Scene title", "VIAJEROS DE LA FRONTERA", (0.0, -0.78, 2.65), 0.34, lettering, stage)
    make_text("Elara name", "ELARA", (-2.45, -0.98, 0.43), 0.19, lettering, stage)
    make_text("Elara role", "MAGA ERRANTE", (-2.45, -0.985, 0.26), 0.1, lettering, stage)
    make_text("Nix name", "NIX", (0.0, -0.98, 0.43), 0.19, lettering, stage)
    make_text("Nix role", "ALQUIMISTA IMP", (0.0, -0.985, 0.26), 0.1, lettering, stage)
    make_text("Bruk name", "BRUK", (2.45, -0.98, 0.43), 0.19, lettering, stage)
    make_text("Bruk role", "MERCADER PUGLIN", (2.45, -0.985, 0.26), 0.1, lettering, stage)

    world = bpy.data.worlds.new("Twilight studio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.clear()
    background = world.node_tree.nodes.new("ShaderNodeBackground")
    output = world.node_tree.nodes.new("ShaderNodeOutputWorld")
    world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    background.inputs["Color"].default_value = (0.018, 0.028, 0.06, 1.0)
    background.inputs["Strength"].default_value = 0.2

    for name, location, energy, size, color in [
        ("Key | warm", (-4.0, -4.5, 6.0), 210, 4.0, (1.0, 0.78, 0.56)),
        ("Fill | cool", (4.5, -2.0, 4.0), 150, 4.5, (0.45, 0.68, 1.0)),
        ("Rim | moon", (0.0, 3.0, 5.5), 260, 3.5, (0.34, 0.62, 1.0)),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        light = bpy.data.objects.new(name, data)
        stage.objects.link(light)
        light.location = location
        light.rotation_euler = (Vector((0.0, 0.0, 1.0)) - light.location).to_track_quat("-Z", "Y").to_euler()

    camera_data = bpy.data.cameras.new("NPC lineup camera")
    camera = bpy.data.objects.new("NPC lineup camera", camera_data)
    stage.objects.link(camera)
    camera.location = (0.0, -10.5, 3.25)
    camera.rotation_euler = (Vector((0.0, 0.0, 1.28)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 7.8
    scene.camera = camera

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 80
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = str(OUTPUT / "fantasy_npcs_preview.png")
    scene.camera.data.lens = 50
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(OUTPUT / "fantasy_npcs_preview.png")
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.use_file_extension = True

    bpy.context.view_layer.objects.active = camera
    bpy.ops.object.select_all(action="DESELECT")
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"

    bpy.ops.file.pack_all()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "fantasy_npcs.blend"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    setup_scene()
