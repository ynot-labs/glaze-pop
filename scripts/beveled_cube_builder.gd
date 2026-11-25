class_name BeveledCubeBuilder
extends RefCounted

## Procedural Standard Beveled Cube Generator (GDD 5.1: Single Mesh, <= 96 tris!)
## Produces a crisp chamfered cube (44 triangles, smooth weighted bevel normals)
## so all 3D sculptures render in 1 Draw Call via MultiMeshInstance3D at locked 60fps.

static func create_beveled_cube(half_extent: float = 0.485, bevel: float = 0.095) -> ArrayMesh:
	var a: float = half_extent
	var b: float = half_extent - bevel

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 24 corner-offset vertices (3 per octant corner -> 6 octant faces + 12 edge chamfers + 8 corner triangles)
	# Each vertex gets a subtly rounded normal (weighted toward face normal + radial bevel) for glossy plastic highlights!
	var add_quad := func(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, flat_n: Vector3, round_blend: float) -> void:
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		var nrms: Array[Vector3] = []
		for p in pts:
			nrms.append(flat_n.lerp(p.normalized(), round_blend).normalized())
		# Tri 1: 0, 1, 2
		st.set_normal(nrms[0]); st.add_vertex(pts[0])
		st.set_normal(nrms[1]); st.add_vertex(pts[1])
		st.set_normal(nrms[2]); st.add_vertex(pts[2])
		# Tri 2: 0, 2, 3
		st.set_normal(nrms[0]); st.add_vertex(pts[0])
		st.set_normal(nrms[2]); st.add_vertex(pts[2])
		st.set_normal(nrms[3]); st.add_vertex(pts[3])

	var add_tri := func(p0: Vector3, p1: Vector3, p2: Vector3) -> void:
		var fn: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		if fn.dot((p0 + p1 + p2).normalized()) < 0.0:
			var tmp: Vector3 = p1
			p1 = p2
			p2 = tmp
			fn = -fn
		for p in [p0, p1, p2]:
			st.set_normal(fn.lerp(p.normalized(), 0.45).normalized())
			st.add_vertex(p)

	# 6 Main Flat Faces (12 tris)
	# +Y top
	add_quad.call(Vector3(-b, a, -b), Vector3(b, a, -b), Vector3(b, a, b), Vector3(-b, a, b), Vector3.UP, 0.14)
	# -Y bottom
	add_quad.call(Vector3(-b, -a, b), Vector3(b, -a, b), Vector3(b, -a, -b), Vector3(-b, -a, -b), Vector3.DOWN, 0.14)
	# +Z front
	add_quad.call(Vector3(-b, b, a), Vector3(b, b, a), Vector3(b, -b, a), Vector3(-b, -b, a), Vector3.BACK, 0.14)
	# -Z back
	add_quad.call(Vector3(b, b, -a), Vector3(-b, b, -a), Vector3(-b, -b, -a), Vector3(b, -b, -a), Vector3.FORWARD, 0.14)
	# +X right
	add_quad.call(Vector3(a, b, b), Vector3(a, b, -b), Vector3(a, -b, -b), Vector3(a, -b, b), Vector3.RIGHT, 0.14)
	# -X left
	add_quad.call(Vector3(-a, b, -b), Vector3(-a, b, b), Vector3(-a, -b, b), Vector3(-a, -b, -b), Vector3.LEFT, 0.14)

	# 12 Edge Bevel Strips (24 tris)
	# Top 4 edges
	add_quad.call(Vector3(-b, a, b), Vector3(b, a, b), Vector3(b, b, a), Vector3(-b, b, a), Vector3(0, 1, 1).normalized(), 0.30)
	add_quad.call(Vector3(b, a, -b), Vector3(-b, a, -b), Vector3(-b, b, -a), Vector3(b, b, -a), Vector3(0, 1, -1).normalized(), 0.30)
	add_quad.call(Vector3(b, a, b), Vector3(b, a, -b), Vector3(a, b, -b), Vector3(a, b, b), Vector3(1, 1, 0).normalized(), 0.30)
	add_quad.call(Vector3(-b, a, -b), Vector3(-b, a, b), Vector3(-a, b, b), Vector3(-a, b, -b), Vector3(-1, 1, 0).normalized(), 0.30)

	# Bottom 4 edges
	add_quad.call(Vector3(-b, -b, a), Vector3(b, -b, a), Vector3(b, -a, b), Vector3(-b, -a, b), Vector3(0, -1, 1).normalized(), 0.30)
	add_quad.call(Vector3(b, -b, -a), Vector3(-b, -b, -a), Vector3(-b, -a, -b), Vector3(b, -a, -b), Vector3(0, -1, -1).normalized(), 0.30)
	add_quad.call(Vector3(a, -b, b), Vector3(a, -b, -b), Vector3(b, -a, -b), Vector3(b, -a, b), Vector3(1, -1, 0).normalized(), 0.30)
	add_quad.call(Vector3(-a, -b, -b), Vector3(-a, -b, b), Vector3(-b, -a, b), Vector3(-b, -a, -b), Vector3(-1, -1, 0).normalized(), 0.30)

	# 4 Vertical side edges
	add_quad.call(Vector3(b, b, a), Vector3(a, b, b), Vector3(a, -b, b), Vector3(b, -b, a), Vector3(1, 0, 1).normalized(), 0.30)
	add_quad.call(Vector3(-a, b, b), Vector3(-b, b, a), Vector3(-b, -b, a), Vector3(-a, -b, b), Vector3(-1, 0, 1).normalized(), 0.30)
	add_quad.call(Vector3(a, b, -b), Vector3(b, b, -a), Vector3(b, -b, -a), Vector3(a, -b, -b), Vector3(1, 0, -1).normalized(), 0.30)
	add_quad.call(Vector3(-b, b, -a), Vector3(-a, b, -b), Vector3(-a, -b, -b), Vector3(-b, -b, -a), Vector3(-1, 0, -1).normalized(), 0.30)

	# 8 Corner Triangular Bevels (8 tris -> Total = 12 + 24 + 8 = 44 triangles!)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px := Vector3(sx * a, sy * b, sz * b)
				var py := Vector3(sx * b, sy * a, sz * b)
				var pz := Vector3(sx * b, sy * b, sz * a)
				add_tri.call(px, py, pz)

	st.index()
	return st.commit()


static func create_core_sphere(radius: float = 0.56) -> SphereMesh:
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 20
	sph.rings = 10
	return sph
