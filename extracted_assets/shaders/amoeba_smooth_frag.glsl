#version 100
// Amoeba Smooth — ported from AmoebaSmooth.metal (amoebaSmooth_frag).
// Smooth variant: alpha from blobs only, NO vignette, 3D dome lighting applied
// only to blobs (via alpha) so dots never get "pin" highlights.
precision highp float;

varying vec2 vUV;

uniform float u_time;
uniform vec2  u_resolution;

// Color
uniform float u_hue;            // 0..1
uniform float u_saturation;     // 0..2
uniform float u_value;          // 0..2

// Motion
uniform float u_speed;          // Kotlin bakes speed into u_time and sends 1.0 (matches iOS provider)
uniform float u_wobble;         // provider-integrated wobble PHASE

// Structure
uniform float u_density;        // 0.05..1.0 (smaller = denser)
uniform float u_blobCount;      // 1..24
uniform float u_blobRadius;     // 0.02..0.35
uniform float u_smoothK;        // 0.01..1.0
uniform float u_dotRadius;      // 0..0.25

// Look
uniform float u_bgLevel;        // 0..1
uniform float u_alphaSoftness;  // 0..1

const int AS_MAX_BLOBS = 24;
const float AS_SQRT_HALF = 0.7071067811865476;

float as_circleSDF(vec2 p, float r) { return length(p) - r; }

float as_pmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Centered tile fold; Metal source implements GLSL floor-mod, which is mod() here.
vec2 as_mod2(vec2 p, vec2 size) {
    vec2 m = mod(p + size * 0.5, size);
    return m - size * 0.5;
}

vec3 as_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Returns combined distance (dots + blobs), and also outputs the blob-only distance.
float as_df(vec2 p, float TIME, out float outBlobDist) {
    // Dots grid
    float cell = max(u_density, 1e-4);
    vec2 dp = as_mod2(p, vec2(cell));
    float ddots = length(dp) - max(u_dotRadius, 0.0);

    // Blobs
    float dblobs = 1e6;
    int bc = int(clamp(u_blobCount, 1.0, 24.0));
    float r = max(u_blobRadius, 1e-4);
    float k = max(u_smoothK, 1e-4);

    // Secondary wobble (phase provided by CPU)
    float t2 = TIME + u_wobble;

    for (int i = 0; i < AS_MAX_BLOBS; ++i) {
        if (i >= bc) { break; }
        float fi = float(i);
        vec2 c = vec2(
            sin(TIME + fi),
            sin(fi * fi + t2 * AS_SQRT_HALF)
        );
        float dd = as_circleSDF(p - c, r);
        dblobs = as_pmin(dblobs, dd, k);
    }

    outBlobDist = dblobs;

    float d = 1e6;
    d = min(d, ddots);
    d = as_pmin(d, dblobs, k);
    return d;
}

// Post-process: keep original gamma + contrast + saturation tweak, NO vignette.
vec3 as_postProcessNoVignette(vec3 col) {
    col = pow(clamp(col, 0.0, 1.0), vec3(1.0 / 2.2));
    col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);
    col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);
    return col;
}

float as_domeHeight(float bd, float radiusHint) {
    float r = max(radiusHint, 1e-4);

    // Signed mapping: 0 at boundary (bd=0), 1 near center (bd ~= -r)
    float x = clamp((-bd) / r, 0.0, 1.0);

    // Smooth twice for rounded top (no pins)
    x = x * x * (3.0 - 2.0 * x);
    x = x * x * (3.0 - 2.0 * x);

    return 1.35 * x;
}

void main() {
    vec2 RES = max(u_resolution, vec2(1.0));
    float TIME = u_time;

    // Centered mapping via NDC-equivalent coordinates
    vec2 p = vUV * 2.0 - 1.0;
    p.x *= RES.x / RES.y;

    float aa = 2.0 / RES.y;
    const float z = 1.4;

    float blobDist = 0.0;
    float d = as_df(p / z, TIME, blobDist) * z;
    blobDist *= z;

    // Combined mask (dots+blobs) for COLOR only
    float m = smoothstep(-aa, aa, -d);

    // Blob-only alpha (dots never appear in alpha)
    float soft = clamp(u_alphaSoftness, 0.0, 1.0);
    float aa2 = mix(aa, aa * 6.0, soft);
    float alpha = smoothstep(-aa2, aa2, -blobDist);
    alpha = clamp(alpha, 0.0, 1.0);
    if (alpha < 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    vec3 blobCol = as_hsv2rgb(vec3(fract(u_hue),
                                   clamp(u_saturation, 0.0, 2.0),
                                   clamp(u_value, 0.0, 2.0)));

    float bg = clamp(u_bgLevel, 0.0, 1.0);
    vec3 bgCol = vec3(bg);

    // Base flat color mix (includes dots) — keeps the original dot look.
    vec3 baseCol = mix(bgCol, blobCol, m);

    // ---------------------------
    // 3D lighting (BLOBS ONLY) via smoothed heightfield normals from blobDist.
    // ---------------------------

    // Larger epsilon smooths the gradient a lot (this is crucial)
    float eps = max(aa * 8.0, 1e-4);

    float tmp = 0.0;
    float bd_x1 = 0.0; float bd_x2 = 0.0; float bd_y1 = 0.0; float bd_y2 = 0.0;
    as_df((p + vec2(eps, 0.0)) / z, TIME, tmp); bd_x1 = tmp * z;
    as_df((p - vec2(eps, 0.0)) / z, TIME, tmp); bd_x2 = tmp * z;
    as_df((p + vec2(0.0, eps)) / z, TIME, tmp); bd_y1 = tmp * z;
    as_df((p - vec2(0.0, eps)) / z, TIME, tmp); bd_y2 = tmp * z;

    float h0  = as_domeHeight(blobDist, u_blobRadius);
    float hx1 = as_domeHeight(bd_x1,    u_blobRadius);
    float hx2 = as_domeHeight(bd_x2,    u_blobRadius);
    float hy1 = as_domeHeight(bd_y1,    u_blobRadius);
    float hy2 = as_domeHeight(bd_y2,    u_blobRadius);

    float dhdx = (hx1 - hx2) / (2.0 * eps);
    float dhdy = (hy1 - hy2) / (2.0 * eps);

    // Strong but stable (because eps is larger)
    float normalStrength = 10.0;
    vec3 N = normalize(vec3(-dhdx * normalStrength,
                            -dhdy * normalStrength,
                             1.0));

    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 L = normalize(vec3(-0.35, 0.55, 0.75));
    float diff = max(dot(N, L), 0.0);

    // Broader spec to avoid pin tips
    vec3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), 26.0);

    float fres = pow(1.0 - max(dot(N, V), 0.0), 2.0);

    // Height-based boost (center reads "thicker")
    float heightBoost = 0.85 + 0.85 * clamp(h0, 0.0, 1.0);

    vec3 lit = blobCol * (0.10 + 2.0 * diff) * heightBoost;
    lit += vec3(spec * 2.0 * heightBoost);
    lit += blobCol * fres * 0.75;

    // Apply 3D only on blobs (alpha), so dots stay smooth/flat.
    vec3 col = mix(baseCol, lit, alpha);

    col = as_postProcessNoVignette(col);

    gl_FragColor = vec4(col, alpha);
}
