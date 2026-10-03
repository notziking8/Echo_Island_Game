shader_type spatial;
render_mode specular_disabled;
uniform bool worn_route = false;
varying vec3 world_point;
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wash(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1,0)), f.x), mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), f.x), f.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float patches = wash(world_point.xz * 0.22) * 0.7 + wash(world_point.xz * 0.61) * 0.3;
	// Explicit linear pigments keep the Compatibility lighting from turning
	// these broad washes into the old luminous lime-green surface.
	vec3 grass = mix(vec3(0.17,0.30,0.085), vec3(0.31,0.46,0.15), smoothstep(0.15,0.88,patches));
	float center = sin((17.0-world_point.z) * 0.27) * 0.7;
	float distance_to_path = abs(world_point.x - center);
	float dirt = (1.0-smoothstep(0.65,1.75 + (patches-0.5)*0.6,distance_to_path)) * (worn_route ? 0.85 : 0.0);
	ALBEDO = mix(grass, vec3(0.51,0.43,0.25), dirt);
	ROUGHNESS = 1.0;
}
