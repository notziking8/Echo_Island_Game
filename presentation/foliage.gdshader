shader_type spatial;
uniform vec4 leaf_color : source_color = vec4(0.49, 0.85, 0.34, 1.0);
void vertex() {
	VERTEX.x += sin(TIME * 1.1 + MODEL_MATRIX[3].x + VERTEX.y * 2.0) * 0.035;
}
void fragment() {
	ALBEDO = leaf_color.rgb;
	ROUGHNESS = 0.9;
}
