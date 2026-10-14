extends Node3D

var actor: CharacterBody3D
var head: Node3D
var leaves: Array[Node3D] = []
var clock := 0.0
var movement := 0.0
var recoil_amount := 0.0
var landing_amount := 0.0
var previously_airborne := false

func configure(model: Node3D, character: CharacterBody3D) -> void:
  actor = character
  head = Node3D.new()
  head.name = "PeashooterHeadPivot"
  model.add_child(head)
  head.position = Vector3(0.0, 1.48, 0.0)

  var parts: Array[MeshInstance3D] = []
  _collect_meshes(model, parts)

  for part in parts:
    var n := String(part.name).to_lower()
    var belongs_to_head := n.begins_with("green_") or n.begins_with("green_light_") or n.begins_with("snout_") or n.begins_with("lip_") or n.begins_with("mouth_") or n.begins_with("dark_green_") or n.begins_with("eyes_") or n.begins_with("pupil_") or n.begins_with("shine_") or n.begins_with("freckles_")

    if belongs_to_head:
      part.reparent(head, true)
    elif (n.begins_with("leaf_") or n.begins_with("light_leaf_")) and leaves.size() < 24:
      var pivot := Node3D.new()
      pivot.name = "LeafPivot"
      model.add_child(pivot)
      pivot.global_position = part.to_global(part.get_aabb().get_center())
      part.reparent(pivot, true)
      leaves.append(pivot)

  print("Peashooter animation ready")

func _collect_meshes(root: Node, result: Array[MeshInstance3D]) -> void:
  for child in root.get_children():
    if child is MeshInstance3D:
      result.append(child)
    _collect_meshes(child, result)

func recoil() -> void:
  recoil_amount = 1.0

func _process(delta: float) -> void:
  if actor == null or head == null:
    return

  clock += delta

  var horizontal_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
  movement = move_toward(movement, clampf(horizontal_speed / 5.5, 0.0, 1.0), delta * 6.0)
  recoil_amount = move_toward(recoil_amount, 0.0, delta * 6.5)

  var airborne := not actor.is_on_floor()

  if previously_airborne and not airborne:
    landing_amount = 1.0

  previously_airborne = airborne
  landing_amount = move_toward(landing_amount, 0.0, delta * 4.0)

  var step_phase := clock * 10.0

  head.rotation.x = sin(clock * 2.6) * 0.025 + sin(step_phase) * movement * 0.10 - recoil_amount * 0.23
  head.rotation.z = sin(clock * 1.8) * 0.035 + cos(step_phase * 0.5) * movement * 0.055

  head.position.y = 1.48 + sin(clock * 2.7) * 0.016 + absf(sin(step_phase)) * movement * 0.055 + (0.10 if airborne else 0.0) - landing_amount * 0.11

  head.scale = Vector3(1.0 + landing_amount * 0.05, 1.0 - landing_amount * 0.08, 1.0 + landing_amount * 0.05)

  for i in range(leaves.size()):
    var phase := float(i) * 0.65
    leaves[i].rotation.z = sin(clock * 2.8 + phase) * 0.05 + sin(step_phase + phase) * movement * 0.18
    leaves[i].rotation.x = cos(clock * 2.0 + phase) * 0.035 + cos(step_phase + phase) * movement * 0.08
