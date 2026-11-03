shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// 두 종류의 감각을 분리해서 그린다.
//  1) 촉각(touch) : 지팡이 끝이 실제로 닿은 지점 주변의 아주 좁은 범위 (수십 cm)
//  2) 청각 반향(echo) : 두드리는 소리가 '넓고 단단한 면'(벽, 가림막)에 반사되어 돌아오는 희미한 단서.
//     기둥·벤치·바닥 무늬 같은 작은 물체는 반향으로 거의 알 수 없으므로 반사율(COLOR.r)이 0이다.
//     주변 소음이 크면 echo_gain이 낮아져 반향이 들리지 않는다.

uniform float clock = 0.0;
uniform vec4 pulse0 = vec4(0.0, 0.0, 0.0, -100.0);
uniform vec4 pulse1 = vec4(0.0, 0.0, 0.0, -100.0);
uniform vec4 pulse2 = vec4(0.0, 0.0, 0.0, -100.0);
uniform vec4 pulse3 = vec4(0.0, 0.0, 0.0, -100.0);
uniform vec4 pulse4 = vec4(0.0, 0.0, 0.0, -100.0);
uniform vec4 pulse5 = vec4(0.0, 0.0, 0.0, -100.0);
// x = 촉각 반경(m), y = 반향 최대 거리(m)
uniform vec2 shape0 = vec2(0.0);
uniform vec2 shape1 = vec2(0.0);
uniform vec2 shape2 = vec2(0.0);
uniform vec2 shape3 = vec2(0.0);
uniform vec2 shape4 = vec2(0.0);
uniform vec2 shape5 = vec2(0.0);

uniform float echo_gain = 1.0;          // 0 = 소음에 완전히 묻힘
uniform float touch_persistence = 1.6;  // 손끝 감각의 잔상(기억)
uniform float echo_persistence = 0.7;   // 반향은 순간적이고 금방 사라진다
uniform float wave_speed = 9.0;         // 시각화용 전파 속도

varying vec3 world_position;
varying float reflectivity;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    reflectivity = COLOR.r;
}

float sense(vec4 pulse, vec2 shape) {
    float age = clock - pulse.w;
    if (age < 0.0) {
        return 0.0;
    }
    float d = distance(world_position, pulse.xyz);
    float result = 0.0;
    // 촉각: 닿은 곳만, 거의 즉시
    if (d < shape.x) {
        float since = age - d / 4.0;
        if (since >= 0.0) {
            float flash = exp(-since * 9.0);
            float memory = 0.75 * pow(max(0.0, 1.0 - since / touch_persistence), 1.4);
            float edge = 1.0 - smoothstep(shape.x * 0.45, shape.x, d);
            result = max(flash, memory) * edge;
        }
    }
    // 청각 반향: 넓은 면만, 희미하게
    float range = shape.y * echo_gain * reflectivity;
    if (range > 0.05 && d < range) {
        float since = age - d / wave_speed;
        if (since >= 0.0) {
            float flash = exp(-since * 7.0);
            float memory = 0.45 * max(0.0, 1.0 - since / echo_persistence);
            float edge = 1.0 - smoothstep(range * 0.35, range, d);
            result = max(result, 0.42 * max(flash, memory) * edge);
        }
    }
    return result;
}

void fragment() {
    float intensity = sense(pulse0, shape0);
    intensity = max(intensity, sense(pulse1, shape1));
    intensity = max(intensity, sense(pulse2, shape2));
    intensity = max(intensity, sense(pulse3, shape3));
    intensity = max(intensity, sense(pulse4, shape4));
    intensity = max(intensity, sense(pulse5, shape5));
    if (intensity < 0.008) {
        discard;
    }
    ALBEDO = vec3(1.0);
    ALPHA = intensity;
}
