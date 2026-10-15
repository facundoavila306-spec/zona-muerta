extends Node3D
# Jugador en primera persona: movimiento, cámara, linterna, armas.
const WDAT := {
	"Pistola": {"k": "gun", "mag": 15, "res": -1, "dmg": 34, "rate": 0.13, "auto": false, "spread": 0.012, "rl": 1.9, "hx": 2.2, "noise": 26, "rec": 0.02, "pellets": 1, "kb": 0.0},
	"Revolver": {"k": "gun", "mag": 6, "res": 30, "dmg": 95, "rate": 0.38, "auto": false, "spread": 0.008, "rl": 3.2, "hx": 2.5, "noise": 32, "rec": 0.05, "pellets": 1, "kb": 0.3},
	"Bombeo": {"k": "gun", "mag": 6, "res": 30, "dmg": 20, "rate": 0.72, "auto": false, "spread": 0.1, "rl": 3.0, "hx": 1.6, "noise": 40, "rec": 0.07, "pellets": 12, "kb": 1.4},
	"Recortada": {"k": "gun", "mag": 2, "res": 20, "dmg": 20, "rate": 0.28, "auto": false, "spread": 0.15, "rl": 2.6, "hx": 1.5, "noise": 42, "rec": 0.09, "pellets": 14, "kb": 1.8},
	"Fusil": {"k": "gun", "mag": 20, "res": 120, "dmg": 34, "rate": 0.0909, "auto": true, "spread": 0.012, "rl": 2.9, "hx": 3.0, "noise": 34, "rec": 0.025, "pellets": 1, "kb": 0.1},
	"Rifle": {"k": "gun", "mag": 5, "res": 30, "dmg": 190, "rate": 1.0, "auto": false, "spread": 0.003, "rl": 3.4, "hx": 3.0, "noise": 38, "rec": 0.08, "pellets": 1, "kb": 0.6},
	"Stillson": {"k": "melee", "dmg": 75, "rate": 0.27, "reach": 3.2, "arc": 1.75},
	"Cano": {"k": "melee", "dmg": 58, "rate": 0.21, "reach": 3.4, "arc": 1.8},
	"Hacha": {"k": "melee", "dmg": 140, "rate": 0.32, "reach": 3.1, "arc": 1.7},
	"Molotov": {"k": "throw", "n": 4, "rate": 1.2},
	"Bengala": {"k": "throw", "n": 3, "rate": 1.0}}
const WORDER := ["Pistola", "Revolver", "Bombeo", "Recortada", "Fusil", "Rifle", "Stillson", "Cano", "Hacha", "Molotov", "Bengala"]
const WNAME := {"Pistola": "Pistola 9 mm", "Revolver": "Revólver .38", "Bombeo": "Escopeta de bombeo", "Recortada": "Recortada", "Fusil": "FAL", "Rifle": "Rifle con mira", "Stillson": "Llave Stillson", "Cano": "Caño", "Hacha": "Hacha", "Molotov": "Molotov", "Bengala": "Bengala"}

var main: Node3D
var cam: Camera3D
var head: Node3D
var flash: SpotLight3D
var muzzle: OmniLight3D
var vm: Node3D            # view model holder
var vm_models := {}
var yaw := 0.0
var pitch := 0.0
var py := 0.0
var vy := 0.0
var gnd := true
var vel := Vector2.ZERO
var stam := 1.0
var tired := false
var crouch := 0.0
var bob_t := 0.0
var moving := 0.0
var fl_on := true
var hurt := 0.0
var poison := 0.0
var cur := "Fusil"
var WS := {}               # estado por arma {mag,res}
var fire_cd := 0.0
var reload_t := 0.0
var kick := 0.0
var swing := 0.0
var shove_t := 0.0
var sens := 0.0022
var captured := false
var dead_t := -1.0
const EYE := 1.62
const R := 0.3

func _ready() -> void:
	main = get_parent()
	head = Node3D.new(); add_child(head)
	cam = Camera3D.new(); cam.fov = 74.0; cam.near = 0.05; cam.far = 420.0; head.add_child(cam)
	flash = SpotLight3D.new()
	flash.light_energy = 3.2; flash.light_specular = 0.3; flash.spot_range = 55.0; flash.spot_angle = 36.0; flash.spot_angle_attenuation = 0.8; flash.light_cull_mask = 1
	flash.light_color = Color(1.0, 0.95, 0.85); flash.shadow_enabled = true; flash.shadow_bias = 0.03
	flash.position = Vector3(0.15, -0.1, 1.1); cam.add_child(flash)
	muzzle = OmniLight3D.new(); muzzle.omni_range = 9.0; muzzle.light_energy = 0.0; muzzle.light_color = Color(1, 0.7, 0.35); muzzle.light_cull_mask = 1
	muzzle.position = Vector3(0.2, -0.15, -0.8); cam.add_child(muzzle)
	vm = Node3D.new(); cam.add_child(vm)
	var vl := OmniLight3D.new(); vl.light_cull_mask = 2; vl.light_energy = 0.9; vl.omni_range = 2.0; vl.position = Vector3(-0.2, 0.3, 0.2); vl.light_color = Color(0.9, 0.9, 1.0); cam.add_child(vl)
	for n in WORDER:
		var d: Dictionary = WDAT[n]
		if d["k"] == "gun": WS[n] = {"mag": d["mag"], "res": d["res"]}
		elif d["k"] == "throw": WS[n] = {"mag": 0, "res": d["n"]}
		else: WS[n] = {"mag": 0, "res": 0}
		var m := build_vm(n); m.visible = false; vm.add_child(m); vm_models[n] = m
		for c in find_meshes(m): c.layers = 2; c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	select(cur)

func spawn_at(x: float, z: float, y0: float, yw: float) -> void:
	position = Vector3(x, y0, z); py = y0; yaw = yw; pitch = 0.0

# ---- modelos en primera persona (sencillos, oscuros)
func box(p: Node3D, size: Vector3, pos: Vector3, c: Color, metal := 0.3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = Chars.mat(c, 0.45, 0.0, metal); mi.position = pos; p.add_child(mi); return mi

func build_vm(n: String) -> Node3D:
	var r := Node3D.new(); r.name = n
	var gun := Color(0.12, 0.12, 0.13); var wood := Color(0.3, 0.18, 0.1); var skin := Color(0.82, 0.62, 0.48)
	var d: Dictionary = WDAT[n]
	match d["k"]:
		"gun":
			var L: float = {"Pistola": 0.2, "Revolver": 0.22, "Bombeo": 0.7, "Recortada": 0.45, "Fusil": 0.8, "Rifle": 0.9}[n]
			box(r, Vector3(0.035, 0.05, L), Vector3(0, 0.02, -L * 0.5), gun)
			box(r, Vector3(0.05, 0.08, 0.14), Vector3(0, -0.02, -0.02), gun)             # recámara
			box(r, Vector3(0.03, 0.1, 0.04), Vector3(0, -0.09, 0.02), wood if n != "Pistola" else gun)  # empuñadura
			if L > 0.4:
				box(r, Vector3(0.05, 0.06, 0.25), Vector3(0, -0.03, -L * 0.55), wood if n != "Fusil" else gun)  # guardamano
				box(r, Vector3(0.045, 0.1, 0.22), Vector3(0, -0.06, 0.16), wood if n != "Fusil" else gun)  # culata
			if n == "Rifle": box(r, Vector3(0.03, 0.03, 0.18), Vector3(0, 0.07, -0.25), gun)
			if n == "Fusil": box(r, Vector3(0.03, 0.14, 0.05), Vector3(0, -0.12, -0.12), gun)
			box(r, Vector3(0.02, 0.012, 0.01), Vector3(0, 0.05, -L + 0.02), gun)  # mira
			# mano
			var hand := Node3D.new(); hand.position = Vector3(0.0, -0.1, 0.03); r.add_child(hand)
			Chars.sphere(hand, 0.045, skin)
		"melee":
			var L: float = {"Stillson": 0.45, "Cano": 0.7, "Hacha": 0.6}[n]
			box(r, Vector3(0.03, 0.03, L), Vector3(0, 0, -L * 0.5), Color(0.5, 0.5, 0.52) if n != "Hacha" else wood, 0.6)
			if n == "Stillson": box(r, Vector3(0.05, 0.08, 0.1), Vector3(0, 0.03, -L + 0.05), Color(0.7, 0.3, 0.1))
			if n == "Hacha": box(r, Vector3(0.012, 0.16, 0.14), Vector3(0, 0.05, -L + 0.07), Color(0.6, 0.6, 0.62), 0.7)
			Chars.sphere(r, 0.045, skin, Vector3(0, 0, -0.05))
		"throw":
			if n == "Molotov":
				box(r, Vector3(0.06, 0.16, 0.06), Vector3.ZERO, Color(0.3, 0.5, 0.3))
				box(r, Vector3(0.02, 0.08, 0.02), Vector3(0, 0.1, 0), Color(0.9, 0.85, 0.7))
			else:
				box(r, Vector3(0.03, 0.22, 0.03), Vector3.ZERO, Color(0.75, 0.15, 0.1))
			Chars.sphere(r, 0.045, skin, Vector3(0, -0.1, 0))
	return r

func find_meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out.append_array(find_meshes(c))
	return out

func select(n: String) -> void:
	if not WDAT.has(n): return
	if vm_models.has(cur): vm_models[cur].visible = false
	cur = n; vm_models[n].visible = true; reload_t = 0.0; kick = 0.0; swing = 0.0
	main.hud.flash_weapon(WNAME[n])

func _input(e: InputEvent) -> void:
	if not captured: return
	if e is InputEventMouseMotion:
		yaw -= e.relative.x * sens; pitch = clampf(pitch - e.relative.y * sens, -1.45, 1.45)
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: cycle(1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP: cycle(-1)
		elif e.button_index == MOUSE_BUTTON_RIGHT: shove()
	if e is InputEventKey and e.pressed and not e.echo:
		var ks := {KEY_1: "Pistola", KEY_2: "Revolver", KEY_3: "Bombeo", KEY_4: "Recortada", KEY_5: "Fusil", KEY_6: "Rifle", KEY_7: "Stillson", KEY_8: "Cano", KEY_9: "Hacha", KEY_0: "Molotov", KEY_G: "Bengala"}
		if ks.has(e.keycode): select(ks[e.keycode])
		elif e.keycode == KEY_R: start_reload()
		elif e.keycode == KEY_F:
			fl_on = not fl_on; flash.visible = fl_on
		elif e.keycode == KEY_E:
			main.interact(); get_viewport().set_input_as_handled()
		elif e.keycode == KEY_M: main.hud.toggle_map()

func cycle(d: int) -> void:
	var i := WORDER.find(cur)
	for k in WORDER.size():
		i = posmod(i + d, WORDER.size())
		var n: String = WORDER[i]
		var s: Dictionary = WS[n]
		if WDAT[n]["k"] == "melee" or s["mag"] > 0 or s["res"] != 0: select(n); return

func fwd() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

func eye() -> Vector3:
	return position + Vector3(0, EYE - crouch * 0.55, 0)

func _process(dt: float) -> void:
	if dead_t >= 0.0:
		dead_t += dt; pitch = lerpf(pitch, -0.6, dt * 2.0); py = lerpf(py, 0.0, dt)
		update_cam(); return
	# movimiento
	var ix := 0.0; var iz := 0.0
	if captured:
		if Input.is_key_pressed(KEY_W): iz -= 1.0
		if Input.is_key_pressed(KEY_S): iz += 1.0
		if Input.is_key_pressed(KEY_A): ix -= 1.0
		if Input.is_key_pressed(KEY_D): ix += 1.0
	var l := Vector2(ix, iz).length()
	var sprint := captured and Input.is_key_pressed(KEY_SHIFT) and l > 0 and not tired and iz < 0
	var cr_in := captured and Input.is_key_pressed(KEY_CTRL)
	crouch = move_toward(crouch, 1.0 if cr_in else 0.0, dt * 6.0)
	if sprint:
		stam = maxf(0.0, stam - dt * 0.22)
		if stam <= 0.0: tired = true
	else:
		stam = minf(1.0, stam + dt * (0.1 if tired else 0.16))
		if stam > 0.35: tired = false
	var sp := (9.2 if sprint else 5.4) * (0.55 if crouch > 0.5 else 1.0) * (0.75 if tired else 1.0) * (0.8 if poison > 0 else 1.0)
	var mx := 0.0; var mz := 0.0
	if l > 0:
		ix /= l; iz /= l
		var fx := -sin(yaw); var fz := -cos(yaw)
		mx = fx * -iz + fz * ix; mz = fz * -iz - fx * ix
	var tv := Vector2(mx, mz) * sp
	vel = vel.lerp(tv, 1.0 - exp(-dt * (12.0 if gnd else 2.5)))
	moving = lerpf(moving, l, dt * 8.0)
	var nx := position.x + vel.x * dt; var nz := position.z + vel.y * dt
	var c := GS.collide(Vector2(nx, nz), R, py, 0.75)
	# saltar a bordes bajos automáticamente al avanzar
	if gnd and l > 0:
		var h := GS.cell_h(floori((position.x + mx * 0.6) / GS.CS), floori((position.z + mz * 0.6) / GS.CS))
		if h > py + 0.04 and h <= 0.75 and h < 50.0:
			vy = maxf(vy, sqrt(2.0 * 11.0 * (h - py + 0.2))); gnd = false
	position.x = c.x; position.z = c.y
	vy -= 11.0 * dt
	if captured and Input.is_key_pressed(KEY_SPACE) and gnd: vy = 4.6; gnd = false
	py += vy * dt
	var gh := GS.ground_h(position.x, position.z, py, 0.75)
	if py <= gh:
		py = gh; vy = 0.0; gnd = true
	position.y = py
	bob_t += dt * (12.0 if sprint else 8.0) * moving
	# venenos / heridas
	if poison > 0.0:
		poison -= dt; GS.hp -= 3.2 * dt
		if GS.hp <= 0.0: die()
	hurt = maxf(0.0, hurt - dt * 1.4)
	# armas
	fire_cd = maxf(0.0, fire_cd - dt); kick = lerpf(kick, 0.0, dt * 9.0); swing = maxf(0.0, swing - dt * 4.0); shove_t = maxf(0.0, shove_t - dt * 5.0)
	muzzle.light_energy = lerpf(muzzle.light_energy, 0.0, dt * 25.0)
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0: finish_reload()
	var d: Dictionary = WDAT[cur]
	if captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cd <= 0.0 and reload_t <= 0.0:
		if d["k"] == "melee" or d.get("auto", false) or not _held:
			attack()
		_held = true
	else:
		_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	update_cam()
var _held := false

func update_cam() -> void:
	head.position = Vector3(0, EYE - crouch * 0.55 + sin(bob_t) * 0.025 * moving, 0)
	head.rotation = Vector3(pitch + kick * 0.6, yaw, sin(bob_t * 0.5) * 0.008 * moving)
	var d: Dictionary = WDAT[cur]
	var base := Vector3(0.2, -0.18, -0.42)
	if d["k"] == "melee": base = Vector3(0.22, -0.22, -0.35)
	var sw := sin(bob_t * 0.5) * 0.012 * moving
	var off := Vector3(sw, absf(cos(bob_t * 0.5)) * 0.01 * moving, kick * 0.9)
	vm.position = base + off
	vm.rotation = Vector3(kick * 2.0 - swing * 1.4, 0.0 + swing * 0.6, swing * 0.5)
	if reload_t > 0.0:
		vm.position.y -= 0.12; vm.rotation.x -= 0.6
	if shove_t > 0.0: vm.position.z -= shove_t * 0.25

# ---- disparos
func start_reload() -> void:
	var d: Dictionary = WDAT[cur]
	if d["k"] != "gun" or reload_t > 0.0: return
	var s: Dictionary = WS[cur]
	if s["mag"] >= d["mag"] or s["res"] == 0: return
	reload_t = d["rl"]; main.sfx("reload", eye())

func finish_reload() -> void:
	var d: Dictionary = WDAT[cur]; var s: Dictionary = WS[cur]
	var need: int = d["mag"] - s["mag"]
	if s["res"] < 0: s["mag"] = d["mag"]
	else:
		var take: int = mini(need, s["res"]); s["mag"] += take; s["res"] -= take

func attack() -> void:
	var d: Dictionary = WDAT[cur]; var s: Dictionary = WS[cur]
	fire_cd = d["rate"]
	var o := eye(); var f := fwd()
	match d["k"]:
		"gun":
			if s["mag"] <= 0:
				start_reload(); fire_cd = 0.25; return
			s["mag"] -= 1
			kick = d["rec"] * 4.0; muzzle.light_energy = 3.5
			main.sfx("shot_" + cur, o); main.noise(o, d["noise"])
			for i in int(d["pellets"]):
				var sp: float = d["spread"] * (1.0 + crouch * -0.3 + moving * 0.8)
				var dir := (f + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * sp * 2.0).normalized()
				main.hitscan(o, dir, d["dmg"], d["hx"], d["kb"], true)
			if s["mag"] <= 0: start_reload()
		"melee":
			swing = 1.0; main.sfx("swing", o)
			main.melee(o, f, d["reach"], d["arc"], d["dmg"], true)
		"throw":
			if s["res"] <= 0: return
			s["res"] -= 1; swing = 0.8
			main.throw_item(cur, o + f * 0.4, f * 13.0 + Vector3(0, 3.5, 0) + Vector3(vel.x, 0, vel.y) * 0.5)
			if s["res"] <= 0: cycle(-1)

func shove() -> void:
	if shove_t > 0.0 or dead_t >= 0.0: return
	shove_t = 1.0; main.sfx("swing", eye())
	main.melee(eye(), fwd(), 2.2, 1.6, 4.0, false, 3.5)

func take_damage(d: float, from: Vector3) -> void:
	if dead_t >= 0.0: return
	GS.hp -= d; hurt = minf(1.0, hurt + 0.35 + d * 0.01)
	main.sfx("hurt", eye())
	if GS.hp <= 0.0: die()

func die() -> void:
	if dead_t >= 0.0: return
	GS.hp = 0.0; dead_t = 0.0; main.on_player_dead()

func give(n: String, q: int) -> void:
	var s: Dictionary = WS[n]
	if WDAT[n]["k"] == "gun":
		if s["res"] >= 0: s["res"] = mini(WDAT[n]["res"] * 2, s["res"] + q)
	else: s["res"] = mini(8, s["res"] + q)
