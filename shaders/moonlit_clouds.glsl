precision mediump float;
varying vec2 vUV;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_zoom;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + vec2(20.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed * 0.15;

    // Pozycja księżyca
    vec2 moonPos = vec2(0.35, 0.25);
    float moonDist = length(uv - moonPos);

    // Kula księżyca z kraterami
    float moonMask = smoothstep(0.28, 0.27, moonDist);
    float moonTexture = 0.85 + 0.15 * noise((uv - moonPos) * 15.0);
    vec3 moonCol = vec3(0.95, 0.96, 1.0) * moonTexture * moonMask;

    // Blask księżyca (Halo / Corona)
    float moonGlow = exp(-moonDist * 2.5) * 0.85;
    vec3 haloCol = vec3(0.4, 0.6, 0.8) * moonGlow;

    // Przepływające fotorealistyczne chmury nocne
    vec2 cloudUV = uv * 1.5 + vec2(t * 0.4, t * 0.05);
    float c1 = fbm(cloudUV);
    float c2 = fbm(cloudUV * 2.0 + vec2(15.0, 8.0));
    float cloudDensity = smoothstep(0.25, 0.75, c1 + c2 * 0.4);

    // Oświetlenie krawędzi chmur przez księżyc (silver lining)
    float edgeLight = pow(clamp(1.0 - moonDist * 1.2, 0.0, 1.0), 2.0) * cloudDensity * 1.3;

    // Nocne niebo
    vec3 skyBase = mix(vec3(0.01, 0.02, 0.05), vec3(0.04, 0.06, 0.12), uv.y * 0.5 + 0.5);

    // Gwiazdy widoczne w przerwach między chmurami
    float starGrid = hash(floor(uv * 40.0));
    float star = step(0.985, starGrid) * (1.0 - cloudDensity) * (1.0 - moonMask);
    vec3 starCol = vec3(0.8, 0.9, 1.0) * star * (0.6 + 0.4 * sin(t * 10.0 + starGrid * 100.0));

    // Kompozycja
    vec3 col = skyBase + haloCol + starCol;
    col = mix(col, moonCol, moonMask);
    // Chmury zasłaniające niebo i księżyc
    vec3 cloudCol = mix(vec3(0.02, 0.03, 0.06), vec3(0.3, 0.4, 0.55), edgeLight);
    col = mix(col, cloudCol, cloudDensity * 0.85);

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
