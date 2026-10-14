extends RefCounted
# Optional model adapter.  An actual exported and licensed GLB model can
# replace the hand-built temporary plant without changing the game logic.
const MODEL_PATHS := {
    "peashooter": "res://assets/models/peashooter.glb",
    "sunflower": "res://assets/models/sunflower.glb",
    "cactus": "res://assets/models/cactus.glb",
    "browncoat": "res://assets/models/browncoat.glb",
}

static func instance_model(model_id: String) -> Node3D:
    var path: String = MODEL_PATHS.get(model_id, "")
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if resource is PackedScene:
        return (resource as PackedScene).instantiate() as Node3D
    return null
