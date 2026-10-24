from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "custom_equipment" / "mythical_beasts" / "mythical_beasts.blend"
OUTPUT = ROOT / "assets" / "custom_equipment" / "mythical_bosses"


def export_boss(collection_name: str, boss_name: str, offset: float) -> None:
    collections = [
        collection
        for collection in bpy.data.collections
        if collection.name in (collection_name, collection_name + " | details")
    ]
    if not collections:
        raise RuntimeError("Boss collection not found: " + collection_name)

    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for collection in collections:
        for obj in collection.all_objects:
            if obj.type not in {"MESH", "EMPTY"}:
                continue
            if any(term in obj.name.lower() for term in ("plinth", "title", "studio")):
                continue
            if obj not in selected:
                selected.append(obj)

    if not selected:
        raise RuntimeError("Boss collection has no exportable geometry: " + collection_name)

    for obj in selected:
        obj.select_set(True)
        if obj.parent is None and obj.type == "EMPTY":
            obj.location.x -= offset
            obj.name = boss_name

    bpy.context.view_layer.objects.active = selected[0]
    destination = OUTPUT / (boss_name.lower() + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
    )
    print("Exported", boss_name, "with", len(selected), "objects to", destination)


OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
export_boss("01 | Ignivar the elder dragon", "Ignivar", 0.0)
export_boss("03 | Vyrm the three-headed hydra", "Vyrm", 4.35)
