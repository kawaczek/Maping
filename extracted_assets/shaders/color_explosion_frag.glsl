#version 100
// Port of ColorExplosion.metal (ce_fragment) — kishimisu color explosion with
// canonical kaleidoscope fold and transparent background.
// Time model matches iOS provider: u_time = integrated dt*speed (flow),
// u_timePalette = integrated dt*paletteSpeed (palette). Both accumulated on CPU.
precision highp float;
varying vec2 vUV;

uniform float u_time;         // timeFlow (speed-integrated)
uniform float u_timePalette;  // timePalette (paletteSpeed-integrated)
uniform vec2 u_resolution;

uniform float u_zoom;          // 0.25..3
uniform float u_rotation;      // 0..1 turns (not exposed on iOS UI; fixed 0)
uniform float u_reps;          // 2..64
uniform float u_kaleidoSmooth; // 0..0.35
uniform float u_layers;        // 1..8
uniform float u_frequency;     // 2..14
uniform float u_intensity;     // 0..3
uniform float u_glow;          // 0..3
uniform float u_contrast;      // 0..3
uniform float u_darkness;      // 0..1 (not exposed on iOS UI; fixed 0)

const float CE_PI  = 3.141592654;
const float CE_TAU = 6.283185308;

float ce_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 ce_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

vec2 ce_rot(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2 ce_fract2(vec2 v) { return v - floor(v); }

// GLSL-style mod (negative-safe) — identical to Metal ce_mod
float ce_mod(float x, float y) {
    return x - y * floor(x / y);
}

vec3 ce_palette(float t) {
    return (1.0 + cos(vec3(0.0, 1.0, 2.0) + CE_TAU * t)) * 0.5;
}

// IQ smooth min -> used for pabs
float ce_pmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
float ce_pmax(float a, float b, float k) {
    return -ce_pmin(-a, -b, k);
}
float ce_pabs(float a, float k) {
    return ce_pmax(a, -a, k);
}

vec3 ce_aces_approx(vec3 v) {
    v = max(v, vec3(0.0));
    v *= 0.6;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

vec2 ce_toPolar(vec2 p) {
    return vec2(length(p), atan(p.y, p.x)); // [-pi, pi]
}
vec2 ce_toRect(vec2 p) {
    return p.x * vec2(cos(p.y), sin(p.y));
}

// ------------------------------------------------------------
// TRUE symmetry kaleido fold: canonical wedge mapping
// ------------------------------------------------------------
vec2 ce_kaleidoCanonical(vec2 p, float sm, float reps) {
    reps = max(2.0, reps);

    vec2 pol = ce_toPolar(p);
    float r = pol.x;
    float a = pol.y;

    // Normalize to [0, TAU)
    a = (a < 0.0) ? (a + CE_TAU) : a;

    // Wedge size and half wedge
    float wedge = CE_TAU / reps;
    float halfW = 0.5 * wedge;

    // Reduce angle into [0, wedge)
    a = ce_mod(a, wedge);

    // Mirror into [0, halfW] around wedge center (canonical orientation)
    a = abs(a - halfW);
    a = halfW - a;

    // Optional smoothing near the wedge boundary
    float seg = CE_PI / reps;
    float sa = seg - ce_pabs(seg - a, sm);
    a = clamp(sa, 0.0, seg);

    pol.x = r;
    pol.y = a;
    return ce_toRect(pol);
}

// Kishimisu-like accumulation (expects p already folded!)
vec3 ce_kishimisu(vec2 p, float t, float layers, float freq, float tPal) {
    vec2 p0 = p;
    vec3 col = vec3(0.0);

    int L = int(clamp(layers, 1.0, 8.0));

    vec2 p1 = p;
    for (int i = 0; i < 8; i++) {
        if (i >= L) break;

        p1 = ce_fract2(p1 * 2.0 + 0.0125 * t) - 0.5;

        float d = length(p1) * exp(-length(p0));

        float tt = length(p0) + (float(i) * 0.4) + (tPal * 0.2);
        vec3 cc = ce_palette(tt);

        d = sin(d * freq + t) / 8.0;
        d = abs(d);
        d = max(d, 0.005);

        float inv = (0.0125 / d);
        float w = inv * inv;

        col += cc * w;
    }

    return col;
}

vec3 ce_applyContrast(vec3 c, float k) {
    return (c - 0.5) * k + 0.5;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));

    vec2 q = vUV;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= (res.x / res.y);

    float t    = u_time;
    float tPal = u_timePalette;

    float rot = (u_rotation * CE_TAU) + 0.025 * t;
    p = ce_rot(p, rot);

    float z = max(0.05, u_zoom);
    p /= z;

    // --- Canonical kaleido fold (perfect wedge symmetry) ---
    vec2 kp = p;
    float rep = max(2.0, u_reps);
    float sm = clamp(u_kaleidoSmooth, 0.0, 0.35);
    kp = ce_kaleidoCanonical(kp, sm, rep);

    // Symmetry-safe motion: radial breathe only (no translation)
    float breathe = 1.0 + 0.12 * sin(0.21 * t);
    kp *= breathe;

    float freq = max(2.0, u_frequency);
    vec3 col = ce_kishimisu(kp, t, u_layers, freq, tPal);

    col = clamp(col, 0.0, 4.0);

    // radial center glow (symmetry-safe)
    float rr = length(p);
    vec3 gcol = ce_palette(0.125 * tPal);
    col += (u_glow * 0.08) * (gcol * gcol) / max(rr * rr + 0.02, 0.02);

    col *= max(0.0, u_intensity);

    col = ce_aces_approx(col);
    col = max(col, vec3(0.0));
    col = sqrt(col);

    float dk = ce_sat(u_darkness);
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3(luma), dk * 0.55);
    col *= (1.0 - dk * 0.65);

    col = ce_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = ce_sat3(col);

    // --- Transparent background: make "black" go CLEAR more aggressively ---
    float a = max(max(col.r, col.g), col.b);
    a = smoothstep(0.08, 0.45, a);
    a = pow(a, 1.6);

    // Kill ultra-faint speckle
    if (a < 0.002) {
        gl_FragColor = vec4(0.0);
        return;
    }

    gl_FragColor = vec4(col, a);
}
