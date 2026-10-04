#version 100
// Amoeba Walk — ported from AmoebaWalk.metal (amoeba_walk_frag).
// CC0 "2D Amoebas" shader: smooth-min blob field over a dot grid, HSV blob color,
// transparent background with controllable edge softness.
precision highp float;

varying vec2 vUV;

uniform float u_time;
uniform vec2  u_resolution;

// Color
uniform float u_hue;            // 0..1 blob hue
uniform float u_saturation;     // 0..2
uniform float u_value;          // 0..2

// Motion
uniform float u_speed;          // Kotlin bakes speed into u_time and sends 1.0 (matches iOS provider)
uniform float u_wobble;         // 0..2 secondary motion offset

// Structure
uniform float u_density;        // 0.05..1.0 (smaller = denser)
uniform float u_blobCount;      // 1..24
uniform float u_blobRadius;     // 0.02..0.35
uniform float u_smoothK;        // 0.01..1.0 (pmin smoothing)
uniform float u_dotRadius;      // 0..0.25

// Look
uniform float u_bgLevel;        // 0..1 background gray
uniform float u_vignette;       // 0..1 vignette strength
uniform float u_alphaSoftness;  // 0..1 alpha edge softness

const int AW_MAX_BLOBS = 24;
const float AW_SQRT_HALF = 0.7071067811865476;

float aw_circleSDF(vec2 p, float r) {
    return length(p) - r;
}

float aw_pmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Centered tile fold. The Metal source hand-implements GLSL floor-mod
// (m = m - size*floor(m/size)), which is exactly GLSL's mod() — always positive.
vec2 aw_mod2(vec2 p, vec2 size) {
    vec2 m = mod(p + size * 0.5, size);
    return m - size * 0.5;
}

vec3 aw_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float aw_df(vec2 p, float TIME) {
    // Grid of dots (density controls tiling size)
    float cell = max(u_density, 1e-4);
    vec2 dp = aw_mod2(p, vec2(cell));
    float ddots = length(dp) - max(u_dotRadius, 0.0);

    // Blobs
    float dblobs = 1e6;
    int bc = int(clamp(u_blobCount, 1.0, 24.0));
    float r = max(u_blobRadius, 1e-4);
    float k = max(u_smoothK, 1e-4);

    // Secondary wobble adds richness without rotation
    float t2 = TIME + u_wobble;

    for (int i = 0; i < AW_MAX_BLOBS; ++i) {
        if (i >= bc) { break; }
        float fi = float(i);
        vec2 c = 1.0 * vec2(
            sin(TIME + fi),
            sin(fi * fi + t2 * AW_SQRT_HALF)
        );
        float dd = aw_circleSDF(p - c, r);
        dblobs = aw_pmin(dblobs, dd, k);
    }

    float d = 1e6;
    d = min(d, ddots);

    // Smooth min between blobs and dots makes it amoeba-like
    d = aw_pmin(d, dblobs, k);
    return d;
}

vec3 aw_postProcess(vec3 col, vec2 q, float vignetteStrength) {
    col = pow(clamp(col, 0.0, 1.0), vec3(1.0 / 2.2));
    col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);          // contrast
    col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);               // saturation

    // Same vignette shape, strength mixes toward no-vignette
    float vig = 0.5 + 0.5 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);
    col *= mix(1.0, vig, clamp(vignetteStrength, 0.0, 1.0));
    return col;
}

void main() {
    vec2 RESOLUTION = max(u_resolution, vec2(1.0));

    // Provider supplies smooth phase in u_time; speed multiplies motion without jitter.
    float TIME = u_time * max(u_speed, 0.0);

    // Centered mapping (vUV plays the role of Metal's (ndc+1)*0.5)
    vec2 q = vUV;                    // 0..1
    vec2 p = vUV * 2.0 - 1.0;        // -1..1
    p.x *= RESOLUTION.x / RESOLUTION.y;

    float aa = 2.0 / RESOLUTION.y;

    const float z = 1.4;
    float d = aw_df(p / z, TIME) * z;

    // Background base (param)
    float bg = clamp(u_bgLevel, 0.0, 1.0);
    vec3 col = vec3(bg);

    // Amoeba mask
    float m = smoothstep(-aa, aa, -d);

    // Blob color (param)
    float h = fract(u_hue);
    float s = clamp(u_saturation, 0.0, 2.0);
    float v = clamp(u_value, 0.0, 2.0);
    vec3 blobCol = aw_hsv2rgb(vec3(h, s, v));

    col = mix(col, blobCol, m);

    col = aw_postProcess(col, q, u_vignette);

    // Transparent background with controllable edge softness
    float soft = clamp(u_alphaSoftness, 0.0, 1.0);
    float alpha = m;
    if (soft > 0.0) {
        // soften the edge by widening AA band
        float aa2 = mix(aa, aa * 6.0, soft);
        alpha = smoothstep(-aa2, aa2, -d);
    }
    alpha = clamp(alpha, 0.0, 1.0);

    if (alpha < 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        gl_FragColor = vec4(col, alpha);
    }
}
