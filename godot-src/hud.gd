extends CanvasLayer
# HUD, mapa, tarjetas (comercio / pedidos), menú de pausa y menú principal.
var main: Node3D
var hp_bar: ColorRect
var hp_bg: ColorRect
var hp_txt: Label
var ammo: Label
var wname: Label
var wname_t := 0.0
var info: Label
var msg_l: Label
var msg_t := 0.0
var hint_l: Label
var obj_l: Label
var hurt_r: ColorRect
var pois_r: ColorRect
var fade_r: ColorRect
var cross: Control
var map_c: Control
var map_tex: Texture2D
var map_open := false
var card: PanelContainer
var card_v: VBoxContainer
var card_kind := ""
var card_ref := {}
var menu: PanelContainer
var menu_v: VBoxContainer
var menu_kind := ""   # "main" / "pause" / "dead"
var fps_l: Label
var font_big: int = 22

func lab(parent: Node, size: int, col := Color(0.92, 0.93, 0.95)) -> Label:
	var l := Label.new(); l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); l.add_theme_constant_override("shadow_offset_x", 1); l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l); return l

func _ready() -> void:
	main = get_parent()
	layer = 5
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	hurt_r = ColorRect.new(); hurt_r.set_anchors_preset(Control.PRESET_FULL_RECT); hurt_r.color = Color(0.7, 0.0, 0.0, 0.0); hurt_r.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hurt_r)
	pois_r = ColorRect.new(); pois_r.set_anchors_preset(Control.PRESET_FULL_RECT); pois_r.color = Color(0.6, 0.85, 0.1, 0.0); pois_r.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(pois_r)
	# vida
	hp_bg = ColorRect.new(); hp_bg.position = Vector2(28, 660); hp_bg.size = Vector2(260, 14); hp_bg.color = Color(0, 0, 0, 0.55); root.add_child(hp_bg)
	hp_bar = ColorRect.new(); hp_bar.position = Vector2(30, 662); hp_bar.size = Vector2(256, 10); hp_bar.color = Color(0.43, 0.7, 0.29); root.add_child(hp_bar)
	hp_txt = lab(root, 30); hp_txt.position = Vector2(28, 622)
	ammo = lab(root, 40); ammo.position = Vector2(1080, 640); ammo.size = Vector2(170, 50); ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wname = lab(root, 15, Color(0.8, 0.82, 0.85)); wname.position = Vector2(980, 616); wname.size = Vector2(270, 24); wname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info = lab(root, 15, Color(0.85, 0.87, 0.9)); info.position = Vector2(980, 20); info.size = Vector2(270, 80); info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_l = lab(root, 12, Color(0.6, 0.6, 0.65)); fps_l.position = Vector2(12, 8)
	msg_l = lab(root, 20); msg_l.position = Vector2(240, 420); msg_l.size = Vector2(800, 120); msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; msg_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_l = lab(root, 17, Color(1.0, 0.85, 0.5)); hint_l.position = Vector2(340, 560); hint_l.size = Vector2(600, 30); hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_l = lab(root, 15, Color(0.95, 0.9, 0.75)); obj_l.position = Vector2(340, 16); obj_l.size = Vector2(600, 30); obj_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross = Control.new(); cross.set_anchors_preset(Control.PRESET_FULL_RECT); cross.mouse_filter = Control.MOUSE_FILTER_IGNORE; cross.draw.connect(_draw_cross); root.add_child(cross)
	# mapa
	map_tex = load("res://data/mapa_top.png")
	map_c = Control.new(); map_c.set_anchors_preset(Control.PRESET_FULL_RECT); map_c.visible = false; map_c.draw.connect(_draw_map); root.add_child(map_c)
	# tarjeta
	card = PanelContainer.new(); card.visible = false; card.position = Vector2(390, 150); card.size = Vector2(500, 380)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.07, 0.05, 0.96); sb.border_color = Color(0.91, 0.64, 0.23); sb.set_border_width_all(2); sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb); root.add_child(card)
	card_v = VBoxContainer.new(); card_v.add_theme_constant_override("separation", 8); card.add_child(card_v)
	menu = PanelContainer.new(); menu.visible = false; menu.position = Vector2(340, 120); menu.size = Vector2(600, 460)
	var sb2 := StyleBoxFlat.new(); sb2.bg_color = Color(0.03, 0.04, 0.06, 0.97); sb2.border_color = Color(0.17, 0.23, 0.3); sb2.set_border_width_all(2); sb2.set_content_margin_all(28)
	menu.add_theme_stylebox_override("panel", sb2); root.add_child(menu)
	menu_v = VBoxContainer.new(); menu_v.add_theme_constant_override("separation", 10); menu.add_child(menu_v)
	fade_r = ColorRect.new(); fade_r.set_anchors_preset(Control.PRESET_FULL_RECT); fade_r.color = Color(0, 0, 0, 0); fade_r.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(fade_r)

func flash_weapon(n: String) -> void:
	wname.text = n; wname_t = 2.5

func message(t: String, secs: float) -> void:
	msg_l.text = t; msg_t = secs

func toggle_map() -> void:
	map_open = not map_open; map_c.visible = map_open

func _draw_cross() -> void:
	if main.player == null or menu.visible or card.visible: return
	var c := cross.size * 0.5
	var sp = 4.0 + main.player.moving * 5.0 + main.player.kick * 40.0
	var col := Color(1, 1, 1, 0.8)
	cross.draw_line(c + Vector2(-sp - 6, 0), c + Vector2(-sp, 0), col, 1.5)
	cross.draw_line(c + Vector2(sp + 6, 0), c + Vector2(sp, 0), col, 1.5)
	cross.draw_line(c + Vector2(0, -sp - 6), c + Vector2(0, -sp), col, 1.5)
	cross.draw_line(c + Vector2(0, sp + 6), c + Vector2(0, sp), col, 1.5)
	cross.draw_circle(c, 1.2, col)

func _draw_map() -> void:
	var sz := map_c.size
	var mh := sz.y - 40.0; var mw := mh * 610.0 / 860.0
	var o := Vector2((sz.x - mw) * 0.5, 20.0)
	map_c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.75))
	map_c.draw_texture_rect(map_tex, Rect2(o, Vector2(mw, mh)), false)
	var k := mw / 1220.0
	for r in GS.extras.get("refuges", []):
		var p := o + Vector2(r["x"], r["z"]) * k
		map_c.draw_circle(p, 6.0, Color(1, 0.7, 0.2))
		map_c.draw_string(ThemeDB.fallback_font, p + Vector2(8, 4), r["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.5))
	var ob: Dictionary = main.refuge.objective()
	if not ob.is_empty():
		var p = o + ob["pos"] * k
		map_c.draw_circle(p, 6.0, Color(0.3, 0.8, 1.0)); map_c.draw_circle(p, 9.0, Color(0.3, 0.8, 1.0, 0.4))
		map_c.draw_string(ThemeDB.fallback_font, p + Vector2(10, 4), ob["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.9, 1))
	for l in ["hospital", "muni", "carrefour", "monumento", "plaza"]:
		if GS.extras["lm"].has(l):
			var q: Dictionary = GS.extras["lm"][l]
			var p := o + Vector2(q["x"], q["z"]) * k
			map_c.draw_string(ThemeDB.fallback_font, p, {"hospital": "Hospital", "muni": "Municipalidad", "carrefour": "Carrefour", "monumento": "Monumento", "plaza": "Plaza"}[l], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.75, 0.8))
	var P: Node3D = main.player
	var pp := o + Vector2(P.position.x, P.position.z) * k
	var f := Vector2(-sin(P.yaw), -cos(P.yaw))
	map_c.draw_colored_polygon(PackedVector2Array([pp + f * 10.0, pp + f.rotated(2.5) * 7.0, pp + f.rotated(-2.5) * 7.0]), Color(0.4, 1.0, 0.4))
	map_c.draw_string(ThemeDB.fallback_font, Vector2(o.x, sz.y - 6), "M: cerrar el mapa", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))

# ---------------- tarjetas
func open_card(kind: String, r: Dictionary) -> void:
	card_kind = kind; card_ref = r; card.visible = true; main.set_paused(true)
	render_card("")

func close_card() -> void:
	card.visible = false; card_kind = ""; main.set_paused(false)

func render_card(note: String) -> void:
	for c in card_v.get_children(): c.queue_free()
	var k := lab(card_v, 12, Color(0.91, 0.64, 0.23)); k.text = (card_ref.get("name", "Refugio") + " · " + ("Comerciante" if card_kind == "trade" else "Mesa de pedidos")).to_upper()
	if card_kind == "trade":
		var t := lab(card_v, 20); t.text = card_ref.get("tname", "") + ": «¿Qué necesitás, pibe? Pagás con chapas.»"
		var ch := lab(card_v, 16, Color(1, 0.85, 0.5)); ch.text = "Tenés %d chapas" % GS.chapas
		for i in main.refuge.TRADE.size():
			var it: Dictionary = main.refuge.TRADE[i]
			var l := lab(card_v, 17, Color(0.95, 0.95, 0.9) if GS.chapas >= it["p"] else Color(0.6, 0.6, 0.6))
			l.text = "%d · %s  — %d chapas" % [i + 1, it["n"], it["p"]]
	else:
		var rf: Node3D = main.refuge
		var t := lab(card_v, 18); t.text = "La jefa: «Esto es lo que hace falta. Elegí uno.»" if rf.mi < 0 else "Pedido en curso: " + rf.missions[rf.mi].d["item"]
		var n := 0
		for i in rf.missions.size():
			var m: Dictionary = rf.missions[i]
			if m.state != "pend" or n >= 4: continue
			n += 1
			var l := lab(card_v, 16, Color(0.95, 0.95, 0.9) if rf.mi < 0 else Color(0.6, 0.6, 0.6))
			l.text = "%d · %s (%s) — %s" % [n, m.d["item"], m.d["who"], m.d["name"]]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.custom_minimum_size.x = 440
			m["key"] = n
		if n == 0:
			var l := lab(card_v, 16); l.text = "No queda nada por pedir. Gracias por todo."
	if note != "":
		var nl := lab(card_v, 15, Color(1, 0.8, 0.5)); nl.text = note
	var f := lab(card_v, 13, Color(0.7, 0.7, 0.7)); f.text = "1-4 elegir · E o Esc cerrar"

func card_key(k: int) -> void:
	if card_kind == "trade":
		if k >= 1 and k <= 4: render_card(main.refuge.buy(k - 1))
	elif card_kind == "missions":
		var rf: Node3D = main.refuge
		for i in rf.missions.size():
			var m: Dictionary = rf.missions[i]
			if m.state == "pend" and m.get("key", -1) == k:
				rf.accept(i); close_card(); return

# ---------------- menús
func show_menu(kind: String) -> void:
	menu_kind = kind; menu.visible = true
	for c in menu_v.get_children(): c.queue_free()
	var t := lab(menu_v, 42, Color(0.93, 0.95, 0.97)); t.text = "ZONA MUERTA"
	var s := lab(menu_v, 13, Color(0.6, 0.65, 0.7)); s.text = "Neuquén · después de Vaca Muerta · El Gallo McFlay"
	if kind == "main":
		for e in [["1", "Nueva partida"], ["2", "Continuar (cargar partida)"], ["3", "Salir"]]:
			var l := lab(menu_v, 22); l.text = e[0] + " · " + e[1]
		var h := lab(menu_v, 14, Color(0.7, 0.72, 0.75)); h.autowrap_mode = TextServer.AUTOWRAP_WORD; h.custom_minimum_size.x = 540
		h.text = "WASD moverse · Shift correr · Ctrl agacharse · Espacio saltar · Click disparar · Click der. empujar · R recargar · F linterna · E usar · M mapa · 1-9/0/G armas · Esc pausa"
	elif kind == "pause":
		for e in [["1", "Seguir"], ["2", "Guardar partida"], ["3", "Cargar partida"], ["4", "Salir al menú"]]:
			var l := lab(menu_v, 22); l.text = e[0] + " · " + e[1]
	elif kind == "dead":
		var l := lab(menu_v, 26, Color(0.9, 0.3, 0.3)); l.text = "Te comieron."
		for e in [["1", "Volver al último refugio"], ["2", "Cargar partida"], ["3", "Salir al menú"]]:
			var l2 := lab(menu_v, 22); l2.text = e[0] + " · " + e[1]
	var v := lab(menu_v, 12, Color(0.45, 0.5, 0.55)); v.text = "Godot 4.3 · versión " + main.VERSION

func hide_menu() -> void:
	menu.visible = false; menu_kind = ""

func _process(dt: float) -> void:
	var P: Node3D = main.player
	fps_l.text = "%d fps" % Engine.get_frames_per_second()
	if P == null: return
	hp_bar.size.x = 256.0 * clampf(GS.hp / 100.0, 0.0, 1.0)
	hp_bar.color = Color(0.43, 0.7, 0.29) if GS.hp > 60 else (Color(0.84, 0.63, 0.18) if GS.hp > 30 else Color(0.75, 0.22, 0.17))
	hp_txt.text = str(ceili(GS.hp))
	var d: Dictionary = P.WDAT[P.cur]; var s: Dictionary = P.WS[P.cur]
	if d["k"] == "gun": ammo.text = ("—" if P.reload_t > 0.0 else str(s["mag"])) + " / " + ("∞" if s["res"] < 0 else str(s["res"]))
	elif d["k"] == "throw": ammo.text = "x%d" % s["res"]
	else: ammo.text = ""
	wname_t -= dt; wname.modulate.a = clampf(wname_t, 0.0, 1.0) if wname_t < 1.0 else 1.0
	info.text = "%s\nBajas: %d\nCriaturas: %d\nChapas: %d" % [main.clock_text(), GS.kills, main.creatures.alive_count(), GS.chapas]
	msg_t -= dt; msg_l.modulate.a = clampf(msg_t, 0.0, 1.0)
	hint_l.text = main.hint_text()
	var ob: Dictionary = main.refuge.objective()
	if ob.is_empty(): obj_l.text = ""
	else:
		var dd = (ob["pos"] - Vector2(P.position.x, P.position.z)).length()
		var ang := atan2(ob["pos"].x - P.position.x, -(ob["pos"].y - P.position.z))
		var rel := wrapf(ang - P.yaw, -PI, PI)
		var arrow := "▲" if absf(rel) < 0.4 else ("▶" if rel > 0 and rel < 2.6 else ("◀" if rel < 0 and rel > -2.6 else "▼"))
		obj_l.text = "%s  %s  %d m" % [arrow, ob["text"], int(dd)]
	hurt_r.color.a = clampf(P.hurt * 0.55 + (0.25 + 0.15 * sin(main.time * 5.0) if GS.hp < 30 and GS.hp > 0 else 0.0), 0.0, 0.8)
	pois_r.color.a = clampf(P.poison * 0.12, 0.0, 0.45) if P.poison > 0 else 0.0
	fade_r.color.a = clampf(P.dead_t * 0.5, 0.0, 0.85) if P.dead_t >= 0.0 else maxf(0.0, fade_r.color.a - dt)
	if map_open: map_c.queue_redraw()
	cross.queue_redraw()
