from pathlib import Path
from math import cos, pi, sin
from random import Random

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "custom_equipment" / "mythical_beasts"


def make_material(name, color, metallic=0.0, roughness=0.55, emission=0.0, texture_scale=0.0):
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
    if texture_scale:
        bump = material.node_tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.13
        bump.inputs["Distance"].default_value = 0.018
        material.node_tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        coordinates = material.node_tree.nodes.new("ShaderNodeTexCoord")
        scales = material.node_tree.nodes.new("ShaderNodeTexVoronoi")
        scales.feature = "DISTANCE_TO_EDGE"
        scales.inputs["Scale"].default_value = texture_scale
        ramp = material.node_tree.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.025
        ramp.color_ramp.elements[1].position = 0.13
        material.node_tree.links.new(coordinates.outputs["Generated"], scales.inputs["Vector"])
        material.node_tree.links.new(scales.outputs["Distance"], ramp.inputs["Fac"])
        material.node_tree.links.new(ramp.outputs["Color"], bump.inputs["Height"])
        bump.inputs["Strength"].default_value = 0.14
        bump.inputs["Distance"].default_value = 0.009
    return material


def make_membrane_material(name, color):
    material = make_material(name, color, metallic=0.02, roughness=0.54)
    shader = next(node for node in material.node_tree.nodes if node.bl_idname == "ShaderNodeBsdfPrincipled")
    shader.inputs["Subsurface Weight"].default_value = 0.06
    shader.inputs["Coat Weight"].default_value = 0.12
    coordinates = material.node_tree.nodes.new("ShaderNodeTexCoord")
    noise = material.node_tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 24.0
    noise.inputs["Detail"].default_value = 2.0
    bump = material.node_tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.1
    bump.inputs["Distance"].default_value = 0.012
    material.node_tree.links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
    material.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    material.node_tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return material


def make_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def make_root(name, collection, x):
    root = bpy.data.objects.new(name + " | root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.3
    root.location.x = x
    collection.objects.link(root)
    return root


def make_mesh(name, vertices, faces, material, collection, parent):
    mesh = bpy.data.meshes.new(name + " | mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def make_sphere(name, location, scale, material, collection, parent, subdivisions=2):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24 if subdivisions < 3 else 32,
        ring_count=16 if subdivisions < 3 else 24,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.scale = scale
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    refine = obj.modifiers.new("High-density smooth surface", "SUBSURF")
    refine.subdivision_type = "CATMULL_CLARK"
    refine.levels = 1
    refine.render_levels = 2
    obj.parent = parent
    return obj


def make_tapered_tube(name, points, radii, material, collection, parent, sides=16, steps=5):
    control_points = [Vector(point) for point in points]
    vertices = []
    faces = []
    sample_count = (len(control_points) - 1) * steps + 1

    for sample in range(sample_count):
        position = sample / steps
        segment = min(int(position), len(control_points) - 2)
        fraction = position - segment
        previous = control_points[max(segment - 1, 0)]
        start = control_points[segment]
        end = control_points[segment + 1]
        following = control_points[min(segment + 2, len(control_points) - 1)]
        point = 0.5 * (
            (2.0 * start)
            + (-previous + end) * fraction
            + (2.0 * previous - 5.0 * start + 4.0 * end - following) * fraction**2
            + (-previous + 3.0 * start - 3.0 * end + following) * fraction**3
        )
        tangent = (end - previous).normalized()
        axis_u = tangent.cross(Vector((0.0, 1.0, 0.0)))
        if axis_u.length < 0.001:
            axis_u = tangent.cross(Vector((1.0, 0.0, 0.0)))
        axis_u.normalize()
        axis_v = tangent.cross(axis_u).normalized()
        radius_start = radii[segment]
        radius_end = radii[segment + 1]
        radius = radius_start + (radius_end - radius_start) * fraction
        for side in range(sides):
            angle = 2.0 * 3.141592653589793 * side / sides
            offset = axis_u * (radius * cos(angle))
            offset += axis_v * (radius * sin(angle))
            vertices.append(tuple(point + offset))

    for ring in range(sample_count - 1):
        for side in range(sides):
            following = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + following
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(range(sides - 1, -1, -1)))
    last_ring = (sample_count - 1) * sides
    faces.append(tuple(last_ring + side for side in range(sides)))

    obj = make_mesh(name, vertices, faces, material, collection, parent)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    refine = obj.modifiers.new("Organic high-density surface", "SUBSURF")
    refine.levels = 1
    refine.render_levels = 2
    return obj


def make_scale_plate(name, center, width, height, depth, material, collection, parent):
    x, y, z = center
    vertices = [
        (x, y - depth, z + height),
        (x + width, y, z + height * 0.18),
        (x, y + depth * 0.2, z - height),
        (x - width, y, z + height * 0.18),
        (x, y - depth * 1.4, z + height * 0.08),
    ]
    obj = make_mesh(
        name,
        vertices,
        [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)],
        material,
        collection,
        parent,
    )
    solidify = obj.modifiers.new("Raised scale edge", "SOLIDIFY")
    solidify.thickness = depth * 0.5
    bevel = obj.modifiers.new("Soft scale edge", "BEVEL")
    bevel.width = min(width, height) * 0.14
    bevel.segments = 2
    return obj


def make_rounded_scale(name, location, size, material, collection, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12,
        ring_count=8,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.scale = size
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.parent = parent
    return obj


def make_feather(name, start, tip, width, material, collection, parent):
    start = Vector(start)
    tip = Vector(tip)
    direction = tip - start
    obj = make_sphere(
        name,
        (start + tip) * 0.5,
        (width, width, direction.length * 0.62),
        material,
        collection,
        parent,
        subdivisions=2,
    )
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction)
    return obj


def make_rod(name, start, end, radius, material, collection, parent, vertices=10):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=direction.length,
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Soft forged edges", "BEVEL")
    bevel.width = radius * 0.18
    bevel.segments = 3
    for polygon in obj.data.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    obj.parent = parent
    return obj


def make_spike(name, base, tip, radius, material, collection, parent, vertices=8):
    base = Vector(base)
    tip = Vector(tip)
    direction = tip - base
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius,
        radius2=0.012,
        depth=direction.length,
        location=(base + tip) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    obj.parent = parent
    return obj


def add_dragon_scale_rows(prefix, center_y, center_z, radius_x, radius_y, radius_z, x_steps, z_steps, material, collection, root, scale):
    rng = Random(f"{prefix}:{center_y}:{center_z}")
    for row in range(z_steps):
        z = center_z - radius_z * 0.78 + row * (radius_z * 1.56 / max(z_steps - 1, 1))
        z += rng.uniform(-0.12, 0.12) * (radius_z * 1.56 / max(z_steps - 1, 1))
        offset = radius_x / (x_steps * 2) if row % 2 else 0.0
        for column in range(x_steps):
            x = -radius_x * 0.72 + column * (radius_x * 1.44 / max(x_steps - 1, 1)) + offset
            x += rng.uniform(-0.12, 0.12) * (radius_x * 1.44 / max(x_steps - 1, 1))
            normalized = (x / radius_x) ** 2 + ((z - center_z) / radius_z) ** 2
            if normalized >= 0.9:
                continue
            y = center_y - radius_y * (1.0 - normalized) ** 0.5 - 0.018
            selected_material = material[1] if isinstance(material, (tuple, list)) and (row + column) % 5 == 0 else material[0] if isinstance(material, (tuple, list)) else material
            scale_obj = make_rounded_scale(
                prefix + " | overlapping dragon scale",
                (x, y + 0.008, z),
                (scale[0], scale[1], scale[2]),
                selected_material,
                collection,
                root,
            )
            scale_obj.hide_render = True


def make_wing(name, side, y, material, bone_material, collection, root, reach=2.55, peak=2.85):
    points = [
        (side * 0.45, y, 2.0),
        (side * 0.95, y, 2.23),
        (side * reach, y, peak),
        (side * (reach * 0.97), y, 2.42),
        (side * (reach * 0.92), y, 1.9),
        (side * (reach * 0.82), y, 1.44),
        (side * (reach * 0.68), y, 1.05),
        (side * (reach * 0.51), y, 0.94),
        (side * 0.82, y, 1.18),
    ]
    root_point = Vector(points[0])
    rib_tips = [Vector(points[index]) for index in range(2, len(points))]
    rib_paths = []
    for index, tip in enumerate(rib_tips):
        if index == 0:
            control = Vector(points[1])
            control.y -= 0.07
        else:
            control = (root_point + tip) * 0.5
            control.z += 0.16
            control.y -= 0.08
        rib_paths.append((root_point, control, tip))

    def sample_rib(path, t):
        start, control, end = path
        return start * ((1.0 - t) ** 2) + control * (2.0 * (1.0 - t) * t) + end * (t**2)

    for panel in range(len(rib_paths) - 1):
        vertices = []
        faces = []
        length_steps = 12
        width_steps = 5
        for row in range(length_steps + 1):
            t = row / length_steps
            for column in range(width_steps + 1):
                u = column / width_steps
                a = sample_rib(rib_paths[panel], t)
                b = sample_rib(rib_paths[panel + 1], t)
                point = a.lerp(b, u)
                point.y -= 0.14 * sin(pi * u) * sin(pi * t)
                vertices.append(tuple(point))
        for row in range(length_steps):
            for column in range(width_steps):
                a = row * (width_steps + 1) + column
                b = a + 1
                faces.append((a, b, b + width_steps + 1, a + width_steps + 1))
        membrane = make_mesh(name + " | curved membrane panel", vertices, faces, material, collection, root)
        for polygon in membrane.data.polygons:
            polygon.use_smooth = True
        thickness = membrane.modifiers.new("Thin living wing membrane", "SOLIDIFY")
        thickness.thickness = 0.014

    for path in rib_paths:
        make_tapered_tube(
            name + " | wing finger",
            path,
            [0.052, 0.03, 0.009],
            material,
            collection,
            root,
            sides=10,
            steps=3,
        )
    if "feathered" in name:
        for feather_row, fraction in enumerate((0.78, 0.88, 0.98)):
            for feather_index in range(7):
                start_x = 0.63 + feather_index * 0.19
                end_x = min(start_x + 0.47, reach * 0.96)
                root_z = 1.5 + feather_index * 0.11
                tip_z = 0.84 + feather_index * 0.11 + (feather_row - 1) * 0.17
                make_feather(
                    name + " | layered flight feather",
                    (side * start_x, y - 0.03 * feather_row, root_z),
                    (side * end_x, y - 0.035 * feather_row, tip_z * fraction + root_z * (1.0 - fraction)),
                    0.06,
                    bone_material,
                    collection,
                    root,
                )


def make_title_card(title, subtitle, x, material, collection):
    for body, z, size in [(title, 0.46, 0.18), (subtitle, 0.27, 0.085)]:
        curve = bpy.data.curves.new(title + " | lettering", "FONT")
        curve.body = body
        curve.size = size
        curve.align_x = "CENTER"
        curve.extrude = 0.002
        obj = bpy.data.objects.new(title + " | " + body, curve)
        collection.objects.link(obj)
        obj.location = (x, -1.48, z)
        obj.rotation_euler.x = 1.5708
        obj.data.materials.append(material)


def make_plinth(name, x, radius, stone, gold, collection):
    for label, z, depth, current_radius, material in [
        ("stone base", 0.10, 0.22, radius, stone),
        ("bronze rim", 0.225, 0.035, radius * 0.965, gold),
        ("top surface", 0.25, 0.035, radius * 0.91, stone),
    ]:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=64,
            radius=current_radius,
            depth=depth,
            location=(x, 0.0, z),
        )
        obj = bpy.context.object
        obj.name = name + " | " + label
        move_to_collection(obj, collection)
        obj.data.materials.append(material)
        bevel = obj.modifiers.new("Carved edge", "BEVEL")
        bevel.width = 0.035
        bevel.segments = 3
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")


def fuse_dragon_body(collection):
    organic_parts = (
        "powerful ribcage",
        "armored abdomen",
        "elegant S-curved neck",
        "long predatory skull",
        "narrow dragon muzzle",
        "muscular hind leg",
        "muscular foreleg",
        "long muscular tail",
    )
    selected = [
        obj
        for obj in collection.objects
        if obj.type == "MESH" and any(part in obj.name for part in organic_parts)
    ]
    if len(selected) < 2:
        raise RuntimeError("Dragon body parts were not created; cannot fuse the body mesh.")

    for obj in selected:
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.select_set(True)
    body = selected[0]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()

    remesh = body.modifiers.new("Unified organic anatomy", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.03
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = body.modifiers.new("Sculpted muscle transitions", "SMOOTH")
    smooth.factor = 0.65
    smooth.iterations = 4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    subdiv = body.modifiers.new("High-resolution creature surface", "SUBSURF")
    subdiv.levels = 1
    subdiv.render_levels = 2
    for polygon in body.data.polygons:
        polygon.use_smooth = True
    body.name = "Ignivar | fused sculpted anatomy"


def fuse_dragon_head(collection):
    head_parts = [
        obj
        for obj in collection.objects
        if obj.type == "MESH"
        and any(label in obj.name for label in ("long predatory skull", "tapered dragon muzzle", "rounded snout tip"))
    ]
    if len(head_parts) != 3:
        raise RuntimeError("Dragon skull, muzzle, and snout tip were not all created.")
    for obj in head_parts:
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in head_parts:
        obj.select_set(True)
    head = head_parts[0]
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    remesh = head.modifiers.new("Continuous sculpted skull and muzzle", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.018
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = head.modifiers.new("Soft facial transitions", "SMOOTH")
    smooth.factor = 0.55
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    subdiv = head.modifiers.new("Fine facial surface", "SUBSURF")
    subdiv.levels = 1
    subdiv.render_levels = 2
    for polygon in head.data.polygons:
        polygon.use_smooth = True
    head.name = "Ignivar | sculpted continuous head"


def build_dragon(x, collection, props, materials):
    scale, dark, wing_mat, horn, belly, eye, fang = materials[:7]
    root = make_root("01 | Ignivar the elder dragon", collection, x)

    make_sphere("Ignivar | powerful ribcage", (0.0, 0.08, 1.53), (0.66, 1.16, 0.68), scale, collection, root, 3)
    make_sphere("Ignivar | armored abdomen", (0.0, -0.55, 1.29), (0.42, 0.5, 0.52), belly, collection, root, 3)
    rng = Random(1187)
    for row in range(7):
        z = 0.91 + row * 0.12
        for column in range(6):
            plate_x = (column - 2.5) * 0.11 + rng.uniform(-0.012, 0.012)
            normalized = (plate_x / 0.44) ** 2 + ((z - 1.29) / 0.55) ** 2
            if normalized >= 0.94:
                continue
            plate_y = -0.55 - 0.5 * (1.0 - normalized) ** 0.5 - 0.025
            make_scale_plate(
                "Ignivar | segmented ventral armor",
                (plate_x, plate_y, z),
                0.085,
                0.055,
                0.028,
                belly,
                props,
                root,
            )
    make_tapered_tube(
        "Ignivar | elegant S-curved neck",
        [(0.0, -0.57, 1.83), (0.0, -0.84, 2.13), (0.0, -0.79, 2.55),
         (0.0, -1.04, 2.92), (0.0, -1.42, 3.02), (0.0, -1.66, 2.9)],
        [0.4, 0.33, 0.27, 0.24, 0.2, 0.16],
        scale,
        collection,
        root,
        sides=20,
        steps=7,
    )
    make_sphere("Ignivar | long predatory skull", (0.0, -1.58, 2.98), (0.29, 0.48, 0.24), scale, collection, root, 3)
    make_tapered_tube(
        "Ignivar | tapered dragon muzzle",
        [(0.0, -1.68, 2.91), (0.0, -1.94, 2.84), (0.0, -2.24, 2.79), (0.0, -2.48, 2.8)],
        [0.22, 0.205, 0.17, 0.125],
        scale,
        collection,
        root,
        sides=20,
        steps=6,
    )
    make_sphere(
        "Ignivar | rounded snout tip",
        (0.0, -2.4, 2.8),
        (0.135, 0.15, 0.105),
        scale,
        collection,
        root,
        subdivisions=3,
    )
    make_tapered_tube(
        "Ignivar | defined lower jaw",
        [(0.0, -1.8, 2.68), (0.0, -2.05, 2.64), (0.0, -2.32, 2.67), (0.0, -2.43, 2.72)],
        [0.18, 0.15, 0.12, 0.085],
        dark,
        collection,
        root,
        sides=16,
        steps=5,
    )
    for side in (-1, 1):
        make_sphere("Ignivar | recessed eye socket", (side * 0.242, -1.79, 3.055), (0.06, 0.028, 0.055), dark, props, root)
        make_sphere("Ignivar | amber eye", (side * 0.248, -1.817, 3.057), (0.031, 0.018, 0.029), eye, props, root)
        make_sphere("Ignivar | vertical slit pupil", (side * 0.249, -1.833, 3.057), (0.008, 0.007, 0.022), dark, props, root, subdivisions=1)
        make_sphere("Ignivar | eye glint", (side * 0.243, -1.835, 3.068), (0.006, 0.005, 0.006), fang, props, root, subdivisions=1)
        make_sphere("Ignivar | inset nostril", (side * 0.085, -2.525, 2.835), (0.012, 0.018, 0.012), dark, props, root, subdivisions=1)
        make_tapered_tube(
            "Ignivar | protective brow ridge",
            [(side * 0.15, -1.75, 3.115), (side * 0.24, -1.82, 3.13), (side * 0.33, -1.77, 3.11)],
            [0.045, 0.039, 0.012],
            scale,
            props,
            root,
            sides=12,
            steps=4,
        )
        make_tapered_tube(
            "Ignivar | mouth corner",
            [(side * 0.15, -2.02, 2.73), (side * 0.13, -2.23, 2.72), (side * 0.075, -2.4, 2.735)],
            [0.013, 0.01, 0.003],
            dark,
            props,
            root,
            sides=10,
            steps=5,
        )
        make_tapered_tube(
            "Ignivar | swept-back crown horn",
            [(side * 0.19, -1.42, 3.13), (side * 0.23, -1.3, 3.27), (side * 0.29, -1.02, 3.4), (side * 0.34, -0.72, 3.48)],
            [0.105, 0.09, 0.05, 0.006],
            horn,
            props,
            root,
            sides=12,
            steps=5,
        )
        make_tapered_tube(
            "Ignivar | curved jaw fang",
            [(side * 0.2, -2.2, 2.76), (side * 0.2, -2.24, 2.69), (side * 0.18, -2.29, 2.61)],
            [0.045, 0.027, 0.003],
            fang,
            props,
            root,
            sides=10,
            steps=4,
        )
    fuse_dragon_head(collection)

    for index in range(14):
        y = -0.65 + index * 0.15
        z = 2.05 + min(index, 5) * 0.14
        make_spike(
            "Ignivar | back spike",
            (0.0, y, z),
            (0.0, y + 0.1, z + 0.17 - index * 0.005),
            0.048,
            horn,
            props,
            root,
        )
    for side in (-1, 1):
        make_wing("Ignivar | wing " + str(side), side, 0.38, wing_mat, dark, props, root, reach=2.8, peak=3.72)
        hip = (side * 0.53, 0.5, 1.13)
        knee = (side * 0.7, 0.69, 0.6)
        ankle = (side * 0.73, 0.24, 0.34)
        make_tapered_tube("Ignivar | muscular hind leg", [hip, (side * 0.77, 0.62, 0.88), knee, ankle], [0.34, 0.31, 0.2, 0.13], scale, collection, root)
        make_sphere("Ignivar | rear claw foot", (side * 0.73, 0.02, 0.27), (0.26, 0.32, 0.17), dark, props, root)
        for claw in (-1, 0, 1):
            make_spike(
                "Ignivar | talon",
                (side * 0.71 + claw * 0.14, -0.25, 0.25),
                (side * 0.71 + claw * 0.14, -0.46, 0.15),
                0.085,
                horn,
                props,
                root,
            )
        shoulder = (side * 0.56, -0.5, 1.83)
        elbow = (side * 0.76, -0.24, 1.14)
        wrist = (side * 0.78, -0.94, 0.39)
        make_tapered_tube("Ignivar | muscular foreleg", [shoulder, elbow, wrist], [0.27, 0.19, 0.12], scale, collection, root)
        make_sphere("Ignivar | front paw", (side * 0.78, -1.02, 0.32), (0.24, 0.3, 0.15), dark, props, root)
        for claw in (-1, 0, 1):
            make_spike(
                "Ignivar | curved front talon",
                (side * 0.78 + claw * 0.13, -1.2, 0.32),
                (side * 0.78 + claw * 0.13, -1.48, 0.17),
                0.065,
                horn,
                props,
                root,
            )

    tail_points = [(0.0, 0.72, 1.38), (0.42, 0.94, 1.12), (1.0, 0.86, 0.86), (1.65, 0.36, 0.77), (2.35, -0.35, 0.94), (2.72, -0.92, 1.26)]
    make_tapered_tube(
        "Ignivar | long muscular tail",
        tail_points,
        [0.32, 0.26, 0.19, 0.13, 0.075, 0.02],
        scale,
        collection,
        root,
    )
    for index in range(15):
        fraction = index / 14.0
        tail_x = 0.12 + fraction * 2.5
        y = 0.87 - 1.72 * fraction
        z = 1.3 - 0.44 * fraction + 0.42 * max(0.0, (fraction - 0.72) * 3.5)
        height = 0.16 * (1.0 - fraction * 0.55)
        make_spike(
            "Ignivar | tail ridge",
            (tail_x, y, z),
            (tail_x + 0.06, y + 0.09, z + height),
            0.065 * (1.0 - fraction * 0.6),
            horn,
            props,
            root,
        )
    fuse_dragon_body(collection)
    make_plinth("Ignivar", x, 1.67, materials[7], horn, collection)
    make_title_card("IGNIVAR", "DRAGON ANCESTRAL", x, materials[8], collection)
    for obj in collection.objects:
        if any(label in obj.name for label in ("stone base", "bronze rim", "top surface", "IGNIVAR", "DRAGON ANCESTRAL")):
            obj.hide_render = True
    return root


def build_griffin(x, collection, props, materials):
    feather, gold, wing_mat, brown, belly, eye, claw = materials[:7]
    root = make_root("02 | Aurelion the griffin", collection, x)

    make_sphere("Aurelion | lion torso", (0.0, 0.08, 1.0), (0.77, 0.95, 0.79), gold, collection, root, 3)
    make_sphere("Aurelion | chest ruff", (0.0, -0.62, 1.32), (0.75, 0.45, 0.77), belly, props, root, 3)
    make_sphere("Aurelion | eagle head", (0.0, -0.94, 2.03), (0.48, 0.46, 0.49), feather, collection, root, 3)
    make_sphere("Aurelion | hooked beak", (0.0, -1.33, 1.88), (0.22, 0.34, 0.23), claw, props, root)
    make_spike("Aurelion | beak tip", (0.0, -1.52, 1.8), (0.0, -1.49, 1.59), 0.16, claw, props, root)
    for row in range(3):
        z = 1.12 + row * 0.2
        for column in range(5):
            x = -0.46 + column * 0.23 + (0.08 if row % 2 else 0.0)
            normalized = (x / 0.75) ** 2 + ((z - 1.32) / 0.77) ** 2
            if normalized >= 0.88:
                continue
            y = -0.62 - 0.45 * (1.0 - normalized) ** 0.5 - 0.025
            make_feather(
                "Aurelion | layered breast feather",
                (x, y, z + 0.12),
                (x, y - 0.05, z - 0.1),
                0.047,
                brown,
                props,
                root,
            )

    for side in (-1, 1):
        make_sphere("Aurelion | keen eye", (side * 0.31, -1.25, 2.12), (0.075, 0.06, 0.07), eye, props, root)
        make_spike(
            "Aurelion | feather crest",
            (side * 0.17, -0.81, 2.4),
            (side * 0.34, -0.74, 2.95),
            0.14,
            belly,
            props,
            root,
        )
        for index in range(3):
            start = (side * (0.66 + index * 0.08), -0.08 + index * 0.07, 1.68)
            end = (side * (1.45 + index * 0.15), 0.04 + index * 0.05, 1.92 - index * 0.12)
            make_rod("Aurelion | layered wing feather", start, end, 0.15, belly, props, root, vertices=8)
        make_wing(
            "Aurelion | feathered wing " + str(side),
            side,
            0.22,
            wing_mat,
            gold,
            props,
            root,
            reach=2.7,
            peak=2.92,
        )

        shoulder = (side * 0.5, -0.38, 1.34)
        elbow = (side * 0.73, -0.72, 0.87)
        wrist = (side * 0.75, -0.93, 0.49)
        make_rod("Aurelion | front leg", shoulder, elbow, 0.22, gold, collection, root, vertices=12)
        make_rod("Aurelion | front ankle", elbow, wrist, 0.16, gold, collection, root, vertices=10)
        make_sphere("Aurelion | front paw", (side * 0.75, -0.98, 0.39), (0.24, 0.28, 0.16), claw, props, root)
        for index in (-1, 0, 1):
            make_spike(
                "Aurelion | front talon",
                (side * 0.75 + index * 0.13, -1.13, 0.38),
                (side * 0.75 + index * 0.13, -1.33, 0.27),
                0.065,
                belly,
                props,
                root,
            )

        hip = (side * 0.47, 0.56, 1.1)
        hock = (side * 0.65, 0.85, 0.55)
        paw = (side * 0.67, 0.42, 0.34)
        make_rod("Aurelion | hind thigh", hip, hock, 0.27, gold, collection, root, vertices=12)
        make_rod("Aurelion | hind shin", hock, paw, 0.16, gold, collection, root)
        make_sphere("Aurelion | hind paw", paw, (0.25, 0.29, 0.15), claw, props, root)

    for index in range(6):
        y = 0.73 + index * 0.3
        make_sphere(
            "Aurelion | lion tail tuft",
            (0.0, y, 0.72 + index * 0.018),
            (0.09, 0.2, 0.095),
            belly,
            props,
            root,
            subdivisions=1,
        )
    make_spike("Aurelion | tail plume", (0.0, 2.52, 0.84), (0.0, 2.92, 1.1), 0.2, belly, props, root)
    make_plinth("Aurelion", x, 1.55, materials[7], materials[3], collection)
    make_title_card("AURELION", "GRIFO DE LOS CIELOS", x, materials[8], collection)
    return root


def build_hydra(x, collection, props, materials):
    scales, dark, wing_mat, horn, belly, eye, fang = materials[:7]
    root = make_root("03 | Vyrm the three-headed hydra", collection, x)

    make_sphere("Vyrm | immense body", (0.0, 0.0, 1.14), (1.04, 1.0, 0.91), scales, collection, root, 3)
    make_sphere("Vyrm | armored belly", (0.0, -0.64, 0.99), (0.75, 0.41, 0.62), belly, props, root, 3)
    add_dragon_scale_rows(
        "Vyrm",
        -0.64,
        0.99,
        0.75,
        0.41,
        0.62,
        9,
        5,
        scales,
        props,
        root,
        (0.09, 0.027, 0.058),
    )
    make_wing("Vyrm | left frill", -1, 0.25, wing_mat, horn, props, root, reach=1.95, peak=2.54)
    make_wing("Vyrm | right frill", 1, 0.25, wing_mat, horn, props, root, reach=1.95, peak=2.54)

    for side in (-1, 0, 1):
        offset = side * 0.8
        neck_start = (side * 0.48, -0.32, 1.64)
        neck_end = (offset, -0.86, 2.45 - abs(side) * 0.12)
        head_y = -1.12 - (0.13 if side == 0 else 0.0)
        head_z = 2.51 - abs(side) * 0.09
        make_rod("Vyrm | serpent neck", neck_start, neck_end, 0.2, scales, collection, root, vertices=12)
        make_sphere("Vyrm | serpent head", (offset, head_y, head_z), (0.31, 0.37, 0.32), scales, collection, root, 2)
        make_sphere("Vyrm | fanged muzzle", (offset, head_y - 0.27, head_z - 0.14), (0.25, 0.29, 0.17), dark, props, root)
        make_sphere("Vyrm | snout scales", (offset, head_y - 0.46, head_z - 0.1), (0.18, 0.12, 0.09), scales, props, root)
        for facing in (-1, 1):
            make_sphere(
                "Vyrm | burning eye",
                (offset + facing * 0.2, head_y - 0.25, head_z + 0.075),
                (0.065, 0.05, 0.06),
                eye,
                props,
                root,
            )
            make_spike(
                "Vyrm | crown horn",
                (offset + facing * 0.17, head_y + 0.02, head_z + 0.24),
                (offset + facing * 0.31, head_y + 0.15, head_z + 0.65),
                0.095,
                horn,
                props,
                root,
            )
            make_spike(
                "Vyrm | serpent fang",
                (offset + facing * 0.13, head_y - 0.42, head_z - 0.08),
                (offset + facing * 0.13, head_y - 0.45, head_z - 0.23),
                0.045,
                fang,
                props,
                root,
            )

    for side in (-1, 1):
        hip = (side * 0.68, 0.45, 1.1)
        knee = (side * 0.84, 0.58, 0.56)
        foot = (side * 0.86, -0.03, 0.32)
        make_rod("Vyrm | giant haunch", hip, knee, 0.29, scales, collection, root, vertices=12)
        make_rod("Vyrm | rear leg", knee, foot, 0.18, dark, collection, root)
        make_sphere("Vyrm | rear foot", foot, (0.28, 0.31, 0.16), dark, props, root)
        for index in (-1, 0, 1):
            make_spike(
                "Vyrm | hooked claw",
                (side * 0.86 + index * 0.13, -0.23, 0.31),
                (side * 0.86 + index * 0.13, -0.43, 0.2),
                0.07,
                horn,
                props,
                root,
            )
    for index in range(6):
        y = -0.25 + index * 0.31
        make_spike("Vyrm | dorsal ridge", (0.0, y, 1.85), (0.0, y + 0.04, 2.18), 0.13, horn, props, root)

    make_rod("Vyrm | heavy tail", (0.0, 0.69, 1.2), (0.0, 1.51, 0.87), 0.26, scales, collection, root)
    make_rod("Vyrm | tapering tail", (0.0, 1.51, 0.87), (0.0, 2.32, 0.75), 0.16, scales, collection, root)
    make_spike("Vyrm | spade tail", (0.0, 2.2, 0.75), (0.0, 2.69, 0.82), 0.25, horn, props, root, vertices=5)
    make_plinth("Vyrm", x, 1.68, materials[7], horn, collection)
    make_title_card("VYRM", "HIDRA DE TRES CABEZAS", x, materials[8], collection)
    return root


def setup_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)

    scene = bpy.context.scene
    stage = make_collection("Stage | mythical bestiary")
    props = make_collection("Details | horns claws and scales")

    night = make_material("Neutral studio floor", (0.72, 0.7, 0.68), roughness=0.9)
    slate = make_material("Basalt plinth", (0.10, 0.14, 0.2), metallic=0.28, roughness=0.63)
    brass = make_material("Ancient bronze", (0.57, 0.32, 0.085), metallic=0.76, roughness=0.28)
    lettering = make_material("Runic gold", (1.0, 0.72, 0.3), metallic=0.25, roughness=0.32, emission=0.8)

    dragon = (
        make_material("Dragon | scarlet scales", (0.21, 0.004, 0.014), metallic=0.06, roughness=0.5, texture_scale=54),
        make_material("Dragon | deep red scale shadows", (0.105, 0.003, 0.009), metallic=0.08, roughness=0.42, texture_scale=44),
        make_membrane_material("Dragon | leathery red wing membrane", (0.16, 0.004, 0.011)),
        make_material("Dragon | black horn", (0.09, 0.06, 0.045), metallic=0.12, roughness=0.38, texture_scale=26),
        make_material("Dragon | pale rose belly plates", (0.31, 0.12, 0.12), metallic=0.02, roughness=0.56, texture_scale=35),
        make_material("Dragon | ember eyes", (1.0, 0.24, 0.012), roughness=0.18, emission=1.5),
        make_material("Dragon | ivory fangs", (0.9, 0.77, 0.53), roughness=0.35),
        slate,
        lettering,
    )
    griffin = (
        make_material("Griffin | tawny gold plumage", (0.67, 0.37, 0.095), metallic=0.12, roughness=0.55, texture_scale=50),
        make_material("Griffin | golden lion", (0.78, 0.45, 0.11), metallic=0.08, roughness=0.5, texture_scale=46),
        make_material("Griffin | ivory wings", (0.83, 0.75, 0.57), metallic=0.04, roughness=0.54, texture_scale=62),
        make_material("Griffin | chestnut feathers", (0.31, 0.12, 0.042), roughness=0.58, texture_scale=52),
        make_material("Griffin | cream chest", (0.9, 0.7, 0.37), roughness=0.58, texture_scale=45),
        make_material("Griffin | sun eyes", (1.0, 0.53, 0.045), roughness=0.2, emission=0.8),
        make_material("Griffin | beak and talons", (0.18, 0.105, 0.055), metallic=0.28, roughness=0.3),
        slate,
        lettering,
    )
    hydra = (
        make_material("Hydra | deep sea scales", (0.035, 0.3, 0.24), metallic=0.28, roughness=0.38, texture_scale=60),
        make_material("Hydra | dark teal armor", (0.015, 0.12, 0.12), metallic=0.38, roughness=0.3, texture_scale=48),
        make_material("Hydra | emerald frills", (0.07, 0.48, 0.34), metallic=0.14, roughness=0.46, texture_scale=36),
        make_material("Hydra | jade horns", (0.22, 0.67, 0.46), metallic=0.3, roughness=0.26, texture_scale=30),
        make_material("Hydra | pale scales", (0.48, 0.77, 0.57), roughness=0.52, texture_scale=52),
        make_material("Hydra | venom eyes", (0.45, 1.0, 0.06), roughness=0.18, emission=1.2),
        make_material("Hydra | bone teeth", (0.85, 0.79, 0.55), roughness=0.33),
        slate,
        lettering,
    )

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0.0, 0.0, -0.04))
    floor = bpy.context.object
    floor.name = "Midnight black stage"
    move_to_collection(floor, stage)
    floor.data.materials.append(night)

    lineups = [
        (0.0, build_dragon, "01 | Ignivar the elder dragon"),
        (-4.35, build_griffin, "02 | Aurelion the griffin"),
        (4.35, build_hydra, "03 | Vyrm the three-headed hydra"),
    ]
    for x, build, name in lineups:
        collection = make_collection(name)
        details = make_collection(name + " | details")
        build(x, collection, details, dragon if build == build_dragon else griffin if build == build_griffin else hydra)
        if build != build_dragon:
            collection.hide_render = True
            details.hide_render = True

    for body, location, size in [
        ("IGNIVAR", (0.0, -1.1, 4.35), 0.37),
        ("DRAGON ESCARLATA", (0.0, -1.1, 4.02), 0.14),
    ]:
        curve = bpy.data.curves.new(body + " | title", "FONT")
        curve.body = body
        curve.size = size
        curve.align_x = "CENTER"
        curve.extrude = 0.002
        title = bpy.data.objects.new(body + " | title", curve)
        stage.objects.link(title)
        title.location = location
        title.rotation_euler.x = 1.5708
        title.data.materials.append(lettering)
        title.hide_render = True

    world = bpy.data.worlds.new("Mythic night")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.clear()
    background = world.node_tree.nodes.new("ShaderNodeBackground")
    output = world.node_tree.nodes.new("ShaderNodeOutputWorld")
    world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    background.inputs["Color"].default_value = (0.78, 0.77, 0.75, 1.0)
    background.inputs["Strength"].default_value = 0.45

    for name, location, energy, size, color in [
        ("Key | softbox", (-5.0, -5.0, 7.0), 750, 5.0, (1.0, 0.82, 0.72)),
        ("Fill | softbox", (4.0, -3.0, 5.0), 500, 4.5, (0.72, 0.78, 1.0)),
        ("Rim | softbox", (0.0, 3.0, 7.0), 650, 4.0, (1.0, 0.6, 0.55)),
    ]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        data.color = color
        light = bpy.data.objects.new(name, data)
        stage.objects.link(light)
        light.location = location
        light.rotation_euler = (Vector((0.0, 0.0, 1.4)) - light.location).to_track_quat("-Z", "Y").to_euler()

    camera_data = bpy.data.cameras.new("Bestiary portrait camera")
    camera = bpy.data.objects.new("Bestiary portrait camera", camera_data)
    stage.objects.link(camera)
    camera.location = (8.0, -10.0, 3.7)
    camera.rotation_euler = (Vector((0.0, 0.25, 1.95)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 8.0
    scene.camera = camera

    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 128
    scene.render.resolution_x = 1350
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.25
    scene.render.filepath = str(OUTPUT / "mythical_beasts_preview.png")

    bpy.ops.object.select_all(action="DESELECT")
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"

    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "mythical_beasts.blend"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    setup_scene()
