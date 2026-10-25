extends Node2D

const DreadOverlayScript = preload("res://scripts/dread_overlay.gd")

const PlayerScript = preload("res://scripts/player.gd")
const ABYSSAL_CREATURE_TEXTURE = preload("res://art/abyssal_creature.png")
const ABYSSAL_CREATURE_FRONT_OPEN = preload("res://art/abyssal_creature_front_open.png")
const ABYSSAL_CREATURE_FRONT_CLOSED = preload("res://art/abyssal_creature_front_closed.png")
const WORLD_WIDTH := 2280.0
const WORLD_HEIGHT := 620.0
const ARCHIVE_POSITIONS := [Vector2(352.0, 375.0), Vector2(895.0, 192.0), Vector2(1378.0, 414.0)]
const FALSE_ECHO_POSITIONS := [Vector2(690.0, 354.0), Vector2(1195.0, 255.0)]
const DEAD_DIVER_POSITIONS := [Vector2(352.0, 375.0), Vector2(895.0, 192.0), Vector2(1378.0, 414.0), Vector2(1855.0, 478.0)]
const ARCHIVE_NAMES := ["M. VENN / 1531", "E. MARROW / 1531", "J. ROOK / 1531"]
const OPTIONAL_RECORDING_POSITION := Vector2(1515.0, 132.0)
const BELL_POSITION := Vector2(2070.0, 308.0)

var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var title_label: Label
var depth_label: Label
var objective_label: Label
var caption: Label
var prompt: Label
var fade: ColorRect
var dread_overlay: Node
var finale_title: Label
var finale_backdrop: ColorRect
var ambience: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var pressure_layer: AudioStreamPlayer
var distant_bell: AudioStreamWAV
var recorder_ping: AudioStreamWAV
var swim_sfx: AudioStreamWAV
var pressure_sfx: AudioStreamWAV
var bowed_creature_reveal: AudioStreamWAV
var bowed_creature_lunge: AudioStreamWAV
var bowed_creature_body: AudioStreamWAV
var iron_groan: AudioStreamWAV
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index := 0
var evidence_found := [false, false, false]
var particles: Array[Vector2] = []
var elapsed := 0.0
var bell_timer := 8.0
var groan_timer := 17.0
var swim_timer := 0.0
var listen_target_index := -1
var false_echo_index := -1
var listening_was_down := false
var finale_active := false
var finale_complete := false
var finale_time := 0.0
var final_jumpscare_active := false
var final_end_screen_active := false
var final_jumpscare_time := 0.0
var final_end_screen_time := 0.0
var creature_reveal_sting_played := false
var final_bow_lunge_played := false
var final_bow_body_played := false
var optional_recording_found := false
var creature_seen := false
var creature_sighting_active := false
var creature_sighting_time := 0.0
var creature_position := Vector2.ZERO

func _ready() -> void:
	_setup_input()
	randomize()
	for i in range(92):
		particles.append(Vector2(randf_range(0.0, WORLD_WIDTH), randf_range(0.0, WORLD_HEIGHT)))
	_build_environment()
	_build_player()
	_build_ui()
	_build_audio()
	caption.text = "THE BELL IS A RECORDING. THE DEAD STILL WEAR THEIR NAMES."
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
	_add_solid(Vector2(WORLD_WIDTH * 0.5, -12.0), Vector2(WORLD_WIDTH + 80.0, 24.0))
	_add_solid(Vector2(WORLD_WIDTH * 0.5, WORLD_HEIGHT + 12.0), Vector2(WORLD_WIDTH + 80.0, 24.0))
	_add_solid(Vector2(-12.0, WORLD_HEIGHT * 0.5), Vector2(24.0, WORLD_HEIGHT + 80.0))
	_add_solid(Vector2(WORLD_WIDTH + 12.0, WORLD_HEIGHT * 0.5), Vector2(24.0, WORLD_HEIGHT + 80.0))
	# Large ruins leave a winding channel open. Their silhouettes and collision shapes match.
	_add_solid(Vector2(300.0, 49.0), Vector2(370.0, 98.0))
	_add_solid(Vector2(560.0, 592.0), Vector2(430.0, 56.0))
	_add_solid(Vector2(900.0, 52.0), Vector2(340.0, 104.0))
	_add_solid(Vector2(1295.0, 587.0), Vector2(410.0, 66.0))
	_add_solid(Vector2(1660.0, 330.0), Vector2(54.0, 270.0))
	_add_solid(Vector2(1880.0, 53.0), Vector2(230.0, 106.0))

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
	player.position = Vector2(72.0, 438.0)
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
	player.panicking = true
	add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.3
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = int(WORLD_HEIGHT)
	player.add_child(camera)

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	dread_overlay = DreadOverlayScript.new()
	hud.add_child(dread_overlay)
	var panel := Control.new()
	panel.name = "HudScale"
	panel.size = Vector2(320.0, 180.0)
	panel.scale = Vector2(2.0, 2.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	_add_panel(panel, Rect2(7.0, 6.0, 162.0, 18.0), Color(0.012, 0.025, 0.027, 0.91))
	title_label = _add_label(panel, Vector2(11.0, 7.0), Vector2(152.0, 8.0), "THE BELL FOUNDRY", 7, Color("d3c5a0"))
	depth_label = _add_label(panel, Vector2(11.0, 15.0), Vector2(152.0, 7.0), "611 M  //  NO ASCENT", 6, Color("8b9180"))
	_add_panel(panel, Rect2(237.0, 6.0, 76.0, 18.0), Color(0.012, 0.025, 0.027, 0.86))
	objective_label = _add_label(panel, Vector2(241.0, 10.0), Vector2(70.0, 10.0), "COHORT  0 / 3", 6, Color("b79a69"))
	_add_panel(panel, Rect2(8.0, 143.0, 304.0, 27.0), Color(0.006, 0.014, 0.018, 0.92))
	caption = _add_label(panel, Vector2(17.0, 146.0), Vector2(286.0, 20.0), "", 8, Color("d5d0be"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_panel(panel, Rect2(8.0, 128.0, 108.0, 12.0), Color(0.006, 0.014, 0.018, 0.82))
	prompt = _add_label(panel, Vector2(12.0, 130.0), Vector2(100.0, 8.0), "WASD SWIM   E LISTEN", 6, Color("82988a"))
	var controls_note := _add_label(panel, Vector2(194.0, 130.0), Vector2(118.0, 8.0), "SHIFT  KICK HARDER", 6, Color("82988a"))
	controls_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_panel(panel, Rect2(7.0, 34.0, 38.0, 7.0), Color(0.006, 0.014, 0.018, 0.72))
	_add_label(panel, Vector2(10.0, 34.0), Vector2(32.0, 7.0), "AIR", 5, Color("78877c"))
	var air_back := ColorRect.new()
	air_back.position = Vector2(28.0, 36.0)
	air_back.size = Vector2(13.0, 2.0)
	air_back.color = Color("26322e")
	panel.add_child(air_back)
	var air_bar := ColorRect.new()
	air_bar.name = "AirBar"
	air_bar.position = Vector2(28.0, 36.0)
	air_bar.size = Vector2(10.0, 2.0)
	air_bar.color = Color("839286")
	panel.add_child(air_bar)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.004, 0.009, 0.012, 0.68)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fade)
	finale_backdrop = _add_panel(panel, Rect2(31.0, 59.0, 258.0, 62.0), Color(0.008, 0.012, 0.014, 0.94))
	finale_backdrop.visible = false
	finale_title = _add_label(panel, Vector2(40.0, 66.0), Vector2(240.0, 46.0), "", 10, Color("c7b894"))
	finale_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finale_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	finale_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finale_title.visible = false

func _add_panel(parent: Control, rect: Rect2, tint: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = tint
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _add_label(parent: Control, at: Vector2, bounds: Vector2, value: String, size: int, tint: Color) -> Label:
	var node := Label.new()
	node.position = at
	node.size = bounds
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", tint)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _build_audio() -> void:
	ambience = _make_loop("res://audio/deep_current.wav", -14.0)
	breath_player = _make_loop("res://audio/helmet_breath.wav", -9.0)
	pressure_layer = _make_loop("res://audio/pressure_roomtone.wav", -23.0)
	distant_bell = load("res://audio/distant_bell.wav") as AudioStreamWAV
	recorder_ping = load("res://audio/recorder_ping.wav") as AudioStreamWAV
	swim_sfx = load("res://audio/swim_kick.wav") as AudioStreamWAV
	pressure_sfx = load("res://audio/cliffhanger_pressure.wav") as AudioStreamWAV
	bowed_creature_reveal = load("res://audio/bowed_creature_reveal.wav") as AudioStreamWAV
	bowed_creature_lunge = load("res://audio/bowed_creature_lunge.wav") as AudioStreamWAV
	bowed_creature_body = load("res://audio/bowed_creature_body.wav") as AudioStreamWAV
	iron_groan = load("res://audio/iron_keel_groan.wav") as AudioStreamWAV
	for i in range(5):
		var sound := AudioStreamPlayer.new()
		sound.volume_db = -14.0
		add_child(sound)
		sfx_players.append(sound)
	if ambience:
		ambience.play()
	if breath_player:
		breath_player.play()
	if pressure_layer:
		pressure_layer.play()

func _make_loop(path: String, level_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.stream = stream
	sound.volume_db = level_db
	add_child(sound)
	return sound

func _play_sfx(stream: AudioStream, level_db: float, jitter := 0.04, pitch_multiplier := 1.0) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var sound := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	sound.stream = stream
	sound.volume_db = level_db
	sound.pitch_scale = pitch_multiplier * randf_range(1.0 - jitter, 1.0 + jitter)
	sound.play()

func _process(delta: float) -> void:
	elapsed += delta
	if final_jumpscare_active:
		_process_final_jumpscare(delta)
		queue_redraw()
		return
	if final_end_screen_active:
		final_end_screen_time += delta
		finale_title.modulate.a = clampf((final_end_screen_time - 0.18) / 0.95, 0.0, 1.0)
		finale_backdrop.color.a = lerpf(0.0, 0.96, clampf(final_end_screen_time / 0.38, 0.0, 1.0))
		queue_redraw()
		return
	_update_environmental_current()
	var distance_to_bell := player.position.distance_to(BELL_POSITION)
	var dread_stress := 0.24 + maxf(0.0, 1.0 - distance_to_bell / 760.0) * 0.24
	if player.listening:
		dread_stress += 0.18
	if creature_sighting_active:
		dread_stress = 1.0
	if finale_active:
		dread_stress = 0.92
	if dread_overlay:
		dread_overlay.call("set_dread", 0.21 + maxf(0.0, 1.0 - player.position.x / WORLD_WIDTH) * 0.05, dread_stress)
	if pressure_layer:
		pressure_layer.volume_db = -23.0 + dread_stress * 8.0
	groan_timer -= delta
	if groan_timer <= 0.0 and not creature_sighting_active and not finale_active:
		_play_sfx(iron_groan, -25.0, 0.14)
		groan_timer = randf_range(34.0, 52.0)
	if creature_sighting_active:
		_process_creature_sighting(delta)
		queue_redraw()
		return
	if fade.color.a > 0.0 and not finale_active:
		fade.color.a = maxf(0.0, fade.color.a - delta * 0.44)
	if finale_active:
		_process_finale(delta)
		queue_redraw()
		return
	if player.listening and not listening_was_down:
		_play_sfx(distant_bell, -23.0, 0.05)
	listening_was_down = player.listening
	if player.listening:
		_update_listen_target()
		if false_echo_index >= 0:
			prompt.text = "ECHO %s  BROKEN LOOP" % _bearing_name(player.listen_direction)
		elif listen_target_index >= 0:
			prompt.text = "ECHO %s  COHORT %d" % [_bearing_name(player.listen_direction), listen_target_index + 1]
		else:
			prompt.text = "ECHO %s  THE BELL" % _bearing_name(player.listen_direction)
	elif not optional_recording_found and player.position.distance_to(OPTIONAL_RECORDING_POSITION) < 36.0:
		listen_target_index = -1
		prompt.text = "F  PLAY LOOSE CYLINDER"
	elif _near_recoverable_archive():
		listen_target_index = -1
		prompt.text = "F  READ THE NAMEPLATE"
	elif player.position.distance_to(BELL_POSITION) < 106.0:
		listen_target_index = -1
		prompt.text = "F  EXAMINE THE BELL"
	else:
		listen_target_index = -1
		prompt.text = "WASD SWIM   E LISTEN"
	if Input.is_action_just_pressed("interact"):
		_interact()
	swim_timer -= delta
	if player.velocity.length() > 34.0 and swim_timer <= 0.0:
		_play_sfx(swim_sfx, -20.0, 0.12)
		swim_timer = randf_range(0.9, 1.35)
	bell_timer -= delta
	if bell_timer <= 0.0:
		_play_sfx(distant_bell, -26.0, 0.03)
		bell_timer = randf_range(21.0, 32.0)
	_update_hud()
	queue_redraw()

func _start_creature_sighting() -> void:
	creature_seen = true
	creature_sighting_active = true
	creature_sighting_time = 0.0
	creature_reveal_sting_played = false
	creature_position = player.position + Vector2(355.0, -17.0)
	player.velocity = Vector2.ZERO
	player.environmental_current = Vector2.ZERO
	player.controls_enabled = false
	player.panicking = true
	player.listening = false
	prompt.text = ""
	caption.text = "A pale shape drifts beyond the stone arch."
	camera.offset = Vector2.ZERO
	if ambience:
		ambience.volume_db = -26.0
	if breath_player:
		breath_player.volume_db = -3.5
	for sound in sfx_players:
		sound.stop()
	# Leave a breath of near-silence before the creature's rough, bowed-string swell.

func _process_creature_sighting(delta: float) -> void:
	creature_sighting_time += delta
	if creature_sighting_time >= 0.34 and not creature_reveal_sting_played:
		creature_reveal_sting_played = true
		_play_sfx(bowed_creature_reveal, -6.5, 0.0, 0.88)
	creature_position.x -= 140.0 * delta
	creature_position.y = player.position.y - 17.0 + sin(elapsed * 0.72) * 1.6 + sin(elapsed * 2.15) * 0.48
	camera.offset = Vector2(sin(elapsed * 24.0) * 0.55, sin(elapsed * 17.0) * 0.34)
	if creature_sighting_time < 1.8:
		caption.text = "A pale shape drifts beyond the stone arch."
	elif creature_sighting_time < 4.0:
		caption.text = "No lamp. No bubbles. It is far larger than the diver."
	else:
		caption.text = "Your suit records only empty water."
	if creature_sighting_time >= 5.5:
		creature_sighting_active = false
		for sound in sfx_players:
			sound.stop()
		camera.offset = Vector2.ZERO
		player.controls_enabled = true
		player.panicking = false
		caption.text = "The current settles. The nameplates remain."
		prompt.text = "WASD SWIM   E LISTEN"
		if ambience:
			ambience.volume_db = -14.0
		if breath_player:
			breath_player.volume_db = -9.0

func _process_finale(delta: float) -> void:
	finale_time += delta
	player.controls_enabled = false
	player.panicking = true
	if pressure_layer:
		pressure_layer.volume_db = lerpf(-16.0, -9.0, clampf(finale_time / 8.0, 0.0, 1.0))
	if breath_player:
		breath_player.volume_db = lerpf(-8.0, -3.0, clampf(finale_time / 7.0, 0.0, 1.0))
	if finale_time < 2.0:
		caption.text = "The bell's cylinder turns. A voice plays from its cracked horn."
	elif finale_time < 4.5:
		caption.text = "\"Your families are safe below. Descend for Rhegan.\""
	elif finale_time < 7.0:
		caption.text = "The same promise that sent every cohort down."
	else:
		caption.text = "The hoist keeps descending. There is no ascent."
	if finale_time < 1.2:
		camera.offset = Vector2(sin(elapsed * 33.0) * 1.2, sin(elapsed * 22.0) * 0.8)
	else:
		camera.offset = Vector2(sin(elapsed * 2.7) * 0.38, sin(elapsed * 1.9) * 0.28)
	if finale_time > 3.0:
		fade.color = Color(0.003, 0.008, 0.011, clampf((finale_time - 3.0) / 3.6, 0.0, 0.58))
	if finale_time > 6.0:
		finale_title.text = "COHORT 1548" + "\n" + "RETURN NOT AUTHORISED"
		finale_title.visible = true
		finale_title.modulate.a = clampf((10.0 - finale_time) / 2.0, 0.0, 1.0)
	if finale_time > 10.0:
		finale_complete = true
		_start_final_jumpscare()

func _start_final_jumpscare() -> void:
	finale_active = false
	final_jumpscare_active = true
	final_end_screen_active = false
	final_jumpscare_time = 0.0
	final_end_screen_time = 0.0
	final_bow_lunge_played = false
	final_bow_body_played = false
	player.controls_enabled = false
	player.panicking = true
	player.velocity = Vector2.ZERO
	player.listening = false
	player.visible = false
	camera.offset = Vector2.ZERO
	caption.text = ""
	prompt.text = ""
	finale_title.visible = false
	finale_backdrop.visible = false
	fade.color.a = 0.0
	var hud_panel := hud.get_node("HudScale") as Control
	for child in hud_panel.get_children():
		child.visible = false
	for sound in sfx_players:
		sound.stop()
	if ambience:
		ambience.volume_db = -60.0
	if breath_player:
		breath_player.stop()
	if pressure_layer:
		pressure_layer.volume_db = -60.0
	# A short pocket of silence lets the following bowed attack feel close and physical.

func _process_final_jumpscare(delta: float) -> void:
	final_jumpscare_time += delta
	player.controls_enabled = false
	player.panicking = true
	player.velocity = Vector2.ZERO
	if final_jumpscare_time >= 0.20 and not final_bow_lunge_played:
		final_bow_lunge_played = true
		_play_sfx(bowed_creature_lunge, -4.5, 0.0, 1.08)
	if final_jumpscare_time >= 0.72 and not final_bow_body_played:
		final_bow_body_played = true
		_play_sfx(bowed_creature_body, -12.0, 0.0, 1.0)
	var head_lunge := clampf((final_jumpscare_time - 0.20) / 0.72, 0.0, 1.0)
	if final_jumpscare_time < 0.92:
		var recoil := sin(final_jumpscare_time * 28.0) * head_lunge
		camera.offset = Vector2(sin(elapsed * 43.0) * head_lunge * 2.0 + recoil * 1.0, sin(elapsed * 37.0) * head_lunge * 1.6 - recoil * 0.6)
	else:
		var bite_phase := (final_jumpscare_time - 0.92) * TAU * 1.52
		var bite_snap := pow(maxf(0.0, cos(bite_phase)), 2.4)
		camera.offset = Vector2(sin(elapsed * 47.0) * (0.35 + bite_snap * 2.7), sin(elapsed * 41.0) * (0.28 + bite_snap * 1.7))
	if final_jumpscare_time >= 2.90:
		for sound in sfx_players:
			sound.stop()
		final_jumpscare_active = false
		final_end_screen_active = true
		final_end_screen_time = 0.0
		camera.offset = Vector2.ZERO
		finale_title.text = "DEMO OVER\nTHANKS FOR PLAYING"
		finale_title.visible = true
		finale_title.modulate = Color(0.78, 0.76, 0.68, 0.0)
		finale_title.add_theme_font_size_override("font_size", 12)
		finale_backdrop.visible = true
		finale_backdrop.color.a = 0.0
		player.controls_enabled = false
		player.panicking = false
		caption.text = ""
		prompt.text = ""

func _update_environmental_current() -> void:
	var position := player.position
	var current := Vector2.ZERO
	if position.x > 500.0 and position.x < 790.0 and position.y > 165.0:
		current = Vector2(-14.0, sin(elapsed * 0.8) * 5.0)
	elif position.x > 1100.0 and position.x < 1510.0 and position.y < 545.0:
		current = Vector2(-8.0, 12.0 + sin(elapsed * 0.55) * 3.0)
	player.environmental_current = current

func _interact() -> void:
	if not optional_recording_found and player.position.distance_to(OPTIONAL_RECORDING_POSITION) < 36.0:
		optional_recording_found = true
		_play_sfx(recorder_ping, -9.0, 0.03)
		caption.text = "PAYROLL 1531: \"Crown scrip is worthless in Rhegan. The mine shop is closed. They still deduct its prices from our wages.\""
		prompt.text = "OPTIONAL RECORDING FOUND"
		return
	var nearest_index := -1
	var nearest_distance := 43.0
	for i in range(ARCHIVE_POSITIONS.size()):
		if evidence_found[i]:
			continue
		var distance: float = player.position.distance_to(ARCHIVE_POSITIONS[i])
		if distance < nearest_distance:
			nearest_index = i
			nearest_distance = distance
	if nearest_index >= 0:
		evidence_found[nearest_index] = true
		_play_sfx(recorder_ping, -8.0, 0.03)
		match nearest_index:
			0:
				caption.text = "M. VENN / SHIFT LOG / 1531: \"We cast the bell frame from chapel bronze. The foreman says it must hang before the next shift.\""
			1:
				caption.text = "E. MARROW / HABITATION COUNT / 1531: \"Cots: 43. Blankets: 43. Workers on roll: 19. The other names remain assigned to night shift.\""
			2:
				caption.text = "J. ROOK / FITTER'S NOTE / 1531: \"I removed the clapper at dawn. At dusk the bell rang. No one entered it in the ledger.\""
		if _archive_count() == 3:
			objective_label.text = "COHORT  3 / 3"
			prompt.text = "FIND THE BELL"
		else:
			prompt.text = "PLATE RECOVERED  %d / 3" % _archive_count()
		_update_hud()
		if _archive_count() >= 2 and not creature_seen:
			_start_creature_sighting()
		return
	if player.position.distance_to(BELL_POSITION) < 106.0:
		if _archive_count() >= 3 and not finale_complete:
			finale_active = true
			finale_time = 0.0
			caption.text = "A stamped cylinder is locked inside the bell."
			_play_sfx(pressure_sfx, -7.0, 0.02)
			_play_sfx(distant_bell, -11.0, 0.02)
			if ambience:
				ambience.volume_db = -21.0
			if pressure_layer:
				pressure_layer.volume_db = -12.0
		elif _archive_count() < 3:
			caption.text = "The hoist mechanism is sealed. Recover the cohort records."
		else:
			caption.text = "The cylinder only repeats the Crown's promise."
	elif _near_false_echo():
		caption.text = "A broken line repeats: \"Your family is below.\" No name. No reply."
	else:
		caption.text = "A dead line. The bell is repeating somewhere below."

func _near_recoverable_archive() -> bool:
	for i in range(ARCHIVE_POSITIONS.size()):
		if not evidence_found[i] and player.position.distance_to(ARCHIVE_POSITIONS[i]) < 43.0:
			return true
	return false

func _update_listen_target() -> void:
	listen_target_index = -1
	false_echo_index = -1
	var nearest_distance := INF
	var target := BELL_POSITION
	if _archive_count() < 3:
		for i in range(ARCHIVE_POSITIONS.size()):
			if evidence_found[i]:
				continue
			var distance: float = player.position.distance_squared_to(ARCHIVE_POSITIONS[i])
			if distance < nearest_distance:
				nearest_distance = distance
				listen_target_index = i
		for i in range(FALSE_ECHO_POSITIONS.size()):
			var distance: float = player.position.distance_squared_to(FALSE_ECHO_POSITIONS[i])
			if distance < nearest_distance:
				nearest_distance = distance
				listen_target_index = -1
				false_echo_index = i
				target = FALSE_ECHO_POSITIONS[i]
		if listen_target_index >= 0:
			target = ARCHIVE_POSITIONS[listen_target_index]
	player.listen_direction = (target - player.position).normalized()
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

func _archive_count() -> int:
	var count := 0
	for found in evidence_found:
		if found:
			count += 1
	return count

func _near_false_echo() -> bool:
	for position in FALSE_ECHO_POSITIONS:
		if player.position.distance_to(position) < 40.0:
			return true
	return false

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var depth := 611 + int(maxf(0.0, player.position.x - 72.0) * 0.035) + int(maxf(0.0, player.position.y - 260.0) * 0.22)
	title_label.text = "THE BELL FOUNDRY"
	depth_label.text = "%d M  //  NO ASCENT" % depth
	objective_label.text = "COHORT  %d / 3" % _archive_count() if not finale_complete else "COHORT  1548"
	var air_bar := hud.get_node("HudScale/AirBar") as ColorRect
	air_bar.size.x = 8.5 + sin(elapsed * 1.1) * 1.1

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, WORLD_HEIGHT), Color("020709"))
	# The works are built into a drowned stone cathedral, then plated over with iron and brass.
	draw_rect(Rect2(0.0, 0.0, WORLD_WIDTH, 155.0), Color("071114"))
	draw_rect(Rect2(0.0, 155.0, WORLD_WIDTH, 205.0), Color("050c10"))
	draw_rect(Rect2(0.0, 360.0, WORLD_WIDTH, 240.0), Color("03080b"))
	_draw_abyssal_creature()
	for shaft in range(4):
		var x := 175.0 + float(shaft) * 605.0
		var flicker := 0.012 + (sin(elapsed * 0.7 + float(shaft) * 1.9) + 1.0) * 0.006
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 45.0, 0.0), Vector2(x + 162.0, 295.0), Vector2(x + 90.0, 295.0)]), Color(0.24, 0.39, 0.34, flicker))
	_draw_drowned_arch(120.0, 33.0, 415.0, 302.0, 0)
	_draw_drowned_arch(610.0, 82.0, 390.0, 249.0, 1)
	_draw_drowned_arch(1120.0, 24.0, 455.0, 335.0, 2)
	_draw_drowned_arch(1745.0, 60.0, 355.0, 300.0, 3)
	_draw_hoist()
	_draw_empty_vein()
	_draw_broken_structures()
	_draw_bell()
	_draw_seabed()
	_draw_dead_divers()
	_draw_archive_plates()
	_draw_optional_recording()
	_draw_false_echoes()
	_draw_current_streams()
	_draw_aetherite_seams()
	for i in range(particles.size()):
		var origin: Vector2 = particles[i]
		var px := fposmod(origin.x + sin(elapsed * 0.13 + float(i)) * 2.0, WORLD_WIDTH)
		var py := fposmod(origin.y - elapsed * (0.55 + float(i % 5) * 0.16), WORLD_HEIGHT)
		var alpha := 0.10 + float(i % 6) * 0.025
		draw_rect(Rect2(px, py, 1.0, 1.0), Color(0.62, 0.69, 0.61, alpha))
	for bubble in range(18):
		var bx := float(bubble) * 127.0 + 61.0 + sin(elapsed * 0.7 + float(bubble)) * 2.0
		var by := WORLD_HEIGHT - fposmod(elapsed * (5.0 + float(bubble % 4)), WORLD_HEIGHT - 80.0)
		draw_rect(Rect2(bx, by, 1.0, 1.0), Color(0.51, 0.67, 0.63, 0.29))
	if finale_active:
		var tremor := sin(finale_time * 31.0) * clampf(finale_time, 0.0, 1.0) * 2.0
		draw_rect(Rect2(BELL_POSITION.x - 57.0 + tremor, BELL_POSITION.y - 8.0, 114.0, 4.0), Color("a07543"))
	if final_jumpscare_active or final_end_screen_active:
		_draw_final_jumpscare()

func _draw_drowned_arch(x: float, y: float, width: float, height: float, variant: int) -> void:
	var stone := Color("101816") if variant % 2 == 0 else Color("121916")
	var edge := Color("3f4033") if variant % 2 == 0 else Color("493e2f")
	var pillar_width := 22.0 + float(variant % 2) * 4.0
	draw_rect(Rect2(x, y + height * 0.43, pillar_width, height * 0.57), stone)
	draw_rect(Rect2(x + width - pillar_width, y + height * 0.43, pillar_width, height * 0.57), stone)
	draw_rect(Rect2(x - 4.0, y + height * 0.43, pillar_width + 8.0, 7.0), edge)
	draw_rect(Rect2(x + width - pillar_width - 4.0, y + height * 0.43, pillar_width + 8.0, 7.0), edge)
	draw_rect(Rect2(x + 8.0, y + height * 0.43 - 8.0, width - 16.0, 14.0), stone)
	draw_arc(Vector2(x + width * 0.5, y + height * 0.43), width * 0.5 - 10.0, PI, TAU, 30, edge, 7.0, false)
	draw_arc(Vector2(x + width * 0.5, y + height * 0.43), width * 0.5 - 20.0, PI, TAU, 30, stone, 4.0, false)
	draw_rect(Rect2(x + pillar_width + 7.0, y + height * 0.43 + 1.0, 2.0, height * 0.56), Color("252c26"))
	draw_rect(Rect2(x + width - pillar_width - 10.0, y + height * 0.43 + 1.0, 2.0, height * 0.56), Color("242b27"))
	# The older stonework is laid in uneven courses beneath the later metalwork.
	for course in range(5):
		var course_y := y + height * 0.43 + 24.0 + float(course) * 34.0
		if course_y >= y + height - 8.0:
			continue
		var left_offset := 0.0 if course % 2 == 0 else 7.0
		var right_offset := 0.0 if course % 2 != 0 else 6.0
		draw_rect(Rect2(x + 3.0 + left_offset, course_y, pillar_width - 8.0, 1.0), Color("2b322a"))
		draw_rect(Rect2(x + 3.0 + left_offset, course_y + 1.0, pillar_width - 11.0, 0.7), Color("080f0e"))
		draw_rect(Rect2(x + width - pillar_width + 4.0 + right_offset, course_y, pillar_width - 8.0, 1.0), Color("30352b"))
		draw_rect(Rect2(x + width - pillar_width + 4.0 + right_offset, course_y + 1.0, pillar_width - 11.0, 0.7), Color("080f0e"))
	for chisel in range(7):
		var mark_x := x + 12.0 + float((chisel * 17 + variant * 9) % int(maxf(20.0, width - 24.0)))
		var mark_y := y + height * 0.43 + 36.0 + float((chisel * 23) % int(maxf(24.0, height * 0.38)))
		draw_line(Vector2(mark_x, mark_y), Vector2(mark_x + 2.5, mark_y + 3.0), Color("4a4838", 0.64), 0.8, false)
		draw_rect(Rect2(mark_x + 2.0, mark_y + 3.0, 1.0, 1.0), Color("101613"))
	for rivet in range(6):
		var rx := x + 40.0 + float(rivet) * (width - 80.0) / 5.0
		draw_rect(Rect2(rx, y + height * 0.43 - 2.0, 2.0, 2.0), Color("98734a"))
	# Corroded Crown plates remain nailed over the older carved stone.
	draw_rect(Rect2(x + width * 0.5 - 24.0, y + height * 0.43 + 17.0, 48.0, 14.0), Color("0b1111"))
	draw_rect(Rect2(x + width * 0.5 - 21.0, y + height * 0.43 + 20.0, 42.0, 2.0), Color("655139"))
	draw_rect(Rect2(x + width * 0.5 - 15.0, y + height * 0.43 + 25.0, 30.0, 1.0), Color("715b3c"))
	# Water has eaten into the stone and left rusty runoff beneath the iron fasteners.
	for seam in range(3):
		var seam_x := x + 44.0 + float(seam) * (width - 88.0) / 2.0
		var seam_y := y + height * 0.43 + 9.0 + float((seam + variant) % 2) * 4.0
		draw_rect(Rect2(seam_x, seam_y, 1.0, 9.0 + float((variant + seam) % 3) * 3.0), Color("332d24"))
		draw_rect(Rect2(seam_x + 1.0, seam_y + 4.0, 1.0, 5.0), Color("493526"))
	for chip in range(5):
		var chip_x := x + 17.0 + float((chip * 53 + variant * 19) % int(maxf(20.0, width - 34.0)))
		var chip_y := y + height * 0.43 + 15.0 + float((chip * 7 + variant) % 18)
		draw_rect(Rect2(chip_x, chip_y, 3.0, 1.0), Color("080e0d"))
		draw_rect(Rect2(chip_x + 1.0, chip_y + 1.0, 2.0, 1.0), Color("262821"))
	# Small barnacle clusters sit on the shaded side of each drowned pillar.
	for cluster in range(3):
		var barnacle_x := x + (width - pillar_width - 5.0 if cluster % 2 == 0 else 4.0)
		var barnacle_y := y + height * 0.63 + float(cluster) * 37.0
		draw_rect(Rect2(barnacle_x, barnacle_y, 3.0, 2.0), Color("394036"))
		draw_rect(Rect2(barnacle_x + 1.0, barnacle_y - 1.0, 2.0, 1.0), Color("56604a"))

func _draw_hoist() -> void:
	# The ascent cage is visibly sheared off. Its cable vanishes upward beyond the frame.
	draw_rect(Rect2(74.0, 0.0, 5.0, 146.0), Color("151a16"))
	draw_rect(Rect2(77.0, 0.0, 1.0, 98.0), Color("746044"))
	draw_rect(Rect2(45.0, 139.0, 68.0, 8.0), Color("171e1a"))
	draw_rect(Rect2(49.0, 141.0, 60.0, 2.0), Color("99764c"))
	for bar in range(5):
		var bx := 52.0 + float(bar) * 13.0
		draw_rect(Rect2(bx, 147.0, 3.0, 73.0), Color("222a24"))
		draw_rect(Rect2(bx + 1.0, 149.0, 1.0, 68.0), Color("6e5a40"))
	draw_rect(Rect2(44.0, 216.0, 69.0, 8.0), Color("171e1a"))
	draw_rect(Rect2(49.0, 218.0, 59.0, 2.0), Color("70563b"))
	draw_line(Vector2(75.0, 216.0), Vector2(60.0, 238.0), Color("604d37"), 3.0, false)
	draw_line(Vector2(82.0, 216.0), Vector2(94.0, 236.0), Color("604d37"), 3.0, false)
	draw_rect(Rect2(61.0, 236.0, 34.0, 7.0), Color("181e1a"))
	draw_rect(Rect2(63.0, 237.0, 30.0, 2.0), Color("745839"))
	for rivet_y in [150.0, 211.0]:
		for rivet_x in [48.0, 105.0]:
			draw_rect(Rect2(rivet_x, rivet_y, 2.0, 2.0), Color("b28c54"))
	draw_colored_polygon(PackedVector2Array([Vector2(77.0, 98.0), Vector2(92.0, 111.0), Vector2(82.0, 127.0), Vector2(68.0, 117.0)]), Color("070b0b"))

func _draw_empty_vein() -> void:
	# The extraction cut is scraped bare; only old drill marks and a few dead crystals remain.
	draw_colored_polygon(PackedVector2Array([
		Vector2(145.0, 486.0), Vector2(209.0, 414.0), Vector2(281.0, 462.0),
		Vector2(332.0, 423.0), Vector2(401.0, 478.0), Vector2(452.0, 447.0),
		Vector2(494.0, 516.0), Vector2(433.0, 576.0), Vector2(217.0, 580.0)
	]), Color("101612"))
	draw_polyline(PackedVector2Array([Vector2(208.0, 487.0), Vector2(262.0, 461.0), Vector2(321.0, 500.0), Vector2(388.0, 475.0), Vector2(434.0, 516.0)]), Color("504331"), 3.0, false)
	for mark in range(9):
		var mx := 226.0 + float(mark % 3) * 48.0
		var my := 500.0 + float(mark / 3) * 18.0
		draw_line(Vector2(mx, my), Vector2(mx + 15.0, my - 5.0), Color("624d36"), 2.0, false)
	draw_colored_polygon(PackedVector2Array([Vector2(312.0, 475.0), Vector2(318.0, 452.0), Vector2(323.0, 477.0)]), Color("25483d"))
	draw_rect(Rect2(317.0, 463.0, 2.0, 7.0), Color("46725b"))

func _draw_broken_structures() -> void:
	# Collision footprints: upper masonry slab, fallen lower works, and the shear pillar.
	draw_rect(Rect2(115.0, 0.0, 370.0, 98.0), Color("151916"))
	draw_rect(Rect2(122.0, 88.0, 354.0, 5.0), Color("59472f"))
	draw_rect(Rect2(124.0, 92.0, 348.0, 2.0), Color("917046"))
	for bolt in range(12):
		var bx := 135.0 + float(bolt) * 29.0
		draw_rect(Rect2(bx, 89.0, 2.0, 2.0), Color("c09254"))
		if bolt % 2 == 0:
			draw_rect(Rect2(bx + 3.0, 94.0, 14.0, 1.0), Color("3b3d31", 0.82))
			draw_rect(Rect2(bx + 5.0, 95.0, 1.0, 2.0), Color("927046", 0.76))
	draw_rect(Rect2(345.0, 566.0, 430.0, 54.0), Color("111713"))
	draw_rect(Rect2(352.0, 566.0, 415.0, 6.0), Color("5b4830"))
	draw_polyline(PackedVector2Array([Vector2(349.0, 566.0), Vector2(385.0, 548.0), Vector2(432.0, 566.0), Vector2(488.0, 543.0), Vector2(536.0, 566.0)]), Color("907044"), 2.0, false)
	draw_rect(Rect2(730.0, 0.0, 340.0, 104.0), Color("151916"))
	draw_rect(Rect2(737.0, 94.0, 326.0, 5.0), Color("59472f"))
	for bolt in range(10):
		var bx := 751.0 + float(bolt) * 31.0
		draw_rect(Rect2(bx, 95.0, 2.0, 2.0), Color("b0834b"))
		if bolt % 2 == 1:
			draw_rect(Rect2(bx + 4.0, 91.0, 12.0, 1.0), Color("34392f", 0.82))
			draw_rect(Rect2(bx + 5.0, 92.0, 1.0, 2.0), Color("765d3c", 0.78))
	draw_rect(Rect2(1090.0, 559.0, 410.0, 61.0), Color("101612"))
	draw_rect(Rect2(1100.0, 560.0, 388.0, 6.0), Color("59472f"))
	draw_rect(Rect2(1274.0, 0.0, 42.0, 195.0), Color("121815"))
	draw_rect(Rect2(1281.0, 0.0, 5.0, 187.0), Color("55442f"))
	draw_rect(Rect2(1633.0, 195.0, 54.0, 270.0), Color("111714"))
	draw_rect(Rect2(1642.0, 197.0, 5.0, 266.0), Color("58462f"))
	draw_rect(Rect2(1648.0, 305.0, 39.0, 6.0), Color("927046"))
	draw_rect(Rect2(1765.0, 0.0, 230.0, 106.0), Color("141815"))
	draw_rect(Rect2(1771.0, 96.0, 217.0, 5.0), Color("59472f"))
	# Broken chain hoists, mineral carts, and abandoned tools lie outside the swimming lane.
	for chain in range(12):
		var cx := 555.0 + float(chain) * 44.0
		var drop := 175.0 + float((chain * 37) % 124)
		draw_line(Vector2(cx, 0.0), Vector2(cx + sin(float(chain)) * 5.0, drop), Color("352e22"), 2.0, false)
		draw_rect(Rect2(cx - 2.0, drop, 5.0, 3.0), Color("6b5234"))
	for cart in [670.0, 1185.0, 1515.0]:
		draw_rect(Rect2(cart, 500.0, 54.0, 8.0), Color("1a201b"))
		draw_rect(Rect2(cart + 3.0, 502.0, 48.0, 2.0), Color("76583a"))
		for wheel in [cart + 9.0, cart + 43.0]:
			draw_arc(Vector2(wheel, 513.0), 5.0, 0.0, TAU, 12, Color("70563a"), 2.0, false)
		draw_rect(Rect2(cart + 7.0, 488.0, 37.0, 10.0), Color("26251e"))
		draw_rect(Rect2(cart + 13.0, 485.0, 12.0, 4.0), Color("5d4830"))
		draw_rect(Rect2(cart + 28.0, 486.0, 9.0, 3.0), Color("384438"))

func _draw_bell() -> void:
	var x := BELL_POSITION.x
	var y := BELL_POSITION.y
	var sway := sin(elapsed * 0.35) * 1.2
	var glow := 0.12 + (sin(elapsed * 0.8) + 1.0) * 0.035
	draw_rect(Rect2(x - 105.0, y - 99.0, 210.0, 210.0), Color(0.22, 0.35, 0.31, glow * 0.24))
	# A massive foundry bell hangs in its frame, pitted and silent until its dead cylinder turns.
	draw_rect(Rect2(x - 93.0, y - 119.0, 186.0, 11.0), Color("101612"))
	draw_rect(Rect2(x - 85.0, y - 116.0, 170.0, 4.0), Color("705438"))
	draw_rect(Rect2(x - 71.0, y - 111.0, 10.0, 74.0), Color("181c17"))
	draw_rect(Rect2(x + 61.0, y - 111.0, 10.0, 74.0), Color("181c17"))
	draw_rect(Rect2(x - 69.0, y - 108.0, 5.0, 68.0), Color("795c39"))
	draw_rect(Rect2(x + 62.0, y - 108.0, 5.0, 68.0), Color("795c39"))
	draw_rect(Rect2(x - 38.0 + sway, y - 83.0, 76.0, 21.0), Color("433b2a"))
	draw_rect(Rect2(x - 31.0 + sway, y - 78.0, 62.0, 9.0), Color("90704a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 29.0 + sway, y - 72.0), Vector2(x + 29.0 + sway, y - 72.0),
		Vector2(x + 38.0 + sway, y - 34.0), Vector2(x + 51.0 + sway, y + 21.0),
		Vector2(x + 62.0 + sway, y + 35.0), Vector2(x - 62.0 + sway, y + 35.0),
		Vector2(x - 51.0 + sway, y + 21.0), Vector2(x - 38.0 + sway, y - 34.0)
	]), Color("22251e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 26.0 + sway, y - 68.0), Vector2(x + 26.0 + sway, y - 68.0),
		Vector2(x + 34.0 + sway, y - 31.0), Vector2(x + 45.0 + sway, y + 19.0),
		Vector2(x + 53.0 + sway, y + 29.0), Vector2(x - 53.0 + sway, y + 29.0),
		Vector2(x - 45.0 + sway, y + 19.0), Vector2(x - 34.0 + sway, y - 31.0)
	]), Color("64513a"))
	draw_rect(Rect2(x - 26.0 + sway, y - 64.0, 52.0, 7.0), Color("96744a"))
	draw_rect(Rect2(x - 43.0 + sway, y - 14.0, 86.0, 6.0), Color("302d23"))
	# Hammered facets and an old foundry seal break up the otherwise broad bronze face.
	for dent in range(18):
		var dent_x := x - 39.0 + float((dent * 29) % 78) + sway
		var dent_y := y - 53.0 + float((dent * 17) % 76)
		var dent_color := Color("392f24", 0.68) if dent % 2 == 0 else Color("92734b", 0.48)
		draw_rect(Rect2(dent_x, dent_y, 1.5 + float(dent % 2), 1.0), dent_color)
		draw_rect(Rect2(dent_x + 1.0, dent_y + 1.0, 1.0, 1.0), Color("514332", 0.68))
	draw_rect(Rect2(x - 18.0 + sway, y - 50.0, 36.0, 26.0), Color("393a2c", 0.78))
	draw_rect(Rect2(x - 15.0 + sway, y - 47.0, 30.0, 1.0), Color("a07a4b", 0.86))
	draw_arc(Vector2(x + sway, y - 39.0), 10.0, PI, TAU, 12, Color("b18a55", 0.88), 1.0, false)
	draw_rect(Rect2(x - 8.0 + sway, y - 38.0, 16.0, 1.0), Color("98734a"))
	draw_rect(Rect2(x - 3.0 + sway, y - 45.0, 6.0, 11.0), Color("222820"))
	draw_rect(Rect2(x - 1.0 + sway, y - 43.0, 2.0, 7.0), Color("b08a54"))
	for seal_bolt in [-15.0, 14.0]:
		draw_rect(Rect2(x + seal_bolt + sway, y - 46.0, 2.0, 2.0), Color("c09a61"))
	# Fine casting ribs run down toward the worn lip; tiny breaks expose dark oxidized bronze.
	for rib_x in [-34.0, -27.0, 27.0, 34.0]:
		draw_line(Vector2(x + rib_x + sway, y - 33.0), Vector2(x + rib_x * 1.23 + sway, y + 17.0), Color("9a754a", 0.63), 1.0, false)
	for pit in range(9):
		var pit_x := x - 42.0 + float((pit * 19) % 84) + sway
		var pit_y := y - 4.0 + float((pit * 11) % 25)
		draw_rect(Rect2(pit_x, pit_y, 2.0, 1.0), Color("171a16", 0.88))
		draw_rect(Rect2(pit_x + 1.0, pit_y - 1.0, 1.0, 1.0), Color("a17645", 0.62))
	draw_rect(Rect2(x - 54.0 + sway, y + 24.0, 108.0, 12.0), Color("171a16"))
	draw_rect(Rect2(x - 51.0 + sway, y + 25.0, 102.0, 3.0), Color("b0814a"))
	draw_rect(Rect2(x - 44.0 + sway, y + 29.0, 88.0, 3.0), Color("9b7446"))
	draw_rect(Rect2(x - 5.0 + sway, y + 31.0, 10.0, 23.0), Color("191d19"))
	draw_rect(Rect2(x - 3.0 + sway, y + 49.0, 6.0, 7.0), Color("624c35"))
	# The recording horn and waxed cylinder are bolted to the bell's side.
	draw_rect(Rect2(x + 68.0, y - 25.0, 34.0, 32.0), Color("101613"))
	draw_rect(Rect2(x + 72.0, y - 21.0, 25.0, 23.0), Color("3c392b"))
	draw_rect(Rect2(x + 76.0, y - 17.0, 17.0, 13.0), Color("181f1c"))
	draw_rect(Rect2(x + 80.0, y - 15.0, 8.0, 4.0), Color("987349"))
	draw_arc(Vector2(x + 97.0, y - 9.0), 7.0, -1.1, 1.1, 12, Color("b08a54"), 2.0, false)
	for bolt_x in [-47.0, 44.0]:
		draw_rect(Rect2(x + bolt_x, y - 57.0, 3.0, 3.0), Color("d0a76b"))
		draw_rect(Rect2(x + bolt_x, y + 11.0, 3.0, 3.0), Color("b1854d"))
	if finale_active:
		var ring := 0.12 + maxf(0.0, sin(finale_time * 3.4)) * 0.22
		draw_arc(Vector2(x, y - 3.0), 80.0 + sin(finale_time * 2.0) * 2.0, 0.0, TAU, 32, Color(0.56, 0.66, 0.54, ring), 1.0, true)

func _draw_seabed() -> void:
	draw_rect(Rect2(0.0, 596.0, WORLD_WIDTH, 24.0), Color("080c0b"))
	draw_rect(Rect2(0.0, 591.0, WORLD_WIDTH, 6.0), Color("181e19"))
	for i in range(54):
		var x := float(i) * 43.0 + float((i * 17) % 23)
		var h := 5.0 + float((i * 13) % 19)
		draw_rect(Rect2(x, 591.0 - h, 2.0, h), Color("121c17") if i % 2 == 0 else Color("17221a"))
	for i in range(25):
		var x := float(i) * 89.0 + 26.0
		draw_rect(Rect2(x, 584.0, 18.0, 7.0), Color("20231d"))
		draw_rect(Rect2(x + 4.0, 580.0, 9.0, 5.0), Color("2c2d24"))
		draw_rect(Rect2(x + 5.0, 581.0, 6.0, 1.0), Color("6c6448", 0.6))
	for gravel in range(112):
		var gx := float((gravel * 59) % int(WORLD_WIDTH - 3.0)) + 1.0
		var gy := 587.0 + float((gravel * 7) % 8)
		draw_rect(Rect2(gx, gy, 1.0 + float(gravel % 3), 1.0), Color("2a3027") if gravel % 3 else Color("514737", 0.8))
		if gravel % 11 == 0:
			draw_rect(Rect2(gx + 1.0, gy - 1.0, 1.0, 1.0), Color("849077", 0.42))

func _draw_archive_plates() -> void:
	for index in range(ARCHIVE_POSITIONS.size()):
		var drift := sin(elapsed * 0.42 + float(index) * 1.7) * 1.5
		var position: Vector2 = ARCHIVE_POSITIONS[index] + Vector2(0.0, drift)
		var pulse := 0.12 + (sin(elapsed * 2.2 + float(index) * 1.8) + 1.0) * 0.055
		if player.listening and listen_target_index == index and not evidence_found[index]:
			draw_arc(position, 32.0, 0.0, TAU, 24, Color(0.49, 0.71, 0.58, 0.28), 1.0, true)
			draw_arc(position, 43.0, 0.0, TAU, 24, Color(0.49, 0.71, 0.58, 0.13), 1.0, true)
		# Use the corpse's own transform so every named plate stays strapped to its chest as it drifts.
		var rotations := [-0.17, 0.12, PI - 0.11]
		draw_set_transform(position, rotations[index % rotations.size()], Vector2(0.50, 0.50))
		var tag_center := Vector2(1.0, -2.0)
		draw_line(tag_center + Vector2(-11.0, -3.0), tag_center + Vector2(-9.0, -8.0), Color("433a2b"), 1.0, false)
		draw_line(tag_center + Vector2(11.0, -3.0), tag_center + Vector2(9.0, -8.0), Color("433a2b"), 1.0, false)
		draw_rect(Rect2(tag_center.x - 16.0, tag_center.y - 4.0, 32.0, 9.0), Color("080c0b"))
		draw_rect(Rect2(tag_center.x - 15.0, tag_center.y - 3.0, 30.0, 7.0), Color("29271f") if evidence_found[index] else Color("514632"))
		draw_rect(Rect2(tag_center.x - 14.0, tag_center.y - 2.0, 28.0, 1.0), Color("8e6d43") if not evidence_found[index] else Color("514735"))
		draw_rect(Rect2(tag_center.x - 13.0, tag_center.y + 2.0, 26.0, 1.0), Color("151a17"))
		for bolt_x in [-13.0, 12.0]:
			var bolt_color := Color(0.82, 0.65, 0.42, pulse) if not evidence_found[index] else Color("625137")
			draw_rect(Rect2(tag_center.x + bolt_x, tag_center.y - 1.0, 2.0, 2.0), bolt_color)
		var registry: PackedStringArray = ARCHIVE_NAMES[index].split(" / ")
		var name_tint := Color("d2c19a") if not evidence_found[index] else Color("858171")
		draw_string(ThemeDB.fallback_font, tag_center + Vector2(-13.0, -0.5), registry[0], HORIZONTAL_ALIGNMENT_CENTER, 26.0, 3, name_tint)
		draw_string(ThemeDB.fallback_font, tag_center + Vector2(-13.0, 3.5), registry[1], HORIZONTAL_ALIGNMENT_CENTER, 26.0, 3, Color("a38a61") if not evidence_found[index] else Color("645c4c"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_optional_recording() -> void:
	if optional_recording_found:
		return
	var position := OPTIONAL_RECORDING_POSITION
	var shimmer := 0.10 + (sin(elapsed * 1.3) + 1.0) * 0.035
	draw_rect(Rect2(position.x - 12.0, position.y - 9.0, 25.0, 18.0), Color(0.43, 0.60, 0.50, shimmer))
	draw_rect(Rect2(position.x - 7.0, position.y - 7.0, 17.0, 14.0), Color("111714"))
	draw_rect(Rect2(position.x - 5.0, position.y - 5.0, 13.0, 10.0), Color("494333"))
	draw_rect(Rect2(position.x - 2.0, position.y - 4.0, 8.0, 8.0), Color("252820"))
	draw_rect(Rect2(position.x - 1.0, position.y - 2.0, 3.0, 4.0), Color("a37c48"))
	draw_rect(Rect2(position.x + 6.0, position.y - 2.0, 2.0, 4.0), Color("927044"))
	draw_rect(Rect2(position.x - 8.0, position.y + 7.0, 5.0, 2.0), Color("6a5537"))
	draw_rect(Rect2(position.x + 6.0, position.y + 7.0, 5.0, 2.0), Color("6a5537"))

func _draw_dead_divers() -> void:
	for index in range(DEAD_DIVER_POSITIONS.size()):
		var position: Vector2 = DEAD_DIVER_POSITIONS[index]
		var drift := sin(elapsed * 0.42 + float(index) * 1.7) * 1.5
		_draw_dead_diver(position + Vector2(0.0, drift), index)

func _draw_dead_diver(position: Vector2, variant: int) -> void:
	var rotations := [-0.17, 0.12, PI - 0.11, PI + 0.19]
	draw_set_transform(position, rotations[variant % rotations.size()], Vector2(0.50, 0.50))
	var suit := Color("18201e") if variant % 2 == 0 else Color("1b201c")
	var cloth_highlight := Color("30372d")
	var trim := Color("4a4939")
	var brass := Color("66543b")
	var bone := Color("8a8065")
	var algae := Color("293d32")
	# Slack tether, old air tank and a rotten canvas shell, all close to the player's scale.
	draw_line(Vector2(-45.0, -12.0), Vector2(-28.0, -14.0), Color("322c21"), 2.0, false)
	draw_line(Vector2(-28.0, -14.0), Vector2(-15.0, -13.0), Color("292820"), 1.0, false)
	draw_rect(Rect2(7.0, -20.0, 10.0, 29.0), Color("111716"))
	draw_rect(Rect2(9.0, -18.0, 6.0, 24.0), Color("32372e"))
	draw_rect(Rect2(8.0, -18.0, 2.0, 21.0), brass)
	draw_rect(Rect2(-13.0, -13.0, 30.0, 23.0), suit)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -12.0), Vector2(4.0, -14.0), Vector2(17.0, -7.0),
		Vector2(18.0, 5.0), Vector2(10.0, 10.0), Vector2(-12.0, 8.0)
	]), cloth_highlight)
	draw_rect(Rect2(-14.0, -15.0, 22.0, 4.0), trim)
	draw_rect(Rect2(-11.0, -12.0, 16.0, 1.0), brass)
	draw_line(Vector2(-6.0, -12.0), Vector2(-4.0, 8.0), Color("424137"), 1.0, false)
	draw_rect(Rect2(1.0, -5.0, 6.0, 5.0), Color("302d23"))
	draw_rect(Rect2(2.0, -4.0, 4.0, 3.0), brass)
	# A tear in the chest exposes pixel-art ribs and vertebrae inside the flooded suit.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, -8.0), Vector2(8.0, -7.0), Vector2(10.0, 2.0),
		Vector2(4.0, 6.0), Vector2(-7.0, 3.0), Vector2(-9.0, -3.0)
	]), Color("090f0f"))
	draw_line(Vector2(0.0, -7.0), Vector2(1.0, 5.0), bone, 2.0, false)
	for rib in range(4):
		var ry := -6.0 + float(rib) * 3.0
		draw_line(Vector2(-5.0, ry), Vector2(5.0, ry + 1.0), bone, 1.4, false)
	draw_rect(Rect2(-2.0, 5.0, 7.0, 2.0), bone)
	draw_rect(Rect2(-1.0, 7.0, 2.0, 2.0), bone)
	# The cracked brass helmet holds a visible little skull behind cloudy dark glass.
	draw_rect(Rect2(-40.0, -31.0, 30.0, 29.0), Color("252720"))
	draw_rect(Rect2(-39.0, -32.0, 27.0, 4.0), brass)
	draw_rect(Rect2(-38.0, -4.0, 25.0, 4.0), trim)
	draw_rect(Rect2(-36.0, -27.0, 22.0, 21.0), Color("0a1111"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32.0, -23.0), Vector2(-28.0, -26.0), Vector2(-21.0, -25.0),
		Vector2(-17.0, -21.0), Vector2(-18.0, -14.0), Vector2(-22.0, -11.0),
		Vector2(-30.0, -13.0), Vector2(-33.0, -18.0)
	]), bone)
	draw_rect(Rect2(-30.0, -20.0, 3.0, 3.0), Color("111614"))
	draw_rect(Rect2(-22.0, -20.0, 3.0, 3.0), Color("111614"))
	draw_colored_polygon(PackedVector2Array([Vector2(-28.0, -15.0), Vector2(-24.0, -15.0), Vector2(-26.0, -12.0)]), Color("2a2c25"))
	draw_rect(Rect2(-28.0, -12.0, 2.0, 2.0), Color("b3a580"))
	draw_rect(Rect2(-25.0, -12.0, 2.0, 2.0), Color("b3a580"))
	draw_line(Vector2(-37.0, -27.0), Vector2(-34.0, -23.0), Color("75705c"), 1.0, false)
	draw_rect(Rect2(-39.0, -28.0, 2.0, 2.0), Color("937448"))
	draw_rect(Rect2(-13.0, -5.0, 3.0, 3.0), Color("977247"))
	# Limbs sag in the current. Bone segments show through split cuffs and tears.
	draw_line(Vector2(-13.0, -3.0), Vector2(-21.0, 8.0), suit.lightened(0.04), 7.0, false)
	draw_line(Vector2(-21.0, 8.0), Vector2(-25.0, 15.0), suit, 5.0, false)
	draw_line(Vector2(-14.0, -2.0), Vector2(-21.0, 8.0), bone, 2.0, false)
	draw_line(Vector2(-21.0, 8.0), Vector2(-25.0, 14.0), bone, 2.0, false)
	draw_rect(Rect2(-27.0, 14.0, 5.0, 3.0), Color("292a23"))
	draw_line(Vector2(15.0, -6.0), Vector2(25.0, 3.0), suit, 6.0, false)
	draw_line(Vector2(25.0, 3.0), Vector2(30.0, 11.0), suit, 4.0, false)
	draw_line(Vector2(16.0, -5.0), Vector2(25.0, 3.0), bone, 2.0, false)
	draw_line(Vector2(25.0, 3.0), Vector2(30.0, 10.0), bone, 2.0, false)
	draw_line(Vector2(-3.0, 8.0), Vector2(4.0, 17.0), suit, 7.0, false)
	draw_line(Vector2(4.0, 17.0), Vector2(11.0, 24.0), suit, 6.0, false)
	draw_line(Vector2(-2.0, 8.0), Vector2(4.0, 17.0), bone, 2.0, false)
	draw_line(Vector2(4.0, 17.0), Vector2(10.0, 23.0), bone, 2.0, false)
	draw_line(Vector2(10.0, 6.0), Vector2(18.0, 14.0), suit, 7.0, false)
	draw_line(Vector2(18.0, 14.0), Vector2(25.0, 20.0), suit, 6.0, false)
	draw_line(Vector2(10.0, 7.0), Vector2(18.0, 14.0), bone, 2.0, false)
	draw_line(Vector2(18.0, 14.0), Vector2(25.0, 19.0), bone, 2.0, false)
	draw_rect(Rect2(7.0, 21.0, 10.0, 4.0), Color("292a23"))
	draw_rect(Rect2(20.0, 17.0, 10.0, 4.0), Color("292a23"))
	# Sea growth threads through the helmet rim, torn seams, tank and boots.
	draw_line(Vector2(-36.0, -30.0), Vector2(-42.0, -37.0), algae, 2.0, false)
	draw_line(Vector2(-42.0, -37.0), Vector2(-47.0, -39.0), algae.lightened(0.12), 1.0, false)
	draw_line(Vector2(-42.0, -37.0), Vector2(-40.0, -43.0), algae, 1.0, false)
	draw_line(Vector2(-8.0, -12.0), Vector2(-4.0, -20.0), algae, 2.0, false)
	draw_line(Vector2(-4.0, -20.0), Vector2(1.0, -23.0), algae.lightened(0.12), 1.0, false)
	draw_line(Vector2(13.0, 7.0), Vector2(18.0, 13.0), algae, 2.0, false)
	draw_line(Vector2(18.0, 13.0), Vector2(22.0, 14.0), algae.lightened(0.15), 1.0, false)
	draw_line(Vector2(5.0, 22.0), Vector2(2.0, 28.0), algae, 2.0, false)
	draw_rect(Rect2(17.0, -18.0, 3.0, 3.0), Color("354337"))
	draw_rect(Rect2(-16.0, 1.0, 3.0, 3.0), Color("404638"))
	if variant == 3:
		# A fourth suit has its registry tab deliberately ground blank.
		draw_line(Vector2(-10.0, -3.0), Vector2(-8.0, -8.0), Color("352e21"), 1.0, false)
		draw_rect(Rect2(-16.0, -5.0, 32.0, 9.0), Color("080c0b"))
		draw_rect(Rect2(-15.0, -4.0, 30.0, 7.0), Color("302b21"))
		draw_rect(Rect2(-14.0, -3.0, 28.0, 1.0), Color("70553a"))
		for scratch in range(5):
			draw_line(Vector2(-9.0 + float(scratch) * 4.0, -1.0), Vector2(-7.0 + float(scratch) * 4.0, 1.0), Color("76654b"), 1.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_abyssal_creature() -> void:
	if not creature_sighting_active:
		return
	# A low, muted parallax factor places it behind the foundry and the diver.
	var camera_center := camera.get_screen_center_position()
	var distant_center := camera_center + (creature_position - camera_center) * 0.42
	var sprite_size := ABYSSAL_CREATURE_TEXTURE.get_size() * 0.08
	var visibility := clampf(creature_sighting_time / 0.45, 0.0, 1.0)
	var tint := Color(0.68, 0.73, 0.69, 0.84 * visibility)
	var sprite_origin := distant_center - sprite_size * 0.5
	var columns: int = 64
	var rows: int = 12
	var swim_phase: float = elapsed * 3.7
	# The skull-heavy head leads; a traveling lateral wave grows down the body into the tail.
	for column in range(columns):
		var u0: float = float(column) / float(columns)
		var u1: float = float(column + 1) / float(columns)
		var wave0: float = _fish_body_wave(u0, swim_phase)
		var wave1: float = _fish_body_wave(u1, swim_phase)
		var bend0: float = _fish_body_bend(u0, swim_phase)
		var bend1: float = _fish_body_bend(u1, swim_phase)
		for row in range(rows):
			var v0: float = float(row) / float(rows)
			var v1: float = float(row + 1) / float(rows)
			var top_left := Vector2(sprite_origin.x + sprite_size.x * u0 + bend0 * (v0 - 0.5), sprite_origin.y + sprite_size.y * v0 + wave0)
			var top_right := Vector2(sprite_origin.x + sprite_size.x * u1 + bend1 * (v0 - 0.5), sprite_origin.y + sprite_size.y * v0 + wave1)
			var bottom_right := Vector2(sprite_origin.x + sprite_size.x * u1 + bend1 * (v1 - 0.5), sprite_origin.y + sprite_size.y * v1 + wave1)
			var bottom_left := Vector2(sprite_origin.x + sprite_size.x * u0 + bend0 * (v1 - 0.5), sprite_origin.y + sprite_size.y * v1 + wave0)
			var quad := PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
			var uv := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
			draw_colored_polygon(quad, tint, uv, ABYSSAL_CREATURE_TEXTURE)
	# A few tiny bubbles drift from the damaged gills, helping sell its scale in the far water.
	for bubble in range(3):
		var bubble_phase := fposmod(creature_sighting_time * 7.0 + float(bubble) * 17.0, 28.0)
		var bubble_pos := distant_center + Vector2(-sprite_size.x * 0.34 - float(bubble % 2) * 3.0, -sprite_size.y * 0.04 - bubble_phase)
		draw_rect(Rect2(bubble_pos, Vector2(1.0, 1.0)), Color(0.69, 0.79, 0.74, 0.20 * visibility))

func _fish_body_wave(u: float, phase: float) -> float:
	var tail_envelope := pow(clampf(u, 0.0, 1.0), 1.72)
	var traveling_wave := sin(phase - u * TAU * 1.34) * 19.0 * tail_envelope
	var tail_beat := sin(phase * 1.12 - u * TAU * 2.15) * 4.0 * pow(clampf(u, 0.0, 1.0), 2.2)
	return traveling_wave + tail_beat

func _fish_body_bend(u: float, phase: float) -> float:
	var tail_envelope := pow(clampf(u, 0.0, 1.0), 1.8)
	return sin(phase - u * TAU * 1.34 + 0.42) * 5.0 * tail_envelope

func _screen_to_world(point: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return camera.get_screen_center_position() + (point - viewport_size * 0.5) / camera.zoom

func _draw_screen_rect(rect: Rect2, tint: Color) -> void:
	draw_rect(Rect2(_screen_to_world(rect.position), rect.size / camera.zoom), tint)

func _draw_screen_polygon(points: PackedVector2Array, tint: Color) -> void:
	var world_points := PackedVector2Array()
	for point in points:
		world_points.append(_screen_to_world(point))
	draw_colored_polygon(world_points, tint)

func _draw_screen_ellipse(center: Vector2, radii: Vector2, tint: Color, segments := 40) -> void:
	var points := PackedVector2Array()
	for segment in range(segments):
		var angle := TAU * float(segment) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	_draw_screen_polygon(points, tint)

func _draw_screen_line(from: Vector2, to: Vector2, tint: Color, width := 1.0) -> void:
	draw_line(_screen_to_world(from), _screen_to_world(to), tint, maxf(0.5, width / camera.zoom.x), false)

func _draw_screen_texture_region(texture: Texture2D, destination: Rect2, source: Rect2, tint: Color) -> void:
	var world_rect := Rect2(_screen_to_world(destination.position), destination.size / camera.zoom)
	draw_texture_rect_region(texture, world_rect, source, tint, false)

func _draw_front_fish_lunge(viewport_size: Vector2, progress: float, alpha: float = 1.0) -> void:
	var texture_size := ABYSSAL_CREATURE_FRONT_OPEN.get_size()
	var sprite_size := lerpf(viewport_size.x * 0.64, maxf(viewport_size.x, viewport_size.y) * 1.92, progress)
	var tremor := Vector2(sin(elapsed * 39.0) * (1.0 + progress * 2.2), sin(elapsed * 31.0) * (1.0 + progress * 1.5))
	var mouth_anchor_y := lerpf(0.50, 0.62, progress)
	var sprite_origin := Vector2(viewport_size.x * 0.5 - sprite_size * 0.5, viewport_size.y * 0.52 + tremor.y - sprite_size * mouth_anchor_y)
	var sprite_rect := Rect2(sprite_origin + Vector2(tremor.x, 0.0), Vector2.ONE * sprite_size)
	_draw_screen_texture_region(ABYSSAL_CREATURE_FRONT_OPEN, sprite_rect, Rect2(Vector2.ZERO, texture_size), Color(0.80, 0.87, 0.82, alpha))

func _draw_front_fish_bite(viewport_size: Vector2, bite_snap: float) -> void:
	# Both frames are the same front-facing fish; the whole jaw pose comes from each aligned sprite.
	var mouth_open := bite_snap < 0.52
	var texture: Texture2D = ABYSSAL_CREATURE_FRONT_OPEN if mouth_open else ABYSSAL_CREATURE_FRONT_CLOSED
	var texture_size := texture.get_size()
	var bite_zoom := 1.0 + bite_snap * 0.035
	var sprite_size := maxf(viewport_size.x, viewport_size.y) * 1.86 * bite_zoom
	var mouth_anchor_y := 0.62
	var snap_jolt := sin(elapsed * 49.0) * (1.0 + bite_snap * 1.8)
	var mouth_center := Vector2(viewport_size.x * 0.5 + snap_jolt, viewport_size.y * 0.51 + sin(elapsed * 38.0) * 1.3)
	var sprite_origin := mouth_center - Vector2(sprite_size * 0.5, sprite_size * mouth_anchor_y)
	var sprite_rect := Rect2(sprite_origin, Vector2.ONE * sprite_size)
	_draw_screen_texture_region(texture, sprite_rect, Rect2(Vector2.ZERO, texture_size), Color(0.84, 0.89, 0.84, 1.0))

func _draw_final_jumpscare() -> void:
	var viewport_size := get_viewport_rect().size
	_draw_screen_rect(Rect2(Vector2.ZERO, viewport_size), Color("010305"))
	if final_end_screen_active:
		# Hold the almost-total black behind the cold title card.
		for fleck in range(28):
			var fx := float((fleck * 73) % int(viewport_size.x))
			var fy := float((fleck * 41) % int(viewport_size.y))
			_draw_screen_rect(Rect2(Vector2(fx, fy), Vector2(1.0, 1.0)), Color(0.48, 0.55, 0.5, 0.08))
		return
	var time := final_jumpscare_time
	if time < 0.24:
		# A dim, head-on glimpse reveals the face before it surges out of the black.
		var glint := 0.15 + sin(elapsed * 25.0) * 0.035
		_draw_front_fish_lunge(viewport_size, 0.0, glint)
		return
	if time < 0.92:
		var approach := clampf((time - 0.24) / 0.68, 0.0, 1.0)
		var eased_approach := approach * approach * (3.0 - 2.0 * approach)
		_draw_front_fish_lunge(viewport_size, pow(eased_approach, 1.16), lerpf(0.34, 1.0, eased_approach))
		if time >= 0.56:
			_draw_consumed_diver(viewport_size, time, 0.0)
		if time > 0.72:
			var impact_flash := (1.0 - clampf((time - 0.72) / 0.2, 0.0, 1.0)) * 0.12
			_draw_screen_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.74, 0.76, 0.65, impact_flash))
		return
	var bite_time := time - 0.92
	var bite_phase := bite_time * TAU * 1.52
	var bite_snap := pow(maxf(0.0, cos(bite_phase)), 2.4)
	_draw_front_fish_bite(viewport_size, bite_snap)
	_draw_consumed_diver(viewport_size, time, bite_snap)
	if bite_snap > 0.88:
		_draw_screen_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.64, 0.58, 0.46, 0.045))

func _draw_consumed_diver(viewport_size: Vector2, time: float, bite_snap: float) -> void:
	var enter := clampf((time - 0.56) / 0.36, 0.0, 1.0)
	var swallow := clampf((time - 2.62) / 0.28, 0.0, 1.0)
	var scale := lerpf(1.95, 2.55, enter) * lerpf(1.0, 0.56, swallow) * (1.0 + bite_snap * 0.035)
	var center := Vector2(viewport_size.x * 0.5 + sin(elapsed * 34.0) * (1.0 + bite_snap), viewport_size.y * 0.69 + sin(elapsed * 21.0) * 2.0 + bite_snap * 2.2 + swallow * 25.0)
	var angle := sin(elapsed * 14.0) * 0.055 + sin(elapsed * 33.0) * 0.025
	var alpha := 1.0 - swallow
	var right_arm_gone := time >= 1.06
	var left_leg_gone := time >= 1.70
	var left_arm_gone := time >= 2.34
	var right_leg_gone := time >= 2.62
	_draw_eaten_diver_body(center, scale, angle, bite_snap, alpha, right_arm_gone, left_arm_gone, left_leg_gone, right_leg_gone)
	if right_arm_gone:
		_draw_eaten_stump(center, Vector2(6.0, -16.0), scale, angle, alpha)
		_draw_ejected_limb(center, Vector2(6.0, -16.0), 1.0, time - 1.06, true, scale, angle, alpha)
	if left_leg_gone:
		_draw_eaten_stump(center, Vector2(-3.0, -2.0), scale, angle, alpha)
		_draw_ejected_limb(center, Vector2(-3.0, -2.0), -1.0, time - 1.70, false, scale, angle, alpha)
	if left_arm_gone:
		_draw_eaten_stump(center, Vector2(-6.0, -16.0), scale, angle, alpha)
		_draw_ejected_limb(center, Vector2(-6.0, -16.0), -1.0, time - 2.34, true, scale, angle, alpha)
	if right_leg_gone:
		_draw_eaten_stump(center, Vector2(3.0, -2.0), scale, angle, alpha)
		_draw_ejected_limb(center, Vector2(3.0, -2.0), 1.0, time - 2.62, false, scale, angle, alpha)

func _draw_eaten_diver_body(origin: Vector2, scale: float, angle: float, bite_snap: float, alpha: float, right_arm_gone: bool, left_arm_gone: bool, left_leg_gone: bool, right_leg_gone: bool) -> void:
	# Canvas tank and articulated limbs use the same brass, charcoal and faded-sage palette as the player.
	_draw_diver_rect(origin, Rect2(Vector2(-12.0, -24.0), Vector2(5.0, 21.0)), scale, angle, _eaten_color("171f20", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-11.0, -22.0), Vector2(3.0, 17.0)), scale, angle, _eaten_color("56645a", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-11.0, -17.0), Vector2(3.0, 1.0)), scale, angle, _eaten_color("8f6d43", alpha))
	var kick := sin(elapsed * 17.0) * 1.6 + bite_snap * 2.4
	if not left_leg_gone:
		_draw_eaten_leg(origin, -1.0, kick, scale, angle, alpha)
	if not right_leg_gone:
		_draw_eaten_leg(origin, 1.0, -kick, scale, angle, alpha)
	_draw_diver_rect(origin, Rect2(Vector2(-7.0, -20.0), Vector2(14.0, 19.0)), scale, angle, _eaten_color("171f20", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-5.5, -18.5), Vector2(11.0, 15.0)), scale, angle, _eaten_color("777c68", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-4.0, -17.0), Vector2(8.0, 12.0)), scale, angle, _eaten_color("a3a48a", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-4.0, -7.0), Vector2(8.0, 2.5)), scale, angle, _eaten_color("5b5544", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-1.5, -7.0), Vector2(3.0, 2.5)), scale, angle, _eaten_color("bc8548", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-6.0, -21.0), Vector2(12.0, 4.0)), scale, angle, _eaten_color("5b5544", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-5.0, -21.0), Vector2(10.0, 1.0)), scale, angle, _eaten_color("8f6d43", alpha))
	var flail := sin(elapsed * 27.0) * (1.4 + bite_snap * 2.0)
	if not left_arm_gone:
		_draw_eaten_arm(origin, -1.0, -flail, scale, angle, alpha)
	if not right_arm_gone:
		_draw_eaten_arm(origin, 1.0, flail, scale, angle, alpha)
	# Thick brass-rimmed helmet, lit glass, and the tiny crown lamp identify the diver at a glance.
	var helmet_center := _eaten_point(origin, Vector2(0.0, -30.0), scale, angle)
	_draw_screen_ellipse(helmet_center + Vector2(0.0, 1.0), Vector2(10.0, 10.0) * scale, _eaten_color("171f20", alpha), 18)
	_draw_screen_ellipse(helmet_center, Vector2(8.6, 8.6) * scale, _eaten_color("8f6d43", alpha), 18)
	_draw_screen_ellipse(helmet_center, Vector2(7.0, 7.0) * scale, _eaten_color("56645a", alpha), 18)
	_draw_screen_ellipse(helmet_center + Vector2(1.5, 0.5) * scale, Vector2(4.5, 5.0) * scale, _eaten_color("244d50", alpha), 16)
	_draw_screen_line(helmet_center + Vector2(-2.5, -3.5) * scale, helmet_center + Vector2(1.5, -4.0) * scale, _eaten_color("8ac4b4", alpha), 1.1 * scale)
	_draw_diver_rect(origin, Rect2(Vector2(-2.0, -41.0), Vector2(4.0, 3.0)), scale, angle, _eaten_color("8f6d43", alpha))
	_draw_diver_rect(origin, Rect2(Vector2(-1.0, -42.0), Vector2(2.0, 2.0)), scale, angle, _eaten_color("ffe6a0", alpha))
	# A broken hose still trails from the helmet toward the tank as the suit is pulled inward.
	_draw_diver_line(origin, Vector2(-8.0, -17.0), Vector2(-7.0, -27.0), scale, angle, _eaten_color("171f20", alpha), 2.5)
	_draw_diver_line(origin, Vector2(-8.0, -17.0), Vector2(-7.0, -27.0), scale, angle, _eaten_color("a67945", alpha), 0.8)

func _draw_eaten_arm(origin: Vector2, side: float, flail: float, scale: float, angle: float, alpha: float) -> void:
	var shoulder := Vector2(side * 6.0, -16.0)
	var elbow := Vector2(side * (9.0 + flail * 0.45), -10.0 + flail)
	var hand := Vector2(side * (8.5 + flail), -5.0 + flail * 0.6)
	_draw_eaten_segment(origin, shoulder, elbow, scale, angle, Color("171f20", alpha), 6.0)
	_draw_eaten_segment(origin, shoulder, elbow, scale, angle, Color("424943", alpha), 4.0)
	_draw_eaten_segment(origin, elbow, hand, scale, angle, Color("171f20", alpha), 5.0)
	_draw_eaten_segment(origin, elbow, hand, scale, angle, Color("626d5b", alpha), 3.0)
	_draw_diver_rect(origin, Rect2(hand - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), scale, angle, Color("202725", alpha))
	_draw_diver_rect(origin, Rect2(hand - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), scale, angle, Color("56645a", alpha))

func _draw_eaten_leg(origin: Vector2, side: float, kick: float, scale: float, angle: float, alpha: float) -> void:
	var hip := Vector2(side * 3.0, -2.0)
	var knee := Vector2(side * (4.0 + kick * 0.45), 4.0 + absf(kick) * 0.3)
	var ankle := Vector2(side * (3.5 + kick), 9.0)
	_draw_eaten_segment(origin, hip, knee, scale, angle, Color("171f20", alpha), 6.0)
	_draw_eaten_segment(origin, hip, knee, scale, angle, Color("424943", alpha), 4.0)
	_draw_eaten_segment(origin, knee, ankle, scale, angle, Color("171f20", alpha), 5.5)
	_draw_eaten_segment(origin, knee, ankle, scale, angle, Color("343d39", alpha), 3.4)
	_draw_diver_rect(origin, Rect2(ankle + Vector2(-2.0, -1.0), Vector2(6.0, 4.0)), scale, angle, Color("171f20", alpha))
	_draw_diver_rect(origin, Rect2(ankle + Vector2(-1.0, 0.0), Vector2(4.0, 2.0)), scale, angle, Color("8f6d43", alpha))

func _draw_eaten_stump(origin: Vector2, local: Vector2, scale: float, angle: float, alpha: float) -> void:
	_draw_diver_rect(origin, Rect2(local + Vector2(-2.0, -1.5), Vector2(4.0, 3.0)), scale, angle, Color("171f20", alpha))
	_draw_diver_rect(origin, Rect2(local + Vector2(-1.5, -0.5), Vector2(3.0, 1.7)), scale, angle, Color("5b4036", alpha))
	_draw_diver_rect(origin, Rect2(local + Vector2(-0.8, -0.25), Vector2(1.5, 0.7)), scale, angle, Color("803f35", alpha * 0.72))
	var bubble_origin := _eaten_point(origin, local + Vector2(0.0, -3.0), scale, angle)
	_draw_screen_ellipse(bubble_origin + Vector2(-2.0, -3.0), Vector2(1.0, 1.4), Color(0.57, 0.77, 0.72, alpha * 0.45), 8)
	_draw_screen_ellipse(bubble_origin + Vector2(3.0, -6.0), Vector2(0.8, 1.0), Color(0.57, 0.77, 0.72, alpha * 0.32), 8)

func _draw_ejected_limb(origin: Vector2, anchor: Vector2, side: float, age: float, is_arm: bool, scale: float, angle: float, alpha: float) -> void:
	if age < 0.0 or age >= 0.54:
		return
	var fade := clampf(1.0 - age / 0.54, 0.0, 1.0) * alpha
	var drift := Vector2(side * (10.0 + age * 42.0), -12.0 + age * age * 70.0)
	var piece_origin := _eaten_point(origin, anchor, scale, angle) + drift
	var piece_scale := scale * (1.0 - age * 0.42)
	var piece_angle := angle + side * (0.18 + age * 2.5)
	if is_arm:
		_draw_eaten_segment(piece_origin, Vector2(0.0, 0.0), Vector2(side * 2.0, 5.0), piece_scale, piece_angle, Color("171f20", fade), 5.5)
		_draw_eaten_segment(piece_origin, Vector2(0.0, 0.0), Vector2(side * 2.0, 5.0), piece_scale, piece_angle, Color("424943", fade), 3.7)
		_draw_eaten_segment(piece_origin, Vector2(side * 2.0, 5.0), Vector2(side * 3.0, 9.0), piece_scale, piece_angle, Color("171f20", fade), 5.0)
		_draw_eaten_segment(piece_origin, Vector2(side * 2.0, 5.0), Vector2(side * 3.0, 9.0), piece_scale, piece_angle, Color("626d5b", fade), 3.0)
		_draw_diver_rect(piece_origin, Rect2(Vector2(side * 2.0 - 2.0, 8.0), Vector2(4.0, 4.0)), piece_scale, piece_angle, Color("202725", fade))
	else:
		_draw_eaten_segment(piece_origin, Vector2(0.0, 0.0), Vector2(side * 1.0, 6.0), piece_scale, piece_angle, Color("171f20", fade), 6.0)
		_draw_eaten_segment(piece_origin, Vector2(0.0, 0.0), Vector2(side * 1.0, 6.0), piece_scale, piece_angle, Color("424943", fade), 4.0)
		_draw_eaten_segment(piece_origin, Vector2(side * 1.0, 6.0), Vector2(0.0, 11.0), piece_scale, piece_angle, Color("171f20", fade), 5.5)
		_draw_eaten_segment(piece_origin, Vector2(side * 1.0, 6.0), Vector2(0.0, 11.0), piece_scale, piece_angle, Color("343d39", fade), 3.2)
		_draw_diver_rect(piece_origin, Rect2(Vector2(-2.0, 10.0), Vector2(6.0, 3.0)), piece_scale, piece_angle, Color("171f20", fade))
		_draw_diver_rect(piece_origin, Rect2(Vector2(-1.0, 10.5), Vector2(4.0, 1.5)), piece_scale, piece_angle, Color("8f6d43", fade))
	for bubble in range(3):
		var bubble_position := piece_origin + Vector2(float(bubble) * side * 4.0, -float(bubble) * 5.0 - 3.0)
		_draw_screen_ellipse(bubble_position, Vector2(0.8, 1.0), Color(0.57, 0.77, 0.72, fade * 0.32), 8)

func _draw_eaten_segment(origin: Vector2, start: Vector2, finish: Vector2, scale: float, angle: float, tint: Color, width: float) -> void:
	_draw_screen_line(_eaten_point(origin, start, scale, angle), _eaten_point(origin, finish, scale, angle), tint, width * scale)

func _draw_diver_line(origin: Vector2, start: Vector2, finish: Vector2, scale: float, angle: float, tint: Color, width: float) -> void:
	_draw_eaten_segment(origin, start, finish, scale, angle, tint, width)

func _draw_diver_rect(origin: Vector2, rect: Rect2, scale: float, angle: float, tint: Color) -> void:
	var corners := PackedVector2Array([
		_eaten_point(origin, rect.position, scale, angle),
		_eaten_point(origin, rect.position + Vector2(rect.size.x, 0.0), scale, angle),
		_eaten_point(origin, rect.position + rect.size, scale, angle),
		_eaten_point(origin, rect.position + Vector2(0.0, rect.size.y), scale, angle)
	])
	_draw_screen_polygon(corners, tint)

func _eaten_point(origin: Vector2, local: Vector2, scale: float, angle: float) -> Vector2:
	return origin + local.rotated(angle) * scale

func _eaten_color(hex: String, alpha: float) -> Color:
	var tint := Color(hex)
	tint.a *= alpha
	return tint

func _draw_false_echoes() -> void:
	for index in range(FALSE_ECHO_POSITIONS.size()):
		var position: Vector2 = FALSE_ECHO_POSITIONS[index]
		var flicker := 0.11 + maxf(0.0, sin(elapsed * 1.7 + float(index) * 2.0)) * 0.08
		if player.listening and false_echo_index == index:
			draw_arc(position, 16.0, 0.0, TAU, 22, Color(0.56, 0.69, 0.55, 0.28), 1.0, true)
			draw_arc(position, 24.0, 0.0, TAU, 22, Color(0.56, 0.69, 0.55, 0.13), 1.0, true)
		# Severed speaking tubes carry the old promise into empty water.
		draw_rect(Rect2(position.x - 9.0, position.y - 3.0, 18.0, 7.0), Color("111714"))
		draw_rect(Rect2(position.x - 7.0, position.y - 1.0, 14.0, 3.0), Color("403a2b"))
		draw_rect(Rect2(position.x - 5.0, position.y, 10.0, 1.0), Color(0.57, 0.68, 0.53, flicker))
		draw_rect(Rect2(position.x - 11.0, position.y + 3.0, 3.0, 4.0), Color("242820"))
		draw_rect(Rect2(position.x + 8.0, position.y + 3.0, 3.0, 4.0), Color("242820"))

func _draw_current_streams() -> void:
	# Silt drifts sideways through two invisible pressure seams; no path is marked as safe.
	for stream in range(20):
		var phase := elapsed * 15.0 + float(stream) * 91.0
		var x := 500.0 + fposmod(850.0 - phase, 930.0)
		var y := 195.0 + float((stream * 47) % 315) + sin(elapsed * 0.8 + float(stream)) * 3.0
		var opacity := 0.08 + float(stream % 3) * 0.025
		draw_line(Vector2(x, y), Vector2(x - 11.0, y + 1.0), Color(0.57, 0.65, 0.56, opacity), 1.0, false)
		draw_rect(Rect2(x - 14.0, y + 2.0, 1.0, 1.0), Color(0.69, 0.72, 0.58, opacity * 0.72))

func _draw_aetherite_seams() -> void:
	# Only a few dull crystals remain; their glow is weak beside the vast empty cut.
	for index in range(8):
		var x := 615.0 + float(index) * 219.0
		var y := 535.0 - float((index * 11) % 65)
		var glow := 0.08 + (sin(elapsed * 1.4 + float(index)) + 1.0) * 0.035
		draw_rect(Rect2(x - 5.0, y - 3.0, 17.0, 13.0), Color(0.18, 0.50, 0.39, glow))
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 5.0), Vector2(x + 4.0, y - 11.0), Vector2(x + 8.0, y + 2.0)]), Color("26463a"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 6.0, y + 4.0), Vector2(x + 12.0, y - 6.0), Vector2(x + 15.0, y + 5.0)]), Color("324c3c"))
		draw_rect(Rect2(x + 3.0, y - 5.0, 1.0, 5.0), Color(0.57, 0.73, 0.56, glow * 2.4))
