extends Node3D

# Garden Warfare Mobile v0.5 - visual pass (original assets)
const MODEL_LOADER = preload("res://scripts/model_loader.gd")
const PEA_ANIM = preload("res://scripts/pea_anim.gd")

var player: CharacterBody3D
var plant: Node3D
var camera: Camera3D
var pea_anim
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
var shot_audio: AudioStreamPlayer3D
var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}

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
	env.background_color = Color("83b4ca")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8deca")
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-53, -33, -18)
	sunlight.light_color = Color("fff1da")
	sunlight.light_energy = 0.79
	sunlight.shadow_enabled = true
	sunlight.shadow_blur = 2.0
	add_child(sunlight)

func _material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var key: String = color.to_html() + ":" + str(roughness)
	if material_cache.has(key):
		return material_cache[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	material_cache[key] = result
	return result

func _texture_mat(which: String, scale_uv: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var key: String = which + str(scale_uv)
	if texture_cache.has(key):
		return texture_cache[key]
	var result := StandardMaterial3D.new()
	result.albedo_texture = load("res://assets/textures/" + which) as Texture2D
	result.roughness = 0.93
	result.uv1_scale = scale_uv
	result.texture_repeat = true
	texture_cache[key] = result
	return result

func _mesh(parent: Node3D, shape: Mesh, where: Vector3, color: Color, sizing: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = shape
	m.material_override = _material(color)
	m.position = where
	m.scale = sizing
	parent.add_child(m)
	return m

func _sphere(parent: Node3D, where: Vector3, sizing: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 9
	return _mesh(parent, shape, where, color, sizing)

func _cylinder(parent: Node3D, where: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	return _mesh(parent, shape, where, color)

func _cone(parent: Node3D, where: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.0
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 11
	return _mesh(parent, shape, where, color)

func _decor_box(parent: Node3D, where: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return _mesh(parent, shape, where, color)

func _textured_box(parent: Node3D, where: Vector3, dimensions: Vector3, tex: String, uv: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := _decor_box(parent, where, dimensions, Color.WHITE)
	mesh.material_override = _texture_mat(tex, uv)
	return mesh

func _solid_box(where: Vector3, dimensions: Vector3, color: Color, tex: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = where
	add_child(body)
	if tex.is_empty():
		_decor_box(body, Vector3.ZERO, dimensions, color)
	else:
		_textured_box(body, Vector3.ZERO, dimensions, tex, Vector3(18,18,1))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	return body

func _build_garden() -> void:
	# Coloured and textured playfield plus soft distant hills.
	_solid_box(Vector3(0, -0.37, 0), Vector3(50, 0.72, 50), Color("669969"), "lawn.png")
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		var distance: float = 32.0 + float(i % 4) * 1.5
		var tone: Color = Color("719b86") if i%2==0 else Color("7ca391")
		_sphere(self, Vector3(cos(angle)*distance, -3.5, sin(angle)*distance), Vector3(15,9,11), tone)
	for i in range(13):
		var t: float = float(i)
		var slab := _textured_box(self, Vector3(sin(t*0.52)*1.2, 0.045, 11.0-t*2.0), Vector3(1.85,0.12,1.5), "pavers.png", Vector3(2,2,1))
		slab.rotation_degrees.y = sin(t*0.7)*7.0
	_textured_box(self,Vector3(-13,0.025,-6.1),Vector3(10,0.09,2.9),"earth.png",Vector3(6,2,1))
	_build_fence()
	_build_house()
	for i in range(11):
		var tx: float = rng.randf_range(-21,21)
		var tz: float = rng.randf_range(-21,21)
		if Vector2(tx+13.0,tz+14.0).length() < 9.5 or Vector2(tx,tz).length() < 6.0:
			continue
		_tree(Vector3(tx,0,tz),rng.randf_range(0.82,1.24),i)
	for i in range(92):
		var fx: float = rng.randf_range(-21,21)
		var fz: float = rng.randf_range(-21,21)
		if Vector2(fx+13.0,fz+14.0).length() < 7.3 or Vector2(fx,fz-8).length() < 4.0:
			continue
		_flower(Vector3(fx,0,fz),i)
	for i in range(22):
		var hx: float = -7.2+float(i)*0.52
		_sphere(self,Vector3(hx,0.38,-18),Vector3(0.85,0.63,0.77),Color("44784b") if i%3==0 else Color("518b52"))
	for i in range(38):
		var side: float = -1.0 if i%2==0 else 1.0
		_bush(Vector3(side*rng.randf_range(13.0,21.5),0,rng.randf_range(-20,20)),rng.randf_range(0.65,1.15))
	for i in range(14):
		_flower(Vector3(-17.2+i*0.63,0.10,-5.65),i)
	_target(Vector3(4,1.2,-8))
	_target(Vector3(8.4,1.2,-11.5))
	_target(Vector3(12.8,1.2,-8))
	_shooting_sign()
	_grass_multimesh()
	_barrel(Vector3(-6,0,5.4))
	_barrel(Vector3(-7.2,0,5.9))
	_bench(Vector3(-8,0,8))

func _build_fence() -> void:
	for x in range(-24,25,3):
		for z in [-23.5, 23.5]:
			_cylinder(self,Vector3(x,1,z),0.13,2,Color("b18459"))
			_cone(self,Vector3(x,2.1,z),0.2,0.35,Color("d9b786"))
			for rail_y in [0.7,1.42]:
				_textured_box(self,Vector3(x,rail_y,z),Vector3(3,0.13,0.16),"wood.png",Vector3(2,1,1))
	for z in range(-22,23,3):
		for x in [-23.5,23.5]:
			_cylinder(self,Vector3(x,1,z),0.13,2,Color("b18459"))
			_cone(self,Vector3(x,2.1,z),0.2,0.35,Color("d9b786"))
			for rail_y in [0.7,1.42]:
				_textured_box(self,Vector3(x,rail_y,z),Vector3(0.16,0.13,3),"wood.png",Vector3(2,1,1))


func _collision_box(where: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = where
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

func _build_house() -> void:
	# Keep solid walls; the prettier surfaces are only decoration.
	_collision_box(Vector3(-13,2.2,-14),Vector3(8,4.4,7))
	_collision_box(Vector3(-19,1.7,-15.2),Vector3(3.9,3.4,5.8))
	var house := Node3D.new()
	house.position = Vector3(-13,0,-14)
	add_child(house)
	# Two-piece shingled pitched roof, plaster, window casings, porch, garage.
	_textured_box(house,Vector3(0,2.2,0),Vector3(8,4.4,7),"stucco.png",Vector3(3,2,1))
	_decor_box(house,Vector3(0,0.18,0),Vector3(8.6,0.36,7.7),Color("ab9277"))
	_decor_box(house,Vector3(0,4.33,0),Vector3(8.4,0.24,7.4),Color("f2e0b5"))
	for side in [-1,1]:
		var roof: MeshInstance3D = _textured_box(house,Vector3(float(side)*2.21,5.22,0),Vector3(5.15,0.26,8.1),"shingles.png",Vector3(5,5,1))
		roof.rotation_degrees.z = -float(side)*27.0
	_textured_box(house,Vector3(-2,6.07,-2.15),Vector3(0.9,1.95,0.95),"stone.png",Vector3(1,2,1))
	_decor_box(house,Vector3(-2,7.13,-2.15),Vector3(1.15,0.18,1.15),Color("5e615c"))
	_textured_box(house,Vector3(0,1.65,3.54),Vector3(1.9,3.27,0.15),"wood.png",Vector3(2,3,1))
	_decor_box(house,Vector3(0,3.36,3.67),Vector3(2.14,0.18,0.2),Color("f4e4c0"))
	for side in [-1,1]:
		_decor_box(house,Vector3(float(side)*1.03,1.65,3.62),Vector3(0.16,3.34,0.22),Color("f4e4c0"))
	_sphere(house,Vector3(0.65,1.68,3.72),Vector3(0.13,0.13,0.13),Color("e1b254"))
	for k in range(3):
		_textured_box(house,Vector3(0,0.15-k*0.03,3.85+k*0.53),Vector3(3+k*0.37,0.22,0.58),"stone.png",Vector3(2,1,1))
	for wx in [-2.55,2.5]:
		_window(house,Vector3(wx,2.75,3.56))
	_textured_box(house,Vector3(0,3.73,4.15),Vector3(5.5,0.16,2.1),"wood.png",Vector3(4,2,1))
	for xx in [-2.55,2.55]:
		_cylinder(house,Vector3(xx,1.85,5.1),0.13,3.7,Color("ede0bf"))
	for xx in [-3.25,3.25]:
		_textured_box(house,Vector3(xx,0.23,4.4),Vector3(0.9,0.46,0.75),"wood.png")
		_bush(house.global_position+Vector3(xx,0,4.4),0.38)
	_textured_box(house,Vector3(-6,1.7,-1.2),Vector3(3.9,3.4,5.8),"stucco.png",Vector3(2,2,1))
	var awning := _textured_box(house,Vector3(-6.1,3.65,-1),Vector3(4.3,0.26,6.25),"shingles.png",Vector3(4,4,1))
	awning.rotation_degrees.z = 11
	_textured_box(house,Vector3(-6,1.65,1.76),Vector3(3.25,2.77,0.15),"wood.png",Vector3(3,3,1))
	for t in range(5):
		_decor_box(house,Vector3(-7.45+float(t)*0.7,1.65,1.85),Vector3(0.045,2.58,0.07),Color("684936"))

func _window(parent: Node3D, where: Vector3) -> void:
	_decor_box(parent,where,Vector3(1.56,1.53,0.18),Color("f5ebd4"))
	_decor_box(parent,where+Vector3(0,0,0.13),Vector3(1.3,1.25,0.07),Color("51899a"))
	_decor_box(parent,where+Vector3(0,0,0.185),Vector3(0.09,1.27,0.08),Color("f8e8cb"))
	_decor_box(parent,where+Vector3(0,0,0.185),Vector3(1.32,0.09,0.08),Color("f8e8cb"))
	_decor_box(parent,where+Vector3(0,-0.81,0.1),Vector3(1.8,0.15,0.35),Color("eee4c9"))
	for side in [-1,1]:
		_textured_box(parent,where+Vector3(float(side)*0.98,0,0.12),Vector3(0.30,1.54,0.12),"wood.png",Vector3(1,3,1))

func _tree(where: Vector3, size_value: float, variant: int) -> void:
	var root := Node3D.new()
	root.position = where
	root.scale = Vector3.ONE * size_value
	add_child(root)
	var trunk := _cylinder(root,Vector3(0,1.63,0),0.31,3.26,Color("805840"))
	trunk.material_override = _texture_mat("wood.png",Vector3(2,3,1))
	for i in range(4):
		var a: float = float(i)*TAU/4.0 + variant*0.2
		var branch := _cylinder(root,Vector3(cos(a)*0.43,3.02,sin(a)*0.43),0.115,1.55,Color("805a42"))
		branch.rotation_degrees.z = cos(a)*43
		branch.rotation_degrees.x = -sin(a)*43
	var tone: Color = Color("4d7755") if variant%3==0 else Color("658c50")
	_sphere(root,Vector3(0,3.9,0),Vector3(2.85,2.18,2.7),tone)
	for i in range(5):
		var a: float = float(i)*TAU/5.0 + variant*0.31
		var c: Color = Color("6c9956") if i%2==0 else Color("547f4d")
		_sphere(root,Vector3(cos(a)*1.05,3.78+sin(a*2)*0.32,sin(a)*0.95),Vector3(1.78,1.65,1.75),c)
	_sphere(root,Vector3(-0.42,4.91,0.17),Vector3(1.65,1.16,1.66),Color("789c60"))

func _bush(where: Vector3, sz: float) -> void:
	var group := Node3D.new()
	group.position = where
	group.scale = Vector3.ONE * sz
	add_child(group)
	for i in range(4):
		var a: float = float(i)*TAU/4.0
		var tone: Color = Color("436d45") if i%2==0 else Color("639355")
		_sphere(group,Vector3(cos(a)*0.37,0.39+float(i%2)*0.13,sin(a)*0.32),Vector3(1.08,0.79,0.98),tone)
	_sphere(group,Vector3(0,0.78,0),Vector3(0.77,0.57,0.74),Color("76a05e"))

func _flower(where: Vector3, variant: int) -> void:
	var colors := [Color("f3cc74"),Color("db8c9f"),Color("fbefe2"),Color("dfaa77"),Color("b6a0d5")]
	var flower := Node3D.new()
	flower.position = where
	add_child(flower)
	_cylinder(flower,Vector3(0,0.24,0),0.032,0.47,Color("3b7945"))
	for i in range(5):
		var a: float = float(i)*TAU/5.0
		_sphere(flower,Vector3(cos(a)*0.18,0.53,sin(a)*0.18),Vector3(0.25,0.12,0.27),colors[variant%5])
	_sphere(flower,Vector3(0,0.53,0),Vector3(0.20,0.20,0.20),Color("79563c"))

func _grass_multimesh() -> void:
	# 650 grass cards in one MultiMesh draw call.
	var grass_mesh := QuadMesh.new()
	grass_mesh.size = Vector2(0.17,0.36)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color("72b75f")
	grass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat.vertex_color_use_as_albedo = true
	grass_mesh.material = grass_mat
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = grass_mesh
	multimesh.instance_count = 650
	for i in range(multimesh.instance_count):
		var x: float = rng.randf_range(-22,22)
		var z: float = rng.randf_range(-22,22)
		if Vector2(x+13,z+14).length() < 7:
			x = rng.randf_range(17,22)
		var angle: float = rng.randf_range(0,TAU)
		var scale_value: float = rng.randf_range(0.65,1.38)
		var basis := Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_value)
		multimesh.set_instance_transform(i,Transform3D(basis,Vector3(x,scale_value*0.14,z)))
		multimesh.set_instance_color(i,Color("4e9860") if i%3==0 else Color("83b95c"))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multimesh
	add_child(inst)

func _target(where: Vector3) -> void:
	var target := StaticBody3D.new()
	target.collision_layer = 4
	target.collision_mask = 0
	target.position = where
	target.set_meta("target",true)
	add_child(target)
	_cylinder(target,Vector3(0,-0.48,0),0.14,1.3,Color("765841"))
	_decor_box(target,Vector3(0,0.57,-0.19),Vector3(2.16,2.13,0.22),Color("765744"))
	for spec in [[1.02,Color("e8e2c8"),0.015],[0.78,Color("c0775b"),0.055],[0.51,Color("efd4a0"),0.095],[0.24,Color("bf6152"),0.135]]:
		var disc := _cylinder(target,Vector3(0,0.57,float(spec[2])),float(spec[0]),0.09,spec[1])
		disc.rotation_degrees.x = 90
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2,2.14,0.7)
	collision.shape = box
	collision.position.y = 0.57
	target.add_child(collision)

func _shooting_sign() -> void:
	for xx in [2.5,14.25]:
		_textured_box(self,Vector3(xx,2.6,-14.6),Vector3(0.22,5.2,0.22),"wood.png",Vector3(1,4,1))
	_textured_box(self,Vector3(8.35,4.64,-14.6),Vector3(12,0.95,0.22),"wood.png",Vector3(6,1,1))
	var sign := Label3D.new()
	sign.text = "GARDEN RANGE"
	sign.font_size = 88
	sign.pixel_size = 0.006
	sign.modulate = Color("efe6c0")
	sign.position = Vector3(8.35,4.49,-14.43)
	add_child(sign)

func _barrel(where: Vector3) -> void:
	var root := Node3D.new()
	root.position = where
	add_child(root)
	_cylinder(root,Vector3(0,0.55,0),0.42,1.1,Color("68818a"))
	for yy in [0.14,0.85]:
		_cylinder(root,Vector3(0,yy,0),0.438,0.11,Color("434e53"))
	_cylinder(root,Vector3(0,1.12,0),0.42,0.12,Color("778e90"))

func _bench(where: Vector3) -> void:
	var root := Node3D.new()
	root.position = where
	add_child(root)
	for xx in [-1,1]:
		_decor_box(root,Vector3(float(xx)*1.05,0.57,0),Vector3(0.15,1.1,0.64),Color("5d625b"))
		_decor_box(root,Vector3(float(xx)*1.05,1.17,-0.4),Vector3(0.15,1.4,0.18),Color("5d625b"))
	for j in range(3):
		_textured_box(root,Vector3(0,1.13,-0.23+j*0.27),Vector3(2.55,0.13,0.24),"wood.png",Vector3(3,1,1))
		_textured_box(root,Vector3(0,1.65+j*0.3,-0.58),Vector3(2.55,0.24,0.15),"wood.png",Vector3(3,1,1))

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PeaHero"
	player.collision_layer = 2
	player.collision_mask = 1
	player.position = Vector3(0,0.55,8)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.48
	player.add_child(collision)
	plant = Node3D.new()
	plant.position.y = -0.4
	player.add_child(plant)
	var imported: Node3D = MODEL_LOADER.instance_model("peashooter")
	if imported != null:
		plant.add_child(imported)
		pea_anim = PEA_ANIM.new()
		player.add_child(pea_anim)
		pea_anim.configure(imported, player)
	else:
		_cylinder(plant,Vector3(0,0.7,0),0.18,1.1,Color("478640"))
		_sphere(plant,Vector3(0,1.55,0),Vector3(1.4,1.37,1.25),Color("78b557"))
	shot_audio = AudioStreamPlayer3D.new()
	shot_audio.stream = load("res://assets/audio/pea_shot.wav")
	shot_audio.unit_size = 4.0
	shot_audio.volume_db = -5.0
	player.add_child(shot_audio)

func set_playing(value: bool) -> void:
	active = value
	joy = Vector2.ZERO
	firing = false

func change_look(delta: Vector2) -> void:
	if not active:
		return
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity,-0.50,0.32)

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
	if pea_anim != null:
		pea_anim.recoil()
	var aim_end: Vector3 = camera.global_position - camera.global_transform.basis.z * 75.0
	var aim_ray := PhysicsRayQueryParameters3D.create(camera.global_position,aim_end,5)
	var aimed_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(aim_ray)
	if not aimed_hit.is_empty():
		aim_end = aimed_hit["position"]
	var start: Vector3 = player.global_position + Vector3(0,1.08,0) + Basis(Vector3.UP,yaw)*Vector3(0,0,-0.95)
	var direction: Vector3 = (aim_end-start).normalized()
	var pea := Node3D.new()
	pea.position = start
	add_child(pea)
	_sphere(pea,Vector3.ZERO,Vector3(0.27,0.27,0.27),Color("a1df57"))
	shots.append({"node":pea,"dir":direction,"ttl":2.1})
	if shot_audio != null:
		shot_audio.play()

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
				_target_wobble(collider as Node3D)
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

func _target_wobble(target: Node3D) -> void:
	var tween := create_tween()
	tween.tween_property(target,"rotation_degrees:z",-8.0,0.07)
	tween.tween_property(target,"rotation_degrees:z",7.0,0.09)
	tween.tween_property(target,"rotation_degrees:z",0.0,0.14)

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
	for i in range(7):
		var a: float = float(i)*TAU/7.0
		var sparkle := _sphere(puff,Vector3(cos(a)*0.27,sin(a)*0.27,0),Vector3(0.17,0.17,0.17),Color("f0db76") if i%2==0 else Color("f5f6cf"))
		var sparkle_tween := create_tween()
		sparkle_tween.tween_property(sparkle,"position",sparkle.position*2.5,0.24)
	var tween := create_tween()
	tween.tween_property(puff,"scale",Vector3.ZERO,0.27)
	tween.tween_callback(puff.queue_free)
	var hit_audio := AudioStreamPlayer3D.new()
	hit_audio.stream = load("res://assets/audio/target_hit.wav")
	hit_audio.position = world_position
	hit_audio.volume_db = -5.0
	add_child(hit_audio)
	hit_audio.finished.connect(hit_audio.queue_free)
	hit_audio.play()
