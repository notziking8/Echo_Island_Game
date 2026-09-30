shader_type spatial;
render_mode cull_disabled;
uniform float reveal : hint_range(0, 1) = 1.0;
uniform vec4 base_color : source_color = vec4(0.45, 0.65, 0.3, 1.0);
varying vec3 local_vertex;
void vertex() { local_vertex = VERTEX; }
void fragment() {
	float noise_value = fract(sin(dot(floor(local_vertex * 34.0), vec3(12.9898,78.233,39.425))) * 43758.5453);
	if (noise_value > reveal) { discard; }
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.85;
	EMISSION = vec3(1.0, 0.67, 0.24) * smoothstep(reveal - 0.08, reveal, noise_value) * 0.8 * (1.0 - step(0.999, reveal));
}
