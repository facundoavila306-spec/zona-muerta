extends SceneTree
const CH := 64.0
var mats_def: Dictionary
var mat_cache := {}
func mat_for(n: String) -> StandardMaterial3D:
	if mat_cache.has(n): return mat_cache[n]
	var e: Dictionary = mats_def.get(n, {"tint":[.6,.6,.6],"sz":[1,1],"png":null,"emis":0})
	var m := StandardMaterial3D.new()
	var t: Array = e["tint"]
	m.albedo_color = Color(t[0], t[1], t[2])
	m.roughness = 0.82
	m.vertex_color_use_as_albedo = true
	if e.get("png") != null:
		m.albedo_texture = load("res://data/" + e["png"])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if e.get("st", 0) == 1 or e.get("alpha", 0) == 1:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
	if float(e.get("emis", 0)) > 0:
		m.emission_enabled = true
		m.emission = Color(t[0], t[1], t[2])
		m.emission_energy_multiplier = float(e["emis"])
	if n == "win":
		m.roughness = 0.15; m.metallic = 0.4; m.albedo_color = Color(0.18, 0.22, 0.3)
	if n == "steel" or n == "blk":
		m.roughness = 0.5; m.metallic = 0.6 if n == "steel" else 0.1
	var safe := n.replace(":", "_").replace("@", "AT").replace(" ", "_").replace(".", "_")
	for ch in ["Á","É","Í","Ó","Ú","Ñ","À"]: safe = safe.replace(ch, "X")
	var path := "res://mat/%s.tres" % safe
	ResourceSaver.save(m, path)
	mat_cache[n] = load(path)
	return mat_cache[n]

var chunks := {}   # Vector2i -> {matname -> {v,n,uv,i}}
func surf(key: Vector2i, mn: String) -> Dictionary:
	if not chunks.has(key): chunks[key] = {}
	var c: Dictionary = chunks[key]
	if not c.has(mn):
		c[mn] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	return c[mn]

func quad(key: Vector2i, mn: String, p: Array, nrm: Vector3, uv: Array) -> void:
	var s := surf(key, mn)
	var order := [0, 1, 2, 3]
	var cr: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if cr.dot(nrm) > 0.0: order = [0, 3, 2, 1]
	var base: int = s["v"].size()
	for k in order:
		var q: Vector3 = p[k]
		var ao := 1.0
		if nrm.y < 0.5: ao = clampf(0.55 + q.y * 0.3, 0.55, 1.0)
		if nrm.y < -0.5: ao = 0.5
		s["v"].push_back(q); s["n"].push_back(nrm); s["uv"].push_back(uv[k]); s["c"].push_back(Color(ao, ao, ao))
	s["i"].append_array(PackedInt32Array([base, base+1, base+2, base, base+2, base+3]))

func face(key: Vector2i, mn: String, f: String, b: Array, st: bool, sz: Array) -> void:
	var x0: float = b[0]; var y0: float = b[1]; var z0: float = b[2]
	var x1: float = b[3]; var y1: float = b[4]; var z1: float = b[5]
	var dx := maxf(x1 - x0, 1e-4); var dy := maxf(y1 - y0, 1e-4); var dz := maxf(z1 - z0, 1e-4)
	var p: Array; var n: Vector3
	match f:
		"t": p = [Vector3(x0,y1,z0), Vector3(x1,y1,z0), Vector3(x1,y1,z1), Vector3(x0,y1,z1)]; n = Vector3(0,1,0)
		"b": p = [Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x1,y0,z1), Vector3(x0,y0,z1)]; n = Vector3(0,-1,0)
		"n": p = [Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x1,y1,z0), Vector3(x0,y1,z0)]; n = Vector3(0,0,-1)
		"s": p = [Vector3(x0,y0,z1), Vector3(x1,y0,z1), Vector3(x1,y1,z1), Vector3(x0,y1,z1)]; n = Vector3(0,0,1)
		"w": p = [Vector3(x0,y0,z0), Vector3(x0,y0,z1), Vector3(x0,y1,z1), Vector3(x0,y1,z0)]; n = Vector3(-1,0,0)
		_:   p = [Vector3(x1,y0,z0), Vector3(x1,y0,z1), Vector3(x1,y1,z1), Vector3(x1,y1,z0)]; n = Vector3(1,0,0)
	var uv: Array = []
	for q in p:
		var u: float; var v: float
		if st:
			match f:
				"t", "b": u = (q.x - x0) / dx; v = (q.z - z0) / dz
				"n": u = (x1 - q.x) / dx; v = (y1 - q.y) / dy
				"s": u = (q.x - x0) / dx; v = (y1 - q.y) / dy
				"w": u = (q.z - z0) / dz; v = (y1 - q.y) / dy
				_:   u = (z1 - q.z) / dz; v = (y1 - q.y) / dy
		else:
			var sx: float = sz[0]; var sy: float = sz[1]
			match f:
				"t", "b": u = q.x / sx; v = q.z / sy
				"n", "s": u = q.x / sx; v = -q.y / sy
				_:        u = q.z / sx; v = -q.y / sy
		uv.append(Vector2(u, v))
	quad(key, mn, p, n, uv)

func mname(m, k: String) -> String:
	if m is String: return m
	return m.get(k, m["a"])

func _init() -> void:
	mats_def = JSON.parse_string(FileAccess.get_file_as_string("res://data/mats.json"))
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/mapa.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://city"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mat"))
	var dm: Array = d["mats"]
	var t0 := Time.get_ticks_msec()
	var nb := 0
	for b in d["boxes"]:
		var m = dm[int(b[6])]
		var dx: float = b[3] - b[0]; var dy: float = b[4] - b[1]; var dz: float = b[5] - b[2]
		var key := Vector2i(int((b[0] + b[3]) * 0.5 / CH), int((b[2] + b[5]) * 0.5 / CH))
		if dx < 0.0: var s0: float = b[0]; b[0] = b[3]; b[3] = s0; dx = -dx
		if dy < 0.0: var t1: float = b[1]; b[1] = b[4]; b[4] = t1; dy = -dy
		if dz < 0.0: var t2: float = b[2]; b[2] = b[5]; b[5] = t2; dz = -dz
		var mn := minf(dx, minf(dy, dz))
		var faces: Array
		if mn < 0.12:
			if dx == mn: faces = ["w", "e"]
			elif dy == mn: faces = ["t", "b"]
			else: faces = ["n", "s"]
		else:
			faces = ["t", "n", "s", "w", "e"]
			if b[1] > 0.05: faces.append("b")
		for f in faces:
			var name := mname(m, f)
			var e: Dictionary = mats_def.get(name, {"sz":[1,1]})
			face(key, name, f, b, e.get("st", 0) == 1, e.get("sz", [1,1]))
		nb += 1
	for f in d["floors"]:
		var key := Vector2i(int((f[0] + f[2]) * 0.5 / CH), int((f[1] + f[3]) * 0.5 / CH))
		var name: String = f[4]
		var e: Dictionary = mats_def.get(name, {"sz":[1,1]})
		face(key, name, "t", [f[0], f[5], f[1], f[2], f[5], f[3]], false, e.get("sz", [1,1]))
	print("caras generadas: ", nb, " cajas; ", Time.get_ticks_msec() - t0, " ms; chunks ", chunks.size())
	var index := []
	var verts := 0
	for key in chunks:
		var mesh := ArrayMesh.new()
		var mesh_aabb := AABB()
		for mn in chunks[key]:
			var s: Dictionary = chunks[key][mn]
			var arr := []; arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = s["v"]; arr[Mesh.ARRAY_NORMAL] = s["n"]; arr[Mesh.ARRAY_TEX_UV] = s["uv"]; arr[Mesh.ARRAY_COLOR] = s["c"]; arr[Mesh.ARRAY_INDEX] = s["i"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat_for(mn))
			verts += s["v"].size()
		var path := "res://city/c_%d_%d.res" % [key.x, key.y]
		ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		mesh_aabb = mesh.get_aabb()
		index.append([key.x, key.y, path, mesh_aabb.position.x, mesh_aabb.position.y, mesh_aabb.position.z, mesh_aabb.size.x, mesh_aabb.size.y, mesh_aabb.size.z])
	var f := FileAccess.open("res://city/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index))
	f.close()
	# extras (luces, fuegos, cuerpos, etc.)
	var ex := {"lamps": d["lamps"], "fires": d["fires"], "corpses": d["corpses"], "picks": d["picks"], "shops": d["shops"], "lm": d["lm"], "signs": d["signs"], "refuges": d.get("refuges", []), "wells": d.get("wells", []), "spots": d.get("spots", [])}
	var f2 := FileAccess.open("res://data/extras.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(ex))
	f2.close()
	print("listo: ", chunks.size(), " chunks, ", verts, " vertices, ", Time.get_ticks_msec() - t0, " ms")
	quit()
