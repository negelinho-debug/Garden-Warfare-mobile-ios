extends Node3D

const MODEL_LOADER = preload("res://scripts/model_loader.gd")

# Entire world is built from meshes at runtime. No external model downloads required.
# All visuals are original, simple procedural fan-art placeholders (not ripped assets).

var player: CharacterBody3D
var plant: Node3D
var camera: Camera3D
var active := false
var joy := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var jump_requested := false
var firing := false
var shot_cooldown := 0.0
var shots: Array[Dictionary] = []
var hits := 0
var hit_callback: Callable
var sensitivity := 0.0038
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 41721
	_build_environment()
	_build_garden()
	_make_player()
	camera = Camera3D.new()
	camera.fov = 67.0
	camera.current = true
	add_child(camera)
	_update_camera(1.0)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("7dbbd9")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d3e8d6")
	env.ambient_light_energy = 0.43
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,-18)
	sun.light_color = Color("fff1c3")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, color: Color, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color)
	part.position = position
	part.scale = scale_value
	parent.add_child(part)
	return part

func _sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 7
	return _mesh(parent,m,pos,color,scale_value)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	return _mesh(parent,m,pos,color)

func _decor_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent,b,pos,color)

func _solid_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	add_child(body)
	_decor_box(body,Vector3.ZERO,size,color)
	var shape := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	shape.shape = s
	body.add_child(shape)
	return body

func _build_garden() -> void:
	_solid_box(Vector3(0,-0.32,0),Vector3(50,0.6,50),Color("4c9a5b"))
	# A curving stepping-stone trail, little hedges, flower beds and wooden fencing.
	for i in range(13):
		var t := float(i)
		_decor_box(self,Vector3(sin(t * 0.52)*1.2,0.01,11.0-t*2.0),Vector3(1.65,0.06,1.4),Color("c3b59a"))
	for x in range(-22,23,3):
		for z in [-23,23]:
			_cylinder(self,Vector3(x,0.9,z),0.13,1.8,Color("a77448"))
			_decor_box(self,Vector3(x,0.86,z),Vector3(3.0,0.17,0.14),Color("d4a66f"))
	for z in range(-22,23,3):
		for x in [-23,23]:
			_cylinder(self,Vector3(x,0.9,z),0.13,1.8,Color("a77448"))
			_decor_box(self,Vector3(x,0.86,z),Vector3(0.14,0.17,3.0),Color("d4a66f"))
	# Small decorated house: boxes are architectural surfaces, not character placeholders.
	_solid_box(Vector3(-13,2.2,-14),Vector3(8,4.4,7),Color("dec49e"))
	_decor_box(self,Vector3(-13,4.62,-14),Vector3(9.2,0.45,8.0),Color("bb624b"))
	_decor_box(self,Vector3(-13,2.15,-10.44),Vector3(1.75,3.25,0.12),Color("8b5d44"))
	_decor_box(self,Vector3(-15.5,2.95,-10.40),Vector3(1.4,1.55,0.13),Color("89cddd"))
	_decor_box(self,Vector3(-10.6,2.95,-10.40),Vector3(1.4,1.55,0.13),Color("89cddd"))
	for i in range(7):
		var tx := rng.randf_range(-20.0,20.0)
		var tz := rng.randf_range(-20.0,20.0)
		if Vector2(tx+13.0,tz+14.0).length() < 8.0 or Vector2(tx,tz).length() < 5.0:
			continue
		_tree(Vector3(tx,0,tz),rng.randf_range(0.8,1.3))
	for i in range(38):
		var fx := rng.randf_range(-20.0,20.0)
		var fz := rng.randf_range(-20.0,20.0)
		if Vector2(fx+13.0,fz+14.0).length() < 6.0:
			continue
		_flower(Vector3(fx,0,fz), i)
	for i in range(15):
		var hx := -4.0+float(i)*0.65
		_sphere(self,Vector3(hx,0.45,-18.0),Vector3(1.1,0.8,0.9),Color("488e42"))
	for i in range(3):
		_target(Vector3(4.0+float(i)*4.4,1.2,-8.0-float(i%2)*3.5))
	# Small flowerbeds and bushes to give the prototype more depth.
	for i in range(36):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var bx: float = side * rng.randf_range(13.0,22.0)
		var bz: float = rng.randf_range(-19.0,19.0)
		var tone: Color = Color("3b8549") if i % 3 == 0 else Color("5f9e49")
		_sphere(self,Vector3(bx,0.40,bz),Vector3(1.1,0.65,0.95),tone)
	# Decorative starting stones.
	for i in range(4):
		_sphere(self,Vector3(-5+float(i)*2,0.12,6.0),Vector3(1.2,0.17,0.9),Color("c7c4af"))

func _tree(pos: Vector3, s: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * s
	add_child(tree)
	_cylinder(tree,Vector3(0,1.65,0),0.32,3.3,Color("916847"))
	_sphere(tree,Vector3(0,3.75,0),Vector3(3.2,2.7,3.0),Color("448b4d"))
	_sphere(tree,Vector3(-1.05,3.2,0.3),Vector3(1.9,1.9,1.9),Color("66a759"))
	_sphere(tree,Vector3(0.85,4.1,-0.45),Vector3(1.9,1.8,2.0),Color("5ca056"))

func _flower(pos: Vector3, variant: int) -> void:
	var colors := [Color("ffe190"),Color("f7abc0"),Color("efeaf5"),Color("ffae6c")]
	var plant_root := Node3D.new()
	plant_root.position = pos
	add_child(plant_root)
	_cylinder(plant_root,Vector3(0,0.22,0),0.026,0.45,Color("3c8b3c"))
	_sphere(plant_root,Vector3(0,0.48,0),Vector3(0.30,0.19,0.30),colors[variant%4])
	_sphere(plant_root,Vector3(0,0.50,0),Vector3(0.12,0.13,0.12),Color("e5a047"))

func _target(pos: Vector3) -> void:
	var target := StaticBody3D.new()
	target.collision_layer = 4
	target.collision_mask = 0
	target.position = pos
	target.set_meta("target",true)
	add_child(target)
	_cylinder(target,Vector3(0,-0.5,0),0.12,1.1,Color("94603f"))
	# Cylinder orientation makes the bullseye face the starting path (positive Z).
	for spec in [[0.94,Color("f4e4c7"),0.04],[0.70,Color("d86155"),0.07],[0.39,Color("f7d385"),0.10]]:
		var disc := _cylinder(target,Vector3(0,0.55,float(spec[2])),float(spec[0]),0.075,spec[1])
		disc.rotation_degrees.x = 90.0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9,1.9,0.5)
	collision.shape = box
	collision.position.y = 0.55
	target.add_child(collision)

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PeaHero"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector3(0,0.55,8)
	add_child(player)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.85
	shape.shape = cap
	shape.position.y = 0.48
	player.add_child(shape)
	plant = Node3D.new()
	plant.position.y = -0.4
	player.add_child(plant)
	var imported: Node3D = MODEL_LOADER.instance_model("peashooter")
	if imported != null:
		# Character forward direction is -Z, adjust GLB scale/rotation here if needed.
		plant.add_child(imported)
		return
	# Rounded original character: used until a legitimate GLB exists.
	_cylinder(plant,Vector3(0,0.83,0),0.20,1.18,Color("4a9b3b"))
	_sphere(plant,Vector3(0,1.55,0),Vector3(1.32,1.24,1.25),Color("80cf39"))
	_sphere(plant,Vector3(0.0,1.51,-0.62),Vector3(0.56,0.55,0.81),Color("56aa29"))
	var snout := _cylinder(plant,Vector3(0,1.45,-1.0),0.29,0.80,Color("69b92d"))
	snout.rotation_degrees.x = 90.0
	_sphere(plant,Vector3(-0.35,1.82,-0.50),Vector3(0.28,0.38,0.14),Color.WHITE)
	_sphere(plant,Vector3(0.35,1.82,-0.50),Vector3(0.28,0.38,0.14),Color.WHITE)
	_sphere(plant,Vector3(-0.33,1.82,-0.615),Vector3(0.11,0.20,0.09),Color("202c1d"))
	_sphere(plant,Vector3(0.33,1.82,-0.615),Vector3(0.11,0.20,0.09),Color("202c1d"))
	_sphere(plant,Vector3(-0.55,0.66,0.00),Vector3(0.88,0.14,0.38),Color("439c41"))
	_sphere(plant,Vector3(0.55,0.66,0.00),Vector3(0.88,0.14,0.38),Color("52ad3b"))
	_sphere(plant,Vector3(0,0.28,0.50),Vector3(0.80,0.18,0.85),Color("378b39"))
	_sphere(plant,Vector3(0,0.28,-0.36),Vector3(0.80,0.18,0.75),Color("52a93b"))

func set_playing(value: bool) -> void:
	active = value
	joy = Vector2.ZERO
	firing = false

func change_look(delta: Vector2) -> void:
	if not active:
		return
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity, -0.50, 0.32)

func request_jump() -> void:
	jump_requested = true

func _physics_process(delta: float) -> void:
	if active:
		var keys := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): keys.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): keys.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): keys.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): keys.y += 1
		var stick: Vector2 = joy if joy.length() > 0.12 else keys.normalized()
		var rotation_basis := Basis(Vector3.UP,yaw)
		var move_dir: Vector3 = rotation_basis * Vector3(stick.x,0,stick.y)
		if move_dir.length() > 1.0: move_dir = move_dir.normalized()
		player.velocity.x = move_dir.x * 5.5
		player.velocity.z = move_dir.z * 5.5
		if player.is_on_floor():
			if jump_requested or Input.is_key_pressed(KEY_SPACE):
				player.velocity.y = 6.2
			else:
				player.velocity.y = -0.2
		else:
			player.velocity.y -= 16.5 * delta
		jump_requested = false
		player.move_and_slide()
		# Smoothly face the camera aim direction; the shot exits the snout.
		plant.rotation.y = lerp_angle(plant.rotation.y,yaw,delta*8.0)
		plant.position.y = -0.4 + sin(Time.get_ticks_msec()*0.012)*0.04 if stick.length() > 0.1 else -0.4
		shot_cooldown -= delta
		if (firing or Input.is_key_pressed(KEY_F)) and shot_cooldown <= 0:
			shoot()
		_update_shots(delta)
	_update_camera(delta)

func shoot() -> void:
	if not active or shot_cooldown > 0.0:
		return
	shot_cooldown = 0.25
	# Raycast through the crosshair, then launch the pea towards that point.
	# This reduces missing close targets due to third-person camera parallax.
	var aim_end: Vector3 = camera.global_position - camera.global_transform.basis.z * 75.0
	var aim_ray := PhysicsRayQueryParameters3D.create(camera.global_position, aim_end, 5)
	var aimed_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(aim_ray)
	if not aimed_hit.is_empty():
		aim_end = aimed_hit["position"]
	var start: Vector3 = player.global_position + Vector3(0,1.08,0) + Basis(Vector3.UP,yaw) * Vector3(0,0,-0.95)
	var direction: Vector3 = (aim_end - start).normalized()
	var pea := Node3D.new()
	pea.position = start
	add_child(pea)
	_sphere(pea,Vector3.ZERO,Vector3(0.30,0.30,0.30),Color("83d438"))
	shots.append({"node":pea,"dir":direction,"ttl":2.1})

func _update_shots(delta: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var shot: Dictionary = shots[i]
		var node: Node3D = shot["node"]
		var displacement: Vector3 = shot["dir"] * 25.0 * delta
		var query := PhysicsRayQueryParameters3D.create(node.global_position,node.global_position+displacement,5)
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			var collider: Object = result["collider"]
			if collider.has_meta("target"):
				hits += 1
				if hit_callback.is_valid(): hit_callback.call(hits)
				_hit_flash(result["position"])
			node.queue_free()
			shots.remove_at(i)
			continue
		node.global_position += displacement
		shot["ttl"] -= delta
		if shot["ttl"] < 0.0:
			node.queue_free()
			shots.remove_at(i)
		else:
			shots[i] = shot

func _update_camera(delta: float) -> void:
	if camera == null: return
	var destination: Vector3
	var look_target: Vector3
	if active:
		var direction := Basis(Vector3.UP,yaw)
		destination = player.global_position + Vector3(0,2.20,0) + direction * Vector3(0,0.5,5.1)
		look_target = player.global_position + Vector3(0,2.4,0) + direction * Vector3(0,pitch*5.0,-12.0)
	else:
		destination = Vector3(10,7,16)
		look_target = Vector3(0,1,0)
	camera.global_position = camera.global_position.lerp(destination,minf(delta*8.0,1.0))
	camera.look_at(look_target,Vector3.UP)

func _hit_flash(world_position: Vector3) -> void:
	var puff := Node3D.new()
	puff.position = world_position
	add_child(puff)
	_sphere(puff, Vector3.ZERO, Vector3(0.42,0.42,0.42), Color("e5f889"))
	var tween := create_tween()
	tween.tween_property(puff, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(puff.queue_free)
