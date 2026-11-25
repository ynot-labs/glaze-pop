class_name DioramaShelf
extends Node3D

## 3D Miniature Glass Cloche Showcase ("微缩玻璃罩展柜", Fig. 3)
## Displays the 6 artisan glass bell jars on warm oak shelves with brass brackets & studio plants.

var camera: Camera3D
var scn_cloche: PackedScene
var sh_glass: Shader = preload("res://shaders/cloche_glass.gdshader")

var bay_roots: Array[Node3D] = []
var keepsake_pivots: Array[Node3D] = []
var bay_lights: Array[OmniLight3D] = []
var is_open: bool = false
var selected_idx: int = 0


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	scn_cloche = load("res://assets/models/cloche_dome.glb")
	position = Vector3(0.0, 42.0, 0.0) # Isolated studio room high above main stage (instant 0ms switch!)
	_build_gallery_cabinet()


func _build_gallery_cabinet() -> void:
	var mat_wall := StandardMaterial3D.new()
	mat_wall.albedo_color = Color(0.56, 0.50, 0.44)
	mat_wall.roughness = 0.88

	var mat_oak := StandardMaterial3D.new()
	mat_oak.albedo_color = Color(0.58, 0.38, 0.21)
	mat_oak.roughness = 0.48

	var mat_brass := StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.86, 0.68, 0.28)
	mat_brass.metallic = 0.85
	mat_brass.roughness = 0.24

	var mat_glass := ShaderMaterial.new()
	mat_glass.shader = sh_glass

	# Warm gallery wall backdrop
	var wall := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(14.0, 12.0, 0.3)
	wall.mesh = w_box
	wall.position = Vector3(0.0, 1.5, -1.65)
	wall.material_override = mat_wall
	add_child(wall)

	# 3 Horizontal Oak Planks + 4 Vertical Oak Uprights (exact match to Fig. 3!)
	for sy in [-1.25, 1.35, 3.95]:
		var plank := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(8.4, 0.20, 2.35)
		plank.mesh = pb
		plank.position = Vector3(0.0, sy, -0.45)
		plank.material_override = mat_oak
		add_child(plank)

	for ux in [-3.95, -1.32, 1.32, 3.95]:
		var post := MeshInstance3D.new()
		var ub := BoxMesh.new()
		ub.size = Vector3(0.18, 5.6, 2.15)
		post.mesh = ub
		post.position = Vector3(ux, 1.35, -0.48)
		post.material_override = mat_oak
		add_child(post)

		# Brass collar accents at shelf joints
		for jy in [-1.12, 1.48, 3.82]:
			var br := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.24, 0.09, 0.26)
			br.mesh = bb
			br.position = Vector3(ux, jy, 0.52)
			br.material_override = mat_brass
			add_child(br)

	# Cute Studio Potted Succulents flanking the shelves (matching Fig. 3 side greenery!)
	var mat_pot := StandardMaterial3D.new()
	mat_pot.albedo_color = Color(0.97, 0.96, 0.94)
	mat_pot.roughness = 0.26
	var mat_leaf := StandardMaterial3D.new()
	mat_leaf.albedo_color = Color(0.28, 0.56, 0.34)
	mat_leaf.roughness = 0.38

	for side_x in [-4.65, 4.65]:
		for row_y in [-1.15, 1.45]:
			var sub_shelf := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(1.25, 0.14, 1.5)
			sub_shelf.mesh = sb
			sub_shelf.position = Vector3(side_x, row_y - 0.08, -0.5)
			sub_shelf.material_override = mat_oak
			add_child(sub_shelf)

			var pot := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.30
			pc.bottom_radius = 0.22
			pc.height = 0.44
			pot.mesh = pc
			pot.position = Vector3(side_x, row_y + 0.22, -0.45)
			pot.material_override = mat_pot
			add_child(pot)

			var foliage := MeshInstance3D.new()
			var fs := SphereMesh.new()
			fs.radius = 0.34
			fs.height = 0.58
			foliage.mesh = fs
			foliage.position = Vector3(side_x, row_y + 0.58, -0.45)
			foliage.material_override = mat_leaf
			add_child(foliage)

	# 6 Glass Cloche Bays (Row 0 = top shelf y=1.45, Row 1 = bottom shelf y=-1.15; Cols x = -2.64, 0.0, +2.64)
	var xs: Array[float] = [-2.64, 0.0, 2.64]
	var ys: Array[float] = [1.45, -1.15]

	for idx in range(6):
		@warning_ignore("integer_division")
		var r: int = idx / 3
		var c: int = idx % 3
		var bay := Node3D.new()
		bay.position = Vector3(xs[c], ys[r], -0.40)
		add_child(bay)
		bay_roots.append(bay)

		var cloche: Node3D = scn_cloche.instantiate()
		cloche.scale = Vector3(0.84, 0.84, 0.84)
		_apply_cloche_glass(cloche, mat_glass)
		bay.add_child(cloche)

		var k_pivot := Node3D.new()
		k_pivot.position = Vector3(0.0, 0.20, 0.0)
		bay.add_child(k_pivot)
		keepsake_pivots.append(k_pivot)

		var spot := OmniLight3D.new()
		spot.position = Vector3(0.0, 2.1, 0.45)
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 0.95
		spot.omni_range = 3.2
		bay.add_child(spot)
		bay_lights.append(spot)


func _apply_cloche_glass(n: Node, glass_mat: ShaderMaterial) -> void:
	if n is MeshInstance3D and n.name.contains("Glass"):
		(n as MeshInstance3D).material_override = glass_mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_apply_cloche_glass(c, glass_mat)


func refresh_collection(unlocked_ids: Dictionary, highlight_idx: int = -1) -> void:
	if highlight_idx >= 0:
		selected_idx = highlight_idx

	var mat_locked := StandardMaterial3D.new()
	mat_locked.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_locked.albedo_color = Color(0.28, 0.25, 0.22, 0.55)
	mat_locked.roughness = 0.55

	for idx in range(6):
		var k_piv: Node3D = keepsake_pivots[idx]
		for child in k_piv.get_children():
			child.queue_free()

		var info: Dictionary = SculptureCatalog.KEEPSAKES[idx]
		var is_unlocked: bool = unlocked_ids.has(String(info["id"]))
		var ps: PackedScene = load(String(info["scene_path"]))
		if ps:
			var inst: Node3D = ps.instantiate()
			inst.scale = Vector3(0.92, 0.92, 0.92)
			if not is_unlocked:
				_override_all_mats(inst, mat_locked)
			k_piv.add_child(inst)

		bay_lights[idx].light_energy = (1.65 if idx == selected_idx else 1.05) if is_unlocked else 0.25


func _override_all_mats(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_override_all_mats(c, mat)


func _process(delta: float) -> void:
	if not is_open:
		return
	for idx in range(keepsake_pivots.size()):
		var speed: float = 1.15 if idx == selected_idx else 0.45
		keepsake_pivots[idx].rotation.y += delta * speed

	if camera != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var aspect: float = vp_size.x / maxf(vp_size.y, 1.0)
		camera.fov = 34.0
		var half_tan_x: float = tan(deg_to_rad(17.0)) * aspect
		var dist: float = maxf(18.2, 5.85 / maxf(half_tan_x, 0.11))
		var target := global_position + Vector3(0.0, 1.25, -0.25)
		var desired := target + Vector3(0.0, 0.42, dist)
		camera.global_position = camera.global_position.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
		camera.look_at(target, Vector3.UP)


func get_bay_screen_pos(idx: int) -> Vector2:
	if camera == null or idx < 0 or idx >= bay_roots.size():
		return Vector2(-999, -999)
	return camera.unproject_position(bay_roots[idx].global_position + Vector3(0.0, 1.05, 0.5))
