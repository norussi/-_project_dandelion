// 연기 속에서 번져 보이는 빛 (유도등 후광, 불꽃).
// 화면을 항상 바라보는 사각형에 둥근 빛을 그린다. 일반 안개(fog) 대신
// 자체적으로 거리에 따라 옅어지게 해서, 물체보다 훨씬 멀리서도 희미하게 보인다.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform float intensity = 1.0;
uniform float see_falloff = 0.12;   // 클수록 가까이서만 보임 (연기 속 빛 감쇠)
uniform float softness = 3.0;       // 클수록 가운데에 몰린 빛
uniform bool use_vertex_color = false;  // 파티클 색 사용 (불꽃)

varying float vis;

void vertex() {
	// 빌보드: 항상 카메라를 향하게
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vis = exp(-length(vp.xyz) * see_falloff);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = exp(-r * r * softness) * clamp(1.0 - r, 0.0, 1.0);
	vec3 col = glow_color.rgb;
	float va = 1.0;
	if (use_vertex_color) {
		col *= COLOR.rgb;
		va = COLOR.a;
	}
	ALBEDO = col * intensity * a * vis * va;
	ALPHA = a * vis * va;
}
