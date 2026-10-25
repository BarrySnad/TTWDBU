extends Node2D

const DreadOverlayScript = preload("res://scripts/dread_overlay.gd")

const PlayerScript = preload("res://scripts/player.gd")
const LEVEL_END := 1200.0
const ELEVATOR_CUTSCENE := "res://scenes/elevator_cutscene.tscn"
var player: CharacterBody2D
var ui: CanvasLayer
var caption: Label
var prompt: Label
var title: Label
var health_marks: Array[ColorRect] = []
var fade: ColorRect
var dread_overlay: Node
var game_over_ui: Control
var game_over_time := 0.0
var game_over := false
var ambience: AudioStreamPlayer
var current_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var airlock_open_sfx: AudioStreamWAV
var airlock_latch_sfx: AudioStreamWAV
var console_beep_sfx: AudioStreamWAV
var footstep_walk_sfx: AudioStreamWAV
var footstep_run_sfx: AudioStreamWAV
var distant_bell_sfx: AudioStreamWAV
var cliffhanger_sfx: AudioStreamWAV
var rng := RandomNumberGenerator.new()
var sfx_index := 0
var footstep_timer := 0.0
var distant_bell_timer := 0.0
var elapsed := 0.0
var message_time := 0.0
var message := ""
var listened_once := false
var door_open := false
var ending := false
var ending_time := 0.0
var player_health := 3
var invulnerability_time := 0.0
var enemy_active := false
var enemy_position := Vector2(755.0, 142.0)
var enemy_state := "idle"
var enemy_timer := 0.0
var enemy_cooldown := 0.0
var enemy_target_x := 755.0
var enemy_attack_resolved := false
var enemy_motion_phase := 0.0
var enemy_is_moving := false
var checkpoint := 0
var stars: Array[Vector2] = []
var bulkhead_collision: StaticBody2D
var console_zone: Area2D
var hatch_zone: Area2D
var lift_zone: Area2D

func _ready() -> void:
    _setup_input()
    for i in range(56):
        stars.append(Vector2(fposmod(float(i * 73 + 19), 1450.0), fposmod(float(i * 47 + 11), 104.0)))
    player = CharacterBody2D.new()
    player.set_script(PlayerScript)
    player.position = Vector2(25, 140)
    player.collision_layer = 1
    player.collision_mask = 1
    var shape := CollisionShape2D.new()
    var capsule := CapsuleShape2D.new()
    capsule.radius = 6.0
    capsule.height = 40.0
    shape.shape = capsule
    shape.position = Vector2(0, -14)
    player.add_child(shape)
    add_child(player)
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(620, 154)
    var floor_shape := CollisionShape2D.new()
    var floor_rect := RectangleShape2D.new()
    floor_rect.size = Vector2(1240, 10)
    floor_shape.shape = floor_rect
    floor_body.add_child(floor_shape)
    add_child(floor_body)
    bulkhead_collision = StaticBody2D.new()
    bulkhead_collision.position = Vector2(496, 90)
    var bulkhead_shape := CollisionShape2D.new()
    var bulkhead_rect := RectangleShape2D.new()
    bulkhead_rect.size = Vector2(8, 116)
    bulkhead_shape.shape = bulkhead_rect
    bulkhead_collision.add_child(bulkhead_shape)
    add_child(bulkhead_collision)
    console_zone = _make_interaction_zone(Vector2(250, 137), 34.0)
    hatch_zone = _make_interaction_zone(Vector2(514, 139), 39.0)
    lift_zone = _make_interaction_zone(Vector2(1147, 130), 43.0)
    var camera := Camera2D.new()
    camera.position = Vector2(0, -36)
    camera.zoom = Vector2(2.0, 2.0)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 5.0
    camera.limit_left = 0
    camera.limit_right = int(LEVEL_END)
    camera.limit_top = 0
    camera.limit_bottom = 180
    player.add_child(camera)
    _build_ui()
    _build_audio()
    _say("The lift stopped three hundred feet below the river.", 5.5)

func _make_interaction_zone(center: Vector2, radius: float) -> Area2D:
    var zone := Area2D.new()
    zone.position = center
    zone.collision_layer = 0
    zone.collision_mask = 1
    zone.monitoring = true
    zone.monitorable = false
    var shape_node := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = radius
    shape_node.shape = shape
    zone.add_child(shape_node)
    add_child(zone)
    return zone

func _setup_input() -> void:
    _bind("move_left", [KEY_A, KEY_LEFT])
    _bind("move_right", [KEY_D, KEY_RIGHT])
    _bind("jump", [KEY_SPACE, KEY_W, KEY_UP])
    _bind("listen", [KEY_E])
    _bind("interact", [KEY_F])
    _bind("sprint", [KEY_SHIFT])

func _bind(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for keycode in keys:
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action, event)

func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)
    dread_overlay = DreadOverlayScript.new()
    ui.add_child(dread_overlay)
    var hud := Control.new()
    hud.name = "HudScale"
    hud.position = Vector2.ZERO
    hud.size = Vector2(320, 180)
    hud.scale = Vector2(2.0, 2.0)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud)
    var panel := ColorRect.new()
    panel.color = Color(0.008, 0.018, 0.026, 0.72)
    panel.position = Vector2(5, 5)
    panel.size = Vector2(111, 19)
    hud.add_child(panel)
    title = Label.new()
    title.position = Vector2(9, 5)
    title.text = "STATION IX  /  03:17"
    title.add_theme_font_size_override("font_size", 8)
    title.add_theme_color_override("font_color", Color("b8c9bd"))
    hud.add_child(title)
    var health_panel := ColorRect.new()
    health_panel.position = Vector2(121, 5)
    health_panel.size = Vector2(54, 19)
    health_panel.color = Color(0.008, 0.018, 0.026, 0.72)
    hud.add_child(health_panel)
    var health_caption := Label.new()
    health_caption.position = Vector2(125, 7)
    health_caption.size = Vector2(20, 9)
    health_caption.text = "SUIT"
    health_caption.add_theme_font_size_override("font_size", 6)
    health_caption.add_theme_color_override("font_color", Color("a9c9be"))
    hud.add_child(health_caption)
    for i in range(3):
        var mark := ColorRect.new()
        mark.position = Vector2(147 + i * 8, 9)
        mark.size = Vector2(5, 5)
        mark.color = Color("69b6aa")
        hud.add_child(mark)
        health_marks.append(mark)
    prompt = Label.new()
    prompt.position = Vector2(191, 5)
    prompt.size = Vector2(124, 13)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    prompt.add_theme_font_size_override("font_size", 8)
    prompt.add_theme_color_override("font_color", Color("a9c9be"))
    hud.add_child(prompt)
    var bar_bg := ColorRect.new()
    bar_bg.position = Vector2(6, 169)
    bar_bg.size = Vector2(54, 4)
    bar_bg.color = Color("22333a")
    hud.add_child(bar_bg)
    var bar := ColorRect.new()
    bar.name = "BreathBar"
    bar.position = Vector2(7, 170)
    bar.size = Vector2(52, 2)
    bar.color = Color("69b6aa")
    hud.add_child(bar)
    caption = Label.new()
    caption.position = Vector2(14, 139)
    caption.size = Vector2(292, 24)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    caption.add_theme_font_size_override("font_size", 9)
    caption.add_theme_color_override("font_color", Color("d4d3bd"))
    hud.add_child(caption)
    fade = ColorRect.new()
    fade.size = Vector2(320, 180)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade.color = Color(0.01, 0.025, 0.04, 1.0)
    hud.add_child(fade)
    game_over_ui = Control.new()
    game_over_ui.position = Vector2(61, 58)
    game_over_ui.size = Vector2(198, 64)
    game_over_ui.visible = false
    game_over_ui.modulate.a = 0.0
    hud.add_child(game_over_ui)
    var game_over_panel := ColorRect.new()
    game_over_panel.size = game_over_ui.size
    game_over_panel.color = Color("07151d")
    game_over_ui.add_child(game_over_panel)
    var game_over_rule := ColorRect.new()
    game_over_rule.position = Vector2(10, 8)
    game_over_rule.size = Vector2(178, 1)
    game_over_rule.color = Color("8d4f33")
    game_over_ui.add_child(game_over_rule)
    var game_over_title := Label.new()
    game_over_title.position = Vector2(8, 16)
    game_over_title.size = Vector2(182, 15)
    game_over_title.text = "SUIT FAILURE"
    game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_over_title.add_theme_font_size_override("font_size", 11)
    game_over_title.add_theme_color_override("font_color", Color("d4d3bd"))
    game_over_ui.add_child(game_over_title)
    var game_over_message := Label.new()
    game_over_message.position = Vector2(8, 33)
    game_over_message.size = Vector2(182, 11)
    game_over_message.text = "THREE IMPACTS. SIGNAL LOST."
    game_over_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_over_message.add_theme_font_size_override("font_size", 6)
    game_over_message.add_theme_color_override("font_color", Color("b8c9bd"))
    game_over_ui.add_child(game_over_message)
    var game_over_hint := Label.new()
    game_over_hint.position = Vector2(8, 48)
    game_over_hint.size = Vector2(182, 10)
    game_over_hint.text = "[R]  RETRY STATION IX"
    game_over_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_over_hint.add_theme_font_size_override("font_size", 7)
    game_over_hint.add_theme_color_override("font_color", Color("c18d49"))
    game_over_ui.add_child(game_over_hint)

func _build_audio() -> void:
    rng.randomize()
    ambience = AudioStreamPlayer.new()
    var drone := load("res://audio/station_drone.wav") as AudioStreamWAV
    drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
    ambience.stream = drone
    ambience.volume_db = -18.0
    ambience.autoplay = true
    add_child(ambience)
    current_player = _make_loop_player("res://audio/station_current.wav", -10.0)
    breath_player = _make_loop_player("res://audio/helmet_breath.wav", -7.0)
    airlock_open_sfx = load("res://audio/airlock_open.wav") as AudioStreamWAV
    airlock_latch_sfx = load("res://audio/airlock_latch.wav") as AudioStreamWAV
    console_beep_sfx = load("res://audio/console_beep.wav") as AudioStreamWAV
    footstep_walk_sfx = load("res://audio/footstep_walk.wav") as AudioStreamWAV
    footstep_run_sfx = load("res://audio/footstep_run.wav") as AudioStreamWAV
    distant_bell_sfx = load("res://audio/distant_bell.wav") as AudioStreamWAV
    cliffhanger_sfx = load("res://audio/cliffhanger_pressure.wav") as AudioStreamWAV
    for i in range(6):
        var sfx_player := AudioStreamPlayer.new()
        sfx_player.volume_db = -8.0
        add_child(sfx_player)
        sfx_players.append(sfx_player)
    distant_bell_timer = rng.randf_range(16.0, 27.0)

func _make_loop_player(stream_path: String, level_db: float) -> AudioStreamPlayer:
    var loop_player := AudioStreamPlayer.new()
    var loop_stream := load(stream_path) as AudioStreamWAV
    loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    loop_player.stream = loop_stream
    loop_player.volume_db = level_db
    loop_player.autoplay = true
    add_child(loop_player)
    return loop_player

func _play_sfx(stream: AudioStreamWAV, level_db: float, pitch_jitter: float = 0.04) -> void:
    var sfx_player := sfx_players[sfx_index]
    sfx_index = (sfx_index + 1) % sfx_players.size()
    sfx_player.stream = stream
    sfx_player.volume_db = level_db
    sfx_player.pitch_scale = rng.randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
    sfx_player.play()

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 1.6:
        fade.color = Color(0.01, 0.025, 0.04, clampf(1.0 - elapsed / 1.6, 0.0, 1.0))
    if message_time > 0.0:
        message_time -= delta
        if message_time <= 0.0:
            caption.text = ""
    if invulnerability_time > 0.0 and not game_over:
        invulnerability_time = maxf(0.0, invulnerability_time - delta)
        var flash_on := int(elapsed * 13.0) % 2 == 0
        player.modulate = Color(1.0, 0.58, 0.48, 0.72) if flash_on else Color.WHITE
    elif not game_over:
        player.modulate = Color.WHITE
    if game_over:
        game_over_time += delta
        fade.color = Color(0.01, 0.025, 0.04, minf(0.78, game_over_time * 0.7))
        game_over_ui.visible = true
        game_over_ui.modulate.a = clampf(game_over_time * 1.8, 0.0, 1.0)
        if Input.is_key_pressed(KEY_R) or Input.is_action_just_pressed("ui_accept"):
            get_tree().reload_current_scene()
        return
    if ending:
        ending_time += delta
        if ending_time < 3.1:
            fade.color = Color(0.01, 0.025, 0.04, minf(0.78, ending_time * 0.17))
        else:
            fade.color = Color(0.01, 0.025, 0.04, clampf(0.78 + (ending_time - 3.1) / 0.85 * 0.22, 0.78, 1.0))
        if ending_time > 1.8:
            caption.text = "STATION IX  //  END OF TRANSMISSION"
            caption.add_theme_font_size_override("font_size", 10)
        if ending_time >= 3.95:
            get_tree().change_scene_to_file(ELEVATOR_CUTSCENE)
        return
    var threat_stress := 0.0
    if enemy_active:
        var enemy_gap := absf(player.global_position.x - enemy_position.x)
        threat_stress = clampf(1.0 - enemy_gap / 250.0, 0.0, 1.0)
        breath_player.volume_db = lerpf(-7.0, -2.8, threat_stress)
        current_player.volume_db = lerpf(-10.0, -15.0, threat_stress)
        ambience.volume_db = lerpf(-18.0, -22.0, threat_stress)
    if dread_overlay:
        dread_overlay.call("set_dread", 0.13 + threat_stress * 0.07, threat_stress)
    var x: float = player.global_position.x
    title.text = "RHEGAN  //  STATION IX" if x < 535.0 else "OPEN WATER  /  312M"
    var listening: bool = player.listening
    var near_console := console_zone.overlaps_body(player)
    var near_hatch := hatch_zone.overlaps_body(player)
    var near_lift := lift_zone.overlaps_body(player)
    prompt.text = "[E] LISTEN" if not (near_console or near_hatch or near_lift) else "[E] LISTEN   [F] INTERACT"
    if listening and not listened_once and x > 70:
        listened_once = true
        _say("A second breathing rhythm answers inside the walls.", 4.0)
    if Input.is_action_just_pressed("interact"):
        if near_console and checkpoint < 1:
            checkpoint = 1
            _play_sfx(console_beep_sfx, -9.0, 0.025)
            _say("CROWN SURVEY 09: 'Upper veins exhausted. A bell is answering from below.'", 5.0)
        elif near_hatch and not door_open:
            door_open = true
            bulkhead_collision.queue_free()
            checkpoint = 2
            _play_sfx(airlock_open_sfx, -5.5, 0.025)
            _say("The outer lock cycles open. Station IX falls away behind you; black water waits beyond.", 4.5)
        elif near_lift and door_open:
            ending = true
            ending_time = 0.0
            _play_sfx(airlock_latch_sfx, -8.0, 0.04)
            _play_sfx(cliffhanger_sfx, -4.0, 0.025)
            _say("The glass fills with a face that is wearing your helmet.", 4.0)
            ambience.volume_db = -26.0
            current_player.volume_db = -17.0
            breath_player.volume_db = -4.0
    _update_enemy(delta)
    _update_movement_audio(delta)
    distant_bell_timer -= delta
    if distant_bell_timer <= 0.0:
        _play_sfx(distant_bell_sfx, -16.0, 0.10)
        distant_bell_timer = rng.randf_range(22.0, 38.0)
    var breath_bar := ui.get_node("HudScale/BreathBar") as ColorRect
    breath_bar.size.x = 44.0 + sin(elapsed * 1.3) * 4.0
    queue_redraw()

func _update_enemy(delta: float) -> void:
    enemy_is_moving = false
    if ending or not door_open or player.global_position.x < 690.0:
        return
    if not enemy_active:
        enemy_active = true
        _play_sfx(cliffhanger_sfx, -19.5, 0.10)
        _say("A ruined dive suit stirs ahead. Listen for its warning, then move or jump.", 4.5)
    enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
    match enemy_state:
        "idle":
            var gap := player.global_position.x - enemy_position.x
            var distance := absf(gap)
            if distance <= 43.0 and enemy_cooldown <= 0.0:
                enemy_state = "windup"
                enemy_timer = 1.1
                enemy_target_x = player.global_position.x
                enemy_attack_resolved = false
                _play_sfx(cliffhanger_sfx, -18.0, 0.08)
                _say("It draws back! Move away or jump before it lunges.", 2.8)
            elif distance > 43.0 and distance < 190.0:
                var old_x := enemy_position.x
                enemy_position.x = move_toward(enemy_position.x, player.global_position.x, 19.0 * delta)
                enemy_is_moving = not is_equal_approx(old_x, enemy_position.x)
                if enemy_is_moving:
                    enemy_motion_phase += delta * 10.5
        "windup":
            enemy_timer -= delta
            if enemy_timer <= 0.0:
                enemy_state = "lunge"
                enemy_timer = 0.38
        "lunge":
            enemy_position.x = move_toward(enemy_position.x, enemy_target_x, 235.0 * delta)
            enemy_is_moving = true
            enemy_motion_phase += delta * 18.0
            enemy_timer -= delta
            if not enemy_attack_resolved:
                var horizontal_gap := absf(enemy_position.x - player.global_position.x)
                var vertical_gap := absf(enemy_position.y - player.global_position.y)
                if horizontal_gap <= 14.0 and vertical_gap <= 17.0:
                    enemy_attack_resolved = true
                    _take_enemy_hit()
            if enemy_timer <= 0.0:
                enemy_state = "recover"
                enemy_timer = 0.55
                enemy_cooldown = 2.15
        "recover":
            enemy_timer -= delta
            if enemy_timer <= 0.0:
                enemy_state = "idle"

func _take_enemy_hit() -> void:
    if invulnerability_time > 0.0 or game_over:
        return
    player_health = maxi(0, player_health - 1)
    invulnerability_time = 1.25
    var knockback_direction := signf(player.global_position.x - enemy_position.x)
    if is_zero_approx(knockback_direction):
        knockback_direction = -1.0
    player.velocity.x = knockback_direction * 78.0
    player.velocity.y = -64.0
    player.call("trigger_hit_reaction")
    _play_sfx(cliffhanger_sfx, -10.0, 0.025)
    _say("Impact! Your suit has taken damage.", 2.4)
    for i in range(health_marks.size()):
        health_marks[i].color = Color("69b6aa") if i < player_health else Color("453c31")
    if player_health <= 0:
        game_over = true
        game_over_time = 0.0
        player.velocity = Vector2.ZERO
        player.set_physics_process(false)

func _update_movement_audio(delta: float) -> void:
    var moving_on_deck := player.is_on_floor() and absf(player.velocity.x) > 9.0
    if not moving_on_deck:
        footstep_timer = 0.04
        return
    footstep_timer -= delta
    if footstep_timer <= 0.0:
        var running := Input.is_action_pressed("sprint")
        var step_sfx := footstep_run_sfx if running else footstep_walk_sfx
        _play_sfx(step_sfx, -9.5 if running else -11.0, 0.07)
        footstep_timer = 0.31 if running else 0.45

func _say(text: String, duration: float) -> void:
    message = text
    caption.text = text
    message_time = duration

func _draw() -> void:
    var cam_x := player.global_position.x - 160.0 if player else 0.0
    draw_rect(Rect2(cam_x, 0, 320, 180), Color("07151d"))
    # Far water and ruined industrial silhouettes
    draw_rect(Rect2(cam_x, 20, 320, 87), Color("0b222a"))
    draw_rect(Rect2(cam_x, 92, 320, 9), Color("102b32"))
    draw_rect(Rect2(cam_x, 103, 320, 1.5), Color(0.16, 0.38, 0.40, 0.24))
    for s in stars:
        var sx := s.x - cam_x * 0.18
        if sx >= cam_x - 2 and sx < cam_x + 322:
            draw_rect(Rect2(sx, s.y, 1, 1), Color(0.30, 0.53, 0.53, 0.45))
    # Slow suspended silt catches the emergency lamps in tiny, stepped glints.
    for i in range(30):
        var particle_x := fposmod(float(i * 43 + 19) + elapsed * (1.2 + float(i % 4) * 0.2), 1420.0)
        var particle_y := 45.0 + fposmod(float(i * 29) + sin(elapsed * 0.6 + float(i)) * 2.0, 94.0)
        if particle_x >= cam_x - 2 and particle_x < cam_x + 322:
            draw_rect(Rect2(particle_x, particle_y, 0.5, 0.5), Color(0.57, 0.75, 0.67, 0.27))
    for section in range(15):
        var bx := section * 96.0
        draw_rect(Rect2(bx, 41, 34, 49), Color("10252b"))
        draw_rect(Rect2(bx + 4, 30, 26, 60), Color("10252b"))
        draw_rect(Rect2(bx + 12, 22, 8, 8), Color("153039"))
        draw_rect(Rect2(bx + 8, 46, 6, 11), Color("142d31"))
        draw_rect(Rect2(bx + 9, 47, 4, 9), Color("27474a"))
        draw_rect(Rect2(bx + 9.5, 48, 0.75, 7), Color("47706b"))
        draw_rect(Rect2(bx + 18, 64, 7, 9), Color("142d31"))
        draw_rect(Rect2(bx + 19, 65, 5, 7), Color("375c5d"))
        draw_rect(Rect2(bx + 20, 68, 2, 3), Color("a46b36"))
        draw_rect(Rect2(bx + 30, 38, 1, 49), Color("1b3438"))
    # Station ceiling, hanging cables, rust and rivets
    draw_rect(Rect2(cam_x, 0, 320, 16), Color("111b1d"))
    draw_rect(Rect2(cam_x, 16, 320, 3), Color("453c31"))
    for i in range(19):
        var wx := cam_x + i * 19.0 + 5.0
        draw_rect(Rect2(wx, 14, 2, 2), Color("877351"))
        draw_rect(Rect2(wx + 0.5, 14.5, 0.5, 0.5), Color("c1a36d"))
    # Riveted cladding and low, intermittent lamps.
    for i in range(11):
        var panel_x := i * 128.0 + 22.0
        draw_rect(Rect2(panel_x, 20, 1, 18), Color("263438"))
        draw_rect(Rect2(panel_x + 2, 37, 1, 0.5), Color("89744c"))
        draw_rect(Rect2(panel_x + 114, 20, 0.5, 8), Color("1d2e31"))
    for i in range(4):
        var lamp_x := i * 318.0 + 80.0
        var flicker := 0.07 + maxf(0.0, sin(elapsed * 2.1 + float(i) * 1.8)) * 0.05
        if door_open:
            var sputter := maxf(0.0, sin(elapsed * 0.83 + float(i) * 2.7))
            flicker *= 0.34 + sputter * 0.95
            if fposmod(elapsed * 0.73 + float(i) * 3.17, 17.0) < 0.19:
                flicker *= 0.12
        draw_rect(Rect2(lamp_x - 10, 18, 20, 18), Color(0.62, 0.53, 0.32, flicker * 0.24))
        draw_rect(Rect2(lamp_x - 4, 18, 8, 2), Color("5a6253"))
        draw_rect(Rect2(lamp_x - 3, 19, 6, 0.75), Color(0.96, 0.73, 0.42, flicker))
    for i in range(10):
        var cx := i * 147.0 + 58.0
        draw_rect(Rect2(cx, 17, 2, 18 + float(i % 3) * 9), Color("263b3d"))
        draw_rect(Rect2(cx - 2, 34 + float(i % 3) * 9, 6, 3), Color("6a5339"))
        draw_rect(Rect2(cx + 0.5, 18, 0.5, 18 + float(i % 3) * 9), Color("506054"))
    # Walkway and shadowed depths
    draw_rect(Rect2(cam_x, 151, 320, 29), Color("090f12"))
    draw_rect(Rect2(cam_x, 149, 320, 3), Color("596051"))
    for i in range(22):
        var fx := cam_x + i * 17.0
        draw_rect(Rect2(fx, 153, 9, 2), Color("2a302c"))
        draw_rect(Rect2(fx + 12, 150, 2, 2), Color("a46b36"))
        draw_rect(Rect2(fx + 1, 153.5, 6, 0.5), Color("53594a"))
        draw_rect(Rect2(fx + 11.5, 150.5, 0.75, 0.75), Color("d3a65c"))
    draw_rect(Rect2(cam_x, 157, 320, 0.5), Color("182223"))
    draw_rect(Rect2(cam_x, 173, 320, 1), Color("101719"))
    # Pipe columns and the old listening console
    for px in [148.0, 306.0, 685.0, 1010.0]:
        draw_rect(Rect2(px, 38, 6, 111), Color("33413b"))
        draw_rect(Rect2(px - 2, 57, 10, 4), Color("68715e"))
        draw_rect(Rect2(px + 1, 71, 2, 15), Color("17292b"))
        draw_rect(Rect2(px + 0.5, 41, 1, 98), Color("74806a"))
        draw_rect(Rect2(px - 1, 80, 8, 1), Color("9a7449"))
        draw_rect(Rect2(px + 6, 93, 1, 8), Color("8f623c"))
    # A damaged pressure panel and instrument make the old station feel worked, not modular.
    draw_rect(Rect2(356, 57, 36, 31), Color("111a1a"))
    draw_rect(Rect2(358, 59, 32, 27), Color("394037"))
    draw_rect(Rect2(360, 61, 28, 23), Color("202b29"))
    draw_rect(Rect2(362, 63, 12, 12), Color("131d1e"))
    draw_arc(Vector2(368, 69), 5.0, 0.0, TAU, 16, Color("89744c"), 1.0, true)
    draw_arc(Vector2(368, 69), 3.5, 0.0, TAU, 16, Color("4d6963"), 0.75, true)
    draw_line(Vector2(368, 69), Vector2(370, 66), Color("c18d49"), 0.75, false)
    draw_rect(Rect2(366, 67, 1, 1), Color("d3ad63"))
    for tick in range(5):
        var tick_x := 378.0 + float(tick % 3) * 3.0
        var tick_y := 64.0 + float(tick / 3) * 6.0
        draw_rect(Rect2(tick_x, tick_y, 1.5, 1.0), Color("9a7449"))
    draw_rect(Rect2(381, 77, 5, 2), Color("8d4f33"))
    draw_rect(Rect2(383, 79, 1, 7), Color("493526"))
    draw_rect(Rect2(385, 83, 1, 3), Color("332d24"))
    draw_rect(Rect2(359, 89, 2, 1), Color("bd7151"))
    draw_rect(Rect2(360, 90, 1, 4), Color("8d4f33"))
    draw_rect(Rect2(236, 111, 32, 38), Color("252f2c"))
    draw_rect(Rect2(232, 107, 40, 5), Color("5b4935"))
    draw_rect(Rect2(242, 116, 20, 11), Color("152f32"))
    draw_rect(Rect2(243, 117, 18, 9), Color("183c3c"))
    draw_rect(Rect2(244, 118, 16, 1), Color("608477"))
    draw_rect(Rect2(245, 119, 4, 3), Color("8d4f33"))
    draw_rect(Rect2(255, 119, 4, 3), Color("79a58a"))
    draw_rect(Rect2(245, 119, 2, 0.75), Color("e2a65d"))
    draw_rect(Rect2(255, 119, 2, 0.75), Color("a4d5ac"))
    draw_rect(Rect2(248, 132, 9, 0.75), Color("84714c"))
    draw_rect(Rect2(248.5, 134, 1, 5), Color("b27d43"))
    draw_rect(Rect2(255, 134, 1, 5), Color("b27d43"))
    draw_rect(Rect2(246, 139, 13, 2), Color("131c1c"))
    # Sealed bulkhead; when opened, a black, dry corridor yawns behind it
    if not door_open:
        draw_rect(Rect2(487, 32, 10, 117), Color("55483a"))
        draw_rect(Rect2(497, 38, 38, 111), Color("182524"))
        draw_rect(Rect2(499, 45, 33, 97), Color("30362f"))
        draw_rect(Rect2(501, 48, 28, 1), Color("86724e"))
        draw_rect(Rect2(501, 50, 1, 72), Color("40483d"))
        draw_rect(Rect2(529, 50, 1, 72), Color("111d1e"))
        draw_rect(Rect2(504, 60, 22, 0.75), Color("3f4c42"))
        draw_rect(Rect2(504, 121, 20, 0.75), Color("1b2927"))
        draw_rect(Rect2(525, 88, 3, 5), Color("c18d49"))
        draw_rect(Rect2(525.5, 89, 1, 3), Color("e3bb71"))
        draw_rect(Rect2(487, 32, 48, 4), Color("7d6744"))
        for ry in [44.0, 137.0]:
            draw_rect(Rect2(491, ry, 40, 2), Color("85734e"))
            draw_rect(Rect2(493, ry + 0.5, 36, 0.5), Color("c2a56c"))
    else:
        # The passage is open to the ocean now: deep teal replaces the dry black corridor.
        draw_rect(Rect2(497, 38, 38, 111), Color("06151a"))
        draw_rect(Rect2(501, 45, 30, 96), Color("09232a"))
        draw_rect(Rect2(510, 51, 21, 88), Color(0.08, 0.30, 0.31, 0.42))
        draw_rect(Rect2(512, 58, 18, 2), Color(0.36, 0.66, 0.55, 0.12))
        for bubble_i in range(4):
            var bubble_y := 125.0 - fposmod(elapsed * 7.0 + float(bubble_i * 21), 72.0)
            draw_rect(Rect2(517.0 + float(bubble_i % 2) * 8.0, bubble_y, 1, 1), Color(0.62, 0.85, 0.79, 0.55))
        draw_rect(Rect2(490, 38, 7, 111), Color("59503e"))
        draw_rect(Rect2(491, 40, 1, 105), Color("aa8956"))
        draw_rect(Rect2(488, 44, 3, 101), Color("252e2a"))
        draw_rect(Rect2(484, 46, 6, 93), Color("383e35"))
        draw_rect(Rect2(486, 48, 1, 88), Color("6f6146"))
        draw_rect(Rect2(508, 102, 12, 3), Color("78806a"))
        draw_rect(Rect2(514, 110, 2, 3), Color("b18148"))
    # Distant lift window and ladder at Station IX's far end
    draw_rect(Rect2(1127, 41, 43, 96), Color("35413b"))
    draw_rect(Rect2(1131, 46, 35, 84), Color("101b20"))
    draw_rect(Rect2(1134, 49, 29, 78), Color(0.19, 0.38, 0.40, 0.58))
    draw_rect(Rect2(1136, 52, 11, 70), Color(0.46, 0.67, 0.58, 0.12))
    draw_rect(Rect2(1137, 53, 1, 67), Color(0.67, 0.82, 0.68, 0.35))
    draw_rect(Rect2(1153, 55, 7, 2), Color("91a07d"))
    draw_rect(Rect2(1154, 56, 5, 1), Color("d6aa67"))
    draw_rect(Rect2(1147, 50, 2, 76), Color("182629"))
    for ry in range(57, 129, 12):
        draw_rect(Rect2(1137, ry, 23, 1), Color("263337"))
    draw_rect(Rect2(1119, 34, 59, 5), Color("766247"))
    # Beyond the lock, Station IX gives way to a broad, open seabed.
    _draw_ocean_exterior()
    # The shape is an early hint until the hatch is opened; then its silhouette tracks the player.
    if enemy_active:
        _draw_enemy()
    elif player and player.listening:
        draw_rect(Rect2(752, 114, 7, 25), Color(0.38, 0.57, 0.49, 0.24))
        draw_rect(Rect2(750, 118, 11, 15), Color(0.30, 0.53, 0.53, 0.20))
        draw_rect(Rect2(753, 108, 8, 8), Color(0.57, 0.75, 0.67, 0.28))
        draw_rect(Rect2(754, 111, 2, 1), Color("c58e55"))
        draw_rect(Rect2(759, 111, 1, 1), Color("c58e55"))
    else:
        draw_rect(Rect2(755, 135, 1, 2), Color("213b3b"))
    # Darkness at the edges; pressure tint grows near the end
    var proximity := clampf((player.global_position.x - 850.0) / 350.0, 0.0, 0.24) if player else 0.0
    if proximity > 0.0:
        draw_rect(Rect2(cam_x, 18, 320, 131), Color(0.10, 0.015, 0.02, proximity))

func _draw_ocean_exterior() -> void:
    # The scenery changes at the outer airlock: station plating gives way to open water.
    var ocean_left := 535.0
    draw_rect(Rect2(ocean_left, 0, 665, 180), Color("030d12"))
    draw_rect(Rect2(ocean_left, 12, 665, 42), Color("06171d"))
    draw_rect(Rect2(ocean_left, 54, 665, 49), Color("082027"))
    draw_rect(Rect2(ocean_left, 103, 665, 42), Color("0b2021"))
    draw_rect(Rect2(ocean_left, 0, 665, 1), Color(0.22, 0.55, 0.49, 0.13))
    # A stepped spill of light from the hatch fades quickly into the green-black deep.
    for i in range(7):
        var beam_y := 34.0 + float(i) * 9.0
        var beam_width := 5.0 + float(i) * 12.0
        var beam_alpha := 0.105 - float(i) * 0.011
        draw_rect(Rect2(536, beam_y, beam_width, 2), Color(0.38, 0.75, 0.65, beam_alpha))
        draw_rect(Rect2(536, beam_y + 2, beam_width + 7, 1), Color(0.27, 0.56, 0.53, beam_alpha * 0.45))
    # Distant broken gantries and pipework form the silhouette of a drowned industrial field.
    for i in range(5):
        var frame_x := 620.0 + float(i) * 119.0
        var frame_top := 28.0 + float((i * 17) % 4) * 11.0
        var frame_color := Color("0a181a") if i % 2 == 0 else Color("0c1b1c")
        draw_rect(Rect2(frame_x, frame_top, 4, 112.0 - frame_top), frame_color)
        draw_rect(Rect2(frame_x + 3, frame_top + 5, 1, 107.0 - frame_top), Color("29433d"))
        draw_rect(Rect2(frame_x + 31, frame_top + 18, 4, 91.0 - frame_top), frame_color)
        draw_rect(Rect2(frame_x - 3, frame_top + 16, 42, 4), frame_color)
        draw_rect(Rect2(frame_x + 5, frame_top + 21, 29, 1), Color("263b36"))
        draw_rect(Rect2(frame_x + 12, frame_top + 23, 2, 34), Color("111e1d"))
        draw_rect(Rect2(frame_x + 24, frame_top + 20, 2, 46), Color("10201f"))
        draw_rect(Rect2(frame_x + 3, 107, 33, 2), Color("1b302b"))
        # Flaking paint, service seams, and exposed fasteners individualize each gantry.
        draw_rect(Rect2(frame_x + 4, frame_top + 8, 1, 16), Color("587052", 0.44))
        draw_rect(Rect2(frame_x + 5, frame_top + 26, 2, 5), Color("70472f", 0.72))
        draw_rect(Rect2(frame_x + 2, frame_top + 36, 2, 7), Color("33433a", 0.78))
        draw_rect(Rect2(frame_x + 28, frame_top + 39, 2, 4), Color("7a4c31", 0.7))
        for fastener_y in [frame_top + 7.0, frame_top + 35.0, 101.0]:
            draw_rect(Rect2(frame_x + 1.0, fastener_y, 1.0, 1.0), Color("9c794b", 0.76))
            draw_rect(Rect2(frame_x + 31.0, fastener_y + 2.0, 1.0, 1.0), Color("8a6945", 0.7))
    # Bent pipes and snapped cables disappear into the water above.
    draw_rect(Rect2(581, 0, 5, 55), Color("101b1d"))
    draw_rect(Rect2(579, 52, 18, 4), Color("273b36"))
    draw_rect(Rect2(594, 54, 3, 28), Color("1b2c29"))
    draw_rect(Rect2(715, 0, 2, 46), Color("142321"))
    draw_rect(Rect2(713, 42, 17, 3), Color("31483d"))
    draw_rect(Rect2(1008, 0, 4, 39), Color("111e1c"))
    draw_rect(Rect2(1007, 36, 26, 3), Color("263a34"))
    draw_rect(Rect2(1031, 38, 2, 35), Color("1a2a27"))
    # A rusted half-buried pressure dome with three dead gauges recalls the reference image.
    _draw_wrecked_control_dome(901.0, 149.0)
    # Seabed and the last fragment of grated station landing.
    draw_rect(Rect2(ocean_left, 145, 665, 35), Color("080f10"))
    draw_rect(Rect2(ocean_left, 145, 92, 3), Color("5a4932"))
    draw_rect(Rect2(ocean_left, 148, 92, 2), Color("202825"))
    for i in range(10):
        var grate_x := 541.0 + float(i) * 8.0
        draw_rect(Rect2(grate_x, 145, 1, 5), Color("8b6a3f"))
        draw_rect(Rect2(grate_x + 3, 147, 3, 0.75), Color("566054"))
    draw_rect(Rect2(628, 143, 33, 8), Color("121a18"))
    draw_rect(Rect2(635, 140, 21, 5), Color("1a211c"))
    draw_rect(Rect2(665, 146, 39, 6), Color("101816"))
    draw_rect(Rect2(674, 143, 22, 4), Color("26322a"))
    draw_rect(Rect2(723, 146, 30, 7), Color("111917"))
    draw_rect(Rect2(731, 142, 17, 5), Color("202a21"))
    draw_rect(Rect2(975, 145, 51, 9), Color("101815"))
    draw_rect(Rect2(983, 141, 31, 6), Color("18231d"))
    draw_rect(Rect2(1062, 146, 43, 8), Color("101715"))
    draw_rect(Rect2(1070, 142, 26, 5), Color("1a241e"))
    draw_rect(Rect2(ocean_left, 156, 665, 1), Color("172321"))
    draw_rect(Rect2(ocean_left, 171, 665, 1), Color("101719"))
    # Fine bubbles rise through the frame while slower silt drifts across the seabed.
    for i in range(24):
        var bubble_x := ocean_left + 11.0 + fposmod(float(i * 71) + elapsed * (1.4 + float(i % 4) * 0.23), 638.0)
        var bubble_y := 25.0 + fposmod(float(i * 31) - elapsed * (4.0 + float(i % 3) * 1.1), 112.0)
        var bubble_alpha := 0.24 + float(i % 3) * 0.09
        draw_rect(Rect2(bubble_x, bubble_y, 1, 1), Color(0.54, 0.79, 0.75, bubble_alpha))
        draw_rect(Rect2(bubble_x + 1, bubble_y + 1, 0.5, 0.5), Color(0.68, 0.86, 0.79, bubble_alpha * 0.7))
    for i in range(22):
        var silt_x := ocean_left + fposmod(float(i * 83) - elapsed * (0.8 + float(i % 3) * 0.2), 662.0)
        var silt_y := 88.0 + fposmod(float(i * 19) + sin(elapsed * 0.4 + float(i)) * 3.0, 70.0)
        draw_rect(Rect2(silt_x, silt_y, 0.75, 0.75), Color(0.68, 0.72, 0.54, 0.19))
    # Sparse kelp silhouettes make the new terrain read as a seabed, not another corridor.
    for i in range(14):
        var kelp_x := 548.0 + float(i) * 48.0
        var kelp_height := 7.0 + float((i * 11) % 15)
        var kelp_sway := sin(elapsed * 0.7 + float(i) * 1.9) * 1.4
        var kelp_color := Color("243a2f") if i % 2 == 0 else Color("1d342e")
        draw_rect(Rect2(kelp_x + kelp_sway, 149.0 - kelp_height, 1, kelp_height), kelp_color)
        draw_rect(Rect2(kelp_x - 2.0 + kelp_sway, 149.0 - kelp_height + 4.0, 3, 1), kelp_color)
        draw_rect(Rect2(kelp_x + 1.0 + kelp_sway, 149.0 - kelp_height + 8.0, 3, 1), kelp_color)
        draw_rect(Rect2(kelp_x - 2.0 + kelp_sway, 149.0 - kelp_height + 12.0, 3, 1), kelp_color)
        if i % 3 == 0:
            draw_rect(Rect2(kelp_x - 1.0 + kelp_sway, 149.0 - kelp_height + 5.0, 1, 2), Color("527456", 0.56))
            draw_rect(Rect2(kelp_x + 2.0 + kelp_sway, 146.0, 1, 1), Color("8c8762", 0.62))
    # Barnacles and a lost marker plate sit in the lee of the old pressure dome.
    for cluster in range(7):
        var barnacle_x := 842.0 + float(cluster) * 23.0
        var barnacle_y := 143.0 - float((cluster * 7) % 5)
        draw_rect(Rect2(barnacle_x, barnacle_y, 3.0, 2.0), Color("26372e"))
        draw_rect(Rect2(barnacle_x + 1.0, barnacle_y - 1.0, 2.0, 1.0), Color("65705a", 0.72))
        draw_rect(Rect2(barnacle_x + 1.0, barnacle_y + 2.0, 1.0, 1.0), Color("12201d"))
    draw_rect(Rect2(1050.0, 125.0, 24.0, 8.0), Color("131a18"))
    draw_rect(Rect2(1052.0, 126.0, 20.0, 5.0), Color("4e4934"))
    draw_rect(Rect2(1054.0, 127.0, 13.0, 1.0), Color("9a7547"))
    draw_rect(Rect2(1054.0, 129.0, 9.0, 1.0), Color("283934"))
    draw_rect(Rect2(1051.0, 126.0, 1.0, 1.0), Color("b78e53"))
    draw_rect(Rect2(1072.0, 126.0, 1.0, 1.0), Color("b78e53"))
    # Return cage at the far end, rebuilt as a submerged salvage lift behind cloudy glass.
    draw_rect(Rect2(1119, 35, 58, 112), Color("0a1215"))
    draw_rect(Rect2(1125, 42, 46, 100), Color("283530"))
    draw_rect(Rect2(1129, 47, 38, 91), Color("061116"))
    draw_rect(Rect2(1132, 51, 32, 83), Color(0.10, 0.31, 0.31, 0.62))
    draw_rect(Rect2(1135, 53, 6, 76), Color(0.54, 0.72, 0.62, 0.12))
    draw_rect(Rect2(1136, 54, 1, 70), Color(0.74, 0.83, 0.68, 0.38))
    draw_rect(Rect2(1147, 47, 2, 89), Color("1b2b29"))
    draw_rect(Rect2(1158, 47, 2, 89), Color("192824"))
    for bar_y in range(57, 133, 12):
        draw_rect(Rect2(1132, bar_y, 32, 1), Color("263b38"))
    draw_rect(Rect2(1124, 38, 48, 4), Color("756044"))
    draw_rect(Rect2(1126, 39, 44, 1), Color("b28a4e"))
    draw_rect(Rect2(1148, 57, 5, 6), Color("171e1c"))
    draw_rect(Rect2(1149, 58, 3, 4), Color("d3a45c"))
    draw_rect(Rect2(1130, 139, 38, 4), Color("766044"))
    draw_rect(Rect2(1134, 142, 30, 2), Color("11191a"))

func _draw_wrecked_control_dome(center_x: float, base_y: float) -> void:
    var shell_colors := [Color("201b17"), Color("35281d"), Color("4b3322"), Color("30251c"), Color("1c1d19"), Color("171d1b")]
    for row in range(6):
        var width := 88.0 - float(row) * 10.0
        var row_y := base_y - 6.0 - float(row) * 5.0
        draw_rect(Rect2(center_x - width * 0.5, row_y, width, 6), shell_colors[row])
        draw_rect(Rect2(center_x - width * 0.5 + 2, row_y, width - 4, 1), Color("725039", 0.5))
    draw_rect(Rect2(center_x - 46, base_y - 8, 92, 4), Color("111715"))
    draw_rect(Rect2(center_x - 41, base_y - 4, 82, 3), Color("5b402c"))
    draw_rect(Rect2(center_x - 40, base_y - 3, 80, 1), Color("8d4f33"))
    # Uneven corrosion patches and bolts on the dome's face.
    for bolt_x in [center_x - 37, center_x - 25, center_x + 24, center_x + 37]:
        draw_rect(Rect2(bolt_x, base_y - 11, 2, 2), Color("a46b36"))
        draw_rect(Rect2(bolt_x + 0.5, base_y - 10.5, 0.75, 0.75), Color("d3ad63"))
    draw_rect(Rect2(center_x - 34, base_y - 18, 5, 4), Color("8d4f33"))
    draw_rect(Rect2(center_x + 31, base_y - 23, 7, 3), Color("8d4f33"))
    draw_rect(Rect2(center_x - 3, base_y - 27, 6, 5), Color("604329"))
    # Three square porthole gauges with brass bezels, glass faces and idle needles.
    for gauge_x in [center_x - 29, center_x - 4, center_x + 21]:
        draw_rect(Rect2(gauge_x - 5, base_y - 29, 12, 12), Color("111715"))
        draw_rect(Rect2(gauge_x - 4, base_y - 28, 10, 10), Color("9a7040"))
        draw_rect(Rect2(gauge_x - 3, base_y - 27, 8, 8), Color("172527"))
        draw_rect(Rect2(gauge_x - 1, base_y - 25, 4, 4), Color("294447"))
        draw_rect(Rect2(gauge_x, base_y - 25, 1, 3), Color("d3ad63"))
        draw_rect(Rect2(gauge_x - 2, base_y - 21, 6, 1), Color("5a4932"))
    # A snapped valve and hose trail down into the sediment.
    draw_rect(Rect2(center_x - 50, base_y - 29, 4, 13), Color("171715"))
    draw_rect(Rect2(center_x - 53, base_y - 30, 10, 3), Color("6d482c"))
    draw_rect(Rect2(center_x + 42, base_y - 31, 5, 14), Color("171715"))
    draw_rect(Rect2(center_x + 39, base_y - 32, 11, 3), Color("74472d"))
    draw_rect(Rect2(center_x + 46, base_y - 17, 2, 13), Color("263531"))

func _draw_enemy() -> void:
    var facing := -1.0 if player.global_position.x < enemy_position.x else 1.0
    var is_winding_up := enemy_state == "windup"
    var is_lunging := enemy_state == "lunge"
    var is_recovering := enemy_state == "recover"
    var windup_progress := clampf(1.0 - enemy_timer / 1.1, 0.0, 1.0) if is_winding_up else 0.0
    var lunge_progress := clampf(1.0 - enemy_timer / 0.38, 0.0, 1.0) if is_lunging else 0.0
    var recovery_progress := clampf(1.0 - enemy_timer / 0.55, 0.0, 1.0) if is_recovering else 0.0
    var windup_pull := 3.0 * windup_progress
    var twitch_clock := fposmod(elapsed + sin(elapsed * 0.37) * 0.45, 5.6)
    var is_twitching := (enemy_state == "idle" or is_recovering) and twitch_clock < 0.16
    var twitch_x := (1.0 if fposmod(elapsed * 47.0, 2.0) < 1.0 else -1.0) if is_twitching else 0.0
    var twitch_y := -0.65 if is_twitching else 0.0
    var x := enemy_position.x - facing * windup_pull + facing * lunge_progress * 1.2 + twitch_x
    var y := enemy_position.y + twitch_y
    if not player.listening and enemy_state == "idle":
        _enemy_pixel(x, y, Vector2(-1.0, -27.0), Vector2(2.0, 18.0), Color(0.30, 0.53, 0.53, 0.13), facing)
        _enemy_pixel(x, y, Vector2(-3.0, -11.0), Vector2(6.0, 2.0), Color(0.30, 0.53, 0.53, 0.10), facing)
        var ghost_step := sin(enemy_motion_phase) * 0.8 if enemy_is_moving else 0.0
        _enemy_pixel(x, y, Vector2(-3.0 + ghost_step, -9.0), Vector2(2.0, 7.0), Color(0.30, 0.53, 0.53, 0.10), facing)
        _enemy_pixel(x, y, Vector2(1.0 - ghost_step, -9.0), Vector2(2.0, 7.0), Color(0.30, 0.53, 0.53, 0.10), facing)
        return
    var opacity := 1.0 if player.listening or is_winding_up or is_lunging else (0.82 if is_recovering else 0.62)
    var idle_sway := sin(elapsed * 2.1) * 0.48 + sin(elapsed * 1.17) * 0.22
    var sway := idle_sway if enemy_state == "idle" else 0.0
    var crouch := (0.6 + windup_progress * 2.4) if is_winding_up else (lunge_progress * 1.1 if is_lunging else 0.0)
    var recovery_sag := sin(recovery_progress * PI) * 1.25 if is_recovering else 0.0
    var step_wave := sin(enemy_motion_phase) if enemy_is_moving else 0.0
    var enemy_stride := step_wave * 1.25
    var enemy_lift_left := maxf(step_wave, 0.0) * 1.5
    var enemy_lift_right := maxf(-step_wave, 0.0) * 1.5
    var front_arm_shift_x := windup_progress * 1.5 + lunge_progress * 4.0
    var front_arm_shift_y := -windup_progress * 3.5 + recovery_sag * 1.4
    var outline := _enemy_tint("171f20", opacity)
    var suit := _enemy_tint("30362f", opacity)
    var cloth := _enemy_tint("56645a", opacity)
    var edge := _enemy_tint("777c68", opacity)
    var brass := _enemy_tint("8f6d43", opacity)
    var rust := _enemy_tint("8d4f33", opacity)
    var glass := _enemy_tint("101b20", opacity)
    var infected := Color(0.41, 0.71, 0.63, opacity * (0.78 + sin(elapsed * 5.0) * 0.16))
    var infected_light := Color(0.65, 0.84, 0.70, opacity * 0.92)
    var shift := Vector2(0.0, crouch + sway + recovery_sag)
    draw_arc(Vector2(x, y - 15.0), 15.0, -2.8, -0.35, 14, Color(0.30, 0.53, 0.53, 0.15), 1.0, true)
    # Same old deep-diver kit as the player: helmet, brass collar, canvas suit, hoses and air cylinder.
    # The cylinder is dented and leaking, with the rear plate torn open.
    _enemy_pixel(x, y, Vector2(-13.0, -20.0) + shift, Vector2(7.0, 19.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-12.0, -19.0) + shift, Vector2(5.0, 16.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(-11.0, -18.0) + shift, Vector2(2.0, 12.0), edge, facing)
    _enemy_pixel(x, y, Vector2(-12.0, -21.0) + shift, Vector2(5.0, 2.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-12.0, -4.0) + shift, Vector2(5.0, 1.5), rust, facing)
    _enemy_pixel(x, y, Vector2(-14.0, -17.0) + shift, Vector2(2.0, 4.0), rust, facing)
    _enemy_pixel(x, y, Vector2(-13.0, -14.0) + shift, Vector2(1.0, 3.0), Color("c18d49", opacity), facing)
    _enemy_pixel(x, y, Vector2(-6.0, -18.0) + shift, Vector2(2.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -17.0) + shift, Vector2(1.0, 3.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -17.0) + shift, Vector2(2.0, 4.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -15.0) + shift, Vector2(1.0, 2.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-7.0, -13.0) + shift, Vector2(2.0, 2.0), rust, facing)
    # Round brass hard-hat shell, matching the player's old standard diving helmet.
    _enemy_pixel(x, y, Vector2(-4.0, -34.0) + shift, Vector2(8.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -32.0) + shift, Vector2(12.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -30.0) + shift, Vector2(16.0, 10.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -20.0) + shift, Vector2(12.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-4.0, -33.0) + shift, Vector2(8.0, 1.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -31.0) + shift, Vector2(12.0, 2.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-7.0, -29.0) + shift, Vector2(14.0, 8.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -21.0) + shift, Vector2(12.0, 1.0), rust, facing)
    # Side ear pieces and a large circular front port with a trapped, indistinct silhouette.
    _enemy_pixel(x, y, Vector2(-10.0, -29.0) + shift, Vector2(3.0, 7.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-9.0, -28.0) + shift, Vector2(2.0, 5.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(7.0, -29.0) + shift, Vector2(3.0, 7.0), outline, facing)
    _enemy_pixel(x, y, Vector2(7.0, -28.0) + shift, Vector2(2.0, 5.0), rust, facing)
    var port_x := 1.0
    _enemy_pixel(x, y, Vector2(port_x - 1.0, -29.0) + shift, Vector2(8.0, 9.0), outline, facing)
    _enemy_pixel(x, y, Vector2(port_x, -28.0) + shift, Vector2(6.0, 7.0), brass, facing)
    _enemy_pixel(x, y, Vector2(port_x + 1.0, -27.0) + shift, Vector2(4.0, 5.0), glass, facing)
    _enemy_pixel(x, y, Vector2(port_x + 1.0, -26.0) + shift, Vector2(2.0, 3.0), Color(0.07, 0.14, 0.15, opacity), facing)
    _enemy_pixel(x, y, Vector2(port_x + 3.0, -25.0) + shift, Vector2(1.0, 2.0), infected, facing)
    _enemy_pixel(x, y, Vector2(port_x + 2.0, -26.0) + shift, Vector2(1.0, 1.0), infected_light, facing)
    # A broken pressure lamp and branching glass cracks; the face stays behind the sealed port.
    _enemy_pixel(x, y, Vector2(-2.0, -27.0) + shift, Vector2(3.0, 2.0), infected, facing)
    _enemy_pixel(x, y, Vector2(1.0, -26.0) + shift, Vector2(2.0, 3.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(port_x + 2.0, -27.0) + shift, Vector2(1.0, 2.0), Color("d4d3bd", opacity * 0.8), facing)
    _enemy_pixel(x, y, Vector2(port_x + 3.0, -25.0) + shift, Vector2(2.0, 1.0), Color("d4d3bd", opacity * 0.58), facing)
    _enemy_pixel(x, y, Vector2(port_x + 2.0, -24.0) + shift, Vector2(1.0, 2.0), Color("d4d3bd", opacity * 0.65), facing)
    _enemy_pixel(x, y, Vector2(port_x, -23.0) + shift, Vector2(2.0, 1.0), Color("d4d3bd", opacity * 0.55), facing)
    # A human gaze moves behind the broken glass, then vanishes in an irregular blink.
    var blink_phase := fposmod(elapsed + sin(elapsed * 0.31) * 0.23, 4.7)
    var eyes_open := not (blink_phase < 0.13 or (blink_phase > 2.96 and blink_phase < 3.08))
    var player_distance := absf(player.global_position.x - enemy_position.x)
    var gaze_shift := 1.0 if player_distance < 78.0 or is_winding_up or is_lunging else 0.0
    var eye_glow := 0.62 + (sin(elapsed * 2.2) + 1.0) * 0.14
    _enemy_pixel(x, y, Vector2(port_x + 1.0, -25.0) + shift, Vector2(1.0, 1.0), Color("070e10", opacity * 0.9), facing)
    _enemy_pixel(x, y, Vector2(port_x + 4.0, -25.0) + shift, Vector2(1.0, 1.0), Color("070e10", opacity * 0.9), facing)
    if eyes_open:
        _enemy_pixel(x, y, Vector2(port_x + 1.0 + gaze_shift, -25.0) + shift, Vector2(1.0, 1.0), Color(0.72, 0.94, 0.70, opacity * eye_glow), facing)
        _enemy_pixel(x, y, Vector2(port_x + 4.0 + gaze_shift, -25.0) + shift, Vector2(1.0, 1.0), Color(0.55, 0.82, 0.65, opacity * eye_glow * 0.72), facing)
    else:
        _enemy_pixel(x, y, Vector2(port_x + 1.0, -25.0) + shift, Vector2(1.0, 1.0), Color("a3a48a", opacity * 0.72), facing)
        _enemy_pixel(x, y, Vector2(port_x + 4.0, -25.0) + shift, Vector2(1.0, 1.0), Color("8a987c", opacity * 0.62), facing)
    var face_pressure := 0.14 + maxf(0.0, sin(elapsed * 1.15 - 0.6)) * 0.22
    _enemy_pixel(x, y, Vector2(port_x + 2.0, -23.0) + shift, Vector2(3.0, 1.0), Color(0.48, 0.66, 0.57, opacity * face_pressure), facing)
    # Studs around the helmet, with a few missing where the shell has split.
    for bolt_x in [-6.0, 5.0]:
        _enemy_pixel(x, y, Vector2(bolt_x, -30.0) + shift, Vector2(1.0, 1.0), Color("c18d49", opacity), facing)
        _enemy_pixel(x, y, Vector2(bolt_x, -21.0) + shift, Vector2(1.0, 1.0), brass, facing)
    # Reinforced torso panels, buckles, a faded unit patch and the regulator plate.
    _enemy_pixel(x, y, Vector2(-7.0, -17.0) + shift, Vector2(15.0, 18.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -16.0) + shift, Vector2(13.0, 16.0), suit, facing)
    _enemy_pixel(x, y, Vector2(-5.0, -15.0) + shift, Vector2(11.0, 14.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(-4.0, -14.0) + shift, Vector2(2.0, 10.0), edge, facing)
    _enemy_pixel(x, y, Vector2(4.0, -13.0) + shift, Vector2(1.0, 9.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-2.0, -14.0) + shift, Vector2(1.0, 8.0), outline, facing)
    _enemy_pixel(x, y, Vector2(1.0, -14.0) + shift, Vector2(1.0, 7.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-1.0, -12.0) + shift, Vector2(4.0, 5.0), outline, facing)
    _enemy_pixel(x, y, Vector2(0.0, -11.0) + shift, Vector2(2.0, 3.0), brass, facing)
    _enemy_pixel(x, y, Vector2(0.5, -10.5) + shift, Vector2(1.0, 1.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(3.0, -8.0) + shift, Vector2(2.0, 3.0), Color("453c31", opacity), facing)
    _enemy_pixel(x, y, Vector2(3.0, -7.0) + shift, Vector2(1.0, 1.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-5.0, -5.0) + shift, Vector2(10.0, 3.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-4.0, -4.0) + shift, Vector2(8.0, 1.0), brass, facing)
    for belt_x in [-3.0, -1.0, 2.0, 4.0]:
        _enemy_pixel(x, y, Vector2(belt_x, -4.0) + shift, Vector2(1.0, 2.0), rust, facing)
    _enemy_pixel(x, y, Vector2(-1.0, -5.0) + shift, Vector2(2.0, 3.0), edge, facing)
    _enemy_pixel(x, y, Vector2(-0.5, -4.0) + shift, Vector2(1.0, 1.0), brass, facing)
    # Shoulder armor has split seams and dark inner fabric, with a loose hose and a dangling clip.
    _enemy_pixel(x, y, Vector2(-7.0, -20.0) + shift, Vector2(14.0, 5.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -19.0) + shift, Vector2(12.0, 3.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-5.0, -18.0) + shift, Vector2(10.0, 1.0), rust, facing)
    _enemy_pixel(x, y, Vector2(-5.0, -16.0) + shift, Vector2(10.0, 1.0), edge, facing)
    for yoke_bolt_x in [-4.0, 3.0]:
        _enemy_pixel(x, y, Vector2(yoke_bolt_x, -18.0) + shift, Vector2(1.0, 1.0), Color("c18d49", opacity), facing)
    _enemy_pixel(x, y, Vector2(-9.0, -17.0) + shift, Vector2(4.0, 5.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -16.0) + shift, Vector2(2.0, 3.0), rust, facing)
    _enemy_pixel(x, y, Vector2(5.0 + front_arm_shift_x, -17.0 + front_arm_shift_y) + shift, Vector2(4.0, 6.0), outline, facing)
    _enemy_pixel(x, y, Vector2(6.0 + front_arm_shift_x, -16.0 + front_arm_shift_y) + shift, Vector2(2.0, 3.0), edge, facing)
    _enemy_pixel(x, y, Vector2(7.0 + front_arm_shift_x, -13.0 + front_arm_shift_y) + shift, Vector2(2.0, 4.0), Color("171f20", opacity), facing)
    _enemy_pixel(x, y, Vector2(8.0 + front_arm_shift_x, -10.0 + front_arm_shift_y) + shift, Vector2(1.0, 3.0), brass, facing)
    _enemy_pixel(x, y, Vector2(7.0 + front_arm_shift_x, -8.0 + front_arm_shift_y) + shift, Vector2(4.0, 4.0), outline, facing)
    _enemy_pixel(x, y, Vector2(8.0 + front_arm_shift_x, -7.0 + front_arm_shift_y) + shift, Vector2(2.0, 2.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(7.0 + front_arm_shift_x, -4.0 + front_arm_shift_y) + shift, Vector2(1.0, 4.0), outline, facing)
    _enemy_pixel(x, y, Vector2(9.0 + front_arm_shift_x, -4.0 + front_arm_shift_y) + shift, Vector2(1.0, 5.0), outline, facing)
    _enemy_pixel(x, y, Vector2(11.0 + front_arm_shift_x, -3.0 + front_arm_shift_y) + shift, Vector2(1.0, 3.0), outline, facing)
    _enemy_pixel(x, y, Vector2(6.0 + front_arm_shift_x, -3.0 + front_arm_shift_y) + shift, Vector2(2.0, 1.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-10.0, -13.0) + shift, Vector2(3.0, 7.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-11.0, -8.0) + shift, Vector2(4.0, 4.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-10.0, -7.0) + shift, Vector2(2.0, 2.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(-11.0, -4.0) + shift, Vector2(1.0, 4.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-9.0, -4.0) + shift, Vector2(1.0, 3.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -3.0) + shift, Vector2(1.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -16.0) + shift, Vector2(1.0, 9.0), brass, facing)
    _enemy_pixel(x, y, Vector2(-7.0, -7.0) + shift, Vector2(2.0, 2.0), rust, facing)
    # Bent legs and mismatched boots retain a human, suit-wearing silhouette.
    _enemy_pixel(x, y, Vector2(-4.0 + enemy_stride, 1.0 + crouch + sway + recovery_sag + enemy_lift_left), Vector2(4.0, 6.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-3.0 + enemy_stride, 1.0 + crouch + sway + recovery_sag + enemy_lift_left), Vector2(2.0, 4.0), cloth, facing)
    _enemy_pixel(x, y, Vector2(1.0 - enemy_stride, -1.0 + crouch + sway + recovery_sag + enemy_lift_right), Vector2(4.0, 7.0), outline, facing)
    _enemy_pixel(x, y, Vector2(2.0 - enemy_stride, 0.0 + crouch + sway + recovery_sag + enemy_lift_right), Vector2(2.0, 5.0), suit, facing)
    _enemy_pixel(x, y, Vector2(-5.0 + enemy_stride, 6.0 + crouch + sway + recovery_sag + enemy_lift_left), Vector2(5.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(1.0 - enemy_stride, 6.0 + crouch + sway + recovery_sag + enemy_lift_right), Vector2(5.0, 2.0), outline, facing)
    _enemy_pixel(x, y, Vector2(-4.0 + enemy_stride, 6.0 + crouch + sway + recovery_sag + enemy_lift_left), Vector2(2.0, 1.0), brass, facing)
    _enemy_pixel(x, y, Vector2(2.0 - enemy_stride, 6.0 + crouch + sway + recovery_sag + enemy_lift_right), Vector2(2.0, 1.0), rust, facing)
    # Mineral growth follows the suit seams from the cracked helmet to the chest and glove.
    _enemy_pixel(x, y, Vector2(-8.0, -30.0) + shift, Vector2(2.0, 2.0), infected, facing)
    _enemy_pixel(x, y, Vector2(-7.0, -32.0) + shift, Vector2(1.0, 3.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -27.0) + shift, Vector2(2.0, 2.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(-9.0, -23.0) + shift, Vector2(2.0, 3.0), infected, facing)
    _enemy_pixel(x, y, Vector2(-8.0, -20.0) + shift, Vector2(2.0, 3.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(-9.0, -17.0) + shift, Vector2(2.0, 2.0), infected, facing)
    _enemy_pixel(x, y, Vector2(-7.0, -15.0) + shift, Vector2(2.0, 3.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(-6.0, -12.0) + shift, Vector2(2.0, 3.0), infected, facing)
    _enemy_pixel(x, y, Vector2(-5.0, -9.0) + shift, Vector2(2.0, 2.0), infected_light, facing)
    _enemy_pixel(x, y, Vector2(-4.0, -7.0) + shift, Vector2(2.0, 2.0), infected, facing)
    # Torn canvas, old repair stitches and corroded plates reveal a diver lost long ago.
    _enemy_pixel(x, y, Vector2(3.0, -18.0) + shift, Vector2(4.0, 1.0), Color("1a201d", opacity), facing)
    _enemy_pixel(x, y, Vector2(4.0, -17.0) + shift, Vector2(3.0, 2.0), Color("56604a", opacity * 0.88), facing)
    _enemy_pixel(x, y, Vector2(6.0, -17.0) + shift, Vector2(1.0, 1.0), Color("d3ad63", opacity * 0.72), facing)
    _enemy_pixel(x, y, Vector2(-2.0, -12.0) + shift, Vector2(1.0, 4.0), Color("1a201d", opacity * 0.86), facing)
    _enemy_pixel(x, y, Vector2(3.0, -10.0) + shift, Vector2(2.0, 1.0), Color("d3ad63", opacity * 0.62), facing)
    _enemy_pixel(x, y, Vector2(4.0, -9.0) + shift, Vector2(1.0, 1.0), Color("171f20", opacity), facing)
    _enemy_pixel(x, y, Vector2(7.0, -4.0) + shift, Vector2(2.0, 2.0), Color("343d39", opacity), facing)
    _enemy_pixel(x, y, Vector2(8.0, -3.0) + shift, Vector2(1.0, 1.0), Color("8f6d43", opacity * 0.76), facing)
    _enemy_pixel(x, y, Vector2(-8.0, -25.0) + shift, Vector2(1.0, 2.0), Color("a4d5ac", opacity * 0.84), facing)
    _enemy_pixel(x, y, Vector2(-7.0, -18.0) + shift, Vector2(1.0, 2.0), Color("a4d5ac", opacity * 0.84), facing)
    _enemy_pixel(x, y, Vector2(-5.0, -11.0) + shift, Vector2(1.0, 2.0), Color("a4d5ac", opacity * 0.84), facing)
    # Canvas weave, old repair seams, and shallow dents add material detail without widening the silhouette.
    for seam_stitch in range(5):
        _enemy_pixel(x, y, Vector2(-3.0 + float(seam_stitch) * 2.0, -16.0) + shift, Vector2(0.75, 0.55), Color("c0ad83", opacity * 0.7), facing)
    for crease in range(4):
        var crease_y := -8.0 + float(crease) * 2.0
        _enemy_pixel(x, y, Vector2(4.0 + float(crease % 2), crease_y) + shift, Vector2(2.0, 0.7), Color("191f1c", opacity * 0.88), facing)
        _enemy_pixel(x, y, Vector2(5.0 + float(crease % 2), crease_y + 0.7) + shift, Vector2(1.0, 0.55), Color("78806b", opacity * 0.48), facing)
    _enemy_pixel(x, y, Vector2(-5.0, -31.0) + shift, Vector2(2.0, 0.75), Color("c18d49", opacity * 0.65), facing)
    _enemy_pixel(x, y, Vector2(5.0, -23.0) + shift, Vector2(1.0, 2.0), Color("8d4f33", opacity * 0.8), facing)
    _enemy_pixel(x, y, Vector2(-4.0 + enemy_stride, 3.0 + crouch + sway + recovery_sag + enemy_lift_left), Vector2(2.0, 1.0), Color("77806b", opacity * 0.56), facing)
    _enemy_pixel(x, y, Vector2(2.0 - enemy_stride, 4.0 + crouch + sway + recovery_sag + enemy_lift_right), Vector2(2.0, 1.0), Color("493e30", opacity * 0.9), facing)
    # The torn tank releases a slow, uneven trail that speeds up as the diver lunges.
    var leak_rate := 3.2 if is_lunging else 1.7
    for bubble_i in range(4):
        var leak_age := fposmod(elapsed * leak_rate + float(bubble_i) * 0.47, 2.2)
        var leak_x := x - facing * (14.0 + float(bubble_i % 2) * 2.0) + sin(elapsed * 2.4 + float(bubble_i)) * 0.7
        var leak_y := y - 15.0 - leak_age * 8.0
        var leak_alpha := opacity * (0.28 + float(bubble_i % 3) * 0.08)
        draw_rect(Rect2(leak_x, leak_y, 1, 1), Color(0.58, 0.82, 0.76, leak_alpha))
        draw_rect(Rect2(leak_x + 1, leak_y + 1, 0.5, 0.5), Color(0.78, 0.91, 0.82, leak_alpha * 0.6))
    if enemy_state == "lunge":
        # The glove reaches out as the diver's remaining air vents in a stream of bubbles.
        _enemy_pixel(x, y, Vector2(7.0, -15.0), Vector2(4.0, 3.0), outline, facing)
        _enemy_pixel(x, y, Vector2(10.0, -14.0), Vector2(3.0, 2.0), cloth, facing)
        draw_rect(Rect2(x + 8.0 * facing, y - 24.0, 1.0, 1.0), Color(0.57, 0.75, 0.67, 0.56))
        draw_rect(Rect2(x + 10.0 * facing, y - 27.0, 0.75, 0.75), Color(0.57, 0.75, 0.67, 0.42))
    if is_winding_up:
        var pulse := 0.45 + (sin(elapsed * 18.0) + 1.0) * 0.18
        _enemy_pixel(x, y, Vector2(-12.0, -28.0), Vector2(3.0, 1.0), Color(0.89, 0.50, 0.23, pulse), facing)
        _enemy_pixel(x, y, Vector2(9.0, -28.0), Vector2(3.0, 1.0), Color(0.89, 0.50, 0.23, pulse), facing)
        _enemy_pixel(x, y, Vector2(-10.0, -31.0), Vector2(1.0, 2.0), Color(0.89, 0.50, 0.23, pulse * 0.75), facing)

func _enemy_pixel(origin_x: float, origin_y: float, offset: Vector2, size: Vector2, color: Color, facing: float) -> void:
    var local_x := offset.x if facing > 0.0 else -offset.x - size.x
    draw_rect(Rect2(origin_x + local_x, origin_y + offset.y, size.x, size.y), color)

func _enemy_tint(hex_color: String, opacity: float) -> Color:
    var result := Color(hex_color)
    result.a = opacity
    return result



