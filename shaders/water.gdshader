shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 shallow_color : source_color = vec3(0.29, 0.79, 0.71);
uniform vec3 deep_color : source_color = vec3(0.035, 0.26, 0.35);
uniform vec3 foam_color : source_color = vec3(1.0, 0.97, 0.86);
uniform float island_radius = 37.2;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 0.35 + TIME * 0.9) * 0.045;
	wave += sin(world_pos.z * 0.47 - TIME * 0.7) * 0.035;
	VERTEX.y += wave;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = length(p);
	float r = dist;
	float angle = atan(p.y, p.x);

	// A small wobble in the shoreline break so the foam does not read as a perfect circle.
	float shore_wobble = sin(angle * 5.0 + 1.7) * 0.8 + sin(angle * 11.0 - 0.4) * 0.35;
	float ring = 37.3 + shore_wobble;
	float foam = smoothstep(1.35, 0.0, abs(r - ring));
	foam *= 0.55 + 0.45 * sin(TIME * 0.8 + angle * 9.0 + r * 0.25);
	foam += smoothstep(0.9, 0.0, abs(r - ring - 1.1)) * 0.25;

	// Turquoise shallows fade into inky-blue water.
	float deep_t = smoothstep(36.5, 72.0, r);
	vec3 col = mix(shallow_color, deep_color, deep_t);
	col = mix(col, shallow_color * 1.10, 0.12 + 0.06 * sin(angle * 3.0 + TIME * 0.3));

	// Soft bands of moving light, kept subtle so the surface reads as water
	// rather than a striped plane.
	float broad = sin(p.x * 0.09 + p.y * 0.17 + TIME * 0.35) * 0.5 + 0.5;
	col += vec3(0.045, 0.065, 0.045) * broad * smoothstep(38.0, 62.0, r);

	float glints = sin(p.x * 1.65 - p.y * 0.85 + TIME * 2.1);
	glints = pow(max(glints, 0.0), 36.0) * smoothstep(38.0, 46.0, r);
	col += glints * vec3(0.28, 0.24, 0.12);

	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * 0.78);
	ALBEDO = col;
	ROUGHNESS = 0.35;
	SPECULAR = 0.25;
	ALPHA = 0.96;
}
