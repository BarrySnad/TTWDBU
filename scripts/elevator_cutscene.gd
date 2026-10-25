extends Node2D

const DreadOverlayScript = preload("res://scripts/dread_overlay.gd")

const PlayerScript = preload("res://scripts/player.gd")
const DEEP_LEVEL := "res://scenes/deep_level.tscn"
const MONOLOGUE := [
	{"at": 0.7, "until": 2.5, "text": "What the hell was that?"},
	{"at": 2.7, "until": 4.8, "text": "That thing... it was wearing my helmet."},
	{"at": 5.0, "until": 7.1, "text": "The Crown drew my birth-year. They called it an honour."},
	{"at": 7.3, "until": 9.9, "text": "They said my family was safe in a settlement below."},
	{"at": 10.1, "until": 12.2, "text": "At this pressure, there is no way back up."},
	{"at": 12.4, "until": 14.4, "text": "What else has the Crown buried down here?"}
]

var player: CharacterBody2D
var camera: Camera2D
var caption: Label
var depth_label: Label
var fade: ColorRect
var ambience: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var pressure_layer: AudioStreamPlayer
var dread_overlay: Node
var sfx_players: Array[AudioStreamPlayer] = []
var clank_sfx: AudioStreamWAV
var rattle_sfx: AudioStreamWAV
var cable_sfx: AudioStreamWAV
var elapsed := 0.0
var cutscene_time := 0.0
var clank_timer := 0.5
var rattle_timer := 1.8
var cable_timer := 3.8
var active_line := -1
var transitioning := false
var transition_time := 0.0
var sfx_index := 0

func _ready() -> void:
	_setup_input()
	_build_player()
	_build_ui()
	_build_audio()
	_play_sound(clank_sfx, -8.0, 0.05)
	_play_sound(rattle_sfx, -13.0, 0.07)

func _setup_input() -> void:
	if not InputMap.has_action("ui_accept"):
		InputMap.add_action("ui_accept")
		for keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event("ui_accept", event)

func _build_player() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(160.0, 157.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(204.0, 8.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	player = CharacterBody2D.new()
	player.name = "DiverInLift"
	player.set_script(PlayerScript)
	player.position = Vector2(160.0, 147.0)
	player.collision_layer = 1
	player.collision_mask = 1
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 6.0
	capsule.height = 40.0
	collision.shape = capsule
	collision.position = Vector2(0.0, -14.0)
	player.add_child(collision)
	player.controls_enabled = false
	player.underwater = false
	player.panicking = true
	add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = false
	player.add_child(camera)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	dread_overlay = DreadOverlayScript.new()
	canvas.add_child(dread_overlay)
	var hud := Control.new()
	hud.name = "HudScale"
	hud.size = Vector2(320.0, 180.0)
	hud.scale = Vector2(2.0, 2.0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	_add_panel(hud, Rect2(8.0, 6.0, 180.0, 20.0), Color(0.008, 0.017, 0.019, 0.82))
	var heading := _add_label(hud, Vector2(13.0, 8.0), Vector2(170.0, 8.0), "RHEGAN // PRESSURE LIFT 02", 6, Color("b8a77d"))
	heading.add_theme_color_override("font_shadow_color", Color("090c0a"))
	depth_label = _add_label(hud, Vector2(13.0, 17.0), Vector2(170.0, 7.0), "DESCENT  //  312 M", 6, Color("82958a"))
	_add_panel(hud, Rect2(8.0, 137.0, 304.0, 33.0), Color(0.006, 0.014, 0.018, 0.91))
	var comms := _add_label(hud, Vector2(15.0, 139.0), Vector2(290.0, 7.0), "DIVER  //  PRIVATE COMMS", 5, Color("a6804e"))
	caption = _add_label(hud, Vector2(16.0, 148.0), Vector2(288.0, 18.0), "", 8, Color("ded7c3"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skip_hint := _add_label(hud, Vector2(224.0, 11.0), Vector2(88.0, 8.0), "SPACE / ENTER  SKIP", 5, Color("6c7970"))
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.002, 0.006, 0.008, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func _add_panel(parent: Control, rect: Rect2, tint: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = tint
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _add_label(parent: Control, at: Vector2, bounds: Vector2, text_value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = bounds
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_audio() -> void:
	ambience = _make_loop("res://audio/elevator_motor.wav", -7.5)
	breath_player = _make_loop("res://audio/helmet_breath.wav", -8.5)
	pressure_layer = _make_loop("res://audio/pressure_roomtone.wav", -25.0)
	clank_sfx = load("res://audio/elevator_clank.wav") as AudioStreamWAV
	rattle_sfx = load("res://audio/elevator_rattle.wav") as AudioStreamWAV
	cable_sfx = load("res://audio/elevator_cable_groan.wav") as AudioStreamWAV
	for i in range(3):
		var sound := AudioStreamPlayer.new()
		sound.volume_db = -10.0
		add_child(sound)
		sfx_players.append(sound)
	if ambience:
		ambience.play()
	if breath_player:
		breath_player.play()
	if pressure_layer:
		pressure_layer.play()

func _make_loop(path: String, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	return sound

func _play_sound(stream: AudioStream, volume_db: float, pitch_jitter := 0.04) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var sound := sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	sound.play()

func _process(delta: float) -> void:
	elapsed += delta
	if not transitioning:
		fade.color.a = maxf(0.0, fade.color.a - delta * 0.76)
		cutscene_time += delta
		_update_monologue()
		clank_timer -= delta
		rattle_timer -= delta
		cable_timer -= delta
		if clank_timer <= 0.0:
			_play_sound(clank_sfx, -9.0, 0.08)
			clank_timer = randf_range(2.1, 4.4)
		if rattle_timer <= 0.0:
			_play_sound(rattle_sfx, -12.0, 0.10)
			rattle_timer = randf_range(3.4, 5.5)
		if cable_timer <= 0.0:
			_play_sound(cable_sfx, -15.0, 0.07)
			cable_timer = randf_range(6.5, 9.0)
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_ESCAPE):
			_begin_transition()
		elif cutscene_time >= 14.8:
			_begin_transition()
		var depth := 312 + int(minf(cutscene_time, 14.8) * 7.2)
		depth_label.text = "DESCENT  //  %d M" % depth
	else:
		transition_time += delta
		fade.color = Color(0.002, 0.006, 0.008, clampf(transition_time / 1.0, 0.0, 1.0))
		if transition_time >= 1.0:
			get_tree().change_scene_to_file(DEEP_LEVEL)
	var descent := clampf(cutscene_time / 14.8, 0.0, 1.0)
	if dread_overlay:
		dread_overlay.call("set_dread", 0.16 + descent * 0.12, 0.3 + descent * 0.5)
	if pressure_layer:
		pressure_layer.volume_db = lerpf(-25.0, -14.0, descent)
	var shake := 0.35 + maxf(0.0, sin(elapsed * 5.4)) * 0.8
	camera.offset = Vector2(sin(elapsed * 27.0) * shake, sin(elapsed * 17.0) * shake * 0.45)
	queue_redraw()

func _update_monologue() -> void:
	var next_line := -1
	for i in range(MONOLOGUE.size()):
		var line: Dictionary = MONOLOGUE[i]
		if cutscene_time >= float(line["at"]) and cutscene_time < float(line["until"]):
			next_line = i
	if next_line == active_line:
		return
	active_line = next_line
	caption.text = str(MONOLOGUE[active_line]["text"]) if active_line >= 0 else ""

func _begin_transition() -> void:
	if transitioning:
		return
	transitioning = true
	transition_time = 0.0
	active_line = -1
	caption.text = "THE LIFT KEEPS DESCENDING."
	if ambience:
		ambience.volume_db = -17.0
	_play_sound(clank_sfx, -4.5, 0.02)
	_play_sound(cable_sfx, -11.0, 0.02)

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 320.0, 240.0), Color("03080a"))
	# The shaft scrolls upward outside the iron cage as the lift drops below Station IX.
	for i in range(18):
		var y := fposmod(float(i) * 18.0 - elapsed * 31.0, 224.0) + 5.0
		var beam_color := Color("121a19") if i % 2 == 0 else Color("0d1516")
		draw_rect(Rect2(0.0, y, 320.0, 5.0), beam_color)
		draw_rect(Rect2(12.0, y + 4.0, 296.0, 1.0), Color("403429", 0.55))
		if i % 3 == 0:
			draw_rect(Rect2(30.0, y - 2.0, 2.0, 8.0), Color("755537"))
			draw_rect(Rect2(286.0, y - 2.0, 2.0, 8.0), Color("755537"))
	# Station lamps and riveted outer guide rails disappear into the black above.
	draw_rect(Rect2(0.0, 0.0, 320.0, 28.0), Color("0b1112"))
	draw_rect(Rect2(0.0, 25.0, 320.0, 4.0), Color("483a29"))
	for i in range(8):
		var sx := float(i) * 46.0 + 18.0
		draw_rect(Rect2(sx, 9.0, 11.0, 2.0), Color(0.84, 0.61, 0.32, 0.18 + maxf(0.0, sin(elapsed * 4.0 + float(i))) * 0.13))
		draw_rect(Rect2(sx + 4.0, 11.0, 3.0, 5.0), Color("242b26"))
	# Cage frame, cross-bracing, cable drum and worn brass floor plate.
	draw_rect(Rect2(52.0, 20.0, 9.0, 140.0), Color("111817"))
	draw_rect(Rect2(59.0, 20.0, 3.0, 140.0), Color("80603b"))
	draw_rect(Rect2(259.0, 20.0, 9.0, 140.0), Color("111817"))
	draw_rect(Rect2(259.0, 20.0, 3.0, 140.0), Color("80603b"))
	draw_rect(Rect2(58.0, 31.0, 204.0, 5.0), Color("191f1c"))
	draw_rect(Rect2(58.0, 32.0, 204.0, 1.0), Color("76593a"))
	draw_rect(Rect2(58.0, 143.0, 204.0, 8.0), Color("1a201c"))
	draw_rect(Rect2(62.0, 143.0, 196.0, 2.0), Color("967346"))
	for bar in range(11):
		var x := 73.0 + float(bar) * 17.2
		var sway := sin(elapsed * 24.0 + float(bar) * 0.8) * 0.35
		draw_rect(Rect2(x + sway, 34.0, 2.0, 109.0), Color("202a27"))
		draw_rect(Rect2(x + 0.5 + sway, 36.0, 0.75, 105.0), Color("5e5945"))
		draw_rect(Rect2(x - 1.0 + sway, 53.0, 4.0, 2.0), Color("a17849"))
	for bolt_y in [43.0, 73.0, 103.0, 133.0]:
		for bolt_x in [57.0, 260.0]:
			draw_rect(Rect2(bolt_x, bolt_y, 2.0, 2.0), Color("c09a61"))
	# The cage jolts, then settles, so the shaking stays tied to the cable rhythm.
	var shudder := sin(elapsed * 31.0) * (0.12 + maxf(0.0, sin(elapsed * 4.7)) * 0.18)
	draw_rect(Rect2(76.0 + shudder, 37.0, 169.0, 2.0), Color("303631"))
	draw_rect(Rect2(77.0 + shudder, 40.0, 1.0, 101.0), Color("8c704a"))
	draw_rect(Rect2(243.0 + shudder, 40.0, 1.0, 101.0), Color("8c704a"))
	# Depth indicator / pressure gauge mounted by the cage door.
	draw_rect(Rect2(274.0, 76.0, 31.0, 44.0), Color("121917"))
	draw_rect(Rect2(277.0, 79.0, 25.0, 17.0), Color("3c382c"))
	draw_rect(Rect2(279.0, 81.0, 21.0, 13.0), Color("152527"))
	draw_rect(Rect2(283.0, 87.0, 12.0, 1.0), Color("c18d49"))
	draw_rect(Rect2(282.0, 101.0, 16.0, 2.0), Color("63472e"))
	draw_rect(Rect2(282.0, 106.0, 12.0, 7.0), Color("24312d"))
	draw_rect(Rect2(284.0, 108.0, 2.0, 3.0), Color("c18d49"))
	# Cable, chain links and the shadow of the unseen shaft above.
	draw_rect(Rect2(155.0, 0.0, 10.0, 34.0), Color("171d1a"))
	draw_rect(Rect2(158.0, 0.0, 4.0, 34.0), Color("80613e"))
	for link in range(6):
		var link_y := 19.0 + float(link) * 4.0 + sin(elapsed * 28.0 + float(link)) * 0.4
		draw_rect(Rect2(153.0, link_y, 14.0, 2.0), Color("625035"))
		draw_rect(Rect2(157.0, link_y + 0.5, 6.0, 1.0), Color("151d1a"))
	# A few loose droplets and dust flakes catch the weak brass lamps.
	for mote in range(24):
		var mx := fposmod(float(mote * 41 + 13) + sin(elapsed * 1.5 + float(mote)) * 4.0, 320.0)
		var my := fposmod(float(mote * 23 + 7) + elapsed * (7.0 + float(mote % 4)), 180.0)
		draw_rect(Rect2(mx, my, 1.0, 1.0), Color(0.71, 0.69, 0.53, 0.17 + float(mote % 3) * 0.05))

