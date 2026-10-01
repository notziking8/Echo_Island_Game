shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 leaf_color : source_color = vec4(0.49, 0.85, 0.34, 1.0);
uniform bool instance_color = false;
varying float height_wash;
void vertex() {
	height_wash = VERTEX.y;
	VERTEX.x += sin(TIME * 1.1 + MODEL_MATRIX[3].x + VERTEX.y * 2.0) * 0.035 * max(VERTEX.y, 0.0);
}
void fragment() {
	vec3 tint = instance_color ? pow(COLOR.rgb, vec3(2.2)) : vec3(1.0);
	ALBEDO = leaf_color.rgb * tint * (0.76 + smoothstep(-0.4, 0.5, height_wash) * 0.13);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.9;
}
