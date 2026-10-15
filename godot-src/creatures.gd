extends Node3D
# Criaturas de Vaca Muerta: aparición, IA, daño, muerte.
const SPDAT := {
	"Naloma": {"hp": 75, "spd": 5.6, "dmg": 4, "reach": 1.3, "atk": 0.3, "cd": 0.55, "r": 0.3, "kind": "condor"},
	"Acequiero": {"hp": 420, "spd": 1.7, "dmg": 18, "reach": 1.3, "atk": 0.6, "cd": 1.6, "r": 0.42, "kind": "human", "scale": 1.35},
	"Imitador": {"hp": 190, "spd": 5.2, "dmg": 16, "reach": 1.1, "atk": 0.4, "cd": 1.1, "r": 0.3, "kind": "human"},
	"Nica": {"hp": 240, "spd": 4.2, "dmg": 20, "reach": 1.4, "atk": 0.45, "cd": 1.4, "r": 0.4, "kind": "gorilla"},
	"Nara": {"hp": 300, "spd": 3.8, "dmg": 10, "reach": 1.4, "atk": 0.5, "cd": 1.5, "r": 0.45, "kind": "boar"},
	"Polvillo": {"hp": 220, "spd": 1.3, "dmg": 7, "reach": 1.1, "atk": 0.5, "cd": 1.2, "r": 0.34, "kind": "human", "scale": 1.1},
	"Nakru": {"hp": 260, "spd": 1.3, "dmg": 22, "reach": 2.2, "atk": 0.5, "cd": 1.3, "r": 0.5, "kind": "worm"},
	"Hinchado": {"hp": 2600, "spd": 4.3, "dmg": 32, "reach": 1.9, "atk": 0.75, "cd": 1.7, "r": 0.55, "kind": "human", "scale": 1.9}}
const SPLIST := ["Naloma", "Imitador", "Nica", "Polvillo", "Nakru", "Nara", "Acequiero"]
const NUZ := ["Paciente", "Enfermero", "Vecino", "Obrero", "Mujer"]
var main: Node3D
var zs: Array = []
var sp_cd := 40.0
var spawn_t := 2.0
var horde_t := 90.0
var max_common := 22
var rng := RandomNumberGenerator.new()
var alerts: Array = []   # [x,z,r,t]

func _ready() -> void:
	main = get_parent(); rng.randomize()

func alive_count() -> int:
	var n := 0
	for z in zs: if z.state != "dead": n += 1
	return n

# ---------------------------------------------------------------- aparición
func free_spot(x: float, z: float) -> bool:
	if not GS.walkable(x, z): return false
	for r in GS.extras.get("refuges", []):
		if Vector2(x - r["x"], z - r["z"]).length() < 48.0: return false
	return true

func spawn(sp: String = "", near := true, at := Vector2.ZERO) -> Dictionary:
	var P: Node3D = main.player
	var pos := at
	if at == Vector2.ZERO:
		for k in 30:
			var a := rng.randf() * TAU; var d := rng.randf_range(28.0, 70.0) if near else rng.randf_range(60.0, 140.0)
			var x := P.position.x + cos(a) * d; var zz := P.position.z + sin(a) * d
			if not free_spot(x, zz): continue
			# no a la vista
			var f = P.fwd()
			if Vector2(f.x, f.z).normalized().dot(Vector2(x - P.position.x, zz - P.position.z).normalized()) > 0.5 and GS.los(P.position.x, P.position.z, x, zz, 1.2): continue
			pos = Vector2(x, zz); break
		if pos == Vector2.ZERO: return {}
	var z := {"x": pos.x, "z": pos.y, "y": 0.0, "yaw": rng.randf() * TAU, "state": "idle", "t": rng.randf() * 10.0, "atk": 0.0, "cd": 0.0, "dead": 0.0, "stag": 0.0, "sp": sp, "fy": 0.0, "detour": 0.0, "dang": 0.0, "alert": 0.0, "fire": 0.0, "tgt": null, "id": zs.size()}
	var kind := "human"; var opts := {"rs": rng.randi_range(0, 2), "creature": true}
	if sp != "":
		var d: Dictionary = SPDAT[sp]
		z["hp"] = d["hp"]; z["spd"] = d["spd"]; z["dmg"] = d["dmg"]; z["reach"] = d["reach"]; z["r"] = d["r"]
		kind = d["kind"]; opts["scale"] = d.get("scale", 1.0)
		if sp == "Imitador": opts["creature"] = false
		if sp == "Hinchado": opts["shirt"] = Color(0.3, 0.1, 0.1)
		if sp == "Polvillo": opts["shirt"] = Color(0.5, 0.45, 0.35)
		if sp == "Nakru": z["nk"] = {"st": "under", "t": rng.randf_range(2.0, 5.0), "em": 0.0}
		if sp == "Naloma": z["fy"] = 3.5
	else:
		z["hp"] = 42.0 + rng.randf() * 20.0; z["spd"] = 3.3 + rng.randf() * 1.3; z["dmg"] = 9.0; z["reach"] = 1.1; z["r"] = 0.3
	var rig := Chars.make(kind, opts)
	rig.position = Vector3(pos.x, 0, pos.y); add_child(rig)
	z["rig"] = rig; z["kind"] = kind; z["h"] = rig.get_meta("height")
	zs.append(z)
	return z

func spawn_special(sp: String) -> void:
	var z := spawn(sp, true)
	if z.is_empty(): return
	if sp == "Nakru": GS.msg("El suelo tiembla...", 2.5)

# ---------------------------------------------------------------- daño
# devuelve el impacto más cercano {z, t, head}
func ray_hit(o: Vector3, d: Vector3, max_t: float) -> Dictionary:
	var best := {"t": max_t, "z": null, "head": false}
	for z in zs:
		if z.state == "dead": continue
		if z.sp == "Nakru" and z.nk.st == "under": continue
		var cx: float = z.x; var cz: float = z.z
		var y0: float = z.y + z.fy; var y1: float = y0 + z.h
		var r: float = z.r * (1.2 if z.kind != "human" else 1.0)
		# cilindro: resolver en XZ
		var ox := o.x - cx; var oz := o.z - cz
		var a := d.x * d.x + d.z * d.z; var b := 2.0 * (ox * d.x + oz * d.z); var c := ox * ox + oz * oz - r * r
		var disc := b * b - 4.0 * a * c
		if a < 1e-6 or disc < 0.0: continue
		var t := (-b - sqrt(disc)) / (2.0 * a)
		if t < 0.0: t = 0.0
		if t > best.t: continue
		var yy := o.y + d.y * t
		if yy < y0 or yy > y1:
			# probar la entrada por arriba/abajo
			var hit := false
			for ty in [y0, y1]:
				if absf(d.y) < 1e-5: continue
				var tt = (ty - o.y) / d.y
				if tt < 0.0 or tt > best.t: continue
				var px = o.x + d.x * tt - cx; var pz = o.z + d.z * tt - cz
				if px * px + pz * pz <= r * r: t = tt; yy = ty; hit = true; break
			if not hit: continue
		best.t = t; best.z = z; best.head = (yy > y0 + z.h * 0.8) and z.kind == "human"
	return best

func damage(z: Dictionary, dmg: float, head: bool, kb: float, from: Vector3, by_player := true) -> void:
	if z.state == "dead": return
	if head: dmg *= 3.0
	z.hp -= dmg
	z.stag = maxf(z.stag, 0.15 + (0.3 if head else 0.0))
	if z.state == "idle": z.state = "chase"; z.alert = 1.0
	if kb > 0.0:
		var d := Vector2(z.x - from.x, z.z - from.z).normalized() * kb
		var c := GS.collide(Vector2(z.x + d.x, z.z + d.y), z.r, z.y, 0.75)
		z.x = c.x; z.z = c.y
	main.spawn_blood(Vector3(z.x, z.y + z.fy + z.h * (0.85 if head else 0.5), z.z))
	if z.hp <= 0.0: kill(z, by_player)

func kill(z: Dictionary, by_player: bool) -> void:
	z.state = "dead"; z.dead = 0.001
	if by_player:
		GS.kills += 1; GS.chapas += 8 if z.sp != "" else 1
	main.sfx("die", Vector3(z.x, 1, z.z))
	if z.sp == "Nara": nara_burst(z)
	if z.sp == "Hinchado": GS.msg("¡Cayó el Hinchado!", 4.0)

func nara_burst(z: Dictionary) -> void:
	main.add_gas(Vector2(z.x, z.z), 3.2, 7.0)
	main.spawn_burst(Vector3(z.x, 0.8, z.z), Color(1.0, 0.65, 0.2), 40)
	var P: Node3D = main.player
	if Vector2(P.position.x - z.x, P.position.z - z.z).length() < 4.0: P.take_damage(18.0, Vector3(z.x, 0, z.z)); P.poison = maxf(P.poison, 3.0)

func noise(p: Vector3, r: float) -> void:
	alerts.append([p.x, p.z, r, 0.5])

# ---------------------------------------------------------------- IA
func targets() -> Array:
	var P: Node3D = main.player
	var out := [[P.position.x, P.position.z, "player", null]]
	for c in main.companions.list:
		if c.hp > 0: out.append([c.x, c.z, "comp", c])
	return out

func _process(dt: float) -> void:
	if main.paused: return
	var P: Node3D = main.player
	# director
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = 1.6
		var n := 0
		for z in zs: if z.state != "dead" and z.sp == "": n += 1
		if n < max_common: spawn("", true)
	sp_cd -= dt
	if sp_cd <= 0.0:
		var ns := 0
		for z in zs: if z.sp != "" and z.sp != "Hinchado" and z.state != "dead": ns += 1
		if ns < 2: spawn_special(SPLIST[rng.randi_range(0, SPLIST.size() - 1)])
		sp_cd = 55.0 + rng.randf() * 35.0
	horde_t -= dt
	if horde_t <= 0.0:
		horde_t = 150.0 + rng.randf() * 90.0
		GS.msg("Se viene una horda...", 3.0); main.sfx("horde", P.position)
		for i in 14: spawn("", true)
	for i in range(alerts.size() - 1, -1, -1):
		alerts[i][3] -= dt
		if alerts[i][3] <= 0.0: alerts.remove_at(i)
	var tg := targets()
	for i in range(zs.size() - 1, -1, -1):
		var z: Dictionary = zs[i]
		z.t += dt
		if z.state == "dead":
			z.dead += dt
			if z.dead > 14.0 or (z.dead > 3.0 and Vector2(z.x - P.position.x, z.z - P.position.z).length() > 120.0):
				z.rig.queue_free(); zs.remove_at(i); continue
			pose(z, 0.0); continue
		# despawn lejos
		var dP := Vector2(z.x - P.position.x, z.z - P.position.z).length()
		if dP > 170.0 and z.sp == "":
			z.rig.queue_free(); zs.remove_at(i); continue
		# fuego
		if z.fire > 0.0:
			z.fire -= dt; z.hp -= 9.0 * dt
			if z.hp <= 0.0: kill(z, true); continue
		if main.in_fire(z.x, z.z) and z.fire <= 0.0: z.fire = 4.0
		# objetivo
		var best = null; var bd := 1e9
		for t in tg:
			var d := Vector2(t[0] - z.x, t[1] - z.z).length()
			if d < bd: bd = d; best = t
		z.tgt = best
		var dx: float = best[0] - z.x; var dz: float = best[1] - z.z; var d := bd
		# percepción
		if z.state == "idle":
			var see := d < 26.0 and GS.los(z.x, z.z, best[0], best[1], 1.3) and (d < 9.0 or absf(angle_difference(z.yaw, atan2(-dx, -dz))) < 1.3)
			var heard := false
			for a in alerts:
				if Vector2(a[0] - z.x, a[1] - z.z).length() < a[2]: heard = true
			if see or heard: z.state = "chase"; z.alert = 1.0
			else:
				# deambular
				if rng.randf() < dt * 0.3: z.dang = rng.randf() * TAU; z.detour = 2.0
				if z.detour > 0.0:
					z.detour -= dt; step(z, cos(z.dang), sin(z.dang), z.spd * 0.3, dt)
					z.yaw = lerp_angle(z.yaw, atan2(-cos(z.dang), -sin(z.dang)), dt * 3.0)
				pose(z, 0.3 if z.detour > 0.0 else 0.0); continue
		z.cd = maxf(0.0, z.cd - dt); z.stag = maxf(0.0, z.stag - dt)
		if z.sp != "" and special_ai(z, dt, d, dx, dz): continue
		if z.atk > 0.0:
			z.atk += dt / (SPDAT[z.sp]["atk"] if z.sp != "" else 0.45)
			if z.atk >= 0.5 and not z.get("hitdone", false):
				z.hitdone = true
				if d < z.reach + 0.5: hit_target(z, best, z.dmg)
			if z.atk >= 1.0: z.atk = 0.0; z.hitdone = false; z.cd = SPDAT[z.sp]["cd"] if z.sp != "" else 1.1
			pose(z, 0.0); continue
		var want_yaw := atan2(-dx, -dz)
		z.yaw = lerp_angle(z.yaw, want_yaw, dt * 6.0)
		if d <= z.reach:
			if z.cd <= 0.0: z.atk = 0.001; z.hitdone = false
			pose(z, 0.0); continue
		if z.stag > 0.0: pose(z, 0.0); continue
		# avanzar con desvío si choca
		var mvx := dx / d; var mvz := dz / d
		if z.detour > 0.0:
			z.detour -= dt; mvx = cos(z.dang); mvz = sin(z.dang)
		var moved := step(z, mvx, mvz, z.spd, dt)
		if not moved and z.detour <= 0.0:
			z.dang = atan2(mvz, mvx) + (PI / 2 if rng.randf() < 0.5 else -PI / 2); z.detour = 0.5 + rng.randf() * 0.5
		pose(z, 1.0)

func step(z: Dictionary, mvx: float, mvz: float, spd: float, dt: float) -> bool:
	var nx: float = z.x + mvx * spd * dt; var nz: float = z.z + mvz * spd * dt
	var c := GS.collide(Vector2(nx, nz), z.r, z.y, 0.75)
	var moved := Vector2(c.x - z.x, c.y - z.z).length() > spd * dt * 0.3
	z.x = c.x; z.z = c.y
	z.y = GS.ground_h(z.x, z.z, z.y, 0.75)
	return moved

func hit_target(z: Dictionary, t: Array, dmg: float) -> void:
	if t[2] == "player": main.player.take_damage(dmg, Vector3(z.x, 0, z.z))
	else: main.companions.hurt(t[3], dmg)

func pose(z: Dictionary, mv: float) -> void:
	var rig: Node3D = z.rig
	var P: Node3D = main.player
	var d2 := Vector2(z.x - P.position.x, z.z - P.position.z).length()
	rig.position = Vector3(z.x, z.y + z.fy, z.z); rig.rotation.y = z.yaw
	rig.visible = d2 < 140.0
	if d2 > 85.0: return
	var st := {"t": z.t, "move": mv, "run": z.spd > 3.0, "atk": z.atk, "dead": z.dead, "creature": z.sp != "Imitador" or z.get("revealed", false)}
	match z.kind:
		"boar": st["infl"] = z.get("infl", 0.0)
		"gorilla": st["crouch"] = z.get("crouch", 0.0); st["air"] = 1.0 if z.get("jump", false) else 0.0
		"condor": st["fly"] = z.fy > 0.5
		"worm": st["em"] = z.nk.em
	Chars.pose(rig, st)

# ---------------------------------------------------------------- especiales (devuelve true si ya manejó el frame)
func special_ai(z: Dictionary, dt: float, d: float, dx: float, dz: float) -> bool:
	var P: Node3D = main.player
	match z.sp:
		"Naloma":
			# vuela en círculos y escupe ácido; baja a picar
			z.yaw = lerp_angle(z.yaw, atan2(-dx, -dz), dt * 4.0)
			if d > 7.0:
				z.fy = lerpf(z.fy, 3.8, dt)
				var ang = z.t * 0.9
				var tx: float = z.tgt[0] + cos(ang) * 6.0; var tz: float = z.tgt[1] + sin(ang) * 6.0
				var v := Vector2(tx - z.x, tz - z.z); if v.length() > 0.1: v = v.normalized()
				z.x += v.x * z.spd * dt; z.z += v.y * z.spd * dt
				if z.cd <= 0.0 and d < 18.0 and GS.los(z.x, z.z, z.tgt[0], z.tgt[1], 2.0):
					z.cd = 2.4 + rng.randf() * 1.6
					main.throw_item("Acido", Vector3(z.x, z.y + z.fy + 0.8, z.z), (Vector3(z.tgt[0], 1.2, z.tgt[1]) - Vector3(z.x, z.y + z.fy + 0.8, z.z)).normalized() * 14.0 + Vector3(0, 2.0, 0))
			else:
				z.fy = lerpf(z.fy, 1.2, dt * 2.0)
				if d > z.reach: step(z, dx / d, dz / d, z.spd, dt)
				elif z.cd <= 0.0 and z.atk <= 0.0: z.atk = 0.001; z.hitdone = false
				if z.atk > 0.0:
					z.atk += dt / 0.3
					if z.atk >= 0.5 and not z.hitdone:
						z.hitdone = true
						if d < z.reach + 0.6: hit_target(z, z.tgt, z.dmg)
					if z.atk >= 1.0: z.atk = 0.0; z.cd = 0.55
			pose(z, 1.0); return true
		"Nica":
			if z.get("jump", false):
				z.jt += dt
				var k: float = minf(1.0, z.jt / 1.15)
				z.x = lerpf(z.jx0, z.jx1, k); z.z = lerpf(z.jz0, z.jz1, k); z.fy = sin(k * PI) * 4.0
				if k >= 1.0:
					z.jump = false; z.fy = 0.0; z.cd = 5.0 + rng.randf() * 3.0
					main.spawn_burst(Vector3(z.x, 0.2, z.z), Color(0.5, 0.45, 0.4), 30); main.sfx("thud", Vector3(z.x, 0, z.z))
					var dp := Vector2(P.position.x - z.x, P.position.z - z.z).length()
					if dp < 4.8: P.take_damage(24.0, Vector3(z.x, 0, z.z))
				pose(z, 0.0); return true
			if z.get("crouch", 0.0) > 0.0:
				z.crouch += dt * 2.0
				if z.crouch >= 1.0:
					z.crouch = 0.0; z.jump = true; z.jt = 0.0; z.jx0 = z.x; z.jz0 = z.z
					var tx: float = z.tgt[0] - dx / d * 1.2; var tz: float = z.tgt[1] - dz / d * 1.2
					if not GS.walkable(tx, tz): tx = z.x + dx * 0.5; tz = z.z + dz * 0.5
					z.jx1 = tx; z.jz1 = tz
				pose(z, 0.0); return true
			if z.cd <= 0.0 and d > 5.0 and d < 16.0 and GS.los(z.x, z.z, z.tgt[0], z.tgt[1], 1.0):
				z.crouch = 0.01; z.yaw = atan2(-dx, -dz); pose(z, 0.0); return true
			return false
		"Nara":
			if z.get("infl", 0.0) > 0.0:
				z.infl += dt / 1.3
				if z.infl >= 1.0:
					nara_burst(z); z.hp = 0.0; kill(z, false)
				pose(z, 0.0); return true
			if d < 4.5 and z.cd <= 0.0:
				z.infl = 0.01; main.sfx("hiss", Vector3(z.x, 0, z.z)); pose(z, 0.0); return true
			return false
		"Nakru":
			var nk: Dictionary = z.nk
			nk.t -= dt
			match nk.st:
				"under":
					nk.em = maxf(0.0, nk.em - dt * 1.5)
					# se mueve rápido bajo tierra hacia el objetivo
					if d > 2.5: step(z, dx / d, dz / d, 5.5, dt)
					if nk.t <= 0.0 and d < 4.0:
						nk.st = "up"; nk.t = 7.0 + rng.randf() * 3.0
						main.spawn_burst(Vector3(z.x, 0.2, z.z), Color(0.45, 0.4, 0.35), 40); main.sfx("rumble", Vector3(z.x, 0, z.z))
					pose(z, 0.0); return true
				"up":
					nk.em = minf(1.0, nk.em + dt * 1.2)
					z.yaw = lerp_angle(z.yaw, atan2(-dx, -dz), dt * 4.0)
					if nk.em >= 1.0:
						if z.atk > 0.0:
							z.atk += dt / 0.5
							if z.atk >= 0.5 and not z.hitdone:
								z.hitdone = true
								if d < z.reach + 0.6: hit_target(z, z.tgt, z.dmg)
							if z.atk >= 1.0: z.atk = 0.0; z.cd = 1.3
						elif d < z.reach and z.cd <= 0.0: z.atk = 0.001; z.hitdone = false
					if nk.t <= 0.0 or d > 9.0:
						nk.st = "under"; nk.t = 3.0 + rng.randf() * 3.0; z.atk = 0.0
					pose(z, 0.0); return true
			return false
		"Imitador":
			if d < 7.0 and not z.get("revealed", false):
				z.revealed = true; GS.msg("¡Es un Imitador!", 2.0)
			if not z.get("revealed", false) and z.cd <= 0.0 and d < 32.0:
				z.cd = 9.0 + rng.randf() * 6.0
				GS.msg("Alguien grita: «¡Ayuda! ¡Por acá!»" if rng.randf() < 0.5 else "Una voz: «¡No me dejen solo, por favor!»", 3.0)
			return false
		"Polvillo":
			if rng.randf() < dt * 1.5: main.add_gas(Vector2(z.x, z.z), 1.6, 2.5)
			return false
	return false
