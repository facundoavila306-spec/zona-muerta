extends Node3D
# Refugios (NPCs, guardias, comercio, literas) y misiones (mesa de pedidos).
var main: Node3D
var refs: Array = []
var guards: Array = []
var npcs: Array = []
const TRADE := [
	{"n": "Munición para todas las armas", "p": 30},
	{"n": "Botiquín: vida completa", "p": 20},
	{"n": "Molotov x2", "p": 25},
	{"n": "Bengala x2", "p": 10}]
const MDEFS := [
	{"who": "Alma", "item": "Insulina", "text": "En la farmacia de Avenida Argentina y Alderete tiene que quedar insulina. Entrá por el frente y buscala en el mostrador.", "spot": "farmacia", "name": "Farmacia · Av. Argentina y Alderete"},
	{"who": "Maxi", "item": "Handy", "text": "En la Comisaría Nº 1, sobre Córdoba, queda un handy en la guardia. Con eso escuchamos al resto de la ciudad.", "spot": "comisaria", "name": "Comisaría Nº 1 · Córdoba"},
	{"who": "Aurelio", "item": "Bidón de nafta", "text": "En el Carrefour, al sur, quedaron bidones al fondo. Es lejos, pero con uno arranco la camioneta.", "lm": "carrefour", "name": "Carrefour"},
	{"who": "Alma", "item": "Antibióticos", "text": "En el hall del Castro Rendón hay antibióticos. Entrá por la guardia, sobre Alderete.", "lm": "hospital", "name": "Hospital Castro Rendón"},
	{"who": "Maxi", "item": "Batería", "text": "En la ferretería de Carlos H. Rodríguez, cerca de Brown, hay una batería de auto. La necesito para la radio.", "spot": "ferA", "name": "Ferretería · Brown y Rodríguez"},
	{"who": "Aurelio", "item": "Llaves", "text": "Las llaves de la camioneta quedaron en una casa vieja sobre La Rioja y San Martín. Revisá el local de la esquina.", "spot": "casaB", "name": "Casa vieja · La Rioja y San Martín"},
	{"who": "Alma", "item": "Leche en polvo", "text": "Para los chicos del refugio. Hay un supermercado La Anónima sobre Brown, cerca de Rivadavia.", "spot": "anonima", "name": "La Anónima · Brown"},
	{"who": "Maxi", "item": "Garrafa", "text": "En una ferretería de Córdoba y Rivadavia hay garrafas. Traeme una llena.", "spot": "ferC", "name": "Ferretería · Córdoba y Rivadavia"},
	{"who": "Aurelio", "item": "Bandera", "text": "Última: la bandera del monumento a San Martín, en la rotonda de la avenida. La colgamos en el refugio.", "lm": "monumento", "name": "Monumento a San Martín"}]
var missions: Array = []   # {d, state: "pend"/"active"/"got"/"done", pick: Vector2, node}
var mi := -1
var mdone := 0
var item_node: Node3D
var item_t := 0.0

func _ready() -> void:
	main = get_parent()

func setup() -> void:
	refs = GS.extras.get("refuges", [])
	var spots: Dictionary = {}
	for s in GS.extras.get("spots", []): spots[s[0]] = s[1]
	for r in refs:
		for n in r["npcs"]:
			var rs: int = n.get("rs", 0)
			var opts := {"rs": rs}
			var nm: String = n["n"]
			if nm == "H_Militar": opts["shirt"] = Color(0.3, 0.36, 0.22); opts["pants"] = Color(0.28, 0.32, 0.2); opts["helmet"] = true
			elif nm == "H_Policia": opts["shirt"] = Color(0.15, 0.2, 0.4); opts["pants"] = Color(0.1, 0.12, 0.2)
			elif nm == "H_Mujer": opts["hair"] = Color(0.35, 0.2, 0.1)
			elif nm == "H_Pibe": opts["scale"] = 0.78
			var rig := Chars.human(opts)
			rig.position = Vector3(n["x"], n.get("y", r["y"]), n["z"]); rig.rotation.y = n["yaw"]
			add_child(rig)
			var e := {"rig": rig, "x": n["x"], "z": n["z"], "y": n.get("y", r["y"]), "yaw": n["yaw"], "role": n["role"], "t": randf() * 7.0, "cd": randf(), "shoot": 0.0, "ref": r}
			npcs.append(e)
			if n["role"] == "guardia":
				guards.append(e)
				var hand := Chars.j(rig, "handR")
				var mi2 := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.04, 0.7); mi2.mesh = bm
				mi2.material_override = Chars.mat(Color(0.12, 0.12, 0.13), 0.45, 0.0, 0.4); mi2.position = Vector3(0, 0, -0.25); mi2.rotation.x = -PI / 2; hand.add_child(mi2)
	# misiones disponibles según lugares del mapa
	for d in MDEFS:
		var p = null
		if d.has("spot") and spots.has(d["spot"]): p = Vector2(spots[d["spot"]][0], spots[d["spot"]][1])
		elif d.has("lm") and GS.extras["lm"].has(d["lm"]):
			var l: Dictionary = GS.extras["lm"][d["lm"]]
			if l.has("spots") and l["spots"].size() > 0: p = Vector2(l["spots"][0][0], l["spots"][0][1])
			else: p = Vector2(l["x"], l["z"])
		if p != null: missions.append({"d": d, "state": "pend", "pick": p})

func near_ref(x: float, z: float) -> Dictionary:
	for r in refs:
		if absf(x - r["x"]) < 16.0 and absf(z - r["z"]) < 20.0: return r
	return {}

func dist2(a: Array, x: float, z: float) -> float:
	return Vector2(a[0] - x, a[1] - z).length()

# texto de ayuda al mirar algo
func hint(px: float, pz: float) -> String:
	var r := near_ref(px, pz)
	if r.is_empty(): return ""
	if dist2(r["trader"], px, pz) < 2.2: return "E · Comerciar con " + r["tname"]
	if dist2(r["table"], px, pz) < 2.2:
		if mi >= 0 and missions[mi].state == "got": return "E · Entregar " + missions[mi].d["item"]
		return "E · Mesa de pedidos"
	if dist2(r["bunk"], px, pz) < 2.2: return "E · Dormir (guarda la partida y curás)"
	return ""

func interact(px: float, pz: float) -> bool:
	var r := near_ref(px, pz)
	if r.is_empty(): return false
	if dist2(r["trader"], px, pz) < 2.2: main.hud.open_card("trade", r); return true
	if dist2(r["table"], px, pz) < 2.2:
		if mi >= 0 and missions[mi].state == "got":
			missions[mi].state = "done"; mdone += 1; GS.chapas += 50; GS.msg("Entregaste " + missions[mi].d["item"] + ". +50 chapas", 4.0); mi = -1
			main.sfx("pick", Vector3(px, 1, pz)); return true
		main.hud.open_card("missions", r); return true
	if dist2(r["bunk"], px, pz) < 2.2:
		GS.hp = 100.0; main.player.poison = 0.0; main.save_now(); main.day_time += 6.0
		GS.msg("Dormiste un rato. Partida guardada.", 3.0); main.sfx("pick", Vector3(px, 1, pz)); return true
	return false

func buy(i: int) -> String:
	var t: Dictionary = TRADE[i]
	if GS.chapas < t["p"]: return "Te faltan chapas, pibe."
	GS.chapas -= t["p"]
	var P: Node3D = main.player
	match i:
		0:
			for n in P.WORDER:
				var d: Dictionary = P.WDAT[n]
				if d["k"] == "gun" and P.WS[n]["res"] >= 0: P.WS[n]["res"] = mini(d["res"] * 2, P.WS[n]["res"] + d["mag"] * 2)
		1: GS.hp = 100.0; P.poison = 0.0
		2: P.give("Molotov", 2)
		3: P.give("Bengala", 2)
	main.sfx("pick", P.position)
	return "Hecho."

func accept(k: int) -> void:
	if mi >= 0: return
	mi = k; missions[k].state = "active"
	GS.msg(missions[k].d["who"] + ": " + missions[k].d["text"], 7.0)
	place_item(missions[k].pick)

func place_item(p: Vector2) -> void:
	if item_node: item_node.queue_free()
	item_node = Node3D.new()
	var mi2 := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5, 0.4, 0.4); mi2.mesh = bm
	mi2.material_override = Chars.mat(Color(0.9, 0.75, 0.3), 0.5, 1.4); item_node.add_child(mi2)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.8, 0.3); l.light_energy = 2.5; l.omni_range = 6.0; l.position.y = 0.6; item_node.add_child(l)
	item_node.position = Vector3(p.x, GS.ground_h(p.x, p.y, 0.0, 99.0) + 0.3, p.y)
	add_child(item_node)

func objective() -> Dictionary:
	if mi < 0: return {}
	var m: Dictionary = missions[mi]
	if m.state == "active": return {"text": m.d["item"] + " · " + m.d["name"], "pos": m.pick}
	var r: Dictionary = refs[0] if refs.size() > 0 else {}
	if r.is_empty(): return {}
	return {"text": "Llevar " + m.d["item"] + " a " + r["name"], "pos": Vector2(r["table"][0], r["table"][1])}

func _process(dt: float) -> void:
	if main.paused: return
	var P: Node3D = main.player
	item_t += dt
	if item_node and mi >= 0 and missions[mi].state == "active":
		item_node.rotation.y = item_t * 1.5; item_node.position.y = GS.ground_h(missions[mi].pick.x, missions[mi].pick.y, 0.0, 99.0) + 0.35 + sin(item_t * 2.0) * 0.1
		if Vector2(P.position.x - missions[mi].pick.x, P.position.z - missions[mi].pick.y).length() < 1.6:
			missions[mi].state = "got"; item_node.queue_free(); item_node = null
			GS.msg("Agarraste " + missions[mi].d["item"] + ". Volvé a la mesa de pedidos del refugio.", 5.0); main.sfx("pick", P.position)
	# NPCs: guardias disparan, el resto respira
	var cr: Node3D = main.creatures
	for e in npcs:
		e.t += dt
		var dP := Vector2(e.x - P.position.x, e.z - P.position.z).length()
		if dP > 90.0: continue
		var aim := false
		if e.role == "guardia":
			e.cd -= dt; e.shoot = maxf(0.0, e.shoot - dt * 6.0)
			var tz = null; var td := 32.0
			for z in cr.zs:
				if z.state == "dead" or (z.sp == "Nakru" and z.nk.st == "under"): continue
				var d := Vector2(z.x - e.x, z.z - e.z).length()
				if d < td: td = d; tz = z
			if tz != null:
				aim = true
				e.rig.rotation.y = lerp_angle(e.rig.rotation.y, atan2(-(tz.x - e.x), -(tz.z - e.z)), dt * 6.0)
				if e.cd <= 0.0:
					e.cd = 0.45; e.shoot = 1.0
					main.sfx("shot_comp", Vector3(e.x, e.y + 1.4, e.z)); main.muzzle_at(Vector3(e.x - sin(e.rig.rotation.y) * 0.7, e.y + 1.5, e.z - cos(e.rig.rotation.y) * 0.7))
					if randf() < 0.75: cr.damage(tz, 30.0, randf() < 0.1, 0.0, Vector3(e.x, 0, e.z), false)
			else: e.rig.rotation.y = lerp_angle(e.rig.rotation.y, e.yaw, dt * 2.0)
		else:
			# mira al jugador si está cerca
			if dP < 5.0: e.rig.rotation.y = lerp_angle(e.rig.rotation.y, atan2(-(P.position.x - e.x), -(P.position.z - e.z)), dt * 3.0)
			else: e.rig.rotation.y = lerp_angle(e.rig.rotation.y, e.yaw, dt * 2.0)
		Chars.pose(e.rig, {"t": e.t, "move": 0.0, "aim": aim, "shoot": e.shoot})
