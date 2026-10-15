extends Node3D
# Zona Muerta · Godot. Orquesta ciudad, luces, jugador, compañeros, criaturas, refugios, sonido y menús.
const VERSION := "g1.1"
var player: Node3D
var creatures: Node3D
var companions: Node3D
var refuge: Node3D
var hud: CanvasLayer
var paused := true
var time := 0.0
var day_time := 19.5 * 60.0   # minutos del día
var fires: Array = []          # {x,z,r,t,node,light}
var gas: Array = []            # {x,z,r,t}
var throws: Array = []         # {kind,node,p,v,t}
var flares: Array = []
var muzzles: Array = []
var all_lights: Array = []
var light_t := 0.0
var sfx_streams := {}
var sfx_pool: Array = []
var env: Environment
var sun: DirectionalLight3D
var started := false
var _soft: GradientTexture2D

func _ready() -> void:
	GS.msg_cb = Callable(self, "on_msg")
	build_env()
	build_city()
	build_lamps_and_fires()
	load_sfx()
	hud = CanvasLayer.new(); hud.set_script(load("res://hud.gd")); add_child(hud)
	player = Node3D.new(); player.set_script(load("res://player.gd")); add_child(player)
	companions = Node3D.new(); companions.set_script(load("res://companions.gd")); add_child(companions)
	creatures = Node3D.new(); creatures.set_script(load("res://creatures.gd")); add_child(creatures)
	refuge = Node3D.new(); refuge.set_script(load("res://refuge.gd")); add_child(refuge)
	refuge.setup()
	var st: Dictionary = GS.meta["start"]
	player.spawn_at(st["x"], st["z"], 0.03, st["yaw"])
	companions.setup(st["x"], st["z"] - 3.0)
	hud.show_menu("main")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := Node.new(); t.set_script(load("res://tester.gd")); add_child(t)

# ---------------------------------------------------------------- ambiente
func build_env() -> void:
	env = Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.015, 0.02, 0.04); sm.sky_horizon_color = Color(0.09, 0.07, 0.06)
	sm.ground_horizon_color = Color(0.06, 0.05, 0.045); sm.ground_bottom_color = Color(0.01, 0.01, 0.012); sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.16, 0.19, 0.26); env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.1; env.tonemap_white = 4.0
	env.fog_enabled = true; env.fog_light_color = Color(0.05, 0.06, 0.08); env.fog_density = 0.012; env.fog_sky_affect = 0.9; env.fog_aerial_perspective = 0.5
	env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.018; env.volumetric_fog_albedo = Color(0.6, 0.62, 0.7); env.volumetric_fog_length = 90.0; env.volumetric_fog_ambient_inject = 0.3
	env.ssao_enabled = true; env.ssao_radius = 1.2; env.ssao_intensity = 2.5
	env.glow_enabled = true; env.glow_intensity = 0.65; env.glow_bloom = 0.08; env.glow_hdr_threshold = 1.1; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true; env.adjustment_contrast = 1.08; env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new()   # luna
	sun.rotation_degrees = Vector3(-48, 30, 0); sun.light_color = Color(0.55, 0.65, 0.9); sun.light_energy = 0.28
	sun.light_cull_mask = 1; sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.directional_shadow_max_distance = 120.0; sun.shadow_bias = 0.04
	add_child(sun)

func build_city() -> void:
	var idx: Array = JSON.parse_string(FileAccess.get_file_as_string("res://city/index.json"))
	for e in idx:
		var mi := MeshInstance3D.new()
		mi.mesh = load(e[2])
		mi.visibility_range_end = 300.0; mi.visibility_range_end_margin = 20.0; mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)

func omni(p: Vector3, c: Color, e: float, r: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new(); l.position = p; l.light_color = c; l.light_energy = e; l.omni_range = r; l.shadow_enabled = shadow
	l.omni_attenuation = 1.3; l.light_cull_mask = 1
	add_child(l); all_lights.append([l, r * 3.0 + 40.0]); return l

func build_lamps_and_fires() -> void:
	var lamps: Array = GS.extras["lamps"]
	var n := 0
	for l in lamps:
		var t: int = int(l[2])
		var c: Array = l[3] if l[3] is Array else [1, 0.85, 0.6]
		var col := Color(c[0], c[1], c[2])
		var y: float = float(l[6]) if l.size() > 6 and l[6] != null else (4.1 if t == 6 else 2.9)
		var I: float = float(l[4]) if l[4] != null else 2.0
		var R: float = float(l[5]) if l[5] != null else 12.0
		if t == 3: col = Color(1, 0.1, 0.06)
		var e := I * (0.75 if t == 6 else 0.9)
		if t == 6 and (n % 3) != 0:
			n += 1; continue
		n += 1
		omni(Vector3(l[0], y, l[1]), col, e, R)
	for f in GS.extras["fires"]:
		add_fire(Vector2(f[0], f[1]), float(f[2]) if f.size() > 2 else 1.0, -1.0)
	for w in GS.extras.get("wells", []):
		var fl := make_fire_node(2.6, true); fl.position = Vector3(w[0], 7.5, w[1]); add_child(fl)
		omni(Vector3(w[0], 9.0, w[1]), Color(1, 0.55, 0.15), 14.0, 60.0)

func soft_tex() -> GradientTexture2D:
	if _soft: return _soft
	var g := Gradient.new(); g.add_point(0.0, Color(1, 1, 1, 1)); g.add_point(0.45, Color(0.5, 0.5, 0.5, 0.5)); g.add_point(0.95, Color(0, 0, 0, 0)); g.add_point(1.0, Color(0, 0, 0, 0))
	_soft = GradientTexture2D.new(); _soft.gradient = g; _soft.fill = GradientTexture2D.FILL_RADIAL; _soft.fill_from = Vector2(0.5, 0.5); _soft.fill_to = Vector2(1, 0.5); _soft.width = 64; _soft.height = 64
	return _soft

func make_fire_node(r: float, big := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(40 * r) if not big else 160; p.lifetime = 0.9 if not big else 1.6; p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = r * 0.5
	p.direction = Vector3.UP; p.spread = 18.0; p.initial_velocity_min = 1.2; p.initial_velocity_max = 2.6 if not big else 6.0; p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.25 * r; p.scale_amount_max = 0.6 * r
	var g := Gradient.new(); g.add_point(0.0, Color(1, 0.9, 0.5, 1)); g.add_point(0.4, Color(1, 0.45, 0.1, 0.9)); g.add_point(1.0, Color(0.2, 0.05, 0.02, 0))
	p.color_ramp = g
	var m := QuadMesh.new(); m.size = Vector2(0.5, 0.5); p.mesh = m
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_texture = soft_tex()
	m.material = mat
	return p

func add_fire(p: Vector2, r: float, t: float) -> void:
	var n := make_fire_node(r); n.position = Vector3(p.x, GS.ground_h(p.x, p.y, 0.0, 99.0) + 0.1, p.y); add_child(n)
	var l := omni(n.position + Vector3(0, 1.2, 0), Color(1, 0.55, 0.2), 3.5 * r, 9.0 * r)
	fires.append({"x": p.x, "z": p.y, "r": r, "t": t, "node": n, "light": l, "ph": randf() * 10.0})

func in_fire(x: float, z: float) -> bool:
	for f in fires:
		if Vector2(f.x - x, f.z - z).length() < f.r + 0.6: return true
	return false

func add_gas(p: Vector2, r: float, t: float) -> void:
	var n := make_fire_node(r); n.position = Vector3(p.x, 0.4, p.y)
	var g := Gradient.new(); g.add_point(0.0, Color(0.7, 0.9, 0.2, 0.5)); g.add_point(1.0, Color(0.5, 0.7, 0.1, 0)); n.color_ramp = g
	n.initial_velocity_min = 0.3; n.initial_velocity_max = 0.8; n.gravity = Vector3(0, 0.2, 0); n.lifetime = 2.0; n.emission_sphere_radius = r
	add_child(n)
	gas.append({"x": p.x, "z": p.y, "r": r, "t": t, "node": n})

# ---------------------------------------------------------------- efectos
func spawn_burst(p: Vector3, c: Color, n: int) -> void:
	var ps := CPUParticles3D.new(); ps.one_shot = true; ps.amount = n; ps.lifetime = 0.7; ps.explosiveness = 1.0
	ps.direction = Vector3.UP; ps.spread = 70.0; ps.initial_velocity_min = 2.0; ps.initial_velocity_max = 5.0; ps.gravity = Vector3(0, -6, 0)
	ps.scale_amount_min = 0.05; ps.scale_amount_max = 0.14; ps.color = c
	var m := BoxMesh.new(); m.size = Vector3.ONE; ps.mesh = m
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.emission_enabled = c.r > 0.9; mat.emission = c; mat.emission_energy_multiplier = 1.5; m.material = mat
	ps.position = p; add_child(ps); ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)

func spawn_blood(p: Vector3) -> void:
	spawn_burst(p, Color(0.5, 0.03, 0.03), 14)

func spark(p: Vector3) -> void:
	spawn_burst(p, Color(1.0, 0.85, 0.5), 8)

func muzzle_at(p: Vector3) -> void:
	var l := omni(p, Color(1, 0.7, 0.35), 2.5, 7.0); muzzles.append([l, 0.08])

# ---------------------------------------------------------------- combate
func hitscan(o: Vector3, d: Vector3, dmg: float, hx: float, kb: float, by_player: bool) -> void:
	var wall := GS.cast_ray(o, d, 140.0)
	var h: Dictionary = creatures.ray_hit(o, d, wall.t)
	if h.z != null:
		creatures.damage(h.z, dmg, h.head, kb, o, by_player)
	elif wall.hit:
		spark(wall.p + wall.n * 0.05)

func melee(o: Vector3, f: Vector3, reach: float, arc: float, dmg: float, by_player: bool, kb := 0.6) -> void:
	var hit := false
	for z in creatures.zs:
		if z.state == "dead": continue
		var dx: float = z.x - o.x; var dz: float = z.z - o.z; var d := Vector2(dx, dz).length()
		if d > reach + z.r: continue
		var ang := absf(angle_difference(atan2(dx, dz), atan2(f.x, f.z)))
		if ang > arc * 0.5: continue
		creatures.damage(z, dmg, false, kb, o, by_player); hit = true
		z.stag = maxf(z.stag, 0.5)
	if hit: sfx("hit", o)

func noise(p: Vector3, r: float) -> void:
	creatures.noise(p, r)

func throw_item(kind: String, p: Vector3, v: Vector3) -> void:
	var n := MeshInstance3D.new()
	var m := BoxMesh.new(); m.size = Vector3(0.12, 0.25, 0.12) if kind != "Acido" else Vector3(0.18, 0.18, 0.18); n.mesh = m
	n.material_override = Chars.mat({"Molotov": Color(0.3, 0.5, 0.3), "Bengala": Color(0.9, 0.2, 0.1), "Acido": Color(0.75, 1.0, 0.15)}[kind], 0.5, 1.5 if kind != "Molotov" else 0.0)
	n.position = p; add_child(n)
	if kind != "Molotov":
		var l := OmniLight3D.new(); l.light_color = Color(1, 0.3, 0.2) if kind == "Bengala" else Color(0.7, 1, 0.2); l.light_energy = 2.0; l.omni_range = 6.0; n.add_child(l)
	throws.append({"kind": kind, "node": n, "p": p, "v": v, "t": 0.0})

func update_throws(dt: float) -> void:
	for i in range(throws.size() - 1, -1, -1):
		var q: Dictionary = throws[i]
		q.t += dt; q.v.y -= (9.8 if q.kind != "Acido" else 5.0) * dt
		var np: Vector3 = q.p + q.v * dt
		var land := false
		if q.kind == "Acido":
			var pp := Vector2(np.x - player.position.x, np.z - player.position.z).length()
			if pp < 0.6 and np.y > player.position.y and np.y < player.position.y + 2.0:
				player.take_damage(9.0, np); player.poison = 4.5; GS.msg("¡Ácido! Te está quemando", 2.0); land = true
		var gh := GS.ground_h(np.x, np.z, np.y, 99.0)
		if np.y <= gh + 0.05: land = true
		elif not GS.walkable(np.x, np.z) and GS.cell_h(floori(np.x / GS.CS), floori(np.z / GS.CS)) > np.y: land = true
		if land or q.t > 8.0:
			var g := Vector2(q.p.x, q.p.z)
			match q.kind:
				"Molotov":
					add_fire(g, 2.3, 9.0); sfx("fire", q.p); spawn_burst(Vector3(g.x, 0.3, g.y), Color(1, 0.6, 0.2), 30)
				"Bengala":
					flares.append({"x": g.x, "z": g.y, "t": 14.0, "node": q.node}); creatures.noise(Vector3(g.x, 0, g.y), 60.0)
					q.node.position = Vector3(g.x, gh + 0.1, g.y); throws.remove_at(i); continue
				"Acido":
					add_gas(g, 1.0, 3.5)
			q.node.queue_free(); throws.remove_at(i); continue
		q.p = np; q.node.position = np; q.node.rotation.x += dt * 8.0

# ---------------------------------------------------------------- sonido (wavs generados)
func load_sfx() -> void:
	for n in ["shot_Pistola", "shot_Revolver", "shot_Bombeo", "shot_Recortada", "shot_Fusil", "shot_Rifle", "shot_comp", "reload", "swing", "hit", "hurt", "die", "pick", "thud", "rumble", "hiss", "horde", "fire"]:
		var p := "res://data/sfx/%s.wav" % n
		if ResourceLoader.exists(p): sfx_streams[n] = load(p)
	for i in 14:
		var a := AudioStreamPlayer3D.new(); a.max_distance = 70.0; a.unit_size = 6.0; add_child(a); sfx_pool.append(a)

func sfx(n: String, p: Vector3) -> void:
	if not sfx_streams.has(n): return
	for a in sfx_pool:
		if not a.playing:
			a.stream = sfx_streams[n]; a.position = p; a.pitch_scale = randf_range(0.92, 1.08); a.play(); return

# ---------------------------------------------------------------- flujo
func set_paused(v: bool) -> void:
	paused = v
	player.captured = not v
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_CAPTURED

func on_msg(t: String, secs: float) -> void:
	hud.message(t, secs)

func clock_text() -> String:
	var m := int(day_time) % 1440
	return "%02d:%02d" % [m / 60, m % 60]

func hint_text() -> String:
	if paused: return ""
	var h: String = refuge.hint(player.position.x, player.position.z)
	if h != "": return h
	for c in companions.list:
		if c.hp <= 0.0 and Vector2(c.x - player.position.x, c.z - player.position.z).length() < 2.2: return "E · Levantar a " + c.n
	return ""

func interact() -> void:
	if paused:
		if hud.card.visible: hud.close_card()
		return
	if refuge.interact(player.position.x, player.position.z): return
	if companions.try_revive(player.position.x, player.position.z): sfx("pick", player.position)

func new_game() -> void:
	GS.hp = 100.0; GS.chapas = 0; GS.kills = 0; day_time = 19.5 * 60.0
	for z in creatures.zs: z.rig.queue_free()
	creatures.zs.clear(); creatures.spawn_t = 6.0; creatures.sp_cd = 45.0; creatures.horde_t = 120.0
	refuge.mi = -1
	for m in refuge.missions: m.state = "pend"
	if refuge.item_node: refuge.item_node.queue_free(); refuge.item_node = null
	var st: Dictionary = GS.meta["start"]
	player.spawn_at(st["x"], st["z"], 0.03, st["yaw"]); player.dead_t = -1.0; player.poison = 0.0
	for n in player.WORDER:
		var d: Dictionary = player.WDAT[n]
		player.WS[n] = {"mag": d.get("mag", 0), "res": d.get("res", 0) if d["k"] == "gun" else (d.get("n", 0) if d["k"] == "throw" else 0)}
	player.select("Fusil")
	companions.setup(st["x"], st["z"] - 3.0)
	started = true
	hud.hide_menu(); set_paused(false)
	GS.msg("Capilla del Pozo, refugio. Alma, Aurelio y Maxi van con vos. E con el comerciante, la mesa de pedidos y las literas. M: mapa.", 9.0)

func save_now() -> void:
	var m := []
	for q in refuge.missions: m.append(q.state)
	GS.save_game({"x": player.position.x, "z": player.position.z, "yaw": player.yaw, "hp": GS.hp, "chapas": GS.chapas, "kills": GS.kills, "ws": player.WS, "cur": player.cur, "mi": refuge.mi, "missions": m, "day": day_time, "v": VERSION})

func load_now() -> bool:
	var s := GS.load_game()
	if s.is_empty():
		GS.msg("No hay partida guardada.", 3.0); return false
	new_game()
	player.spawn_at(s["x"], s["z"], 0.03, s["yaw"]); GS.hp = s["hp"]; GS.chapas = int(s["chapas"]); GS.kills = int(s["kills"]); day_time = s["day"]
	for n in s["ws"]: player.WS[n] = {"mag": int(s["ws"][n]["mag"]), "res": int(s["ws"][n]["res"])}
	player.select(s["cur"])
	for i in mini(s["missions"].size(), refuge.missions.size()): refuge.missions[i].state = s["missions"][i]
	refuge.mi = int(s["mi"])
	if refuge.mi >= 0 and refuge.missions[refuge.mi].state == "active": refuge.place_item(refuge.missions[refuge.mi].pick)
	companions.setup(player.position.x, player.position.z - 3.0)
	GS.msg("Partida cargada.", 3.0); return true

func on_player_dead() -> void:
	set_paused(true); hud.show_menu("dead")

func respawn_refuge() -> void:
	var r: Dictionary = refuge.refs[0]
	GS.hp = 100.0; player.poison = 0.0; player.dead_t = -1.0
	player.spawn_at(r["x"], r["z"] - 6.0, 0.03, 0.0)
	for z in creatures.zs: z.rig.queue_free()
	creatures.zs.clear(); creatures.spawn_t = 8.0
	companions.setup(r["x"], r["z"] - 3.0)
	hud.hide_menu(); set_paused(false)

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k = e.keycode
		if hud.menu.visible:
			match hud.menu_kind:
				"main":
					if k == KEY_1: new_game()
					elif k == KEY_2: load_now()
					elif k == KEY_3: get_tree().quit()
				"pause":
					if k == KEY_1 or k == KEY_ESCAPE:
						hud.hide_menu(); set_paused(false)
					elif k == KEY_2:
						save_now(); GS.msg("Partida guardada.", 2.5); hud.hide_menu(); set_paused(false)
					elif k == KEY_3: load_now()
					elif k == KEY_4:
						hud.hide_menu(); hud.show_menu("main"); set_paused(true)
				"dead":
					if k == KEY_1: respawn_refuge()
					elif k == KEY_2: load_now()
					elif k == KEY_3:
						hud.hide_menu(); hud.show_menu("main")
			return
		if hud.card.visible:
			if k == KEY_ESCAPE or k == KEY_E or k == KEY_ENTER: hud.close_card()
			elif k >= KEY_1 and k <= KEY_4: hud.card_key(k - KEY_1 + 1)
			return
		if k == KEY_ESCAPE and started:
			if hud.map_open:
				hud.toggle_map(); return
			hud.show_menu("pause"); set_paused(true)
		if k == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func update_lights() -> void:
	var p := player.position
	for i in range(all_lights.size() - 1, -1, -1):
		var l: OmniLight3D = all_lights[i][0]
		if not is_instance_valid(l) or l.is_queued_for_deletion():
			all_lights.remove_at(i); continue
		l.visible = Vector2(l.position.x - p.x, l.position.z - p.z).length() < all_lights[i][1]

func _process(dt: float) -> void:
	time += dt
	light_t -= dt
	if light_t <= 0.0:
		light_t = 0.4; update_lights()
	for i in range(muzzles.size() - 1, -1, -1):
		muzzles[i][1] -= dt
		if muzzles[i][1] <= 0.0:
			muzzles[i][0].queue_free(); muzzles.remove_at(i)
	for f in fires:
		f.light.light_energy = (3.0 + sin(time * 13.0 + f.ph) * 0.8 + sin(time * 31.0 + f.ph) * 0.4) * f.r
	if paused: return
	day_time += dt * 0.5
	update_throws(dt)
	for i in range(fires.size() - 1, -1, -1):
		var f: Dictionary = fires[i]
		if f.t > 0.0:
			f.t -= dt
			if f.t <= 0.0:
				f.node.queue_free(); f.light.queue_free(); fires.remove_at(i)
	for i in range(gas.size() - 1, -1, -1):
		gas[i].t -= dt
		if gas[i].t <= 0.0:
			gas[i].node.queue_free(); gas.remove_at(i)
		elif Vector2(gas[i].x - player.position.x, gas[i].z - player.position.z).length() < gas[i].r + 0.4 and player.poison < 1.0: player.poison = 2.0
	for i in range(flares.size() - 1, -1, -1):
		flares[i].t -= dt; creatures.noise(Vector3(flares[i].x, 0, flares[i].z), 45.0)
		if flares[i].t <= 0.0:
			flares[i].node.queue_free(); flares.remove_at(i)
	if player.dead_t < 0.0 and in_fire(player.position.x, player.position.z): player.take_damage(12.0 * dt, player.position)
