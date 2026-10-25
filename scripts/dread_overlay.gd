extends ColorRect

var _material: ShaderMaterial
var _phase := 0.0

func _ready() -> void:
	name = "AbyssalDreadOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
	uniform float darkness : hint_range(0.0, 0.4) = 0.16;
	uniform float stress : hint_range(0.0, 1.0) = 0.0;
	uniform float phase = 0.0;
	float hash21(vec2 p) {
		p = fract(p * vec2(123.34, 456.21));
		p += dot(p, p + 45.32);
		return fract(p.x * p.y);
	}
	void fragment() {
		vec2 uv = SCREEN_UV;
		float current_warp = sin(uv.y * 118.0 + phase * 2.1) * (0.00025 + stress * 0.0011);
		uv.x += current_warp;
		vec4 source = texture(screen_texture, uv);
		float radius = length((SCREEN_UV - vec2(0.5)) * vec2(0.9, 1.38));
		float vignette = smoothstep(0.18, 0.79, radius) * (0.20 + stress * 0.14);
		float grain = (hash21(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + floor(phase * 17.0)) - 0.5) * (0.012 + stress * 0.023);
		float scan = sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 3.14159 + phase * 2.0) * (0.003 + stress * 0.006);
		float blackout = 0.0;
		if (stress > 0.65) {
			float pulse = fract(phase * 0.31);
			blackout = (1.0 - smoothstep(0.0, 0.035, abs(pulse - 0.17))) * stress * 0.08;
		}
		vec3 cold_tint = vec3(0.76, 0.88, 0.86);
		vec3 color = source.rgb * cold_tint * (1.0 - darkness - vignette - blackout) + vec3(grain + scan * 0.45, grain + scan * 0.9, grain + scan);
		COLOR = vec4(max(color, vec3(0.0)), 1.0);
	}
	"""
	_material.shader = shader
	material = _material
	_material.set_shader_parameter("darkness", 0.16)
	_material.set_shader_parameter("stress", 0.0)

func _process(delta: float) -> void:
	_phase += delta
	if _material:
		_material.set_shader_parameter("phase", _phase)

func set_dread(darkness: float, stress: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("darkness", clampf(darkness, 0.0, 0.4))
	_material.set_shader_parameter("stress", clampf(stress, 0.0, 1.0))
