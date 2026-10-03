shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 pigment : source_color = vec4(0.8, 0.7, 0.5, 1.0);
uniform bool wood = false;
varying vec3 local_point;
varying float upward;
void vertex() { local_point = VERTEX; upward = NORMAL.y; }
void fragment() {
	float wash = sin(local_point.x * 2.1 + sin(local_point.z * 1.7) * 1.3 + local_point.y * 0.7) * 0.55 + sin(local_point.z * 3.1 + local_point.y * 1.9) * 0.3;
	if (wood) { wash = sin(local_point.x * 13.0 + sin(local_point.y * 0.9) + local_point.z * 8.0) * 0.45; }
	float top = smoothstep(-0.4, 0.8, upward);
	ALBEDO = pigment.rgb * (0.78 + wash * 0.095 + top * 0.07) * COLOR.rgb;
	ROUGHNESS = 1.0;
}
