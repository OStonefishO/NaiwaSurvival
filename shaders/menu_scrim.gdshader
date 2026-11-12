shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float left = 1.0 - smoothstep(0.0, 0.72, uv.x);
	left = pow(left, 0.85);
	float bottom = smoothstep(0.62, 1.0, uv.y);
	float top = smoothstep(0.0, 0.25, 1.0 - uv.y);
	vec3 col = vec3(0.012, 0.060, 0.070);
	float a = left * 0.94 + bottom * 0.42 + top * 0.10;
	COLOR = vec4(col, clamp(a, 0.0, 0.96));
}
