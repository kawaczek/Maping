#version 100
// Port of SoftBlob.metal (sbl_fragment) — 2D slice of a folded torus fractal
// colored by a distance-driven HSV palette.
// Time model matches the current iOS provider: u_time is CPU-accumulated
// (smoothed real dt) * speed, so the shader uses u_time directly.
precision highp float;
varying vec2 vUV;

uniform float u_time;       // speed-integrated, smoothed
uniform vec2 u_resolution;

uniform float u_zoom;       // 0.25..2
uniform float u_contrast;   // 1..3
uniform float u_darkness;   // 0..1 (not exposed on iOS UI; fixed 0)
uniform float u_hueShift;   // 0..1

uniform float u_fractalScale;    // 1.2..2.6
uniform float u_foldSmoothness;  // 0..0.12
uniform float u_foldOffset;      // 0..2

uniform float u_torusRadius;     // 0.05..2
uniform float u_torusTube;       // 0.01..1

uniform float u_paletteFreq;     // 0.25..4
uniform float u_paletteSat;      // 0..2
uniform float u_paletteVal;      // 0..2

uniform float u_gamma;           // 1.2..3
uniform float u_curve;           // 0..1

uniform float u_paletteSourceMix; // 0..1
uniform float u_shapeCdGain;      // 0.1..2
uniform float u_shapeCdBias;      // -2..2

const float SBL_PI  = 3.141592654;
const float SBL_TAU = 6.283185308;

float sbl_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sbl_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

// Metal: float2x2(float2(c, -s), float2(s, c)) — both column-major,
// so mat2(c, -s, s, c) builds the identical matrix.
mat2 sbl_rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float sbl_pcos(float x) { return 0.5 + 0.5 * cos(x); }

vec3 sbl_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 0.6666666667, 0.3333333333, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 sbl_postProcess(vec3 col) {
    float g = max(0.0001, u_gamma);
    col = clamp(col, 0.0, 1.0);
    col = pow(col, 1.0 / vec3(g));

    // "curve" control: blend between linear-ish and the film curve
    float c = sbl_sat(u_curve);
    vec3 curved = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);
    col = mix(col, curved, c);

    // original had a negative mix to grayscale (-0.4). Keep fixed to preserve vibe:
    col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);

    return col;
}

// SDF helpers (same as original)
float sbl_torus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sbl_pmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sbl_pmax(float a, float b, float k) {
    return -sbl_pmin(-a, -b, k);
}

vec3 sbl_pmin3(vec3 a, vec3 b, float k) {
    vec3 h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec3 sbl_pabs(vec3 a, float k) {
    return -sbl_pmin3(a, -a, k);
}

// df3: same structure; parameterized zf/rsm/off and shape sizes
float sbl_df3(vec3 p, float time, inout float g_cd) {
    float d = 1e6;

    float zf  = clamp(u_fractalScale, 1.2, 2.6);
    float rsm = clamp(u_foldSmoothness, 0.0, 0.12);
    float off = clamp(u_foldOffset, 0.0, 2.0);

    vec3 nz = normalize(vec3(1.0, 0.0, -1.0));
    vec3 ny = normalize(vec3(1.0, -1.0, 0.0));

    float z = 1.0;
    float a = 124.7 + time * SBL_TAU / 173.0;
    mat2 rxy = sbl_rot(a);
    mat2 ryz = sbl_rot(a * sqrt(0.5));

    vec3 cp = vec3(0.55, 0.5, 0.45);
    float cdPoint = 1e6;  // original behavior (distance to cp)
    float cdShape = 1e6;  // shape-based distance (torus)

    float torR = clamp(u_torusRadius, 0.05, 2.0);
    float torT = clamp(u_torusTube, 0.01, 1.0);

    for (int i = 0; i < 7; ++i) {
        cdPoint = min(cdPoint, length(p - cp));

        vec3 pp = p;
        float dd = sbl_torus(pp.zxy, vec2(torR, torT));

        cdShape = min(cdShape, abs(dd));
        dd /= z;

        z *= zf;
        p *= zf;

        // keep original rotations
        p.xy = rxy * p.xy;
        p.yz = ryz * p.yz;

        p = sbl_pabs(p, rsm);
        p -= nz * sbl_pmin(0.0, dot(p, nz), rsm) * 2.0;
        p -= ny * sbl_pmin(0.0, dot(p, ny), rsm) * 2.0;

        p -= vec3(off / zf, 0.0, 0.0);

        d = sbl_pmax(d, -(dd - 0.1 / z), 0.05 / z);
        d = min(d, dd);
    }

    float mixW = sbl_sat(u_paletteSourceMix);
    float shapeCd = cdShape * clamp(u_shapeCdGain, 0.1, 10.0) + clamp(u_shapeCdBias, -2.0, 2.0);
    g_cd = mix(cdPoint, shapeCd, mixW);
    return d;
}

float sbl_df2(vec2 p, float time, inout float g_cd) {
    vec3 p3 = vec3(p, mix(0.0, 1.0, sbl_pcos(SBL_TAU * time / 331.0)));
    p3.xz = sbl_rot(SBL_TAU * time / 127.0) * p3.xz;
    p3.yz = sbl_rot(SBL_TAU * time / 231.0) * p3.yz;

    float z = 0.25;
    p3 *= z;
    return sbl_df3(p3, time, g_cd) / z;
}

vec3 sbl_applyContrast(vec3 c, float contrast) {
    return (c - 0.5) * contrast + 0.5;
}

// original palette, but with frequency/sat/val controls
vec3 sbl_color_soft(float cd) {
    float freq = max(0.001, u_paletteFreq);

    float hue = fract(0.85 - 0.5 * SBL_PI * (cd * freq) + u_hueShift);
    float sat = clamp((0.85 * sbl_pcos(10.0 * cd)) * u_paletteSat, 0.0, 1.0);
    float vue = (1.0 - 1.0 * sbl_pcos(8.0 * cd)) * u_paletteVal;

    return sbl_hsv2rgb(vec3(hue, sat, vue));
}

void main() {
    float t = u_time;

    vec2 q = vUV;
    vec2 p = -1.0 + 2.0 * q;

    p.x *= (u_resolution.x / u_resolution.y);
    p *= (1.0 / max(0.0001, u_zoom));

    float g_cd = 0.0;

    // compute cd (side effect). keep original
    float unusedD = sbl_df2(p, t, g_cd);

    float cd = g_cd;

    vec3 col = sbl_color_soft(cd);

    col = sbl_postProcess(col);

    float d = sbl_sat(u_darkness);
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3(luma), d * 0.55);
    col *= (1.0 - d * 0.65);

    col = sbl_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = sbl_sat3(col);

    gl_FragColor = vec4(col, 1.0);
}
