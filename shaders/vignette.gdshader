shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.5) = 0.65;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5)) * 1.25;
	float vig = smoothstep(0.30, 1.0, d) * strength;
	// subtle teal shadow at the edges keeps the diorama cozy.
	COLOR = vec4(0.02, 0.075, 0.08, vig);
}
