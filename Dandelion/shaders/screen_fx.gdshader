// 화면 효과: 연기로 눈이 따가워 흐려짐, 숨이 막혀 시야가 좁아짐(비네트),
// 불 근처의 붉은 열기, 눈을 감고 뜨는 연출(검은 화면).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;        // 0 ~ 1
uniform float vignette = 0.3;    // 0 ~ 1
uniform vec4 tint : source_color = vec4(1.0, 0.35, 0.05, 0.0);   // a = 세기
uniform float fade = 0.0;        // 1 = 완전히 검정
uniform float lid = 0.0;         // 눈꺼풀 (0 = 뜸, 1 = 감음)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	if (blur > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE * (1.0 + blur * 6.0);
		vec3 acc = col;
		acc += texture(screen_tex, uv + vec2(px.x, 0.0)).rgb;
		acc += texture(screen_tex, uv - vec2(px.x, 0.0)).rgb;
		acc += texture(screen_tex, uv + vec2(0.0, px.y)).rgb;
		acc += texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
		acc += texture(screen_tex, uv + px).rgb;
		acc += texture(screen_tex, uv - px).rgb;
		acc += texture(screen_tex, uv + vec2(px.x, -px.y)).rgb;
		acc += texture(screen_tex, uv + vec2(-px.x, px.y)).rgb;
		col = mix(col, acc / 9.0, clamp(blur * 1.5, 0.0, 1.0));
	}
	// 비네트
	vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.35, 1.05 - vignette * 0.55, length(d));
	col *= 1.0 - v * (0.35 + vignette * 0.65);
	// 열기
	col = mix(col, col * 0.6 + tint.rgb * 0.5, tint.a);
	// 눈꺼풀 (위아래에서 닫힘)
	float edge = abs(uv.y - 0.5) * 2.0;
	float closed = smoothstep(1.0 - lid * 1.05, 1.0 - lid * 1.05 + 0.08, edge);
	col *= 1.0 - closed;
	col *= 1.0 - fade;
	COLOR = vec4(col, 1.0);
}
