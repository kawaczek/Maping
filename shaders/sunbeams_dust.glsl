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

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed;

    // Przesunięcie promieni słonecznych od góry z lekkim kątem
    vec2 origin = vec2(0.2, 1.2);
    vec2 dir = uv - origin;
    float dist = length(dir);
    float angle = atan(dir.y, dir.x);

    // Kątowe snopy światła słonecznego
    float rays1 = sin(angle * 12.0 + t * 0.4) * 0.5 + 0.5;
    float rays2 = cos(angle * 22.0 - t * 0.25) * 0.5 + 0.5;
    float rays = pow(rays1 * rays2, 1.5);

    // Pyłki kurzu / cząstki unoszące się w powietrzu w snopach światła
    float dust = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 dUV = uv * (4.0 + fi * 2.0) + vec2(sin(t * 0.5 + fi) * 0.2, -t * 0.3 - fi * 0.5);
        float dGrid = hash(floor(dUV));
        float p = step(0.96, dGrid);
        dust += p * (0.5 + 0.5 * sin(t * 3.0 + dGrid * 50.0)) * (0.8 / (dist + 0.5));
    }

    // Tło: ciepły, głęboki półmrok pokoju
    vec3 ambientDark = mix(vec3(0.02, 0.015, 0.01), vec3(0.06, 0.05, 0.03), uv.y * 0.5 + 0.5);

    // Złote ciepłe światło słoneczne (God rays)
    vec3 sunLight = vec3(1.0, 0.85, 0.55);
    float attenuation = exp(-dist * 0.9);

    vec3 col = ambientDark + sunLight * (rays * attenuation * 0.95 + dust * 1.8 * rays);

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
