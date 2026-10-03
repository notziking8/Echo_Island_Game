shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform vec4 water_color : source_color = vec4(0.20, 0.56, 0.64, 1.0);
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_point.x * 0.55 + TIME * 0.7) * cos(world_point.z * 0.4 + TIME * 0.45) * 0.045;
}
void fragment() {
	float wave = sin(world_point.x * 0.8 + world_point.z * 0.45 + sin(world_point.z * 0.6 - TIME * 0.4) * 1.4 + TIME * 0.65);
	float ribbon = smoothstep(0.94, 0.99, wave) * (0.5 + 0.5 * sin(world_point.z * 1.8 + world_point.x * 0.3));
	ALBEDO = mix(water_color.rgb, vec3(0.45, 0.74, 0.72), ribbon * 0.24);
	ROUGHNESS = 1.0;
}
