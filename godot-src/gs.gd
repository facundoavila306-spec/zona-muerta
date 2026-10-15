extends Node
# Estado global: grilla de colisión, jugador, chapas, guardado.
var W := 0
var H := 0
var CS := 0.75
var G := PackedByteArray()
var GH := PackedByteArray()
var meta: Dictionary
var extras: Dictionary
var mats_def: Dictionary
var hp := 100.0
var chapas := 0
var kills := 0
var msg_cb: Callable
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var f := FileAccess.open("res://data/grid.bin", FileAccess.READ)
	W = f.get_32(); H = f.get_32(); CS = f.get_float(); f.get_float()
	G = f.get_buffer(W * H); GH = f.get_buffer(W * H)
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta.json"))
	extras = JSON.parse_string(FileAccess.get_file_as_string("res://data/extras.json"))
	mats_def = JSON.parse_string(FileAccess.get_file_as_string("res://data/mats.json"))

func gh_at(i: int) -> float:
	var v := GH[i]
	return 99.0 if v == 255 else v / 100.0

func cell_solid(cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= W or cy >= H: return true
	return G[cy * W + cx] == 1

func cell_h(cx: int, cy: int) -> float:
	if cx < 0 or cy < 0 or cx >= W or cy >= H: return 99.0
	var i := cy * W + cx
	return gh_at(i) if G[i] == 1 else 0.0

func walkable(x: float, z: float) -> bool:
	return not cell_solid(floori(x / CS), floori(z / CS))

# Colisión circular contra la grilla; py = altura del que camina (puede subir bordes <= step)
func collide(pos: Vector2, r: float, py: float, step: float) -> Vector2:
	var x := pos.x; var z := pos.y
	for it in 3:
		var x0 := floori((x - r) / CS); var x1 := floori((x + r) / CS)
		var y0 := floori((z - r) / CS); var y1 := floori((z + r) / CS)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				if cx < 0 or cy < 0 or cx >= W or cy >= H: continue
				var i := cy * W + cx
				if G[i] != 1: continue
				var h := gh_at(i)
				if h <= step and py >= h - 0.06: continue
				var nx := clampf(x, cx * CS, cx * CS + CS); var nz := clampf(z, cy * CS, cy * CS + CS)
				var dx := x - nx; var dz := z - nz
				var d2 := dx * dx + dz * dz
				if d2 < r * r:
					if d2 > 1e-8:
						var d := sqrt(d2); var p := r - d
						x += dx / d * p; z += dz / d * p
					else:
						var l := x - cx * CS; var rr := cx * CS + CS - x; var t := z - cy * CS; var b := cy * CS + CS - z
						var m := minf(minf(l, rr), minf(t, b))
						if m == l: x = cx * CS - r
						elif m == rr: x = cx * CS + CS + r
						elif m == t: z = cy * CS - r
						else: z = cy * CS + CS + r
	return Vector2(x, z)

func ground_h(x: float, z: float, py: float, step: float) -> float:
	var cx := floori(x / CS); var cy := floori(z / CS)
	if cx < 0 or cy < 0 or cx >= W or cy >= H: return 0.0
	var i := cy * W + cx
	if G[i] == 1:
		var h := gh_at(i)
		if h <= step and py >= h - 0.06: return h
	return 0.0

func cast_ray(o: Vector3, d: Vector3, max_t: float) -> Dictionary:
	var t := 0.0
	var lcx := floori(o.x / CS); var lcy := floori(o.z / CS)
	while t < max_t:
		t += 0.06
		var p := o + d * t
		if p.y < 0.0: return {"t": t, "p": p, "n": Vector3.UP, "hit": true}
		if p.y > 40.0: break
		var cx := floori(p.x / CS); var cy := floori(p.z / CS)
		var sol := false
		if cx < 0 or cy < 0 or cx >= W or cy >= H: sol = true
		else:
			var i := cy * W + cx
			if G[i] == 1:
				sol = p.y <= gh_at(i) + 0.03
		if sol:
			var n := Vector3.ZERO
			var ddx := cx - lcx; var ddy := cy - lcy
			if ddx != 0 and ddy == 0: n.x = -sign(ddx)
			elif ddy != 0 and ddx == 0: n.z = -sign(ddy)
			elif absf(d.x) > absf(d.z): n.x = -sign(d.x)
			else: n.z = -sign(d.z)
			return {"t": t, "p": p, "n": n, "hit": true}
		lcx = cx; lcy = cy
	return {"t": max_t, "p": o + d * max_t, "n": Vector3.UP, "hit": false}

func los(ax: float, az: float, bx: float, bz: float, y: float) -> bool:
	var d := Vector3(bx - ax, 0, bz - az); var l := d.length()
	if l < 0.01: return true
	return not cast_ray(Vector3(ax, y, az), d / l, l).hit

func msg(t: String, secs: float = 3.0) -> void:
	if msg_cb.is_valid(): msg_cb.call(t, secs)

func save_game(p: Dictionary) -> void:
	var f := FileAccess.open("user://partida.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(p)); f.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists("user://partida.json"): return {}
	var r = JSON.parse_string(FileAccess.get_file_as_string("user://partida.json"))
	return r if r is Dictionary else {}
