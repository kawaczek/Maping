precision mediump float;
varying vec2 vUV;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_zoom;

// Perlin / Simplex szum w 2D dla turbulencji płomienia
float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fraktalny szum brownowski (fBm)
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p = rot * p * 2.0 + vec2(100.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed * 2.0;

    // Przesunięcie płomienia ku dołowi (płomienie unoszą się z dołu ekranu)
    vec2 p = uv;
    p.y += 0.6;

    // Unoszące się gorące powietrze (turbulencja pionowa)
    vec2 fireCoord = p * 1.8;
    fireCoord.y -= t * 1.8;
    fireCoord.x += sin(p.y * 3.0 + t) * 0.15;

    float n = fbm(fireCoord);
    float n2 = fbm(fireCoord * 2.0 + vec2(t * 0.5, 0.0));

    // Kształt stożka płomienia
    float shape = 1.0 - length(vec2(p.x * 2.2, p.y * 1.1));
    float flame = shape + (n + n2 * 0.5) * 0.8;
    flame = clamp(flame, 0.0, 1.0);

    // Fizyczna paleta czarnego ciała: czarny -> ciemna czerwień -> pomarańcz -> jaskrawy żółty -> biały rdzeń
    vec3 cBlack = vec3(0.01, 0.0, 0.0);
    vec3 cRed = vec3(0.8, 0.1, 0.0);
    vec3 cOrange = vec3(1.0, 0.5, 0.0);
    vec3 cYellow = vec3(1.0, 0.9, 0.2);
    vec3 cWhite = vec3(1.0, 1.0, 0.9);

    vec3 col = cBlack;
    if (flame > 0.1) col = mix(cBlack, cRed, smoothstep(0.1, 0.35, flame));
    if (flame > 0.35) col = mix(col, cOrange, smoothstep(0.35, 0.6, flame));
    if (flame > 0.6) col = mix(col, cYellow, smoothstep(0.6, 0.85, flame));
    if (flame > 0.85) col = mix(col, cWhite, smoothstep(0.85, 1.0, flame));

    // Drobne unoszące się iskry (embers)
    vec2 emberCoord = uv * vec2(8.0, 4.0) + vec2(sin(t + uv.y * 5.0) * 0.5, -t * 2.5);
    float embers = pow(hash2(floor(emberCoord)), 24.0) * smoothstep(0.8, -0.4, uv.y);
    col += vec3(1.0, 0.6, 0.1) * embers * 4.0;

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
