extends Node2D

const DreadOverlayScript = preload("res://scripts/dread_overlay.gd")

const PlayerScript = preload("res://scripts/player.gd")
const FOUNDRY_LEVEL := "res://scenes/foundry_level.tscn"
const WORLD_WIDTH := 2400.0
const WORLD_HEIGHT := 500.0
const EVIDENCE_POSITIONS := [Vector2(420.0, 285.0), Vector2(1090.0, 205.0), Vector2(1600.0, 320.0)]
const CUTSCENE_LINES := [
	{"at": 0.8, "until": 2.7, "text": "The lift stopped. The sea did not."},
	{"at": 2.9, "until": 4.9, "text": "They said a refuge waited in the lower trench."},
	{"at": 5.1, "until": 7.2, "text": "They said my family had been sent there."},
	{"at": 7.4, "until": 9.8, "text": "I have to know if that was true."},
	{"at": 10.0, "until": 11.9, "text": "The recorders. Start there."}
]

var player: CharacterBody2D
var camera: Camera2D
var ui: CanvasLayer
var title_label: Label
var depth_label: Label
var objective_label: Label
var caption: Label
var prompt: Label
var finale_title: Label
var fade: ColorRect
var ambience: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var pressure_layer: AudioStreamPlayer
var dread_overlay: Node
var sfx_players: Array[AudioStreamPlayer] = []
var swim_sfx: AudioStreamWAV
var evidence_sfx: AudioStreamWAV
var pressure_sfx: AudioStreamWAV
var distant_sfx: AudioStreamWAV
var elapsed := 0.0
var intro_time := 0.0
var swim_sound_timer := 0.0
var distant_sound_timer := 12.0
var sfx_index := 0
var active_cutscene_line := -1
var cutscene_active := false
var evidence_found := [false, false, false]
var finale_active := false
var finale_time := 0.0
var finale_transitioned := false
var listening_was_down := false
var listen_target_index := -1
var particles: Array[Vector2] = []

func _ready() -> void:
	_setup_input()
	randomize()
	for i in range(68):
		particles.append(Vector2(randf_range(0.0, WORLD_WIDTH), randf_range(0.0, WORLD_HEIGHT)))
	_build_environment()
	_build_player()
	_build_ui()
	_build_audio()
	caption.text = "SEARCH THE WRECK FOR THREE RECORDER SIGNALS."
	prompt.text = "WASD SWIM   E LISTEN"
	_update_hud()

func _setup_input() -> void:
	_bind_if_missing("move_left", [KEY_A, KEY_LEFT])
	_bind_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_bind_if_missing("swim_up", [KEY_W, KEY_UP])
	_bind_if_missing("swim_down", [KEY_S, KEY_DOWN])
	_bind_if_missing("listen", [KEY_E])
	_bind_if_missing("interact", [KEY_F])
	_bind_if_missing("sprint", [KEY_SHIFT])

func _bind_if_missing(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)

func _build_environment() -> void:
	_add_solid(Vector2(WORLD_WIDTH * 0.5, -12.0), Vector2(WORLD_WIDTH + 60.0, 24.0))
	_add_solid(Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT + 12.0), Vector2(WORLD_WIDTH + 60.0, 24.0))
	_add_solid(Vector2(-12.0, WORLD_HEIGHT * 0.5), Vector2(24.0, WORLD_HEIGHT + 60.0))
	_add_solid(Vector2(WORLD_WIDTH + 12.0, WORLD_HEIGHT * 0.5), Vector2(24.0, WORLD_HEIGHT + 60.0))
	# Broken platforms leave a winding, readable swimming route through the wreckage.
	_add_solid(Vector2(335.0, 79.0), Vector2(210.0, 40.0))
	_add_solid(Vector2(690.0, 443.0), Vector2(220.0, 114.0))
	_add_solid(Vector2(930.0, 88.0), Vector2(190.0, 48.0))
	_add_solid(Vector2(1390.0, 445.0), Vector2(250.0, 110.0))
	_add_solid(Vector2(1825.0, 210.0), Vector2(38.0, 148.0))

func _add_solid(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Diver"
	player.set_script(PlayerScript)
	player.position = Vector2(60.0, 225.0)
	player.collision_layer = 1
	player.collision_mask = 1
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 6.0
	capsule.height = 40.0
	collision.shape = capsule
	collision.position = Vector2(0.0, -14.0)
	player.add_child(collision)
	player.underwater = true
	player.controls_enabled = true
	player.panicking = false
	add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_HEIGHT)
	player.add_child(camera)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	dread_overlay = DreadOverlayScript.new()
	ui.add_child(dread_overlay)
	var hud := Control.new()
	hud.name = "HudScale"
	hud.size = Vector2(320.0, 180.0)
	hud.scale = Vector2(2.0, 2.0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	_add_panel(hud, Rect2(7.0, 6.0, 148.0, 18.0), Color(0.012, 0.03, 0.037, 0.88))
	title_label = _add_label(hud, Vector2(11.0, 7.0), Vector2(139.0, 8.0), "LOWER TRENCH", 7, Color("d3c5a0"))
	depth_label = _add_label(hud, Vector2(11.0, 15.0), Vector2(139.0, 7.0), "418 M  //  PRESSURE RISING", 6, Color("7fa39a"))
	_add_panel(hud, Rect2(237.0, 6.0, 76.0, 18.0), Color(0.012, 0.03, 0.037, 0.8))
	objective_label = _add_label(hud, Vector2(241.0, 10.0), Vector2(70.0, 10.0), "RECORDERS  0 / 3", 6, Color("c3b68f"))
	_add_panel(hud, Rect2(8.0, 143.0, 304.0, 27.0), Color(0.008, 0.018, 0.026, 0.88))
	caption = _add_label(hud, Vector2(17.0, 146.0), Vector2(286.0, 20.0), "", 8, Color("ded7c3"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_panel(hud, Rect2(8.0, 128.0, 108.0, 12.0), Color(0.008, 0.018, 0.026, 0.74))
	prompt = _add_label(hud, Vector2(12.0, 130.0), Vector2(100.0, 8.0), "WASD SWIM   E LISTEN", 6, Color("7fa39a"))
	var controls_note := _add_label(hud, Vector2(194.0, 130.0), Vector2(118.0, 8.0), "SHIFT  KICK HARDER", 6, Color("7fa39a"))
	controls_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_panel(hud, Rect2(7.0, 34.0, 38.0, 7.0), Color(0.012, 0.03, 0.037, 0.66))
	_add_label(hud, Vector2(10.0, 34.0), Vector2(32.0, 7.0), "AIR", 5, Color("82968a"))
	var air_bar_back := ColorRect.new()
	air_bar_back.position = Vector2(28.0, 36.0)
	air_bar_back.size = Vector2(13.0, 2.0)
	air_bar_back.color = Color("26352f")
	hud.add_child(air_bar_back)
	var air_bar := ColorRect.new()
	air_bar.name = "AirBar"
	air_bar.position = Vector2(28.0, 36.0)
	air_bar.size = Vector2(10.0, 2.0)
	air_bar.color = Color("83aaa0")
	hud.add_child(air_bar)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.005, 0.012, 0.018, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	finale_title = _add_label(hud, Vector2(40.0, 67.0), Vector2(240.0, 45.0), "", 10, Color("d3c5a0"))
	finale_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finale_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	finale_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finale_title.visible = false

func _add_panel(parent: Control, rect: Rect2, tint: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = tint
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _add_label(parent: Control, at: Vector2, bounds: Vector2, value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = bounds
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_audio() -> void:
	ambience = _make_loop_player("res://audio/deep_current.wav", -11.0)
	breath_player = _make_loop_player("res://audio/helmet_breath.wav", -3.5)
	pressure_layer = _make_loop_player("res://audio/pressure_roomtone.wav", -24.0)
	swim_sfx = load("res://audio/swim_kick.wav") as AudioStreamWAV
	evidence_sfx = load("res://audio/recorder_ping.wav") as AudioStreamWAV
	pressure_sfx = load("res://audio/cliffhanger_pressure.wav") as AudioStreamWAV
	distant_sfx = load("res://audio/distant_bell.wav") as AudioStreamWAV
	for i in range(5):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.volume_db = -12.0
		add_child(sfx_player)
		sfx_players.append(sfx_player)
	if ambience:
		ambience.play()
	if breath_player:
		breath_player.play()
	if pressure_layer:
		pressure_layer.play()

func _make_loop_player(stream_path: String, level_db: float) -> AudioStreamPlayer:
	var loop_player := AudioStreamPlayer.new()
	var loop_stream := load(stream_path) as AudioStreamWAV
	if loop_stream:
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_player.stream = loop_stream
	loop_player.volume_db = level_db
	add_child(loop_player)
	return loop_player

func _play_sfx(stream: AudioStream, level_db: float, pitch_jitter := 0.03) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var sound := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	sound.stream = stream
	sound.volume_db = level_db
	sound.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	sound.play()

func _process(delta: float) -> void:
	elapsed += delta
	if fade.color.a > 0.0 and not finale_active:
		fade.color.a = maxf(0.0, fade.color.a - delta * 0.8)
	var descent := clampf((player.position.x - 60.0) / (WORLD_WIDTH - 120.0), 0.0, 1.0)
	descent = maxf(descent, clampf((player.position.y - 190.0) / 380.0, 0.0, 0.42))
	var stress := 0.20 + descent * 0.38
	if player.listening:
		stress = minf(0.88, stress + 0.17)
	if finale_active:
		stress = maxf(stress, 0.76)
	if dread_overlay:
		dread_overlay.call("set_dread", 0.15 + descent * 0.13, stress)
	if pressure_layer:
		pressure_layer.volume_db = lerpf(-25.0, -15.0, descent)
	if cutscene_active:
		_process_cutscene(delta)
		queue_redraw()
		return
	if finale_active:
		_process_finale(delta)
		queue_redraw()
		return
	if player.listening and not listening_was_down:
		_play_sfx(distant_sfx, -17.0, 0.06)
	listening_was_down = player.listening
	if player.listening:
		_update_listen_target()
		if listen_target_index >= 0:
			prompt.text = "ECHO %s  RECORDER %d" % [_bearing_name(player.listen_direction), listen_target_index + 1]
		else:
			prompt.text = "ECHO %s  RELAY" % _bearing_name(player.listen_direction)
	elif _near_recoverable_evidence():
		listen_target_index = -1
		prompt.text = "F  RECOVER RECORDER"
	elif player.position.distance_to(Vector2(2240.0, 220.0)) < 84.0:
		listen_target_index = -1
		prompt.text = "F  ACTIVATE THE RELAY"
	else:
		listen_target_index = -1
		prompt.text = "WASD SWIM   E LISTEN"
	if Input.is_action_just_pressed("interact"):
		_interact()
	swim_sound_timer -= delta
	if player.velocity.length() > 34.0 and swim_sound_timer <= 0.0:
		_play_sfx(swim_sfx, -17.0, 0.10)
		swim_sound_timer = randf_range(0.62, 0.94)
	distant_sound_timer -= delta
	if distant_sound_timer <= 0.0:
		_play_sfx(distant_sfx, -21.0, 0.08)
		distant_sound_timer = randf_range(19.0, 30.0)
	_update_hud()
	queue_redraw()

func _process_cutscene(delta: float) -> void:
	intro_time += delta
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_ESCAPE):
		_finish_cutscene()
		return
	var line_index := -1
	for i in range(CUTSCENE_LINES.size()):
		var line: Dictionary = CUTSCENE_LINES[i]
		if intro_time >= float(line["at"]) and intro_time < float(line["until"]):
			line_index = i
	if line_index != active_cutscene_line:
		active_cutscene_line = line_index
		if line_index >= 0:
			caption.text = str(CUTSCENE_LINES[line_index]["text"])
		else:
			caption.text = ""
	if intro_time >= 12.3:
		_finish_cutscene()

func _finish_cutscene() -> void:
	cutscene_active = false
	player.controls_enabled = true
	player.panicking = false
	caption.text = "FIND THE THREE RECORDER SIGNALS. LISTEN FOR THEIR ECHO."
	prompt.text = "WASD SWIM   E LISTEN"
	if breath_player:
		breath_player.volume_db = -8.5

func _process_finale(delta: float) -> void:
	finale_time += delta
	player.controls_enabled = false
	player.panicking = true
	if finale_time < 1.8:
		caption.text = "The receiver clicks. Once."
	elif finale_time < 4.4:
		caption.text = "A damaged recording repeats: \"The refuge is a lie.\""
	elif finale_time < 7.1:
		caption.text = "A freight shaft unlocks beneath the relay."
	else:
		caption.text = "The Crown sent another cohort down."
	var reveal := clampf((finale_time - 1.4) / 5.2, 0.0, 1.0)
	camera.zoom = Vector2(lerpf(2.0, 1.12, reveal), lerpf(2.0, 1.12, reveal))
	if finale_time > 6.4:
		fade.color = Color(0.003, 0.008, 0.012, clampf((finale_time - 6.4) / 1.4, 0.0, 0.72))
	if finale_time > 7.0:
		finale_title.text = "LEVEL III" + "\n" + "THE BELL FOUNDRY"
		finale_title.visible = true
		finale_title.modulate.a = clampf((10.2 - finale_time) / 1.8, 0.0, 1.0)
	if finale_time >= 10.2 and not finale_transitioned:
		finale_transitioned = true
		get_tree().change_scene_to_file(FOUNDRY_LEVEL)

func _interact() -> void:
	var closest := -1
	var closest_distance := 39.0
	for i in range(EVIDENCE_POSITIONS.size()):
		if evidence_found[i]:
			continue
		var distance: float = player.position.distance_to(EVIDENCE_POSITIONS[i])
		if distance < closest_distance:
			closest = i
			closest_distance = distance
	if closest >= 0:
		evidence_found[closest] = true
		_play_sfx(evidence_sfx, -7.0, 0.04)
		var recovered_count := _evidence_count()
		match closest:
			0:
				caption.text = "CROWN SURVEY: \"The upper veins are spent. We need ore from below.\""
			1:
				caption.text = "PROJECT ABYSSAL: \"Birth-year selections are permanent. Voices are equipment failure.\""
			2:
				caption.text = "UNSENT: \"No lower refuge. My family was never here. Something knocks below.\""
		if recovered_count == 3:
			objective_label.text = "RELAY UNLOCKED"
			prompt.text = "THE RELAY IS ANSWERING"
		else:
			prompt.text = "RECOVERED  %d / 3" % recovered_count
		_update_hud()
		return
	if player.position.distance_to(Vector2(2240.0, 220.0)) < 68.0:
		if _evidence_count() >= 3:
			finale_active = true
			finale_time = 0.0
			caption.text = "The last recorder fits the relay."
			_play_sfx(pressure_sfx, -5.0, 0.02)
			if ambience:
				ambience.volume_db = -19.0
		else:
			caption.text = "THE RELAY REQUIRES THREE RECORDER SIGNALS."
	else:
		caption.text = "Only static. Keep searching the wreck."

func _near_recoverable_evidence() -> bool:
	for i in range(EVIDENCE_POSITIONS.size()):
		if not evidence_found[i] and player.position.distance_to(EVIDENCE_POSITIONS[i]) < 39.0:
			return true
	return false

func _update_listen_target() -> void:
	listen_target_index = -1
	var nearest_distance := INF
	for i in range(EVIDENCE_POSITIONS.size()):
		if evidence_found[i]:
			continue
		var distance: float = player.position.distance_squared_to(EVIDENCE_POSITIONS[i])
		if distance < nearest_distance:
			nearest_distance = distance
			listen_target_index = i
	var target_position: Vector2 = Vector2(2240.0, 220.0)
	if listen_target_index >= 0:
		target_position = EVIDENCE_POSITIONS[listen_target_index]
	player.listen_direction = (target_position - player.position).normalized()
	if player.listen_direction.is_zero_approx():
		player.listen_direction = Vector2.RIGHT

func _bearing_name(direction: Vector2) -> String:
	var horizontal := "E" if direction.x >= 0.0 else "W"
	var vertical := "S" if direction.y >= 0.0 else "N"
	if absf(direction.x) < 0.32:
		return vertical
	if absf(direction.y) < 0.32:
		return horizontal
	return vertical + "-" + horizontal

func _evidence_count() -> int:
	var count := 0
	for found in evidence_found:
		if found:
			count += 1
	return count

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var depth := 418 + int(maxf(0.0, player.position.x - 60.0) * 0.045) + int(maxf(0.0, player.position.y - 210.0) * 0.32)
	title_label.text = "LOWER TRENCH  //  STATION IX"
	depth_label.text = "%d M  /  PRESSURE RISING" % depth
	objective_label.text = "RECORDERS  %d / 3" % _evidence_count()
	var air_bar := ui.get_node("HudScale/AirBar") as ColorRect
	air_bar.size.x = 9.0 + sin(elapsed * 1.3) * 1.5

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, WORLD_HEIGHT), Color("03090d"))
	# Stratified, almost black water with cold green light leaking from far above.
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, 110.0), Color("07151a"))
	draw_rect(Rect2(0.0, 110.0, WORLD_WIDTH, 130.0), Color("061116"))
	draw_rect(Rect2(0.0, 240.0, WORLD_WIDTH, 140.0), Color("040d12"))
	draw_rect(Rect2(0.0, 380.0, WORLD_WIDTH, 120.0), Color("03080b"))
	for shaft in range(5):
		var sx := 120.0 + float(shaft) * 520.0
		var shaft_alpha := 0.022 + (sin(elapsed * 1.4 + float(shaft) * 1.7) + 1.0) * 0.007
		if fposmod(elapsed + float(shaft) * 4.3, 27.0) < 0.15:
			shaft_alpha *= 0.18
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + 68, 0), Vector2(sx + 178, 240), Vector2(sx + 90, 240)]), Color(0.22, 0.43, 0.41, shaft_alpha))
	# Far-off industrial girders and chain hangers make the descent readable as a station exterior.
	for structure in range(15):
		var sx := float(structure) * 174.0 - 28.0
		var height := 34.0 + float((structure * 13) % 46)
		draw_rect(Rect2(sx, 45.0 + float(structure % 3) * 10.0, 5.0, height), Color("101e20"))
		draw_rect(Rect2(sx - 8.0, 54.0 + float(structure % 3) * 10.0, 21.0, 4.0), Color("172523"))
		draw_rect(Rect2(sx + 5.0, 70.0 + float(structure % 4) * 13.0, 1.0, 16.0), Color("26352f"))
		draw_rect(Rect2(sx + 7.0, 83.0 + float(structure % 4) * 13.0, 3.0, 2.0), Color("68432d"))
	for cable in range(17):
		var cx := float(cable) * 147.0 + 35.0
		var drop := 45.0 + float((cable * 29) % 105)
		draw_line(Vector2(cx, 0), Vector2(cx + sin(float(cable)) * 6.0, drop), Color("172623"), 1.0)
		draw_rect(Rect2(cx - 1.0, drop, 4.0, 3.0), Color("58442f"))
	_draw_distant_divers()
	_draw_fauna()
	# Wreck pieces match their collision shapes so the swimming lanes feel solid and fair.
	_draw_ceiling_wreck(230.0, 59.0, 210.0, 40.0)
	_draw_rubble(580.0, 386.0, 220.0, 114.0)
	_draw_ceiling_wreck(835.0, 64.0, 190.0, 48.0)
	_draw_rubble(1265.0, 390.0, 250.0, 110.0)
	_draw_girder(1806.0, 136.0, 38.0, 148.0)
	_draw_seabed()
	_draw_flora()
	_draw_aetherite()
	_draw_relay()
	for i in range(EVIDENCE_POSITIONS.size()):
		_draw_evidence(i)
	for i in range(particles.size()):
		var seed: Vector2 = particles[i]
		var particle_x := fposmod(seed.x + sin(elapsed * 0.22 + float(i)) * 2.5, WORLD_WIDTH)
		var particle_y := fposmod(seed.y - elapsed * (1.2 + float(i % 4) * 0.25), WORLD_HEIGHT)
		var alpha := 0.15 + float(i % 5) * 0.035
		draw_rect(Rect2(particle_x, particle_y, 1.0, 1.0), Color(0.58, 0.73, 0.66, alpha))
	# Slow bubble chains drift up from split pipes and the suit's damaged regulator.
	for bubble in range(22):
		var bx := float(bubble) * 111.0 + 52.0 + sin(elapsed * 1.2 + float(bubble)) * 3.0
		var by := 470.0 - fposmod(elapsed * (8.0 + float(bubble % 3) * 2.0) + float(bubble * 17), 420.0)
		draw_rect(Rect2(bx, by, 1.5, 1.5), Color(0.42, 0.67, 0.64, 0.38))
		draw_rect(Rect2(bx + 1.0, by + 1.0, 1.0, 1.0), Color(0.69, 0.82, 0.75, 0.21))
	if finale_active:
		_draw_trench_shape()

func _draw_ceiling_wreck(x: float, y: float, width: float, height: float) -> void:
	# Bright rust trim marks the actual collision footprint, while the dark face reads as heavy steel.
	draw_rect(Rect2(x, y, width, height), Color("121917"))
	draw_rect(Rect2(x + 3.0, y + 3.0, width - 12.0, 5.0), Color("344038"))
	draw_rect(Rect2(x + width - 9.0, y + 8.0, 5.0, height - 12.0), Color("202c28"))
	draw_rect(Rect2(x + 2.0, y + height - 5.0, width - 4.0, 3.0), Color("725034"))
	draw_rect(Rect2(x + 0.5, y + 0.5, width - 1.0, height - 1.0), Color("a06d3e"), false, 1.0)
	for rivet in range(int(width / 26.0)):
		var rx := x + 9.0 + float(rivet) * 25.0
		draw_rect(Rect2(rx, y + 4.0, 2.0, 2.0), Color("b27a42"))
		draw_rect(Rect2(rx + 0.5, y + 4.5, 1.0, 1.0), Color("e1bb76"))
	# Brackets stay inside the outline so nothing looks solid where the diver can pass through.
	draw_rect(Rect2(x + 22.0, y + height - 10.0, 3.0, 7.0), Color("60452f"))
	draw_rect(Rect2(x + width - 35.0, y + height - 8.0, 3.0, 5.0), Color("60452f"))

func _draw_rubble(x: float, y: float, width: float, height: float) -> void:
	# A dark, continuous shadow fills the same rectangle as its collider.
	draw_rect(Rect2(x, y, width, height), Color("101715"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y + 25.0), Vector2(x + 25.0, y + 8.0), Vector2(x + 72.0, y + 18.0),
		Vector2(x + 103.0, y + 4.0), Vector2(x + 151.0, y + 18.0), Vector2(x + width - 18.0, y + 6.0),
		Vector2(x + width, y + 30.0), Vector2(x + width, y + height), Vector2(x, y + height)
	]), Color("151b18"))
	draw_polyline(PackedVector2Array([
		Vector2(x, y + 25.0), Vector2(x + 25.0, y + 8.0), Vector2(x + 72.0, y + 18.0),
		Vector2(x + 103.0, y + 4.0), Vector2(x + 151.0, y + 18.0), Vector2(x + width - 18.0, y + 6.0),
		Vector2(x + width, y + 30.0)
	]), Color("a06d3e"), 1.0, false)
	draw_rect(Rect2(x + 30.0, y + 30.0, width - 60.0, 5.0), Color("51402c"))
	draw_rect(Rect2(x + 52.0, y + 23.0, 3.0, 12.0), Color("875336"))
	draw_rect(Rect2(x + width * 0.68, y + 31.0, 4.0, 8.0), Color("8d5b37"))
	for i in range(8):
		var patch_x := x + float(i) * width / 8.0 + 7.0
		draw_rect(Rect2(patch_x, y + 38.0 + float(i % 3) * 8.0, 13.0, 3.0), Color("222822"))
	draw_rect(Rect2(x + 0.5, y + 0.5, width - 1.0, height - 1.0), Color("795537"), false, 1.0)
	for bolt_x in [x + 5.0, x + width - 7.0]:
		draw_rect(Rect2(bolt_x, y + 48.0, 2.0, 2.0), Color("bf8750"))

func _draw_girder(x: float, y: float, width: float, height: float) -> void:
	draw_rect(Rect2(x, y, width, height), Color("101715"))
	draw_rect(Rect2(x + 5.0, y + 3.0, 5.0, height - 6.0), Color("334038"))
	draw_rect(Rect2(x + 1.0, y + 15.0, width - 2.0, 7.0), Color("795336"))
	draw_rect(Rect2(x + 4.0, y + 18.0, width - 8.0, 2.0), Color("bd8451"))
	draw_rect(Rect2(x + 0.5, y + 0.5, width - 1.0, height - 1.0), Color("a06d3e"), false, 1.0)
	for rivet_y in range(int(y + 30.0), int(y + height - 10.0), 22):
		draw_rect(Rect2(x + 2.0, float(rivet_y), 2.0, 2.0), Color("d0aa69"))

func _draw_seabed() -> void:
	draw_rect(Rect2(0.0, 478.0, WORLD_WIDTH, 22.0), Color("090d0c"))
	draw_rect(Rect2(0.0, 474.0, WORLD_WIDTH, 5.0), Color("1a201a"))
	for i in range(51):
		var x := float(i) * 49.0 + float((i * 19) % 17)
		var h := 5.0 + float((i * 11) % 19)
		var plant_color := Color("12211c") if i % 3 else Color("172921")
		draw_rect(Rect2(x, 474.0 - h, 2.0, h), plant_color)
		draw_rect(Rect2(x - 2.0, 474.0 - h * 0.62, 4.0, 2.0), plant_color)
	for i in range(22):
		var x := float(i) * 109.0 + 18.0
		draw_rect(Rect2(x, 468.0, 13.0, 6.0), Color("242a22"))
		draw_rect(Rect2(x + 2.0, 465.0, 7.0, 4.0), Color("30342a"))
		# Layered shell lip and a few worn chalk bands make each stone read as a prop.
		draw_rect(Rect2(x + 3.0, 466.0, 5.0, 1.0), Color("69725b", 0.72))
		draw_rect(Rect2(x + 4.0, 468.0, 1.0, 2.0), Color("181c17"))
	for pebble in range(74):
		var px := float((pebble * 67) % int(WORLD_WIDTH - 4.0)) + 2.0
		var py := 470.0 + float((pebble * 13) % 8)
		var pebble_color := Color("354036") if pebble % 4 == 0 else Color("242d27")
		draw_rect(Rect2(px, py, 1.0 + float(pebble % 3), 1.0), pebble_color)
		if pebble % 7 == 0:
			draw_rect(Rect2(px + 1.0, py - 1.0, 1.0, 1.0), Color("6b7058", 0.56))

func _draw_fauna() -> void:
	# Moving shoals are small, directional silhouettes; they drift freely through the open water.
	for school in range(5):
		var direction := 1.0 if school % 2 == 0 else -1.0
		var travel := fposmod(elapsed * (11.0 + float(school % 3) * 3.0) + float(school) * 493.0, WORLD_WIDTH + 180.0)
		var lead_x := travel - 90.0 if direction > 0.0 else WORLD_WIDTH + 90.0 - travel
		var base_y := 88.0 + float((school * 61) % 272) + sin(elapsed * 0.48 + float(school)) * 9.0
		var fish_count := 3 + school % 3
		var fish_color := Color(0.27, 0.62, 0.62, 0.55) if school % 2 == 0 else Color(0.43, 0.68, 0.58, 0.48)
		for fish in range(fish_count):
			var fish_x := lead_x - direction * float(fish) * 15.0
			var fish_y := base_y + sin(elapsed * 1.2 + float(fish) * 1.7 + float(school)) * 4.0
			var fish_size := 0.68 + float((fish + school) % 3) * 0.16
			_draw_ambient_fish(Vector2(fish_x, fish_y), direction, fish_size, fish_color)
	# Blue-violet jellyfish bob independently, with soft bells and visible trailing tentacles.
	for jelly in range(4):
		var jelly_x := fposmod(195.0 + float(jelly) * 557.0 + elapsed * (3.0 + float(jelly % 2)), WORLD_WIDTH)
		var jelly_y := 132.0 + float((jelly * 73) % 178) + sin(elapsed * 0.62 + float(jelly) * 2.0) * 12.0
		var bell_pulse := 0.8 + (sin(elapsed * 2.2 + float(jelly)) + 1.0) * 0.12
		_draw_ambient_jelly(Vector2(jelly_x, jelly_y), bell_pulse, jelly)

func _draw_distant_divers() -> void:
	# Old suits hang beyond the wreck. They never approach, though their weak lights answer yours.
	var silhouettes: Array[Vector2] = [Vector2(690.0, 274.0), Vector2(1178.0, 284.0), Vector2(1988.0, 250.0)]
	for index in range(silhouettes.size()):
		var phase := float(index) * 2.17
		var apparition := maxf(0.0, sin(elapsed * 0.24 + phase))
		var opacity := 0.075 + apparition * 0.22
		var drift := sin(elapsed * 0.13 + phase) * 5.0
		var position: Vector2 = silhouettes[index] + Vector2(drift, sin(elapsed * 0.27 + phase) * 1.0)
		var visor_flash := maxf(0.0, sin(elapsed * 0.23 + phase + 1.2) - 0.985) * 5.5
		_draw_distant_diver_shadow(position, opacity, visor_flash)

func _draw_distant_diver_shadow(position: Vector2, opacity: float, visor_flash: float) -> void:
	var shade := Color(0.025, 0.043, 0.044, opacity)
	var edge := Color(0.15, 0.19, 0.17, opacity * 0.82)
	var x := position.x
	var y := position.y
	# Old helmet, stiff shoulders, dangling tank and separated boots resolve only briefly in the murk.
	draw_rect(Rect2(x - 4.0, y - 29.0, 8.0, 2.0), shade)
	draw_rect(Rect2(x - 6.0, y - 27.0, 12.0, 9.0), shade)
	draw_rect(Rect2(x - 5.0, y - 26.0, 10.0, 7.0), edge)
	draw_rect(Rect2(x - 2.0, y - 24.0, 5.0, 4.0), Color(0.012, 0.022, 0.024, opacity * 1.2))
	draw_rect(Rect2(x + 1.0, y - 23.0, 1.0, 1.0), Color(0.68, 0.86, 0.78, visor_flash))
	draw_rect(Rect2(x - 7.0, y - 18.0, 14.0, 3.0), edge)
	draw_rect(Rect2(x - 5.0, y - 16.0, 10.0, 11.0), shade)
	draw_rect(Rect2(x - 8.0, y - 15.0, 3.0, 9.0), shade)
	draw_rect(Rect2(x + 5.0, y - 15.0, 3.0, 9.0), shade)
	draw_rect(Rect2(x - 10.0, y - 7.0, 4.0, 2.0), edge)
	draw_rect(Rect2(x + 6.0, y - 7.0, 4.0, 2.0), edge)
	draw_rect(Rect2(x - 8.0, y - 14.0, 3.0, 12.0), shade)
	draw_rect(Rect2(x + 5.0, y - 14.0, 3.0, 12.0), shade)
	draw_rect(Rect2(x - 7.0, y - 3.0, 5.0, 3.0), shade)
	draw_rect(Rect2(x + 2.0, y - 3.0, 5.0, 3.0), shade)
	draw_rect(Rect2(x - 10.0, y - 27.0, 3.0, 8.0), shade)
	draw_line(Vector2(x - 8.0, y - 21.0), Vector2(x - 5.0, y - 14.0), edge, 1.0, false)

func _draw_ambient_fish(position: Vector2, direction: float, scale: float, fish_color: Color) -> void:
	var tail_swing: float = sin(elapsed * 9.0 + position.x * 0.08) * 1.65 * scale
	var tail := PackedVector2Array([
		position + Vector2(-5.0 * direction, 0.0) * scale,
		position + Vector2(-8.0 * direction, -3.0 + tail_swing) * scale,
		position + Vector2(-7.0 * direction, tail_swing * 0.28) * scale,
		position + Vector2(-8.0 * direction, 3.0 + tail_swing) * scale
	])
	var body := PackedVector2Array([
		position + Vector2(-5.0 * direction, 0.0) * scale,
		position + Vector2(-3.0 * direction, -2.0) * scale,
		position + Vector2(1.0 * direction, -2.0) * scale,
		position + Vector2(5.0 * direction, -1.0) * scale,
		position + Vector2(7.0 * direction, 0.0) * scale,
		position + Vector2(5.0 * direction, 1.0) * scale,
		position + Vector2(1.0 * direction, 2.0) * scale,
		position + Vector2(-3.0 * direction, 2.0) * scale
	])
	draw_colored_polygon(tail, Color(fish_color.r * 0.76, fish_color.g * 0.83, fish_color.b * 0.9, fish_color.a * 0.86))
	draw_colored_polygon(body, fish_color)
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(-1.0 * direction, -1.0) * scale,
		position + Vector2(1.0 * direction, -4.0) * scale,
		position + Vector2(3.0 * direction, -1.0) * scale
	]), Color(fish_color.r * 0.86, fish_color.g * 0.95, fish_color.b, fish_color.a))
	var fin_sweep: float = sin(elapsed * 6.2 + position.x * 0.06) * 1.2 * scale
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(0.0 * direction, 1.0) * scale,
		position + Vector2(-1.0 * direction, 3.0 + fin_sweep) * scale,
		position + Vector2(2.0 * direction, 1.0) * scale
	]), Color(fish_color.r * 0.72, fish_color.g * 0.84, fish_color.b * 0.88, fish_color.a * 0.82))
	# Three stepped scale glints and a gill line keep the tiny silhouettes readable in the murk.
	for scale_mark in range(3):
		var mark_x := -1.0 + float(scale_mark) * 2.0
		draw_rect(Rect2(position + Vector2(mark_x * direction, -0.5) * scale, Vector2(1.0, 0.6) * scale), Color(0.78, 0.89, 0.78, fish_color.a * 0.50))
	draw_line(position + Vector2(3.0 * direction, -1.0) * scale, position + Vector2(2.0 * direction, 1.0) * scale, Color(fish_color.r * 0.62, fish_color.g * 0.76, fish_color.b * 0.78, fish_color.a * 0.85), 0.65 * scale, false)
	var eye := position + Vector2(5.0 * direction, -0.5) * scale
	draw_rect(Rect2(eye, Vector2(1.0, 1.0)), Color(0.77, 0.91, 0.79, fish_color.a))

func _draw_ambient_jelly(position: Vector2, pulse: float, variant: int) -> void:
	var bell_color := Color(0.35, 0.58, 0.77, 0.42 + pulse * 0.12) if variant % 2 == 0 else Color(0.40, 0.66, 0.68, 0.38 + pulse * 0.12)
	draw_rect(Rect2(position.x - 7.0, position.y - 5.0, 14.0, 5.0), Color(0.22, 0.57, 0.70, 0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(position.x - 7.0, position.y), Vector2(position.x - 6.0, position.y - 4.0 * pulse),
		Vector2(position.x - 3.0, position.y - 7.0 * pulse), Vector2(position.x + 3.0, position.y - 7.0 * pulse),
		Vector2(position.x + 6.0, position.y - 4.0 * pulse), Vector2(position.x + 7.0, position.y),
		Vector2(position.x + 4.0, position.y + 1.0), Vector2(position.x - 4.0, position.y + 1.0)
	]), bell_color)
	for tentacle in range(4):
		var start := Vector2(position.x - 4.5 + float(tentacle) * 3.0, position.y + 1.0)
		var sway := sin(elapsed * 2.0 + float(tentacle) + float(variant)) * 2.0
		var finish := start + Vector2(sway, 7.0 + float(tentacle % 2) * 3.0)
		draw_line(start, finish, Color(0.45, 0.69, 0.81, 0.38), 1.0, false)
		draw_rect(Rect2(finish, Vector2(1.0, 1.0)), Color(0.70, 0.92, 0.94, 0.64))
	draw_rect(Rect2(position.x - 2.0, position.y - 4.0, 1.0, 1.0), Color(0.76, 0.96, 0.90, 0.74))

func _draw_flora() -> void:
	# Anchored kelp has rooted stalks and broad, swaying leaves, unlike the free-moving fauna.
	var kelp_positions: Array[float] = [118.0, 315.0, 478.0, 872.0, 1132.0, 1584.0, 1718.0, 1924.0, 2107.0, 2314.0]
	for index in range(kelp_positions.size()):
		var height := 44.0 + float((index * 17) % 39)
		_draw_kelp(kelp_positions[index], 474.0, height, index)
	var coral_positions: Array[float] = [256.0, 526.0, 1005.0, 1203.0, 1565.0, 1978.0, 2172.0]
	for index in range(coral_positions.size()):
		_draw_tube_anemone(coral_positions[index], 474.0, index)

func _draw_kelp(x: float, base_y: float, height: float, variant: int) -> void:
	var sway_phase := elapsed * (0.7 + float(variant % 3) * 0.12) + float(variant) * 1.8
	var previous := Vector2(x, base_y)
	var stalk_color := Color("214d43") if variant % 2 == 0 else Color("285347")
	var leaf_color := Color("2d7060") if variant % 2 == 0 else Color("3c7960")
	var highlight := Color(0.39, 0.74, 0.57, 0.62)
	for step in range(1, 8):
		var t := float(step) / 7.0
		var current := Vector2(x + sin(sway_phase + t * 2.3) * (2.0 + t * 4.0), base_y - height * t)
		draw_line(previous, current, Color("0e2724"), 3.0, false)
		draw_line(previous, current, stalk_color, 1.0, false)
		if step % 2 == 0:
			var side := -1.0 if (step + variant) % 4 == 0 else 1.0
			var leaf_length := 7.0 + float((step + variant) % 3) * 2.0
			var leaf_base := current + Vector2(side * 1.0, -0.5)
			var tip := current + Vector2(side * leaf_length, -2.0 - float(step % 3))
			var mid := leaf_base.lerp(tip, 0.57) + Vector2(side * 1.0, -1.5)
			var leaf_edge := mid + Vector2(-side * 1.7, 1.4)
			# Broad, tapered blades give the kelp a distinct silhouette at the 2x camera scale.
			draw_colored_polygon(PackedVector2Array([leaf_base, mid, tip, leaf_edge]), leaf_color)
			draw_line(leaf_base + Vector2(side, 0.0), mid, highlight, 0.8, false)
			draw_line(mid, tip, Color(0.22, 0.48, 0.39, 0.78), 0.65, false)
			draw_rect(Rect2(mid.x - 0.5, mid.y + 1.0, 1.0, 1.0), Color("163c34"))
			if (step + variant) % 3 == 0:
				draw_rect(Rect2(tip.x, tip.y, 1.0, 1.0), Color(0.64, 0.85, 0.61, 0.58))
		previous = current
	draw_rect(Rect2(previous.x - 1.0, previous.y - 2.0, 2.0, 2.0), Color(0.52, 0.86, 0.62, 0.78))

func _draw_tube_anemone(x: float, base_y: float, variant: int) -> void:
	var count := 4 + variant % 3
	var center_glow := Color(0.28, 0.66, 0.62, 0.68)
	for tube in range(count):
		var offset := float(tube) * 3.0 - float(count - 1) * 1.5
		var height := 11.0 + float((tube + variant) % 4) * 3.0
		var lean := sin(elapsed * 1.1 + float(tube + variant)) * 1.3
		var start := Vector2(x + offset, base_y - 1.0)
		var tip := Vector2(x + offset + lean, base_y - height)
		draw_line(start, tip, Color("153c35"), 2.0, false)
		draw_line(start, tip, Color(0.29, 0.63, 0.54, 0.70), 1.0, false)
		draw_rect(Rect2(tip.x - 1.0, tip.y - 1.0, 3.0, 2.0), center_glow)
		draw_rect(Rect2(tip.x, tip.y - 2.0, 1.0, 1.0), Color(0.71, 0.93, 0.69, 0.72))

func _draw_aetherite() -> void:
	for cluster in range(9):
		var x := 96.0 + float(cluster) * 267.0
		var y := 452.0 - float((cluster * 13) % 35)
		var glow := 0.25 + (sin(elapsed * 1.8 + float(cluster)) + 1.0) * 0.11
		draw_rect(Rect2(x - 5.0, y - 3.0, 16.0, 12.0), Color(0.20, 0.66, 0.55, glow * 0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 4, y - 13), Vector2(x + 8, y - 2), Vector2(x + 6, y + 4)]), Color("27564a"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 7, y + 2), Vector2(x + 12, y - 8), Vector2(x + 14, y + 4)]), Color("38816a"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 4.0, y - 10.0), Vector2(x + 5.5, y - 3.0), Vector2(x + 3.5, y + 1.0)]), Color("397762"))
		draw_rect(Rect2(x - 2.0, y + 2.0, 19.0, 3.0), Color("141c18"))
		draw_rect(Rect2(x, y + 4.0, 14.0, 1.0), Color("746041", 0.75))
		draw_rect(Rect2(x + 3.0, y - 8.0, 1.0, 5.0), Color(0.63, 0.91, 0.72, glow))
		draw_rect(Rect2(x + 9.0, y - 2.0, 1.0, 3.0), Color(0.63, 0.91, 0.72, glow * 0.72))
		draw_rect(Rect2(x + 2.0, y - 5.0, 1.0, 1.0), Color(0.82, 0.97, 0.78, glow * 0.82))

func _draw_evidence(index: int) -> void:
	var position: Vector2 = EVIDENCE_POSITIONS[index]
	var bob := sin(elapsed * 1.7 + float(index) * 2.0) * 2.0
	if player.listening and listen_target_index == index and not evidence_found[index]:
		var pulse := 0.22 + (sin(elapsed * 4.0 + float(index)) + 1.0) * 0.13
		draw_arc(position, 18.0 + bob, 0.0, TAU, 24, Color(0.36, 0.78, 0.69, pulse), 1.0, true)
		draw_arc(position, 27.0 + bob, 0.0, TAU, 24, Color(0.36, 0.78, 0.69, pulse * 0.52), 1.0, true)
	if evidence_found[index]:
		draw_rect(Rect2(position.x - 8.0, position.y - 7.0 + bob, 16.0, 13.0), Color("252c26"))
		draw_rect(Rect2(position.x - 6.0, position.y - 5.0 + bob, 12.0, 9.0), Color("434437"))
		draw_rect(Rect2(position.x - 4.0, position.y - 4.0 + bob, 5.0, 2.0), Color("a4834e"))
		draw_rect(Rect2(position.x + 2.0, position.y - 1.0 + bob, 2.0, 2.0), Color("83aaa0"))
	else:
		draw_rect(Rect2(position.x - 8.0, position.y - 8.0 + bob, 16.0, 15.0), Color("101916"))
		draw_rect(Rect2(position.x - 6.0, position.y - 6.0 + bob, 12.0, 11.0), Color("443b2c"))
		draw_rect(Rect2(position.x - 5.0, position.y - 5.0 + bob, 10.0, 2.0), Color("927047"))
		draw_rect(Rect2(position.x - 3.0, position.y - 2.0 + bob, 7.0, 4.0), Color("172527"))
		draw_rect(Rect2(position.x - 1.0, position.y - 1.0 + bob, 2.0, 1.0), Color("709b8a"))
		draw_rect(Rect2(position.x - 11.0, position.y + 6.0 + bob, 22.0, 2.0), Color("131a18"))

func _draw_relay() -> void:
	var x := 2240.0
	var y := 220.0
	var glow := 0.20 + (sin(elapsed * 2.1) + 1.0) * 0.08
	draw_rect(Rect2(x - 39.0, y - 56.0, 78.0, 118.0), Color("0d1514"))
	draw_rect(Rect2(x - 35.0, y - 52.0, 70.0, 110.0), Color("292d25"))
	draw_rect(Rect2(x - 29.0, y - 45.0, 58.0, 93.0), Color("111d1e"))
	draw_rect(Rect2(x - 27.0, y - 43.0, 54.0, 4.0), Color("90643a"))
	draw_rect(Rect2(x - 24.0, y - 38.0, 48.0, 61.0), Color("192526"))
	draw_rect(Rect2(x - 21.0, y - 35.0, 42.0, 4.0), Color("39433a"))
	for i in range(3):
		var dial_x := x - 18.0 + float(i) * 18.0
		draw_rect(Rect2(dial_x, y - 24.0, 12.0, 14.0), Color("111715"))
		draw_rect(Rect2(dial_x + 1.0, y - 23.0, 10.0, 12.0), Color("7e6040"))
		draw_rect(Rect2(dial_x + 3.0, y - 21.0, 6.0, 8.0), Color("163036"))
		draw_rect(Rect2(dial_x + 5.0, y - 20.0, 2.0, 5.0), Color(0.46, 0.80, 0.69, glow))
	draw_rect(Rect2(x - 17.0, y + 1.0, 34.0, 19.0), Color("35352a"))
	draw_rect(Rect2(x - 13.0, y + 4.0, 26.0, 12.0), Color("182527"))
	draw_rect(Rect2(x - 8.0, y + 8.0, 16.0, 3.0), Color(0.32, 0.82, 0.68, glow))
	draw_rect(Rect2(x - 3.0, y + 57.0, 6.0, 24.0), Color("222823"))
	draw_rect(Rect2(x - 34.0, y + 57.0, 68.0, 5.0), Color("58422e"))
	for bolt in [-30.0, 29.0]:
		draw_rect(Rect2(x + bolt, y - 47.0, 2.0, 2.0), Color("c1975e"))
	if finale_active and _evidence_count() >= 3:
		draw_arc(Vector2(x, y - 2.0), 50.0 + sin(elapsed * 2.0) * 2.0, 0.0, TAU, 28, Color(0.35, 0.78, 0.65, 0.18), 1.0, true)

func _draw_trench_shape() -> void:
	var reveal := clampf((finale_time - 1.2) / 5.0, 0.0, 1.0)
	var x := 2240.0
	var top := lerpf(510.0, 330.0, reveal)
	# A vast old diving helmet rises from below, too large to fit the frame.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 118.0, top + 108.0), Vector2(x - 103.0, top + 51.0), Vector2(x - 70.0, top + 19.0),
		Vector2(x - 40.0, top + 2.0), Vector2(x + 44.0, top + 2.0), Vector2(x + 87.0, top + 27.0),
		Vector2(x + 112.0, top + 85.0), Vector2(x + 126.0, top + 170.0), Vector2(x - 126.0, top + 170.0)
	]), Color("020608"))
	draw_rect(Rect2(x - 43.0, top + 69.0, 86.0, 46.0), Color("010405"))
	draw_rect(Rect2(x - 35.0, top + 75.0, 70.0, 32.0), Color(0.19, 0.43, 0.39, 0.14 + reveal * 0.10))
	draw_rect(Rect2(x - 25.0, top + 83.0, 12.0, 4.0), Color(0.70, 0.94, 0.73, 0.45 * reveal))
	draw_rect(Rect2(x + 13.0, top + 83.0, 12.0, 4.0), Color(0.70, 0.94, 0.73, 0.40 * reveal))
	draw_line(Vector2(x - 30.0, top + 93.0), Vector2(x - 17.0, top + 89.0), Color(0.60, 0.79, 0.66, 0.28 * reveal), 2.0)
	draw_line(Vector2(x + 14.0, top + 89.0), Vector2(x + 27.0, top + 94.0), Color(0.60, 0.79, 0.66, 0.28 * reveal), 2.0)

