extends CharacterBody2D

const SPEED := 62.0
const SPRINT_SPEED := 91.0
const GRAVITY := 320.0
const JUMP_VELOCITY := -112.0
const COYOTE_TIME := 0.11
const JUMP_BUFFER := 0.12
var facing := 1
var breath := 0.0
var listening := false
var listen_direction := Vector2.RIGHT
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var gait_phase := 0.0
var hit_reaction := 0.0
var landing_time := 0.0
var underwater := false
var controls_enabled := true
var panicking := false
var swim_pose_angle := 0.0
var environmental_current := Vector2.ZERO
var body_collision: CollisionShape2D
var helmet_light: PointLight2D

func _ready() -> void:
    body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
    helmet_light = PointLight2D.new()
    helmet_light.name = "HelmetLamp"
    helmet_light.texture = _make_lamp_texture()
    helmet_light.color = Color(0.77, 0.88, 0.77, 1.0)
    helmet_light.energy = 0.78
    helmet_light.texture_scale = 2.25
    helmet_light.shadow_enabled = false
    helmet_light.visible = underwater
    add_child(helmet_light)
    _sync_helmet_light()

func _make_lamp_texture() -> GradientTexture2D:
    var glow := Gradient.new()
    glow.colors = PackedColorArray([Color(1.0, 0.91, 0.72, 0.42), Color(0.72, 0.83, 0.75, 0.0)])
    glow.offsets = PackedFloat32Array([0.0, 1.0])
    var texture := GradientTexture2D.new()
    texture.gradient = glow
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.width = 128
    texture.height = 128
    return texture

func _sync_helmet_light() -> void:
    if not is_instance_valid(helmet_light):
        return
    helmet_light.visible = underwater
    helmet_light.position = Vector2(0.0, -32.0).rotated(swim_pose_angle) if underwater else Vector2(4.0 * facing, -29.0)
    helmet_light.energy = 0.69 + (sin(breath * 2.7) + 1.0) * 0.045

func trigger_hit_reaction() -> void:
    hit_reaction = 0.38
    queue_redraw()

func _physics_process(delta: float) -> void:
    breath += delta
    hit_reaction = maxf(0.0, hit_reaction - delta)
    landing_time = maxf(0.0, landing_time - delta)
    if underwater:
        _underwater_physics(delta)
        _sync_helmet_light()
        queue_redraw()
        return
    if not controls_enabled:
        velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
        if is_on_floor():
            velocity.y = 0.0
        else:
            velocity.y += GRAVITY * delta
        listening = false
        move_and_slide()
        queue_redraw()
        return
    var grounded_before := is_on_floor()
    var axis := Input.get_axis("move_left", "move_right")
    if axis != 0.0:
        facing = int(sign(axis))
    var pace := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
    var acceleration := 520.0 if is_on_floor() else 330.0
    velocity.x = move_toward(velocity.x, axis * pace, acceleration * delta)
    if is_zero_approx(axis):
        velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
    if not is_on_floor():
        velocity.y += GRAVITY * delta
        coyote_timer = maxf(0.0, coyote_timer - delta)
    else:
        coyote_timer = COYOTE_TIME
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER
    else:
        jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
    if coyote_timer > 0.0 and jump_buffer_timer > 0.0:
        velocity.y = JUMP_VELOCITY
        coyote_timer = 0.0
        jump_buffer_timer = 0.0
    if not Input.is_action_pressed("jump") and velocity.y < -45.0:
        velocity.y *= 0.72
    listening = Input.is_action_pressed("listen")
    move_and_slide()
    _sync_helmet_light()
    if not grounded_before and is_on_floor():
        landing_time = 0.18
    if is_on_floor() and absf(velocity.x) > 3.0:
        var gait_rate := lerpf(8.5, 15.5, clampf(absf(velocity.x) / SPRINT_SPEED, 0.0, 1.0))
        gait_phase += delta * gait_rate
    queue_redraw()

func _underwater_physics(delta: float) -> void:
    if not controls_enabled:
        velocity = velocity.move_toward(Vector2.ZERO, 80.0 * delta)
        move_and_slide()
        listening = false
        return
    var swim_input := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("swim_up", "swim_down"))
    if swim_input.length_squared() > 1.0:
        swim_input = swim_input.normalized()
    if absf(swim_input.x) > 0.1:
        facing = int(sign(swim_input.x))
    var swim_speed := 76.0 if Input.is_action_pressed("sprint") else 54.0
    var target_velocity := swim_input * swim_speed + environmental_current
    if swim_input.length_squared() < 0.01:
        # The heavy canvas suit slowly sinks when the diver stops kicking.
        target_velocity += Vector2(0.0, 7.0)
    velocity = velocity.move_toward(target_velocity, 138.0 * delta)
    var target_pose_angle := 0.0
    if velocity.length() > 10.0 and controls_enabled:
        # The helmet leads into the direction of travel; legs trail behind.
        target_pose_angle = velocity.angle() + PI * 0.5
    swim_pose_angle = lerp_angle(swim_pose_angle, target_pose_angle, clampf(delta * 4.8, 0.0, 1.0))
    if is_instance_valid(body_collision):
        body_collision.position = Vector2(0.0, -14.0).rotated(swim_pose_angle)
        body_collision.rotation = swim_pose_angle
    listening = Input.is_action_pressed("listen")
    move_and_slide()
    _sync_helmet_light()
    if velocity.length() > 10.0:
        # Slower strokes make the old canvas suit feel like it is pushing through water.
        gait_phase += delta * (3.8 + velocity.length() * 0.035)

func _draw() -> void:
    var horizontal_speed := absf(velocity.x)
    var walking := is_on_floor() and horizontal_speed > 3.0
    var swimming := underwater and velocity.length() > 10.0
    var running := horizontal_speed > SPEED * 0.92
    var airborne := not is_on_floor() and not underwater
    var animated_motion := walking or swimming
    var step_wave := sin(gait_phase) if animated_motion else 0.0
    var swim_wave := sin(gait_phase) if swimming else 0.0
    var stride_power := 1.35 if running else 0.85
    var stride := step_wave * stride_power
    var left_lift := maxf(step_wave, 0.0) * (2.0 if running else 1.4)
    var right_lift := maxf(-step_wave, 0.0) * (2.0 if running else 1.4)
    var left_leg_x := stride
    var right_leg_x := -stride
    if airborne:
        left_lift = 1.4
        right_lift = 1.4
        left_leg_x = -1.1 if facing > 0 else 1.1
        right_leg_x = 1.1 if facing > 0 else -1.1
    elif underwater:
        left_lift = 0.2 + maxf(swim_wave, 0.0) * 2.8
        right_lift = 0.2 + maxf(-swim_wave, 0.0) * 2.8
        left_leg_x = swim_wave * 2.1
        right_leg_x = -swim_wave * 2.1
    var landing_squash := (landing_time / 0.18) * 1.5
    var bob := absf(step_wave) * (0.6 if running else 0.35) - landing_squash if walking or landing_time > 0.0 else sin(breath * 2.0) * 0.28
    if underwater:
        bob = sin(gait_phase * 2.0) * 0.42 if swimming else sin(breath * 2.4) * 0.5
    var arm_swing := sin(gait_phase + PI) * (1.8 if underwater else (1.0 if running else 0.65)) if animated_motion else 0.0
    var air_arm_lift := 1.6 if airborne else (0.65 if underwater and swimming else 0.0)
    var listen_tuck := 0.45 if listening else 0.0
    var left_arm_x := -arm_swing
    var right_arm_x := arm_swing
    var left_arm_y := -air_arm_lift + listen_tuck
    var right_arm_y := -air_arm_lift + listen_tuck
    if swimming:
        # Alternate a forward reach and a backward pull against the scissor kick.
        left_arm_x = -1.2 + swim_wave * 2.7
        right_arm_x = 1.2 - swim_wave * 2.7
        left_arm_y += maxf(swim_wave, 0.0) * 2.7
        right_arm_y += maxf(-swim_wave, 0.0) * 2.7
    var impact_mix := clampf(hit_reaction / 0.38, 0.0, 1.0)
    var landing_mix := clampf(landing_time / 0.18, 0.0, 1.0)
    var panic_mix := 1.0 if panicking else 0.0
    var panic_jitter := sin(breath * 22.0) * 0.65 * panic_mix
    var impact_flail := sin((0.38 - hit_reaction) * 34.0) * 1.25 * impact_mix
    left_arm_x -= impact_flail + landing_mix * 0.35 + panic_jitter
    right_arm_x += impact_flail + landing_mix * 0.35 + panic_jitter
    left_arm_y -= impact_mix * 1.2 + landing_mix * 0.6
    right_arm_y -= impact_mix * 1.7 + landing_mix * 0.6
    var walk_lean := step_wave * (0.055 if running else 0.03)
    var air_lean := clampf(-velocity.y / 700.0, -0.16, 0.16) if airborne else 0.0
    if underwater:
        air_lean = clampf(velocity.y * 0.0021, -0.20, 0.20)
    var impact_lean := -signf(velocity.x) * 0.22 * impact_mix
    var body_angle := lerpf(lerpf(walk_lean, air_lean, 0.85 if airborne or underwater else 0.0), impact_lean, impact_mix)
    if underwater:
        body_angle = swim_pose_angle + (sin(gait_phase * 2.0) * 0.035 if swimming else sin(breath * 1.2) * 0.025)
    body_angle += sin(breath * 18.0) * 0.035 * panic_mix
    draw_set_transform(Vector2(panic_jitter, 0.0), body_angle, Vector2.ONE)
    var tank_x := -10.0 if facing > 0 else 6.0
    var visor_x := 1.0 if facing > 0 else -7.0
    if underwater:
        _draw_helmet_beam(Vector2(0.0, -32.0 + bob), Vector2(0.0, -1.0))
    else:
        _draw_helmet_beam(Vector2(4.0 * facing, -29.0 + bob), Vector2(float(facing), -0.035))
    # Back-mounted air cylinder and the hose that feeds the helmet regulator.
    draw_rect(Rect2(tank_x - 0.5, -19.0 + bob, 4.5, 18.0), Color("171f20"))
    draw_rect(Rect2(tank_x, -18.0 + bob, 3.5, 16.0), Color("56645a"))
    draw_rect(Rect2(tank_x + 0.5, -16.5 + bob, 2.0, 11.0), Color("777c68"))
    draw_rect(Rect2(tank_x, -18.5 + bob, 3.5, 2.0), Color("8f6d43"))
    draw_rect(Rect2(tank_x + 0.5, -6.0 + bob, 2.5, 1.0), Color("bc8548"))
    # Cylinder bands, valve block and a tiny pressure window add a machined third material.
    for tank_band in range(3):
        var band_y := -14.0 + float(tank_band) * 4.0 + bob
        draw_rect(Rect2(tank_x, band_y, 3.5, 0.75), Color("252f2c"))
        draw_rect(Rect2(tank_x + 0.5, band_y + 0.25, 2.0, 0.5), Color("8f6d43"))
    draw_rect(Rect2(tank_x + 1.0, -20.0 + bob, 2.0, 2.0), Color("171f20"))
    draw_rect(Rect2(tank_x + 1.5, -21.0 + bob, 1.0, 2.0), Color("d0a15a"))
    draw_rect(Rect2(tank_x + 1.0, -12.0 + bob, 1.5, 2.0), Color("101819"))
    draw_rect(Rect2(tank_x + 1.5, -11.5 + bob, 0.5, 1.0), Color("82a796"))
    var hose_joint_x := -4.0 if facing > 0 else 4.0
    draw_line(Vector2(tank_x + (4.0 if facing > 0 else 0.0), -15.0 + bob), Vector2(hose_joint_x, -12.0 + bob), Color("252f2c"), 1.5)
    draw_line(Vector2(tank_x + (4.0 if facing > 0 else 0.0), -15.0 + bob), Vector2(hose_joint_x, -12.0 + bob), Color("a67945"), 0.5)
    var helmet_hose_x := -6.0 if facing > 0 else 6.0
    draw_line(Vector2(tank_x + (3.0 if facing > 0 else 1.0), -16.0 + bob), Vector2(helmet_hose_x, -27.0 + bob), Color("171f20"), 2.0)
    draw_line(Vector2(tank_x + (3.0 if facing > 0 else 1.0), -16.0 + bob), Vector2(helmet_hose_x, -27.0 + bob), Color("5b5544"), 0.75)
    # Heavy canvas suit, with a dark outer seam and a reinforced chest panel.
    draw_rect(Rect2(-6.5, -16.5 + bob, 13.0, 17.0), Color("171f20"))
    draw_rect(Rect2(-5.5, -15.5 + bob, 11.0, 15.0), Color("777c68"))
    draw_rect(Rect2(-4.5, -14.5 + bob, 9.0, 13.0), Color("a3a48a"))
    draw_rect(Rect2(-5.5, -15.5 + bob, 3.0, 4.0), Color("56645a"))
    draw_rect(Rect2(2.5, -15.5 + bob, 3.0, 4.0), Color("56645a"))
    draw_rect(Rect2(-4.5, -14.0 + bob, 1.0, 10.0), Color("d0c5a2"))
    draw_rect(Rect2(3.5, -13.5 + bob, 1.0, 9.5), Color("6d7465"))
    draw_rect(Rect2(-2.5, -13.0 + bob, 1.5, 8.0), Color("5b5544"))
    draw_rect(Rect2(1.0, -13.0 + bob, 1.5, 8.0), Color("5b5544"))
    draw_rect(Rect2(-2.0, -11.5 + bob, 4.0, 4.0), Color("56645a"))
    draw_rect(Rect2(-1.0, -10.5 + bob, 2.0, 2.0), Color("8f6d43"))
    draw_rect(Rect2(-0.5, -10.0 + bob, 1.0, 1.0), Color("d3ad63"))
    # Hand-stitched field repair, worn pocket flap and riveted regulator badge.
    var patch_x := 2.0 if facing > 0 else -4.0
    draw_rect(Rect2(patch_x, -14.0 + bob, 2.0, 3.0), Color("626d5b"))
    draw_rect(Rect2(patch_x + 0.5, -13.5 + bob, 1.0, 2.0), Color("8f6d43"))
    draw_rect(Rect2(patch_x - 0.5, -14.5 + bob, 3.0, 0.75), Color("171f20"))
    for stitch in range(3):
        draw_rect(Rect2(-4.5 + float(stitch) * 3.0, -5.0 + bob, 1.0, 0.5), Color("d0c5a2"))
    draw_rect(Rect2(-6.0, -13.0 + bob, 0.75, 5.0), Color("d0c5a2"))
    draw_rect(Rect2(5.25, -12.0 + bob, 0.75, 4.0), Color("5b5544"))
    draw_rect(Rect2(tank_x + 0.5, -11.0 + bob, 2.0, 1.0), Color("171f20"))
    draw_rect(Rect2(tank_x + 1.0, -10.75 + bob, 1.0, 0.5), Color("d0a15a"))
    draw_rect(Rect2(-5.0, -3.5 + bob, 10.0, 2.5), Color("171f20"))
    draw_rect(Rect2(-4.0, -3.0 + bob, 8.0, 1.5), Color("5b5544"))
    for belt_x in [-3.0, -1.0, 2.0, 4.0]:
        draw_rect(Rect2(belt_x, -3.0 + bob, 1.0, 2.0), Color("8f6d43"))
    draw_rect(Rect2(-1.0, -4.0 + bob, 2.0, 3.0), Color("bc8548"))
    # Broad, riveted shoulder yoke fixes the helmet to the canvas suit.
    draw_rect(Rect2(-7.0, -19.0 + bob, 14.0, 5.0), Color("171f20"))
    draw_rect(Rect2(-6.0, -18.0 + bob, 12.0, 3.0), Color("5b5544"))
    draw_rect(Rect2(-5.0, -18.0 + bob, 10.0, 1.0), Color("8f6d43"))
    draw_rect(Rect2(-5.0, -16.0 + bob, 10.0, 1.0), Color("777c68"))
    for rivet_x in [-4.0, 3.0]:
        draw_rect(Rect2(rivet_x, -17.0 + bob, 1.0, 1.0), Color("d3ad63"))
    # The shoulder yoke is hand-fitted: stitch marks and a nicked brass edge catch the light.
    for stitch in range(5):
        var stitch_x := -4.0 + float(stitch) * 2.0
        draw_rect(Rect2(stitch_x, -18.5 + bob, 0.75, 0.5), Color("d0c5a2"))
    draw_rect(Rect2(-6.0, -18.0 + bob, 1.0, 0.75), Color("493526"))
    draw_rect(Rect2(5.0, -17.0 + bob, 1.0, 0.75), Color("b75038"))
    draw_rect(Rect2(-4.5, -7.0 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(3.5, -7.0 + bob, 1.0, 1.0), Color("d3ad63"))
    # Thick collar and old-fashioned round hard-hat helmet with a forward-facing porthole.
    draw_rect(Rect2(-4.5, -20.5 + bob, 9.0, 3.0), Color("171f20"))
    draw_rect(Rect2(-4.0, -20.0 + bob, 8.0, 2.0), Color("8f6d43"))
    draw_rect(Rect2(-3.5, -19.5 + bob, 7.0, 1.0), Color("d0a15a"))
    draw_rect(Rect2(-4.0, -34.0 + bob, 8.0, 2.0), Color("171f20"))
    draw_rect(Rect2(-6.0, -32.0 + bob, 12.0, 2.0), Color("171f20"))
    draw_rect(Rect2(-7.0, -30.0 + bob, 14.0, 10.0), Color("171f20"))
    draw_rect(Rect2(-6.0, -31.0 + bob, 12.0, 11.0), Color("56645a"))
    draw_rect(Rect2(-5.0, -30.0 + bob, 10.0, 9.0), Color("8f6d43"))
    draw_rect(Rect2(-6.0, -21.0 + bob, 12.0, 2.0), Color("171f20"))
    draw_rect(Rect2(-5.0, -21.0 + bob, 10.0, 1.0), Color("d0a15a"))
    draw_rect(Rect2(-8.0, -28.0 + bob, 2.0, 6.0), Color("343d39"))
    draw_rect(Rect2(6.0, -28.0 + bob, 2.0, 6.0), Color("343d39"))
    # Round glass is rendered as stepped pixel rows, with a clean reflection and bolted rim.
    draw_rect(Rect2(visor_x - 1.0, -29.0 + bob, 8.0, 9.0), Color("171f20"))
    draw_rect(Rect2(visor_x, -28.0 + bob, 6.0, 7.0), Color("d0a15a"))
    draw_rect(Rect2(visor_x + 1.0, -27.0 + bob, 4.0, 5.0), Color("244d50"))
    draw_rect(Rect2(visor_x + 1.0, -26.0 + bob, 2.0, 1.0), Color("47706b"))
    draw_rect(Rect2(visor_x + 1.0, -25.0 + bob, 1.0, 2.0), Color("8ac4b4"))
    draw_rect(Rect2(visor_x + 4.0, -26.0 + bob, 1.0, 2.0), Color("8ac4b4"))
    draw_rect(Rect2(-5.0, -29.0 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(4.0, -29.0 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(-5.0, -22.0 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(4.0, -22.0 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(-3.0, -33.0 + bob, 6.0, 1.0), Color("8f6d43"))
    draw_rect(Rect2(-4.0, -16.5 + bob, 1.0, 1.0), Color("d3ad63"))
    draw_rect(Rect2(3.0, -16.5 + bob, 1.0, 1.0), Color("d3ad63"))
    # Flaked enamel, tool scratches and offset highlights break up the smooth helmet shell.
    draw_rect(Rect2(-3.5, -31.0 + bob, 1.5, 0.75), Color("b75038"))
    draw_rect(Rect2(-3.0, -30.5 + bob, 1.0, 0.5), Color("5b5544"))
    draw_rect(Rect2(4.5, -27.0 + bob, 0.75, 2.0), Color("d0a15a"))
    draw_rect(Rect2(-4.5, -23.0 + bob, 0.75, 1.5), Color("4a5c53"))
    draw_rect(Rect2(5.0, -30.0 + bob, 0.75, 1.0), Color("b75038"))
    for port_bolt in [-1.0, 6.0]:
        draw_rect(Rect2(visor_x + port_bolt, -28.0 + bob, 0.75, 0.75), Color("f0cf83"))
    var lamp_mount := Vector2(0.0, -34.0 + bob) if underwater else Vector2(4.0 * facing, -29.0 + bob)
    draw_rect(Rect2(lamp_mount + Vector2(-2.0, -1.0), Vector2(4.0, 3.0)), Color("171f20"))
    draw_rect(Rect2(lamp_mount + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color("8f6d43"))
    draw_rect(Rect2(lamp_mount + Vector2(-0.5, -0.5), Vector2(1.0, 1.0)), Color("ffe6a0"))
    # Underwater strokes are drawn as articulated pixel limbs so the diver visibly reaches, pulls and kicks.
    var wrist_lamp_position := Vector2(5.0 * facing - 1.0 + right_arm_x, -9.0 + bob + right_arm_y)
    if swimming:
        wrist_lamp_position = _draw_swim_limb_set(bob, swim_wave)
    else:
        _draw_arm(Vector2(-5.5, -13.0 + bob), Vector2(-7.0 + left_arm_x, -5.0 + bob + left_arm_y), Color("343d39"), Color("202725"))
        _draw_arm(Vector2(5.5, -13.0 + bob), Vector2(6.0 + right_arm_x, -5.5 + bob + right_arm_y), Color("424943"), Color("202725"))
        _draw_ground_leg(Vector2(-2.0 + left_leg_x, bob - left_lift), false)
        _draw_ground_leg(Vector2(2.0 + right_leg_x, bob - right_lift), true)
    # Wrist lamp and tether clip catch a small amount of warm light.
    draw_rect(Rect2(wrist_lamp_position - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color("303a35"))
    draw_rect(Rect2(wrist_lamp_position - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), Color("e3a859"))
    draw_rect(Rect2(-2.0, -5.5 + bob, 4.0, 1.0), Color("6d7465"))
    draw_rect(Rect2(-1.0, -5.5 + bob, 2.0, 1.0), Color("d3ad63"))
    if listening:
        var alpha := 0.28 + (sin(breath * 8.0) + 1.0) * 0.12
        draw_arc(Vector2(0, -11), 13.0, -1.25, 1.25, 24, Color(0.45, 0.86, 0.77, alpha), 0.5, true)
        draw_arc(Vector2(0, -11), 19.0, -1.1, 1.1, 28, Color(0.45, 0.86, 0.77, alpha * 0.65), 0.5, true)
        # A tiny sonar needle rises from the helmet and turns toward the active signal.
        # Convert the world-space bearing into this diver's rotated drawing space.
        var local_bearing := listen_direction.rotated(-body_angle).normalized()
        var needle_origin := Vector2(0.0, -36.0 + bob)
        var needle_tip := needle_origin + local_bearing * 13.0
        var needle_color := Color(0.45, 0.94, 0.83, 0.72 + sin(breath * 9.0) * 0.16)
        draw_line(needle_origin, needle_tip, Color(0.04, 0.12, 0.13, 0.92), 2.5, false)
        draw_line(needle_origin, needle_tip, needle_color, 1.0, false)
        var needle_side := Vector2(-local_bearing.y, local_bearing.x) * 2.0
        draw_line(needle_tip, needle_tip - local_bearing * 3.0 + needle_side, needle_color, 1.0, false)
        draw_line(needle_tip, needle_tip - local_bearing * 3.0 - needle_side, needle_color, 1.0, false)
    if swimming:
        var bubble_x := tank_x + 2.0 + sin(gait_phase * 1.4) * 1.2
        var bubble_y := -22.0 - fposmod(breath * 8.0, 4.0)
        draw_rect(Rect2(bubble_x, bubble_y, 1.0, 1.0), Color(0.68, 0.86, 0.80, 0.68))
        draw_rect(Rect2(bubble_x + 2.0, bubble_y - 3.0, 0.75, 0.75), Color(0.68, 0.86, 0.80, 0.42))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_helmet_beam(origin: Vector2, direction: Vector2) -> void:
    var forward := direction.normalized()
    var side := Vector2(-forward.y, forward.x)
    var flicker := 0.88 + (sin(breath * 7.1) + sin(breath * 3.7) * 0.4) * 0.035
    for layer in range(3):
        var length := 142.0 - float(layer) * 31.0
        var half_width := 38.0 - float(layer) * 11.0
        var start := origin + forward * (2.0 + float(layer) * 3.0)
        var end := origin + forward * length
        var tint := Color(0.42, 0.62, 0.57, (0.035 + float(layer) * 0.012) * flicker)
        if layer == 2:
            tint = Color(0.83, 0.79, 0.58, 0.08 * flicker)
        draw_colored_polygon(PackedVector2Array([start - side * 2.0, start + side * 2.0, end + side * half_width, end - side * half_width]), tint)
    # A few broken bars keep the beam readable against pixel scenery without looking like a smooth UI cone.
    for band in range(9):
        var distance := 24.0 + float(band) * 12.0
        var half_width := 5.0 + float(band) * 2.3
        var center := origin + forward * distance
        var sparkle := 0.05 + float((band * 3) % 4) * 0.012
        draw_line(center - side * half_width, center + side * half_width, Color(0.89, 0.84, 0.63, sparkle * flicker), 1.0, false)

func _draw_swim_limb_set(bob: float, stroke: float) -> Vector2:
    var left_shoulder := Vector2(-5.5, -13.0 + bob)
    var right_shoulder := Vector2(5.5, -13.0 + bob)
    var left_elbow := left_shoulder + Vector2(-3.5, 1.0 - stroke * 2.0)
    var right_elbow := right_shoulder + Vector2(3.5, 1.0 + stroke * 2.0)
    var left_hand := left_shoulder + Vector2(-4.5 - absf(stroke), 6.0 - stroke * 8.0)
    var right_hand := right_shoulder + Vector2(4.5 + absf(stroke), 6.0 + stroke * 8.0)
    _draw_jointed_arm(left_shoulder, left_elbow, left_hand, Color("343d39"), Color("626d5b"))
    _draw_jointed_arm(right_shoulder, right_elbow, right_hand, Color("424943"), Color("777c68"))
    var left_kick := sin(gait_phase + 0.35)
    var right_kick := sin(gait_phase + PI + 0.35)
    _draw_swim_leg(Vector2(-2.0, -1.0 + bob), left_kick, false)
    _draw_swim_leg(Vector2(2.0, -1.0 + bob), right_kick, true)
    return right_hand + Vector2(0.0, 1.0)

func _draw_jointed_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, suit_color: Color, highlight: Color) -> void:
    draw_line(shoulder, elbow, Color("171f20"), 6.0, false)
    draw_line(elbow, hand, Color("171f20"), 5.0, false)
    draw_line(shoulder, elbow, suit_color, 4.0, false)
    draw_line(elbow, hand, suit_color, 3.0, false)
    draw_line(shoulder + Vector2(-0.6, 0.0), elbow + Vector2(-0.6, 0.0), highlight, 1.0, false)
    draw_rect(Rect2(elbow - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color("5b5544"))
    draw_rect(Rect2(hand - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color("202725"))
    draw_rect(Rect2(hand - Vector2(0.5, 1.0), Vector2(1.0, 1.0)), Color("8f6d43"))

func _draw_swim_leg(hip: Vector2, kick: float, far_leg: bool) -> void:
    var side := -1.0 if hip.x < 0.0 else 1.0
    var knee := hip + Vector2(side * (1.3 + absf(kick)), 3.4 + maxf(kick, 0.0) * 2.0)
    var boot := knee + Vector2(side * (1.1 - kick * 1.7), 4.0 + maxf(-kick, 0.0) * 2.2)
    var suit := Color("343d39") if far_leg else Color("424943")
    draw_line(hip, knee, Color("171f20"), 6.0, false)
    draw_line(knee, boot, Color("171f20"), 5.0, false)
    draw_line(hip, knee, suit, 4.0, false)
    draw_line(knee, boot, suit, 3.0, false)
    draw_rect(Rect2(knee - Vector2(1.5, 1.0), Vector2(3.0, 2.0)), Color("56645a"))
    var toe := boot + Vector2(side * 1.1, 2.0)
    draw_line(boot, toe, Color("171f20"), 5.0, false)
    draw_line(boot, toe, Color("8f6d43"), 2.0, false)
    draw_rect(Rect2(toe - Vector2(1.0, 0.5), Vector2(2.0, 1.0)), Color("d0a15a"))

func _draw_arm(shoulder: Vector2, hand: Vector2, suit_color: Color, glove_color: Color) -> void:
    var elbow := shoulder.lerp(hand, 0.62) + Vector2(signf(hand.x - shoulder.x) * 0.8, 1.0)
    _draw_jointed_arm(shoulder, elbow, hand, suit_color, Color("56645a"))
    draw_rect(Rect2(hand - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), glove_color)

func _draw_ground_leg(hip: Vector2, right_side: bool) -> void:
    var sign_x := 1.0 if right_side else -1.0
    var knee := hip + Vector2(sign_x * 0.4, 3.0)
    var boot := knee + Vector2(sign_x * 0.2, 3.0)
    draw_line(hip, knee, Color("171f20"), 5.0, false)
    draw_line(hip, knee, Color("424943"), 3.0, false)
    draw_rect(Rect2(knee - Vector2(1.5, 1.0), Vector2(3.0, 1.0)), Color("56645a"))
    draw_line(knee, boot, Color("171f20"), 5.0, false)
    draw_line(knee, boot, Color("343d39"), 3.0, false)
    draw_rect(Rect2(boot.x - 2.2, boot.y, 4.5, 2.0), Color("171f20"))
    draw_rect(Rect2(boot.x - 1.5, boot.y, 2.8, 0.75), Color("a67945"))
    for tread in range(3):
        draw_rect(Rect2(boot.x - 1.8 + float(tread) * 1.3, boot.y + 1.5, 0.75, 0.5), Color("6d7465"))
