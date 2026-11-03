import bpy
from mathutils import Vector
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "assets" / "quaternius" / "human_characters"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "custom_faces"
CHARACTERS = (
    ("Female", "Superhero_Female_FullBody.gltf"),
    ("Male", "Superhero_Male_FullBody.gltf"),
)


def smooth_weight(value, start, end):
    t = max(0.0, min(1.0, (value - start) / (end - start)))
    return t * t * (3.0 - 2.0 * t)


def add_shape_key(mesh_object, name, deform):
    if mesh_object.data.shape_keys is None:
        mesh_object.shape_key_add(name="Basis", from_mix=False)
    shape_key = mesh_object.shape_key_add(name=name, from_mix=False)
    world_to_local = mesh_object.matrix_world.inverted()
    for index, vertex in enumerate(mesh_object.data.vertices):
        source = mesh_object.matrix_world @ vertex.co
        result = deform(source.copy())
        shape_key.data[index].co = world_to_local @ result


def head_weight(mesh_object, vertex_index):
    group = mesh_object.vertex_groups.get("Head")
    if group is None:
        return 0.0
    try:
        return group.weight(vertex_index)
    except RuntimeError:
        return 0.0


def author_body_shapes(body, eye_center_z):
    def create_head_shape(name, deform):
        if body.data.shape_keys is None:
            body.shape_key_add(name="Basis", from_mix=False)
        key = body.shape_key_add(name=name, from_mix=False)
        world_to_local = body.matrix_world.inverted()
        for index, vertex in enumerate(body.data.vertices):
            point = body.matrix_world @ vertex.co
            weight = head_weight(body, index)
            if weight <= 0.0 or point.z < 1.48:
                continue
            result = deform(point.copy(), weight)
            key.data[index].co = world_to_local @ result

    def face_square(point, weight):
        amount = smooth_weight(point.z, eye_center_z - 0.12, eye_center_z + 0.015) * weight
        point.x *= 1.0 + 0.11 * amount
        return point

    def face_round(point, weight):
        amount = smooth_weight(point.z, eye_center_z - 0.15, eye_center_z - 0.08) * (1.0 - smooth_weight(point.z, eye_center_z + 0.08, eye_center_z + 0.14)) * weight
        point.x *= 1.0 + 0.09 * amount
        return point

    def face_long(point, weight):
        amount = smooth_weight(point.z, eye_center_z - 0.13, eye_center_z - 0.06) * weight
        point.z += (point.z - (eye_center_z - 0.04)) * 0.09 * amount
        return point

    create_head_shape("Face_Square", face_square)
    create_head_shape("Face_Round", face_round)
    create_head_shape("Face_Long", face_long)

    def jaw_deformer(width_scale, angular=False):
        def deform(point, weight=1.0):
            jaw_weight = (1.0 - smooth_weight(point.z, eye_center_z - 0.1, eye_center_z - 0.015)) * weight
            if angular:
                jaw_weight *= smooth_weight(abs(point.x), 0.015, 0.11)
            point.x *= 1.0 + (width_scale - 1.0) * jaw_weight
            return point
        return deform

    create_head_shape("Jaw_Angular", jaw_deformer(1.1, True))
    create_head_shape("Jaw_Broad", jaw_deformer(1.14))
    create_head_shape("Jaw_Narrow", jaw_deformer(0.88))

    nose_center_z = eye_center_z - 0.035

    def nose_deformer(width_scale=1.0, depth=0.0, height_scale=1.0, lift=0.0):
        def deform(point, weight=1.0):
            front_weight = smooth_weight(-point.y, 0.018, 0.065)
            center_weight = 1.0 - smooth_weight(abs(point.x), 0.012, 0.052)
            height_weight = 1.0 - smooth_weight(abs(point.z - nose_center_z), 0.025, 0.07)
            amount = front_weight * center_weight * height_weight * weight
            point.x *= 1.0 + (width_scale - 1.0) * amount
            point.y -= depth * amount
            point.z = nose_center_z + (point.z - nose_center_z) * (1.0 + (height_scale - 1.0) * amount)
            point.z += lift * amount
            return point
        return deform

    add_shape_key(body, "Nose_Straight", nose_deformer(0.94, 0.002, 1.12))
    add_shape_key(body, "Nose_Wide", nose_deformer(1.32, 0.004, 0.94))
    add_shape_key(body, "Nose_Upturned", nose_deformer(0.96, 0.006, 0.84, 0.006))

    mouth_center_z = eye_center_z - 0.09

    def mouth_deformer(width_scale=1.0, smile=0.0, height_scale=1.0):
        def deform(point, weight=1.0):
            front_weight = smooth_weight(-point.y, 0.012, 0.06)
            center_weight = 1.0 - smooth_weight(abs(point.x), 0.025, 0.09)
            height_weight = 1.0 - smooth_weight(abs(point.z - mouth_center_z), 0.018, 0.055)
            amount = front_weight * center_weight * height_weight * weight
            point.x *= 1.0 + (width_scale - 1.0) * amount
            point.z += smile * smooth_weight(abs(point.x), 0.012, 0.07) * amount
            point.z = mouth_center_z + (point.z - mouth_center_z) * (1.0 + (height_scale - 1.0) * amount)
            return point
        return deform

    create_head_shape("Mouth_Fine", mouth_deformer(0.78, 0.0, 0.84))
    create_head_shape("Mouth_Wide", mouth_deformer(1.3))
    create_head_shape("Mouth_Smile", mouth_deformer(1.12, 0.009))


def author_eye_shapes(eyes):
    bounds = [eyes.matrix_world @ vertex.co for vertex in eyes.data.vertices]
    eye_center_x = (max(point.x for point in bounds) - min(point.x for point in bounds)) * 0.25
    eye_center_z = (max(point.z for point in bounds) + min(point.z for point in bounds)) * 0.5

    def eye_deformer(width=1.0, height=1.0, droop=0.0):
        def deform(point):
            side = -1.0 if point.x < 0.0 else 1.0
            center_x = side * eye_center_x
            point.x = center_x + (point.x - center_x) * width
            point.z = eye_center_z + (point.z - eye_center_z) * height
            point.z -= droop * max(0.0, abs(point.x) - abs(center_x)) / max(eye_center_x, 0.001)
            return point
        return deform

    add_shape_key(eyes, "Eyes_Large", eye_deformer(1.12, 1.2))
    add_shape_key(eyes, "Eyes_Narrow", eye_deformer(1.04, 0.72))
    add_shape_key(eyes, "Eyes_Drooped", eye_deformer(1.0, 0.96, 0.006))


def author_eyebrow_shapes(brows):
    def brow_deformer(width=1.0, lift=0.0, angle=0.0):
        def deform(point):
            side = -1.0 if point.x < 0.0 else 1.0
            center_x = side * 0.032
            point.x = center_x + (point.x - center_x) * width
            point.z += lift + angle * (abs(point.x) - abs(center_x))
            return point
        return deform

    add_shape_key(brows, "Eyes_Large", brow_deformer(1.08, 0.004))
    add_shape_key(brows, "Eyes_Narrow", brow_deformer(0.94, -0.003))
    add_shape_key(brows, "Eyes_Drooped", brow_deformer(1.0, -0.006, 0.16))


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    imported_objects = []
    for character_name, filename in CHARACTERS:
        before = set(bpy.context.scene.objects)
        source_path = SOURCE_DIR / filename
        if not source_path.is_file():
            raise FileNotFoundError(f"Character pack model not found: {source_path}")
        bpy.ops.import_scene.gltf(filepath=str(source_path))
        new_objects = [obj for obj in bpy.context.scene.objects if obj not in before]
        body = next((obj for obj in new_objects if obj.type == "MESH" and obj.name.lower().startswith("superhero_")), None)
        eyes = next((obj for obj in new_objects if obj.type == "MESH" and obj.name.startswith("Eyes")), None)
        brows = next((obj for obj in new_objects if obj.type == "MESH" and obj.name.startswith("Eyebrows")), None)
        if body is None or eyes is None or brows is None:
            raise RuntimeError(f"Expected body, eyes, and eyebrows in {source_path.name}")
        eye_bounds = [eyes.matrix_world @ vertex.co for vertex in eyes.data.vertices]
        eye_center_z = (max(point.z for point in eye_bounds) + min(point.z for point in eye_bounds)) * 0.5
        author_body_shapes(body, eye_center_z)
        author_eye_shapes(eyes)
        author_eyebrow_shapes(brows)
        output_path = OUTPUT_DIR / f"Superhero_{character_name}_FullBody.glb"
        bpy.ops.object.select_all(action="DESELECT")
        for obj in new_objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.export_scene.gltf(
            filepath=str(output_path),
            export_format="GLB",
            export_morph=True,
            export_skins=True,
            use_selection=True,
        )
        print(f"Created {output_path}")
        if character_name == "Female":
            imported_objects.extend(new_objects)
        else:
            for obj in new_objects:
                obj.location.x += 2.2
            imported_objects.extend(new_objects)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in imported_objects)
    for image in bpy.data.images:
        if image.source == "FILE" and image.packed_file is None:
            image.pack()
    bpy.context.view_layer.objects.active = imported_objects[0] if imported_objects else None
    blend_path = OUTPUT_DIR / "character_faces_authoring.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print(f"Saved editable Blender source {blend_path}")


if __name__ == "__main__":
    main()
