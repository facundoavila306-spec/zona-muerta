extends Node
# Personajes y criaturas: mallas suaves (cápsulas/esferas) con articulaciones y poses procedurales.
class_name Chars

static var mat_cache := {}

static func mat(c: Color, rough := 0.75, emis := 0.0, metal := 0.0) -> StandardMaterial3D:
	var k := "%s_%.2f_%.2f_%.2f" % [c.to_html(), rough, emis, metal]
	if mat_cache.has(k): return mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	if emis > 0.0:
		m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emis
	mat_cache[k] = m
	return m

# ---- piezas
static func capsule(parent: Node3D, r: float, len: float, c: Color, off := Vector3.ZERO, rot := Vector3.ZERO, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = r; cm.height = maxf(len, r * 2.0); cm.radial_segments = 12; cm.rings = 4
	mi.mesh = cm; mi.material_override = mat(c, 0.75, emis)
	mi.position = off; mi.rotation = rot
	parent.add_child(mi); return mi

static func sphere(parent: Node3D, r: float, c: Color, off := Vector3.ZERO, scl := Vector3.ONE, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 14; sm.rings = 8
	mi.mesh = sm; mi.material_override = mat(c, 0.7, emis)
	mi.position = off; mi.scale = scl
	parent.add_child(mi); return mi

static func bone(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.name = nm; n.position = pos
	parent.add_child(n); return n

# Segmento que cuelga hacia -Y desde su articulación (muslo, brazo, etc.)
static func limb(j: Node3D, r: float, len: float, c: Color, emis := 0.0) -> MeshInstance3D:
	return capsule(j, r, len, c, Vector3(0, -len * 0.5, 0), Vector3.ZERO, emis)

# ---- paletas
const SKIN := [Color(0.85, 0.66, 0.52), Color(0.72, 0.52, 0.38), Color(0.58, 0.40, 0.28)]
const SHIRT := [Color(0.25, 0.35, 0.55), Color(0.55, 0.2, 0.2), Color(0.3, 0.45, 0.3), Color(0.8, 0.75, 0.6), Color(0.35, 0.3, 0.4), Color(0.9, 0.5, 0.1)]
const PANTS := [Color(0.18, 0.2, 0.3), Color(0.3, 0.25, 0.2), Color(0.12, 0.12, 0.14), Color(0.35, 0.35, 0.3)]
const HAIR := [Color(0.1, 0.08, 0.06), Color(0.3, 0.18, 0.08), Color(0.55, 0.45, 0.3), Color(0.5, 0.5, 0.5)]
const CRE := Color(0.17, 0.17, 0.18)      # piel de criatura (ceniza)
const CRE2 := Color(0.26, 0.26, 0.27)
const BONE := Color(0.82, 0.78, 0.66)
const AMBER := Color(1.0, 0.62, 0.15)

# ======================= HUMANO (sobreviviente, NPC, Nuzluz)
# opts: {rs, creature(bool), scale, shirt, pants, skin, hair, helmet, big}
static func human(opts: Dictionary = {}) -> Node3D:
	var rs: int = opts.get("rs", 0)
	var cre: bool = opts.get("creature", false)
	var sc: float = opts.get("scale", 1.0)
	var skin: Color = CRE if cre else opts.get("skin", SKIN[rs % 3])
	var shirt: Color = (CRE2 if cre else opts.get("shirt", SHIRT[rs % SHIRT.size()]))
	var pants: Color = (CRE if cre else opts.get("pants", PANTS[rs % PANTS.size()]))
	var hair: Color = opts.get("hair", HAIR[rs % HAIR.size()])
	var root := Node3D.new(); root.name = "rig"
	var hips := bone(root, "hips", Vector3(0, 0.95, 0))
	capsule(hips, 0.17, 0.2, pants, Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2))
	var torso := bone(hips, "torso", Vector3(0, 0.1, 0))
	capsule(torso, 0.19, 0.42, shirt, Vector3(0, 0.3, 0))
	if cre:
		# espinas óseas y grietas ámbar
		for i in 4:
			capsule(torso, 0.03, 0.14 + i * 0.03, BONE, Vector3(0, 0.15 + i * 0.1, -0.2), Vector3(0.9, 0, 0))
		sphere(torso, 0.06, AMBER, Vector3(0.08, 0.3, 0.15), Vector3(1, 0.5, 0.4), 2.2)
	var neck := bone(torso, "neck", Vector3(0, 0.58, 0))
	var head := bone(neck, "head", Vector3(0, 0.05, 0))
	sphere(head, 0.12, skin, Vector3(0, 0.1, 0), Vector3(0.9, 1.05, 0.95))
	if cre:
		sphere(head, 0.025, AMBER, Vector3(-0.05, 0.12, 0.1), Vector3.ONE, 3.0)
		sphere(head, 0.025, AMBER, Vector3(0.05, 0.12, 0.1), Vector3.ONE, 3.0)
		capsule(head, 0.035, 0.12, BONE, Vector3(0, 0.0, 0.06), Vector3(1.2, 0, 0))  # mandíbula
	else:
		sphere(head, 0.125, hair, Vector3(0, 0.14, -0.02), Vector3(0.92, 0.75, 0.95))
		if opts.get("helmet", false):
			sphere(head, 0.14, Color(0.25, 0.3, 0.2), Vector3(0, 0.15, 0), Vector3(1, 0.8, 1))
	for side in [-1.0, 1.0]:
		var nm := "L" if side < 0 else "R"
		var sh := bone(torso, "arm" + nm, Vector3(side * 0.24, 0.5, 0))
		limb(sh, 0.06, 0.3, shirt)
		var el := bone(sh, "fore" + nm, Vector3(0, -0.3, 0))
		limb(el, 0.055, 0.28, skin)
		var hd := bone(el, "hand" + nm, Vector3(0, -0.3, 0))
		sphere(hd, 0.055, skin)
		if cre: capsule(hd, 0.02, 0.1, BONE, Vector3(0, -0.07, 0.02))
		var hp := bone(hips, "leg" + nm, Vector3(side * 0.11, -0.02, 0))
		limb(hp, 0.085, 0.42, pants)
		var kn := bone(hp, "shin" + nm, Vector3(0, -0.44, 0))
		limb(kn, 0.07, 0.42, pants)
		var ft := bone(kn, "foot" + nm, Vector3(0, -0.45, 0.03))
		sphere(ft, 0.07, Color(0.12, 0.1, 0.09), Vector3(0, -0.02, 0.04), Vector3(1, 0.6, 1.5))
	root.scale = Vector3.ONE * sc
	root.set_meta("kind", "human")
	root.set_meta("height", 1.78 * sc)
	return root

# ======================= NARA (jabalí con bolsa de gas)
static func boar() -> Node3D:
	var root := Node3D.new(); root.name = "rig"
	var body := bone(root, "body", Vector3(0, 0.6, 0))
	capsule(body, 0.33, 0.6, CRE, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	capsule(body, 0.26, 0.4, CRE2, Vector3(0, 0.12, -0.45), Vector3(PI / 2, 0, 0))
	for i in 5: capsule(body, 0.03, 0.12, BONE, Vector3(0, 0.3, 0.3 - i * 0.18), Vector3(0.3, 0, 0))
	var sac := bone(body, "sac", Vector3(0, 0.05, -0.75))
	sphere(sac, 0.3, Color(1.0, 0.65, 0.2, 0.9), Vector3.ZERO, Vector3.ONE, 1.6)
	var head := bone(body, "head", Vector3(0, 0.05, 0.55))
	sphere(head, 0.22, CRE, Vector3(0, 0, 0.1), Vector3(0.9, 0.9, 1.3))
	capsule(head, 0.09, 0.2, Color(0.3, 0.2, 0.17), Vector3(0, -0.05, 0.4), Vector3(PI / 2, 0, 0))
	for s in [-1.0, 1.0]:
		capsule(head, 0.025, 0.2, BONE, Vector3(s * 0.1, -0.08, 0.35), Vector3(-1.0, 0, s * 0.4))
		sphere(head, 0.03, AMBER, Vector3(s * 0.12, 0.08, 0.28), Vector3.ONE, 3.0)
	for s in [-1.0, 1.0]:
		for f in [0.35, -0.45]:
			var nm := ("F" if f > 0 else "B") + ("L" if s < 0 else "R")
			var hp := bone(body, "leg" + nm, Vector3(s * 0.2, -0.15, f))
			limb(hp, 0.07, 0.3, CRE)
			var kn := bone(hp, "shin" + nm, Vector3(0, -0.3, 0))
			limb(kn, 0.05, 0.3, CRE2)
	root.set_meta("kind", "boar"); root.set_meta("height", 1.1)
	return root

# ======================= NICA (gorila saltador)
static func gorilla() -> Node3D:
	var root := Node3D.new(); root.name = "rig"
	var hips := bone(root, "hips", Vector3(0, 0.75, 0))
	capsule(hips, 0.25, 0.3, CRE, Vector3.ZERO, Vector3(0, 0, PI / 2))
	var torso := bone(hips, "torso", Vector3(0, 0.1, 0))
	capsule(torso, 0.34, 0.5, CRE2, Vector3(0, 0.35, 0.05), Vector3(0.35, 0, 0))
	for i in 3: capsule(torso, 0.04, 0.2, BONE, Vector3(0, 0.3 + i * 0.12, -0.3), Vector3(-1.0, 0, 0))
	sphere(torso, 0.09, AMBER, Vector3(0, 0.35, 0.33), Vector3(1, 0.6, 0.4), 2.0)
	var head := bone(torso, "head", Vector3(0, 0.72, 0.2))
	sphere(head, 0.17, CRE, Vector3(0, 0.08, 0), Vector3(1, 0.9, 1))
	capsule(head, 0.08, 0.16, BONE, Vector3(0, -0.04, 0.12), Vector3(PI / 2, 0, 0))
	for s in [-1.0, 1.0]:
		sphere(head, 0.03, AMBER, Vector3(s * 0.07, 0.1, 0.15), Vector3.ONE, 3.0)
		var nm := "L" if s < 0 else "R"
		var sh := bone(torso, "arm" + nm, Vector3(s * 0.42, 0.55, 0.05))
		limb(sh, 0.11, 0.5, CRE2)
		var el := bone(sh, "fore" + nm, Vector3(0, -0.5, 0))
		limb(el, 0.1, 0.55, CRE)
		var hd := bone(el, "hand" + nm, Vector3(0, -0.58, 0))
		sphere(hd, 0.13, CRE, Vector3.ZERO, Vector3(1, 0.6, 1.2))
		var hp := bone(hips, "leg" + nm, Vector3(s * 0.18, -0.05, 0))
		limb(hp, 0.11, 0.38, CRE)
		var kn := bone(hp, "shin" + nm, Vector3(0, -0.38, 0))
		limb(kn, 0.09, 0.36, CRE2)
	root.set_meta("kind", "gorilla"); root.set_meta("height", 1.9)
	return root

# ======================= NALOMA (cóndor con ácido)
static func condor() -> Node3D:
	var root := Node3D.new(); root.name = "rig"
	var body := bone(root, "body", Vector3(0, 1.3, 0))
	capsule(body, 0.22, 0.5, CRE, Vector3.ZERO, Vector3(PI / 2 - 0.3, 0, 0))
	var neck := bone(body, "neck", Vector3(0, 0.15, 0.3))
	capsule(neck, 0.06, 0.3, Color(0.85, 0.5, 0.45), Vector3(0, 0.12, 0.05), Vector3(0.4, 0, 0))
	capsule(neck, 0.1, 0.1, BONE, Vector3(0, 0.0, 0.0), Vector3(0, 0, PI / 2))  # collar de hueso
	var head := bone(neck, "head", Vector3(0, 0.28, 0.12))
	sphere(head, 0.1, Color(0.75, 0.4, 0.38), Vector3.ZERO, Vector3(0.9, 0.9, 1.2))
	capsule(head, 0.04, 0.2, Color(0.9, 0.85, 0.6), Vector3(0, -0.03, 0.17), Vector3(PI / 2 + 0.3, 0, 0))
	for s in [-1.0, 1.0]:
		sphere(head, 0.025, AMBER, Vector3(s * 0.06, 0.04, 0.07), Vector3.ONE, 3.0)
		var nm := "L" if s < 0 else "R"
		var w := bone(body, "wing" + nm, Vector3(s * 0.2, 0.1, 0))
		capsule(w, 0.07, 0.9, CRE2, Vector3(s * 0.45, 0, 0), Vector3(0, 0, PI / 2))
		var wt := bone(w, "wtip" + nm, Vector3(s * 0.9, 0, 0))
		capsule(wt, 0.05, 0.8, CRE, Vector3(s * 0.4, -0.02, -0.05), Vector3(0, 0, PI / 2))
		for i in 4: capsule(wt, 0.015, 0.3, CRE, Vector3(s * (0.3 + i * 0.15), -0.1, -0.1 - i * 0.03), Vector3(0.3, 0, 0))
		var lg := bone(body, "leg" + nm, Vector3(s * 0.1, -0.15, -0.1))
		limb(lg, 0.03, 0.3, Color(0.6, 0.55, 0.45))
	capsule(body, 0.05, 0.5, CRE, Vector3(0, 0.05, -0.5), Vector3(PI / 2 + 0.2, 0, 0))
	root.set_meta("kind", "condor"); root.set_meta("height", 1.6)
	return root

# ======================= NAKRU (gusano perforador)
static func worm() -> Node3D:
	var root := Node3D.new(); root.name = "rig"
	var prev: Node3D = root
	var r := 0.42
	for i in 5:
		var seg := bone(prev, "seg%d" % i, Vector3(0, 0.55 if i > 0 else 0.3, 0))
		capsule(seg, r, 0.55, CRE if i % 2 == 0 else CRE2, Vector3(0, 0.25, 0))
		# anillo de dientes/hueso por segmento
		for k in 6:
			var a := k * TAU / 6.0
			capsule(seg, 0.03, 0.12, BONE, Vector3(cos(a) * r, 0.25, sin(a) * r), Vector3(0, 0, 0))
		sphere(seg, 0.05, AMBER, Vector3(0, 0.3, r * 0.95), Vector3(1.6, 0.5, 0.5), 2.0)
		prev = seg
		r -= 0.03
	var head := bone(prev, "head", Vector3(0, 0.55, 0))
	sphere(head, 0.4, CRE, Vector3(0, 0.1, 0), Vector3(1, 0.8, 1))
	# boca taladro: tres anillos de dientes
	for ring in 3:
		var rr := 0.34 - ring * 0.09
		for k in 8:
			var a := k * TAU / 8.0 + ring * 0.3
			capsule(head, 0.03, 0.2, BONE, Vector3(cos(a) * rr, 0.35 + ring * 0.08, sin(a) * rr), Vector3(cos(a) * 0.5, 0, -sin(a) * 0.5))
	sphere(head, 0.1, AMBER, Vector3(0, 0.42, 0), Vector3.ONE, 3.0)
	root.set_meta("kind", "worm"); root.set_meta("height", 3.2)
	return root

static func make(kind: String, opts: Dictionary = {}) -> Node3D:
	match kind:
		"boar": return boar()
		"gorilla": return gorilla()
		"condor": return condor()
		"worm": return worm()
		_: return human(opts)

# ======================= POSES
# st: {"t": tiempo, "move": 0..1, "run": bool, "atk": 0..1 (fase de ataque), "dead": 0..1, "air": float, "crouch": 0..1, "fly": bool, "em": 0..1}
static func j(rig: Node3D, nm: String) -> Node3D:
	return rig.find_child(nm, true, false) as Node3D

static func pose(rig: Node3D, st: Dictionary) -> void:
	var kind: String = rig.get_meta("kind", "human")
	var t: float = st.get("t", 0.0)
	var mv: float = st.get("move", 0.0)
	var atk: float = st.get("atk", 0.0)
	var dead: float = st.get("dead", 0.0)
	match kind:
		"human": pose_human(rig, t, mv, st.get("run", false), atk, dead, st.get("creature", false), st.get("aim", false), st.get("shoot", 0.0))
		"boar": pose_boar(rig, t, mv, atk, dead, st.get("infl", 0.0))
		"gorilla": pose_gorilla(rig, t, mv, atk, dead, st.get("crouch", 0.0), st.get("air", 0.0))
		"condor": pose_condor(rig, t, mv, atk, dead, st.get("fly", true))
		"worm": pose_worm(rig, t, mv, atk, dead, st.get("em", 1.0))
	if dead > 0.0 and kind != "worm":
		var r := rig.get_child(0) as Node3D
		r.rotation.x = -PI / 2 * minf(1.0, dead * 1.6) * (1.0 if kind != "condor" else 0.3)
		r.position.y = lerpf(r.position.y, 0.25, minf(1.0, dead))

static func pose_human(rig: Node3D, t: float, mv: float, run: bool, atk: float, dead: float, cre: bool, aim: bool, shoot: float) -> void:
	var f := (9.0 if run else 6.0)
	var sw := sin(t * f) * mv * (0.9 if run else 0.55)
	var hips := j(rig, "hips"); var torso := j(rig, "torso"); var head := j(rig, "head")
	hips.position.y = 0.95 + absf(sin(t * f * 2.0)) * 0.03 * mv - (0.02 if cre else 0.0)
	torso.rotation.x = (0.25 if cre else 0.08 * mv) + (0.08 if run else 0.0)
	torso.rotation.z = sin(t * f) * 0.04 * mv + (sin(t * 2.3) * 0.08 if cre else 0.0)
	head.rotation.x = -0.15 if cre else 0.0
	head.rotation.z = (sin(t * 1.7) * 0.15 if cre else 0.0)
	j(rig, "legL").rotation.x = sw; j(rig, "legR").rotation.x = -sw
	j(rig, "shinL").rotation.x = maxf(0.0, -sw) * 1.2 + 0.05; j(rig, "shinR").rotation.x = maxf(0.0, sw) * 1.2 + 0.05
	var aL := j(rig, "armL"); var aR := j(rig, "armR"); var fL := j(rig, "foreL"); var fR := j(rig, "foreR")
	if aim:
		aR.rotation.x = -1.45; aR.rotation.z = 0.15; fR.rotation.x = -0.15
		aL.rotation.x = -1.25; aL.rotation.z = -0.55; fL.rotation.x = -0.9
		aR.rotation.x += shoot * 0.25
	elif cre:
		aL.rotation.x = -0.9 - sw * 0.5 + atk * -1.4; aR.rotation.x = -0.9 + sw * 0.5 + atk * -1.4
		aL.rotation.z = -0.3; aR.rotation.z = 0.3
		fL.rotation.x = -0.8; fR.rotation.x = -0.8
		if atk > 0.0:
			torso.rotation.x = 0.25 + sin(atk * PI) * 0.6
	else:
		aL.rotation.x = -sw * 0.8; aR.rotation.x = sw * 0.8
		aL.rotation.z = -0.12; aR.rotation.z = 0.12
		fL.rotation.x = -0.4; fR.rotation.x = -0.4

static func pose_boar(rig: Node3D, t: float, mv: float, atk: float, dead: float, infl: float) -> void:
	var f := 11.0
	var body := j(rig, "body"); var head := j(rig, "head")
	body.position.y = 0.6 + absf(sin(t * f)) * 0.05 * mv
	body.rotation.x = sin(t * f) * 0.06 * mv
	head.rotation.x = 0.2 + sin(t * 2.0) * 0.08 + atk * 0.8
	for nm in ["FL", "FR", "BL", "BR"]:
		var ph := 0.0 if nm == "FL" or nm == "BR" else PI
		var s := sin(t * f + ph) * mv * 0.7
		j(rig, "leg" + nm).rotation.x = s
		j(rig, "shin" + nm).rotation.x = maxf(0.0, -s) * 1.1
	var sac := j(rig, "sac")
	var k := 1.0 + infl * 1.3 + sin(t * 3.0) * 0.05
	sac.scale = Vector3(k, k, k)

static func pose_gorilla(rig: Node3D, t: float, mv: float, atk: float, dead: float, crouch: float, air: float) -> void:
	var f := 7.0
	var hips := j(rig, "hips"); var torso := j(rig, "torso")
	hips.position.y = 0.75 - crouch * 0.35 + absf(sin(t * f)) * 0.04 * mv
	torso.rotation.x = 0.55 + crouch * 0.5 - air * 0.6
	for s in ["L", "R"]:
		var ph := 0.0 if s == "L" else PI
		var sw := sin(t * f + ph) * mv
		j(rig, "arm" + s).rotation.x = -0.4 + sw * 0.6 - crouch * 0.4 - air * 1.8 + atk * -1.6
		j(rig, "fore" + s).rotation.x = -0.2 + atk * -0.8
		j(rig, "leg" + s).rotation.x = -sw * 0.6 + crouch * 1.0 - air * 0.8
		j(rig, "shin" + s).rotation.x = maxf(0.0, sw) * 0.9 + crouch * 1.2 + air * 0.6

static func pose_condor(rig: Node3D, t: float, mv: float, atk: float, dead: float, fly: bool) -> void:
	var body := j(rig, "body")
	var flap := sin(t * 6.0)
	body.position.y = (1.3 + flap * 0.06) if fly else 0.6
	body.rotation.x = -0.1 + atk * 0.5
	for s in ["L", "R"]:
		var sg := -1.0 if s == "L" else 1.0
		var w := j(rig, "wing" + s); var wt := j(rig, "wtip" + s)
		if fly:
			w.rotation.z = sg * -flap * 0.55; wt.rotation.z = sg * -flap * 0.7
		else:
			w.rotation.z = sg * 0.9 + sin(t * 2.0) * 0.05; wt.rotation.z = sg * 1.6
		j(rig, "leg" + s).rotation.x = 0.6 if fly else 0.0
	j(rig, "head").rotation.x = sin(t * 1.5) * 0.2 + atk * 0.6

static func pose_worm(rig: Node3D, t: float, mv: float, atk: float, dead: float, em: float) -> void:
	var r := rig.get_child(0) as Node3D
	r.position.y = -3.3 * (1.0 - em)
	for i in 5:
		var s := j(rig, "seg%d" % i)
		s.rotation.x = sin(t * 3.0 + i * 0.8) * 0.12 * (1.0 if i > 0 else 0.0) + (atk * 0.35 if i > 2 else 0.0)
		s.rotation.z = cos(t * 2.2 + i * 0.8) * 0.08
	var h := j(rig, "head")
	h.rotation.y = t * 4.0 * (1.0 + atk * 3.0)
	h.rotation.x = atk * 0.6
	if dead > 0.0:
		r.rotation.z = minf(1.0, dead) * 1.2
		r.position.y -= minf(1.0, dead) * 0.5
