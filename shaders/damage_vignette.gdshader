shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.68, 0.07, 0.035, 1.0);

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5, 0.52)) * 1.42;
	float edge = smoothstep(0.33, 1.0, d);
	float pulse = 0.82 + 0.18 * sin(TIME * 7.0);
	COLOR = vec4(tint.rgb, clamp(edge * intensity * pulse, 0.0, 1.0));
}
