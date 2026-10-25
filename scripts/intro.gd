extends Node2D

const DreadOverlayScript = preload("res://scripts/dread_overlay.gd")

const GAME_SCENE := "res://scenes/main.tscn"
const SPEECH_LINES := [
	{"start": 2.0, "end": 5.0, "text": "People of Rhegan. Our future lies beneath the sea."},
	{"start": 5.2, "end": 8.6, "text": "Aetherite raised the Crown's engines centuries beyond their age."},
	{"start": 8.8, "end": 12.2, "text": "Our upper veins are spent. The abyss may yet hold ore."},
	{"start": 12.4, "end": 16.2, "text": "The birth-year lot is drawn. Your name has been chosen."},
	{"start": 16.4, "end": 19.6, "text": "You are pioneers. Rhegan will remember you as heroes forever."},
	{"start": 19.8, "end": 23.4, "text": "They promise your families are safe in the settlements below."},
	{"start": 23.6, "end": 27.8, "text": "No vessel returns through that pressure. Descend, and secure Rhegan's prosperity."}
]

var elapsed := 0.0
var transitioning := false
var transition_time := 0.0
var crowd_audio: AudioStreamPlayer
var pa_audio: AudioStreamPlayer
var bell_audio: AudioStreamPlayer
var hud: Control
var dread_overlay: Node
var location_label: Label
var banner_label: Label
var speaker_label: Label
var speech_panel: ColorRect
var speech_label: Label
var skip_label: Label
var title_card: Control
var fade: ColorRect

func _ready() -> void:
	_build_hud()
	_build_audio()
	queue_redraw()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	dread_overlay = DreadOverlayScript.new()
	layer.add_child(dread_overlay)
	dread_overlay.call("set_dread", 0.035, 0.025)
	hud = Control.new()
	hud.name = "HudScale"
	hud.size = Vector2(320, 180)
	hud.scale = Vector2(2, 2)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var location_panel := ColorRect.new()
	location_panel.position = Vector2(5, 5)
	location_panel.size = Vector2(130, 17)
	location_panel.color = Color(0.008, 0.018, 0.026, 0.88)
	hud.add_child(location_panel)
	location_label = Label.new()
	location_label.position = Vector2(9, 5)
	location_label.size = Vector2(122, 12)
	location_label.text = "RHEGAN COAST  /  1548"
	location_label.add_theme_font_size_override("font_size", 7)
	location_label.add_theme_color_override("font_color", Color("b8c9bd"))
	hud.add_child(location_label)
	var banner := ColorRect.new()
	banner.position = Vector2(99, 37)
	banner.size = Vector2(122, 15)
	banner.color = Color(0.008, 0.018, 0.026, 0.82)
	hud.add_child(banner)
	banner_label = Label.new()
	banner_label.position = Vector2(100, 38)
	banner_label.size = Vector2(120, 12)
	banner_label.text = "THE CROWN'S DEPTH LOT"
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 6)
	banner_label.add_theme_color_override("font_color", Color("c18d49"))
	hud.add_child(banner_label)
	speech_panel = ColorRect.new()
	speech_panel.position = Vector2(11, 127)
	speech_panel.size = Vector2(298, 42)
	speech_panel.color = Color(0.025, 0.032, 0.032, 0.88)
	hud.add_child(speech_panel)
	speaker_label = Label.new()
	speaker_label.position = Vector2(19, 130)
	speaker_label.size = Vector2(282, 10)
	speaker_label.text = "HERALD OF THE CROWN"
	speaker_label.add_theme_font_size_override("font_size", 6)
	speaker_label.add_theme_color_override("font_color", Color("c18d49"))
	hud.add_child(speaker_label)
	speech_label = Label.new()
	speech_label.position = Vector2(18, 140)
	speech_label.size = Vector2(284, 26)
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.add_theme_font_size_override("font_size", 8)
	speech_label.add_theme_color_override("font_color", Color("d4d3bd"))
	hud.add_child(speech_label)
	skip_label = Label.new()
	skip_label.position = Vector2(248, 169)
	skip_label.size = Vector2(66, 9)
	skip_label.text = "[SPACE] SKIP"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.add_theme_font_size_override("font_size", 6)
	skip_label.add_theme_color_override("font_color", Color("a9c9be"))
	hud.add_child(skip_label)
	_build_title_card()
	fade = ColorRect.new()
	fade.size = Vector2(320, 180)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.01, 0.025, 0.04, 1.0)
	hud.add_child(fade)

func _build_title_card() -> void:
	title_card = Control.new()
	title_card.position = Vector2(25, 54)
	title_card.size = Vector2(270, 68)
	title_card.modulate.a = 0.0
	hud.add_child(title_card)
	var panel := ColorRect.new()
	panel.position = Vector2.ZERO
	panel.size = title_card.size
	panel.color = Color(0.025, 0.035, 0.037, 0.94)
	title_card.add_child(panel)
	var top_rule := ColorRect.new()
	top_rule.position = Vector2(12, 8)
	top_rule.size = Vector2(246, 0.75)
	top_rule.color = Color("c18d49")
	title_card.add_child(top_rule)
	var title_text := Label.new()
	title_text.position = Vector2(8, 15)
	title_text.size = Vector2(254, 39)
	title_text.text = "TO THOSE WHO DOVE\nBEFORE US"
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_text.add_theme_font_size_override("font_size", 17)
	title_text.add_theme_color_override("font_color", Color("d4d3bd"))
	title_card.add_child(title_text)
	var subtitle := Label.new()
	subtitle.position = Vector2(8, 53)
	subtitle.size = Vector2(254, 10)
	subtitle.text = "THE CROWN DRAWS. YOU DESCEND."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 6)
	subtitle.add_theme_color_override("font_color", Color("a9c9be"))
	title_card.add_child(subtitle)

func _build_audio() -> void:
	crowd_audio = _make_loop("res://audio/market_crowd.wav", -10.0)
	pa_audio = _make_loop("res://audio/public_address.wav", -19.0)
	bell_audio = AudioStreamPlayer.new()
	bell_audio.stream = load("res://audio/distant_bell.wav") as AudioStreamWAV
	bell_audio.volume_db = -10.0
	add_child(bell_audio)

func _make_loop(path: String, level_db: float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.stream = stream
	audio.volume_db = level_db
	audio.autoplay = true
	add_child(audio)
	return audio

func _process(delta: float) -> void:
	elapsed += delta
	var unease := clampf(elapsed / 28.0, 0.0, 1.0)
	if transitioning:
		unease = maxf(unease, clampf(transition_time / 3.5, 0.0, 1.0))
	if dread_overlay:
		dread_overlay.call("set_dread", 0.035 + unease * 0.09, 0.025 + unease * 0.12)
	if elapsed >= 1.1 and elapsed < 2.0 and not bell_audio.playing:
		bell_audio.play()
	var active_line := ""
	for line in SPEECH_LINES:
		if elapsed >= line["start"] and elapsed < line["end"]:
			active_line = line["text"]
			break
	speech_panel.visible = not active_line.is_empty()
	speaker_label.visible = not active_line.is_empty()
	speech_label.text = active_line
	if elapsed >= 28.0 and not transitioning:
		title_card.modulate.a = clampf((elapsed - 28.0) / 1.2, 0.0, 1.0)
		skip_label.visible = elapsed < 30.0
		crowd_audio.volume_db = lerpf(-10.0, -22.0, clampf((elapsed - 28.0) / 3.0, 0.0, 1.0))
		pa_audio.volume_db = lerpf(-19.0, -29.0, clampf((elapsed - 28.0) / 3.0, 0.0, 1.0))
	if elapsed >= 32.0 and not transitioning:
		_start_transition()
	if elapsed >= 1.2 and Input.is_action_just_pressed("ui_accept") and not transitioning:
		_start_transition()
	if transitioning:
		transition_time += delta
		fade.color = Color(0.01, 0.025, 0.04, clampf(transition_time / 1.25, 0.0, 1.0))
		if transition_time >= 1.25:
			get_tree().change_scene_to_file(GAME_SCENE)
	queue_redraw()
	if elapsed < 1.2 and not transitioning:
		fade.color = Color(0.01, 0.025, 0.04, 1.0 - elapsed / 1.2)

func _start_transition() -> void:
	transitioning = true
	transition_time = 0.0
	speech_panel.visible = false
	speaker_label.visible = false
	speech_label.text = ""
	skip_label.visible = false
	if title_card.modulate.a < 1.0:
		title_card.modulate.a = 1.0

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0, 2.0))
	var warm_flicker := 0.025 * sin(elapsed * 2.7)
	# Rhegan is Renaissance Europe recast around Aetherite: slate, timber, brass and premature steamworks.
	draw_rect(Rect2(0, 0, 320, 180), Color("07151d"))
	draw_rect(Rect2(0, 0, 320, 89), Color("0b222a"))
	draw_rect(Rect2(0, 0, 320, 47), Color("102b32"))
	draw_rect(Rect2(0, 45, 320, 1), Color(0.16, 0.38, 0.40, 0.16))
	# Smoke-softened sky and distant chimney silhouettes.
	draw_rect(Rect2(14, 16, 46, 8), Color(0.30, 0.53, 0.53, 0.16))
	draw_rect(Rect2(20, 14, 33, 3), Color(0.57, 0.75, 0.67, 0.12))
	draw_rect(Rect2(242, 21, 56, 7), Color(0.30, 0.53, 0.53, 0.14))
	draw_rect(Rect2(253, 18, 35, 3), Color(0.57, 0.75, 0.67, 0.10))
	# Stone guild halls, half-timbered houses, and the city clock tower.
	draw_rect(Rect2(0, 34, 66, 72), Color("17292b"))
	draw_rect(Rect2(8, 27, 17, 79), Color("263438"))
	draw_rect(Rect2(14, 19, 8, 8), Color("33413b"))
	draw_rect(Rect2(29, 44, 28, 62), Color("1b3438"))
	draw_rect(Rect2(35, 32, 14, 12), Color("33413b"))
	draw_rect(Rect2(40, 13, 6, 19), Color("111b1d"))
	draw_rect(Rect2(41, 10, 4, 4), Color("30362f"))
	draw_rect(Rect2(256, 39, 64, 67), Color("17292b"))
	draw_rect(Rect2(263, 27, 19, 12), Color("33413b"))
	draw_rect(Rect2(269, 17, 7, 10), Color("111b1d"))
	draw_rect(Rect2(285, 31, 22, 75), Color("1b3438"))
	draw_rect(Rect2(290, 16, 11, 15), Color("263438"))
	draw_rect(Rect2(295, 7, 3, 9), Color("111b1d"))
	draw_rect(Rect2(79, 49, 162, 58), Color("263438"))
	draw_rect(Rect2(83, 42, 154, 7), Color("111b1d"))
	# Pointed slate roofs and timber framing replace the old Victorian warehouse silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 39), Vector2(28, 17), Vector2(67, 39)]), Color("514235"))
	draw_colored_polygon(PackedVector2Array([Vector2(74, 52), Vector2(158, 15), Vector2(246, 52)]), Color("493a31"))
	draw_colored_polygon(PackedVector2Array([Vector2(253, 41), Vector2(286, 14), Vector2(320, 41)]), Color("514235"))
	draw_line(Vector2(1, 39), Vector2(28, 18), Color("987650"), 1.0)
	draw_line(Vector2(28, 18), Vector2(66, 39), Color("987650"), 1.0)
	draw_line(Vector2(76, 52), Vector2(158, 16), Color("8f7048"), 1.0)
	draw_line(Vector2(158, 16), Vector2(244, 52), Color("8f7048"), 1.0)
	# Individual slate courses and chipped tile highlights give the civic roof more depth.
	for roof_row in range(7):
		var slate_y := 21.0 + float(roof_row) * 4.0
		var roof_half_width := (slate_y - 15.0) * 2.22
		var roof_left := 158.0 - roof_half_width + float(roof_row % 2) * 3.0
		var roof_right := 158.0 + roof_half_width
		var slate_x := roof_left + 2.0
		while slate_x < roof_right - 2.0:
			var slate_width := 4.0 + float(int(slate_x + float(roof_row) * 3.0) % 4)
			draw_rect(Rect2(slate_x, slate_y, minf(slate_width, roof_right - slate_x), 1.0), Color("65503b") if roof_row % 2 == 0 else Color("57463a"))
			draw_rect(Rect2(slate_x + 1.0, slate_y + 1.0, maxf(1.0, minf(slate_width - 2.0, roof_right - slate_x - 1.0)), 0.5), Color("241f1d", 0.78))
			if int(slate_x + float(roof_row) * 5.0) % 5 == 0:
				draw_rect(Rect2(slate_x + 1.0, slate_y, 1.0, 1.0), Color("a17b4c", 0.66))
			slate_x += slate_width + 2.0
	# Timber repair pegs and hairline cracks make the plastered guild hall feel inhabited.
	for repair_x in [101.0, 216.0]:
		draw_rect(Rect2(repair_x, 67.0, 2.0, 7.0), Color("182423"))
		draw_rect(Rect2(repair_x + 0.5, 67.0, 0.75, 5.0), Color("566054"))
		draw_rect(Rect2(repair_x + 3.0, 73.0, 1.0, 4.0), Color("111b1d"))
	for crack in range(5):
		var crack_x := 96.0 + float((crack * 31) % 127)
		var crack_y := 57.0 + float((crack * 13) % 27)
		draw_line(Vector2(crack_x, crack_y), Vector2(crack_x + 1.0, crack_y + 2.0), Color("101b1d", 0.82), 0.7, false)
		draw_line(Vector2(crack_x + 1.0, crack_y + 2.0), Vector2(crack_x, crack_y + 4.0), Color("101b1d", 0.82), 0.7, false)
	for timber_x in [92.0, 126.0, 192.0, 226.0]:
		draw_rect(Rect2(timber_x, 54, 2, 48), Color("5a4935"))
		draw_line(Vector2(timber_x + 2, 63), Vector2(timber_x + 14, 76), Color("735b3d"), 1.0)
		draw_line(Vector2(timber_x + 2, 90), Vector2(timber_x + 14, 78), Color("735b3d"), 1.0)
	# A pressure pipe and flywheel show how Aetherite pulled Rhegan into industry early.
	draw_rect(Rect2(57, 58, 5, 42), Color("64472f"))
	draw_rect(Rect2(58, 60, 2, 38), Color("b08048"))
	draw_rect(Rect2(51, 76, 12, 3), Color("4b3c2e"))
	draw_arc(Vector2(70, 77), 6.0, 0.0, TAU, 8, Color("9c7447"), 1.0, false)
	draw_rect(Rect2(69, 74, 2, 6), Color("b58b54"))
	draw_rect(Rect2(65, 76, 10, 2), Color("b58b54"))
	draw_rect(Rect2(80, 51, 2, 54), Color("33413b"))
	draw_rect(Rect2(238, 51, 2, 54), Color("111b1d"))
	# Ironwork and masonry bands break up the broad walls into chunky pixel clusters.
	draw_rect(Rect2(84, 51, 152, 1), Color("506054"))
	draw_rect(Rect2(84, 84, 152, 1), Color("17292b"))
	for x in [86.0, 118.0, 202.0, 234.0]:
		draw_rect(Rect2(x, 52, 1, 51), Color("1b2927"))
		draw_rect(Rect2(x + 1, 86, 2, 1), Color("5a6253"))
	for x in [88.0, 108.0, 128.0, 192.0, 212.0, 232.0]:
		draw_rect(Rect2(x, 58, 9, 23), Color("111d1e"))
		draw_rect(Rect2(x + 1, 60, 7, 18), Color("5b4935"))
		draw_rect(Rect2(x + 2, 61, 1, 15), Color(0.96, 0.73, 0.39, 0.30))
		draw_rect(Rect2(x + 4, 60, 1, 18), Color("85734e"))
		draw_rect(Rect2(x - 1, 55, 11, 2), Color("33413b"))
		draw_rect(Rect2(x + 1, 80, 2, 1), Color("c18d49"))
	# Central clock tower with a brass-rimmed face.
	draw_rect(Rect2(143, 7, 34, 46), Color("111b1d"))
	draw_rect(Rect2(146, 8, 2, 42), Color("506054"))
	draw_rect(Rect2(147, 2, 26, 9), Color("33413b"))
	draw_rect(Rect2(151, 0, 18, 4), Color("5b4935"))
	draw_rect(Rect2(154, 12, 12, 12), Color("877351"))
	draw_rect(Rect2(155, 13, 10, 10), Color("c18d49"))
	draw_rect(Rect2(156, 14, 8, 8), Color("25353a"))
	draw_rect(Rect2(159.5, 15, 1, 4), Color("d4d3bd"))
	draw_rect(Rect2(160, 17, 3, 1), Color("d4d3bd"))
	draw_rect(Rect2(151, 29, 18, 22), Color("17292b"))
	draw_rect(Rect2(149, 26, 2, 25), Color("263438"))
	draw_rect(Rect2(169, 26, 2, 25), Color("111b1d"))
	draw_rect(Rect2(154, 27, 12, 1), Color("5a6253"))
	# Foundry vents breathe steam above a web of hoist ropes and pulley lines.
	for i in range(5):
		var puff_y := 7.0 - fposmod(elapsed * 2.0 + float(i) * 3.0, 11.0)
		var puff_x := 40.0 + float(i % 2) * 2.0
		draw_rect(Rect2(puff_x, puff_y, 3, 2), Color(0.57, 0.75, 0.67, 0.14))
	for x in [44.0, 274.0]:
		draw_line(Vector2(x, 35), Vector2(x, 63), Color("493c2f"), 1.0)
		draw_rect(Rect2(x - 1, 43, 3, 2), Color("a17949"))
	draw_line(Vector2(44, 37), Vector2(77, 50), Color("493c2f"), 1.0)
	draw_line(Vector2(274, 37), Vector2(244, 50), Color("493c2f"), 1.0)
	# Market awnings, crates, striped fabric, and gas lamps.
	_draw_market_stall(17.0, 83.0, Color("8d4f33"))
	_draw_market_stall(263.0, 83.0, Color("375c5d"))
	_draw_lamp(69.0, 75.0, warm_flicker)
	_draw_lamp(250.0, 75.0, -warm_flicker)
	# Broad stone square and receding paving lines.
	draw_rect(Rect2(0, 104, 320, 76), Color("090f12"))
	draw_rect(Rect2(0, 105, 320, 2), Color("596051"))
	for row in range(6):
		var y := 112.0 + row * 12.0
		draw_rect(Rect2(0, y, 320, 0.75), Color("182223"))
		for i in range(12):
			var x := float(i * 28 + (row % 2) * 14)
			draw_rect(Rect2(x, y + 3, 12, 0.5), Color(0.57, 0.75, 0.67, 0.10))
			draw_rect(Rect2(x + 14, y + 5, 1, 4), Color(0.16, 0.24, 0.25, 0.30))
	# A small civic stage in the exact center of the square.
	draw_rect(Rect2(128, 102, 64, 21), Color("111b1d"))
	draw_rect(Rect2(124, 98, 72, 6), Color("5b4935"))
	draw_rect(Rect2(125, 99, 70, 1), Color("c18d49"))
	draw_rect(Rect2(132, 105, 56, 14), Color("30362f"))
	draw_rect(Rect2(135, 107, 50, 1), Color("85734e"))
	draw_rect(Rect2(130, 120, 60, 1), Color("1b2927"))
	# A government-approved hardhat suit stands beside the speaker, echoing our divers.
	_draw_diver_exhibit(173.0, 73.0)
	# Birth-lot notice: rows of names, with this year's selected line sealed in red wax.
	draw_rect(Rect2(204, 82, 15, 27), Color("111b1d"))
	draw_rect(Rect2(206, 84, 11, 23), Color("a18a62"))
	draw_rect(Rect2(207, 85, 9, 2), Color("5b4935"))
	for row in range(5):
		var row_y := 89.0 + float(row) * 3.0
		draw_rect(Rect2(208, row_y, 5 + float(row % 3), 1), Color("40382d"))
	draw_rect(Rect2(207, 100, 9, 2), Color("813b32"))
	draw_rect(Rect2(213, 100, 2, 2), Color("bd6948"))
	for x in [136.0, 184.0]:
		draw_rect(Rect2(x, 109, 2, 2), Color("877351"))
		draw_rect(Rect2(x + 0.5, 109.5, 0.75, 0.75), Color("d3ad63"))
	# Enamel dedication plaque and repeated rivets, in the same aged brass palette.
	draw_rect(Rect2(148, 112, 24, 5), Color("111b1d"))
	draw_rect(Rect2(149, 113, 22, 3), Color("5b4935"))
	draw_rect(Rect2(150, 114, 20, 1), Color("c18d49"))
	draw_rect(Rect2(154, 115, 12, 1), Color("263438"))
	for x in [134.0, 142.0, 178.0, 186.0]:
		draw_rect(Rect2(x, 117, 1, 1), Color("877351"))
	# The Crown's herald wears a feathered cap, split doublet, mantle and chain of office.
	var gesture := sin(elapsed * 2.1) * 1.5
	draw_colored_polygon(PackedVector2Array([Vector2(151, 82), Vector2(154, 78), Vector2(166, 78), Vector2(169, 83), Vector2(168, 99), Vector2(152, 99)]), Color("17211f"))
	draw_rect(Rect2(154, 82, 12, 15), Color("46352e"))
	draw_rect(Rect2(155, 83, 5, 13), Color("6a4932"))
	draw_rect(Rect2(160, 83, 5, 13), Color("3d4942"))
	draw_rect(Rect2(155, 82, 10, 3), Color("c7b894"))
	draw_line(Vector2(155, 85), Vector2(165, 94), Color("c18d49"), 1.0)
	draw_rect(Rect2(158, 87, 1, 1), Color("e1bd75"))
	draw_rect(Rect2(160, 90, 1, 1), Color("e1bd75"))
	draw_rect(Rect2(162, 93, 1, 1), Color("e1bd75"))
	draw_rect(Rect2(153, 86, 2, 8), Color("8f623c"))
	draw_rect(Rect2(165, 84, 2, 7 + gesture), Color("8f623c"))
	draw_rect(Rect2(166, 82 + gesture, 2, 3), Color("a46b36"))
	# The raised hand holds the sealed order that names the next year's divers.
	draw_rect(Rect2(168, 77 + gesture, 5, 12), Color("d6c69d"))
	draw_rect(Rect2(169, 78 + gesture, 3, 9), Color("efe1bc"))
	draw_rect(Rect2(170, 85 + gesture, 2, 2), Color("8d3f34"))
	draw_rect(Rect2(158, 80, 3, 3), Color("c18d49"))
	draw_rect(Rect2(156, 72, 9, 8), Color("8f623c"))
	draw_rect(Rect2(155, 70, 11, 4), Color("253833"))
	draw_rect(Rect2(154, 72, 13, 2), Color("5b4935"))
	draw_colored_polygon(PackedVector2Array([Vector2(162, 70), Vector2(165, 62), Vector2(166, 71)]), Color("a98a52"))
	draw_rect(Rect2(158, 75, 1, 1), Color("171f20"))
	draw_rect(Rect2(164, 75, 1, 1), Color("171f20"))
	draw_rect(Rect2(157, 78, 7, 1), Color("877351"))
	# Brass speaking horn and Rhegan's crowned pennants behind the podium.
	draw_rect(Rect2(144, 86, 3, 11), Color("263438"))
	draw_rect(Rect2(140, 84, 7, 2), Color("877351"))
	draw_rect(Rect2(139, 83, 3, 4), Color("c18d49"))
	draw_rect(Rect2(123, 78, 1, 18), Color("263438"))
	draw_rect(Rect2(196, 78, 1, 18), Color("263438"))
	draw_rect(Rect2(124, 79, 5, 7), Color("8d4f33"))
	draw_rect(Rect2(191, 79, 5, 7), Color("375c5d"))
	# Layers of citizens. We see the back of our own coat at the bottom of frame.
	for row in range(4):
		var ground_y := 128.0 + row * 13.0
		for i in range(14):
			var citizen_x := float(i * 25 + (row % 2) * 12 - 7)
			if citizen_x > 7.0 and citizen_x < 313.0:
				_draw_citizen(citizen_x, ground_y, row * 14 + i, false)
	_draw_citizen(157.0, 187.0, 77, true)
	# Fine specks and restrained amber glow carry the same submerged atmosphere into the intro.
	for i in range(28):
		var glint_x := fposmod(float(i * 61) + elapsed * 0.7, 320.0)
		var glint_y := 38.0 + fposmod(float(i * 37), 100.0)
		draw_rect(Rect2(glint_x, glint_y, 0.5, 0.5), Color(0.76, 0.82, 0.62, 0.18))
	draw_rect(Rect2(0, 0, 320, 3), Color(0.01, 0.025, 0.04, 0.35))
	draw_rect(Rect2(0, 177, 320, 3), Color(0.01, 0.025, 0.04, 0.68))

func _draw_diver_exhibit(x: float, y: float) -> void:
	# Museum-scale prototype of the brass hardhat suit promised to the recruits.
	# Its heavy silhouette repeats the player's collar, porthole, hose and canvas gear.
	draw_rect(Rect2(x + 7, y - 2, 1, 31), Color("111b1d"))
	draw_rect(Rect2(x + 4, y + 28, 9, 2), Color("5b4935"))
	draw_rect(Rect2(x + 2, y + 30, 13, 2), Color("111b1d"))
	draw_rect(Rect2(x + 3, y + 29, 11, 1), Color("c18d49"))
	# Cylinder, valve and air hose.
	draw_rect(Rect2(x + 1, y + 9, 3, 15), Color("111b1d"))
	draw_rect(Rect2(x + 2, y + 10, 2, 12), Color("375c5d"))
	draw_rect(Rect2(x + 2, y + 12, 1, 8), Color("506054"))
	draw_rect(Rect2(x + 1, y + 8, 3, 2), Color("877351"))
	draw_rect(Rect2(x + 2, y + 7, 1, 2), Color("d3ad63"))
	draw_line(Vector2(x + 3, y + 9), Vector2(x + 7, y + 5), Color("171f20"), 1.5)
	draw_line(Vector2(x + 4, y + 10), Vector2(x + 7, y + 6), Color("8f6d43"), 0.75)
	# Heavy canvas torso, reinforced yoke, seams and belt buckle.
	draw_rect(Rect2(x + 4, y + 15, 9, 11), Color("171f20"))
	draw_rect(Rect2(x + 5, y + 16, 7, 9), Color("424943"))
	draw_rect(Rect2(x + 5, y + 17, 2, 7), Color("56645a"))
	draw_rect(Rect2(x + 11, y + 17, 1, 6), Color("303a35"))
	draw_rect(Rect2(x + 4, y + 14, 9, 3), Color("171f20"))
	draw_rect(Rect2(x + 5, y + 14, 7, 2), Color("8f6d43"))
	draw_rect(Rect2(x + 6, y + 14, 5, 1), Color("d0a15a"))
	draw_rect(Rect2(x + 5, y + 22, 7, 2), Color("171f20"))
	draw_rect(Rect2(x + 8, y + 22, 1, 2), Color("d3ad63"))
	# Cuffs, gloves, weighted boots.
	draw_rect(Rect2(x + 4, y + 18, 2, 4), Color("171f20"))
	draw_rect(Rect2(x + 12, y + 18, 2, 4), Color("171f20"))
	draw_rect(Rect2(x + 5, y + 25, 3, 3), Color("343d39"))
	draw_rect(Rect2(x + 10, y + 25, 3, 3), Color("343d39"))
	draw_rect(Rect2(x + 4, y + 27, 4, 2), Color("171f20"))
	draw_rect(Rect2(x + 10, y + 27, 4, 2), Color("171f20"))
	draw_rect(Rect2(x + 4, y + 27, 3, 1), Color("8f6d43"))
	draw_rect(Rect2(x + 10, y + 27, 3, 1), Color("8f6d43"))
	# Round shell with stepped brass rim, glass porthole and tiny fasteners.
	draw_rect(Rect2(x + 4, y + 3, 10, 11), Color("111b1d"))
	draw_rect(Rect2(x + 5, y + 2, 8, 11), Color("8f6d43"))
	draw_rect(Rect2(x + 6, y + 3, 6, 9), Color("56645a"))
	draw_rect(Rect2(x + 7, y + 5, 4, 5), Color("171f20"))
	draw_rect(Rect2(x + 8, y + 6, 2, 3), Color("244d50"))
	draw_rect(Rect2(x + 8, y + 6, 1, 1), Color("8ac4b4"))
	draw_rect(Rect2(x + 4, y + 11, 10, 3), Color("171f20"))
	draw_rect(Rect2(x + 5, y + 11, 8, 1), Color("d0a15a"))
	for rivet_x in [5.0, 12.0]:
		draw_rect(Rect2(x + rivet_x, y + 4, 1, 1), Color("d3ad63"))
		draw_rect(Rect2(x + rivet_x, y + 12, 1, 1), Color("d3ad63"))

func _draw_market_stall(x: float, y: float, awning_color: Color) -> void:
	draw_rect(Rect2(x, y + 16, 38, 21), Color("111b1d"))
	draw_rect(Rect2(x + 2, y + 17, 34, 1), Color("506054"))
	draw_rect(Rect2(x - 2, y + 9, 42, 7), awning_color)
	for i in range(5):
		draw_rect(Rect2(x + i * 8, y + 9, 1, 7), Color("877351"))
	draw_rect(Rect2(x + 3, y + 17, 31, 1), Color("5a6253"))
	draw_rect(Rect2(x + 5, y + 21, 7, 6), Color("5b4935"))
	draw_rect(Rect2(x + 16, y + 20, 9, 7), Color("506054"))
	draw_rect(Rect2(x + 26, y + 23, 6, 4), Color("8d4f33"))
	draw_rect(Rect2(x + 4, y + 28, 29, 1), Color("17292b"))
	draw_rect(Rect2(x + 1, y + 35, 36, 2), Color("090f12"))
	if x < 100.0:
		# Aetherite is sold as a sacred miracle, even as the Crown's mine ledger empties.
		draw_colored_polygon(PackedVector2Array([Vector2(x + 27, y + 19), Vector2(x + 29, y + 13), Vector2(x + 32, y + 20)]), Color("347c6d"))
		draw_colored_polygon(PackedVector2Array([Vector2(x + 30, y + 20), Vector2(x + 33, y + 15), Vector2(x + 35, y + 21)]), Color("52947a"))
		draw_rect(Rect2(x + 29, y + 16, 1, 3), Color("9ac691"))

func _draw_lamp(x: float, y: float, flicker: float) -> void:
	draw_rect(Rect2(x - 7, y - 12, 14, 17), Color(0.76, 0.48, 0.22, 0.08 + flicker))
	draw_rect(Rect2(x - 1, y, 2, 27), Color("263438"))
	draw_rect(Rect2(x - 4, y - 4, 8, 7), Color("30362f"))
	draw_rect(Rect2(x - 2, y - 3, 4, 5), Color("c18d49"))
	draw_rect(Rect2(x - 1, y - 2, 2, 3), Color("e2a65d"))
	draw_rect(Rect2(x - 5, y + 4, 10, 1), Color("877351"))

func _draw_citizen(x: float, ground_y: float, seed: int, protagonist: bool) -> void:
	var coats := [Color("33413b"), Color("30362f"), Color("252f2c"), Color("453c31"), Color("3b4545"), Color("34464a")]
	var coat: Color = Color("30362f") if protagonist else coats[seed % coats.size()]
	var head_bob := sin(elapsed * (1.4 + float(seed % 4) * 0.15) + float(seed)) * 0.35
	var head_width := 6.0 if protagonist else 5.0 + float(seed % 3)
	var torso_width := 11.0 if protagonist else 7.0 + float(seed % 3)
	draw_rect(Rect2(x - torso_width * 0.5 - 1, ground_y - 13, torso_width + 2, 14), Color("090f12"))
	draw_rect(Rect2(x - torso_width * 0.5, ground_y - 12, torso_width, 13), coat)
	draw_rect(Rect2(x - torso_width * 0.5 + 1, ground_y - 11, 1, 9), Color("506054"))
	draw_rect(Rect2(x + torso_width * 0.5 - 1, ground_y - 11, 1, 9), Color("17292b"))
	draw_rect(Rect2(x - head_width * 0.5, ground_y - 20 + head_bob, head_width, 7), Color("8f623c"))
	draw_rect(Rect2(x - head_width * 0.5 - 1, ground_y - 21 + head_bob, head_width + 2, 2), Color("111b1d"))
	# Hoods, coifs and feathered caps give the crowd a 16th-century silhouette.
	if seed % 4 == 0 and not protagonist:
		draw_rect(Rect2(x - head_width * 0.5 - 1, ground_y - 22 + head_bob, head_width + 2, 3), Color("253833"))
		draw_rect(Rect2(x - head_width * 0.5 - 1, ground_y - 20 + head_bob, 2, 5), Color("253833"))
	elif seed % 4 == 1 and not protagonist:
		draw_rect(Rect2(x - head_width * 0.5 - 1, ground_y - 22 + head_bob, head_width + 2, 2), Color("5b4935"))
		draw_rect(Rect2(x - 1, ground_y - 24 + head_bob, 3, 3), Color("37504a"))
	elif seed % 4 == 2 and not protagonist:
		draw_rect(Rect2(x - head_width * 0.5 - 1, ground_y - 22 + head_bob, head_width + 2, 2), Color("30362f"))
		draw_rect(Rect2(x + 1, ground_y - 24 + head_bob, 1, 3), Color("a98a52"))
	if protagonist:
		draw_rect(Rect2(x - 4, ground_y - 13, 8, 2), Color("8d4f33"))
		draw_rect(Rect2(x - 1, ground_y - 10, 1, 8), Color("c18d49"))
		draw_rect(Rect2(x + 2, ground_y - 12, 2, 2), Color("8d3f34"))
		draw_rect(Rect2(x + 2, ground_y - 12, 1, 1), Color("e1bd75"))
	else:
		draw_rect(Rect2(x + head_width * 0.5 - 1, ground_y - 18 + head_bob, 1, 4), Color("5b4935"))
		# A few recruits already wear the old brass hardhat, visible as tiny crowd silhouettes.
		if seed % 13 == 4 or seed % 13 == 9:
			var helmet_x := x - head_width * 0.5 - 1.0
			draw_rect(Rect2(helmet_x, ground_y - 22 + head_bob, head_width + 2, 8), Color("171f20"))
			draw_rect(Rect2(helmet_x + 1, ground_y - 21 + head_bob, head_width, 6), Color("8f6d43"))
			draw_rect(Rect2(helmet_x + 2, ground_y - 20 + head_bob, head_width - 2, 4), Color("56645a"))
			draw_rect(Rect2(x - 1, ground_y - 19 + head_bob, 3, 3), Color("244d50"))
			draw_rect(Rect2(x - 1, ground_y - 19 + head_bob, 1, 1), Color("8ac4b4"))
			draw_rect(Rect2(helmet_x + 1, ground_y - 15 + head_bob, head_width, 1), Color("d0a15a"))
			draw_rect(Rect2(helmet_x + 2, ground_y - 22 + head_bob, 1, 1), Color("d3ad63"))
			draw_rect(Rect2(helmet_x + head_width, ground_y - 22 + head_bob, 1, 1), Color("d3ad63"))
	# Recurring uniform details make the whole square feel tied to diving work and industry.
	draw_rect(Rect2(x - torso_width * 0.5 + 1, ground_y - 9, torso_width - 2, 1), Color("252f2c"))
	draw_rect(Rect2(x - 1, ground_y - 9, 2, 2), Color("c18d49"))
	draw_rect(Rect2(x - torso_width * 0.5, ground_y - 5, 1, 2), Color("8f6d43"))
	draw_rect(Rect2(x + torso_width * 0.5 - 1, ground_y - 5, 1, 2), Color("8f6d43"))
	# Variations in patching and stitching break up the repeating crowd silhouettes.
	var patch_color: Color = Color("8f6d43") if seed % 2 == 0 else Color("56645a")
	draw_rect(Rect2(x - torso_width * 0.5 + 2, ground_y - 11, 2, 2), patch_color)
	draw_rect(Rect2(x - torso_width * 0.5 + 2.5, ground_y - 10.5, 1, 1), Color("d0a15a", 0.72))
	draw_rect(Rect2(x + torso_width * 0.5 - 2, ground_y - 8, 1, 4), Color("17292b"))
	draw_rect(Rect2(x - 2, ground_y - 2, 1, 2), Color("5b5544"))
	draw_rect(Rect2(x + 1, ground_y - 2, 1, 2), Color("5b5544"))
	if seed % 3 == 1 and not protagonist:
		draw_rect(Rect2(x - torso_width * 0.5 - 1, ground_y - 4, torso_width + 2, 1), Color("171f20"))
		draw_rect(Rect2(x + torso_width * 0.5 - 2, ground_y - 6, 2, 2), Color("8d4f33"))
	draw_rect(Rect2(x - 4, ground_y + 1, 3, 3), Color("090f12"))
	draw_rect(Rect2(x + 1, ground_y + 1, 3, 3), Color("090f12"))
