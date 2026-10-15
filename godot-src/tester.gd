extends Node
# Pruebas automáticas: --  "cmd;cmd;..." (wait:s, new, shot:nombre, key:KEY, hold:KEY:s, look:yaw:pitch, tp:x:z, spawn:Nombre:dist, fl:0/1, eval)
var main: Node3D
var cmds: Array = []
var wait_t := 0.0
var done := false
func _ready() -> void:
	main = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("test="):
			for c in a.substr(5).split(";"): cmds.append(c)
	if cmds.is_empty(): queue_free()
func _process(dt: float) -> void:
	if done: return
	wait_t -= dt
	if wait_t > 0.0: return
	if cmds.is_empty():
		done = true; get_tree().quit(); return
	var c: String = cmds.pop_front(); var a := c.split(":")
	match a[0]:
		"wait": wait_t = float(a[1])
		"new": main.new_game()
		"shot":
			var img := get_viewport().get_texture().get_image(); img.save_png("/tmp/cr/%s.png" % a[1]); print("SHOT ", a[1])
		"key":
			var e := InputEventKey.new(); e.keycode = OS.find_keycode_from_string(a[1]); e.physical_keycode = e.keycode; e.pressed = true; print("KEY ", a[1], " -> ", e.keycode); Input.parse_input_event(e)
			cmds.push_front("release:" + a[1]); wait_t = 0.05
		"hold":
			var e := InputEventKey.new(); e.keycode = OS.find_keycode_from_string(a[1]); e.pressed = true; Input.parse_input_event(e); wait_t = float(a[2])
			cmds.push_front("release:" + a[1])
		"release":
			var e := InputEventKey.new(); e.keycode = OS.find_keycode_from_string(a[1]); e.pressed = false; Input.parse_input_event(e)
		"look": main.player.yaw = float(a[1]); main.player.pitch = float(a[2])
		"tp": main.player.spawn_at(float(a[1]), float(a[2]), 0.03, main.player.yaw)
		"spawn":
			var P: Node3D = main.player; var f: Vector3 = P.fwd(); var d := float(a[2])
			var z: Dictionary = main.creatures.spawn(a[1] if a[1] != "comun" else "", true, Vector2(P.position.x + f.x * d, P.position.z + f.z * d))
			if not z.is_empty(): z.state = "chase"
		"fl": main.player.fl_on = a[1] == "1"; main.player.flash.visible = main.player.fl_on
		"fire":
			var P: Node3D = main.player; P.attack()
		"stats":
			print("STATS hp=", GS.hp, " zs=", main.creatures.zs.size(), " alive=", main.creatures.alive_count(), " fps=", Engine.get_frames_per_second(), " pos=", main.player.position, " chapas=", GS.chapas)
		"time": main.day_time = float(a[1]) * 60.0
