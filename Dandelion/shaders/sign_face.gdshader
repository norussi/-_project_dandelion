// 유도등 표시면: 스스로 빛나는 판. 연기(안개)보다 덜 가려지도록 거리 감쇠를 직접 계산한다.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform sampler2D sign_texture : source_color, filter_linear_mipmap;
uniform vec3 smoke_color : source_color = vec3(0.12, 0.11, 0.10);
uniform float brightness = 1.4;
uniform float see_falloff = 0.09;

varying float vis;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vis = exp(-length(vp.xyz) * see_falloff);
}

void fragment() {
	vec3 c = texture(sign_texture, UV).rgb * brightness;
	ALBEDO = mix(smoke_color, c, vis);
}
