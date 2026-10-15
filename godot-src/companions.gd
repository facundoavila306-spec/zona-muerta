extends Node3D
# Compañeros: Alma, Aurelio y Maxi. Siguen al jugador y disparan a las criaturas.
var main: Node3D
var list: Array = []
const DEFS := [
	{"n": "Alma", "rs": 0, "shirt": Color(0.75, 0.25, 0.35), "pants": Color(0.2, 0.2, 0.28), "hair": Color(0.25, 0.14, 0.08), "dmg": 30.0, "rate": 0.5, "range": 22.0, "gun": "pistola"},
	{"n": "Aurelio", "rs": 1, "shirt": Color(0.3, 0.42, 0.3), "pants": Color(0.3, 0.26, 0.2), "hair": Color(0.5, 0.5, 0.5), "dmg": 55.0, "rate": 0.9, "range": 16.0, "gun": "escopeta"},
	{"n": "Maxi", "rs": 2, "shirt": Color(0.25, 0.35, 0.6), "pants": Color(0.12, 0.12, 0.14), "hair": Color(0.1, 0.08, 0.06), "dmg": 34.0, "rate": 0.16, "range": 26.0, "gun": "fusil"}]

func _ready() -> void:
	main = get_parent()

func setup(x: float, z: float) -> void:
	for c in list: c.rig.queue_free()
	list.clear()
	for i in DEFS.size():
		var d: Dictionary = DEFS[i]
		var rig := Chars.human({"rs": d["rs"], "shirt": d["shirt"], "pants": d["pants"], "hair": d["hair"]})
		# arma en la mano derecha
		var hand := Chars.j(rig, "handR")
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.04, 0.22 if d["gun"] == "pistola" else 0.7); mi.mesh = bm
		mi.material_override = Chars.mat(Color(0.12, 0.12, 0.13), 0.45, 0.0, 0.4); mi.position = Vector3(0, 0, -0.1 if d["gun"] == "pistola" else -0.25)
		mi.rotation.x = -PI / 2; hand.add_child(mi)
		add_child(rig)
		var a := TAU * i / 3.0
		list.append({"n": d["n"], "x": x + cos(a) * 1.6, "z": z + sin(a) * 1.6, "y": 0.0, "yaw": 0.0, "hp": 100.0, "rig": rig, "t": randf() * 5.0, "cd": randf(), "shoot": 0.0, "down": 0.0, "def": d, "mv": 0.0, "detour": 0.0, "dang": 0.0, "aim": false})

func hurt(c: Dictionary, d: float) -> void:
	if c.hp <= 0.0: return
	c.hp -= d
	main.spawn_blood(Vector3(c.x, 1.2, c.z))
	if c.hp <= 0.0:
		c.hp = 0.0; c.down = 0.001; GS.msg(c.n + " cayó. Acercate y apretá E para levantarla." if c.n == "Alma" else c.n + " cayó. Acercate y apretá E para levantarlo.", 4.0)

func try_revive(px: float, pz: float) -> bool:
	for c in list:
		if c.hp <= 0.0 and Vector2(c.x - px, c.z - pz).length() < 2.2:
			c.hp = 45.0; c.down = 0.0; GS.msg(c.n + " está de pie otra vez.", 2.5); return true
	return false

func _process(dt: float) -> void:
	if main.paused: return
	var P: Node3D = main.player
	var cr: Node3D = main.creatures
	for i in list.size():
		var c: Dictionary = list[i]
		c.t += dt
		if c.hp <= 0.0:
			c.down += dt
			if c.down > 45.0: c.hp = 40.0; c.down = 0.0; GS.msg(c.n + " se levantó.", 2.0)
			Chars.pose(c.rig, {"t": c.t, "move": 0.0, "dead": minf(1.0, c.down)})
			c.rig.position = Vector3(c.x, c.y, c.z); c.rig.rotation.y = c.yaw
			continue
		c.hp = minf(100.0, c.hp + dt * 0.8)
		# objetivo de tiro
		var tz = null; var td = c.def["range"]
		for z in cr.zs:
			if z.state == "dead": continue
			if z.sp == "Nakru" and z.nk.st == "under": continue
			if z.sp == "Imitador" and not z.get("revealed", false): continue
			var d := Vector2(z.x - c.x, z.z - c.z).length()
			if d < td and GS.los(c.x, c.z, z.x, z.z, 1.3): td = d; tz = z
		c.cd -= dt; c.shoot = maxf(0.0, c.shoot - dt * 6.0)
		c.aim = tz != null
		if tz != null:
			c.yaw = lerp_angle(c.yaw, atan2(-(tz.x - c.x), -(tz.z - c.z)), dt * 8.0)
			if c.cd <= 0.0:
				c.cd = c.def["rate"]; c.shoot = 1.0
				main.sfx("shot_comp", Vector3(c.x, 1.4, c.z)); main.muzzle_at(Vector3(c.x - sin(c.yaw) * 0.6, 1.4, c.z - cos(c.yaw) * 0.6))
				if randf() < 0.8: cr.damage(tz, c.def["dmg"], randf() < 0.15, 0.0, Vector3(c.x, 0, c.z), false)
		# seguir al jugador
		var slot = TAU * i / 3.0 + P.yaw + PI
		var gx := P.position.x + cos(slot) * 2.2; var gz := P.position.z + sin(slot) * 2.2
		if not GS.walkable(gx, gz): gx = P.position.x; gz = P.position.z
		var dx = gx - c.x; var dz = gz - c.z; var d := Vector2(dx, dz).length()
		var dP := Vector2(P.position.x - c.x, P.position.z - c.z).length()
		var mv := 0.0
		if dP > 60.0:
			# teletransporte si quedó muy atrás
			c.x = P.position.x + sin(P.yaw) * 1.5; c.z = P.position.z + cos(P.yaw) * 1.5
		elif d > 1.2 and (tz == null or dP > 6.0):
			var spd := 5.2 if dP < 8.0 else 8.0
			var mvx = dx / d; var mvz = dz / d
			if c.detour > 0.0: c.detour -= dt; mvx = cos(c.dang); mvz = sin(c.dang)
			var nx: float = c.x + mvx * spd * dt; var nz: float = c.z + mvz * spd * dt
			var cc := GS.collide(Vector2(nx, nz), 0.28, c.y, 0.75)
			var moved := Vector2(cc.x - c.x, cc.y - c.z).length() > spd * dt * 0.3
			c.x = cc.x; c.z = cc.y; mv = 1.0
			if not moved and c.detour <= 0.0: c.dang = atan2(mvz, mvx) + (PI / 2 if randf() < 0.5 else -PI / 2); c.detour = 0.5
			if tz == null: c.yaw = lerp_angle(c.yaw, atan2(-mvx, -mvz), dt * 6.0)
		elif tz == null:
			c.yaw = lerp_angle(c.yaw, P.yaw, dt * 2.0)
		c.y = GS.ground_h(c.x, c.z, c.y, 0.75)
		c.mv = lerpf(c.mv, mv, dt * 8.0)
		c.rig.position = Vector3(c.x, c.y, c.z); c.rig.rotation.y = c.yaw
		if dP < 90.0:
			Chars.pose(c.rig, {"t": c.t, "move": c.mv, "run": dP > 8.0, "aim": c.aim, "shoot": c.shoot})
