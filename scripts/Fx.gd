class_name Fx
extends RefCounted
## 짧은 이펙트(클릭 원, 부채꼴, 순간이동 원 등)를 띄우는 도우미.
## 메시·머티리얼은 처음 한 번만 만들어 재사용한다. 이펙트마다 새로 만들면 그 프레임이 멈춘다.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _bar_texture: ImageTexture


## 불투명 단색 머티리얼. 적의 예비 동작·피격 색, 쓰러진 플레이어의 회색에 쓴다.
static func solid(color: Color) -> StandardMaterial3D:
	var key := "solid_" + color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		_materials[key] = mat
	return _materials[key]


## 반투명, 조명을 받지 않는 머티리얼. 바닥에 깔리는 이펙트용.
static func glow(color: Color) -> StandardMaterial3D:
	var key := "glow_" + color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = mat
	return _materials[key]


## 반지름 1 m 납작한 원판.
static func disc() -> Mesh:
	if not _meshes.has("disc"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 0.02
		mesh.radial_segments = 48
		mesh.rings = 1
		_meshes["disc"] = mesh
	return _meshes["disc"]


## 바깥 반지름 1 m 고리.
static func ring() -> Mesh:
	if not _meshes.has("ring"):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.8
		mesh.outer_radius = 1.0
		mesh.rings = 48
		mesh.ring_segments = 6
		_meshes["ring"] = mesh
	return _meshes["ring"]


## 반지름 1 m 구.
static func sphere() -> Mesh:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_meshes["sphere"] = mesh
	return _meshes["sphere"]


## -Z 방향을 가운데로 펼쳐진 바닥 부채꼴.
static func fan(radius: float, angle_deg: float) -> Mesh:
	var key := "fan_%.2f_%.1f" % [radius, angle_deg]
	if not _meshes.has(key):
		var segments := 16
		var half := deg_to_rad(angle_deg) * 0.5
		var verts := PackedVector3Array()
		for i in segments:
			var a0 := -half + half * 2.0 * i / segments
			var a1 := -half + half * 2.0 * (i + 1) / segments
			verts.append(Vector3.ZERO)
			verts.append(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
			verts.append(Vector3(sin(a1), 0.0, -cos(a1)) * radius)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[key] = mesh
	return _meshes[key]


## 적 체력 바 두 장이 같이 쓰는 100×10 흰색 텍스처.
static func bar_texture() -> ImageTexture:
	if _bar_texture == null:
		var image := Image.create_empty(100, 10, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(image)
	return _bar_texture


## 이펙트 하나를 띄우고 duration 동안 크기를 바꾸며 투명해지게 한 뒤 지운다.
static func spawn(mesh: Mesh, material: Material, position: Vector3, duration: float,
		start_scale: float, end_scale: float, rotation_y := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(inst)
	inst.global_position = position
	inst.rotation.y = rotation_y
	inst.scale = Vector3.ONE * start_scale
	inst.reset_physics_interpolation()
	var tween := inst.create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(inst, "scale", Vector3.ONE * end_scale, duration)
	tween.tween_property(inst, "transparency", 1.0, duration)
	tween.chain().tween_callback(inst.queue_free)


## 게임 시작 때 보이지 않는 곳에 이펙트를 한 번 그려 셰이더 컴파일 멈춤을 미리 없앤다.
static func prewarm(position: Vector3) -> void:
	var mat := glow(Color(1.0, 1.0, 1.0, 0.5))
	for mesh: Mesh in [disc(), ring(), sphere()]:
		spawn(mesh, mat, position, 0.2, 1.0, 1.0)
