#version 100
// Port of BlobJello.metal (bj_blob_jello_frag) — raymarched wobbling jello blob
// with transparent background on miss.
// The Metal vertex stage used a FLIPPED V (uv.y = 1 at the bottom); replicated
// here as uv = vec2(vUV.x, 1.0 - vUV.y) so lighting/orientation match iOS.
// Rotation phases are integrated on the CPU (dt * rotSpeed), matching the
// current iOS provider (u_rotYPhase / u_rotXPhase).
precision highp float;
varying vec2 vUV;

uniform float u_time;       // raw accumulated time (unscaled)
uniform vec2 u_resolution;

uniform float u_rotYBase;   // -pi..pi
uniform float u_rotXBase;   // -pi..pi
uniform float u_rotYPhase;  // CPU-integrated dt * rotYSpeed
uniform float u_rotXPhase;  // CPU-integrated dt * rotXSpeed

uniform float u_posX;       // -2..2
uniform float u_posY;       // -2..2

uniform float u_size;         // 0.35..2.75 radius multiplier
uniform float u_hue;          // 0..1
uniform float u_translucency; // 0..1 (0 = opaque, 1 = very see-through)

// ============================
// Helpers
// ============================

float bj_hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

float bj_noise3(vec3 p) {
    vec3 ip = floor(p);
    vec3 f  = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = bj_hash11(dot(ip + vec3(0.0, 0.0, 0.0), vec3(1.0, 57.0, 113.0)));
    float n100 = bj_hash11(dot(ip + vec3(1.0, 0.0, 0.0), vec3(1.0, 57.0, 113.0)));
    float n010 = bj_hash11(dot(ip + vec3(0.0, 1.0, 0.0), vec3(1.0, 57.0, 113.0)));
    float n110 = bj_hash11(dot(ip + vec3(1.0, 1.0, 0.0), vec3(1.0, 57.0, 113.0)));
    float n001 = bj_hash11(dot(ip + vec3(0.0, 0.0, 1.0), vec3(1.0, 57.0, 113.0)));
    float n101 = bj_hash11(dot(ip + vec3(1.0, 0.0, 1.0), vec3(1.0, 57.0, 113.0)));
    float n011 = bj_hash11(dot(ip + vec3(0.0, 1.0, 1.0), vec3(1.0, 57.0, 113.0)));
    float n111 = bj_hash11(dot(ip + vec3(1.0, 1.0, 1.0), vec3(1.0, 57.0, 113.0)));

    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);

    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);

    return mix(nxy0, nxy1, f.z);
}

vec3 bj_rotY(vec3 p, float a) {
    float s = sin(a), c = cos(a);
    return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

vec3 bj_rotX(vec3 p, float a) {
    float s = sin(a), c = cos(a);
    return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

// Hue->RGB
vec3 bj_hueToRGB(float h) {
    vec3 k = vec3(1.0, 2.0 / 3.0, 1.0 / 3.0);
    vec3 p = abs(fract(h + k) * 6.0 - 3.0);
    return clamp(p - 1.0, 0.0, 1.0);
}

// ============================
// SDF
// ============================

float bj_sdf(vec3 p, float t, float size) {
    float r = 1.15 * size;

    float w1 = sin(p.x * 1.7 + t * 1.3) * 0.08 * size;
    float w2 = sin(p.y * 2.1 - t * 1.1) * 0.07 * size;
    float w3 = sin(p.z * 1.9 + t * 1.7) * 0.06 * size;

    float n = bj_noise3(p * 1.2 + vec3(0.0, t * 0.35, t * 0.25)) * 0.08 * size;
    float wobble = w1 + w2 + w3 + (n - 0.5) * 0.14 * size;

    return length(p) - (r + wobble);
}

vec3 bj_normal(vec3 p, float t, float size) {
    float e = 0.01;
    float dx = bj_sdf(p + vec3(e, 0.0, 0.0), t, size) - bj_sdf(p - vec3(e, 0.0, 0.0), t, size);
    float dy = bj_sdf(p + vec3(0.0, e, 0.0), t, size) - bj_sdf(p - vec3(0.0, e, 0.0), t, size);
    float dz = bj_sdf(p + vec3(0.0, 0.0, e), t, size) - bj_sdf(p - vec3(0.0, 0.0, e), t, size);
    return normalize(vec3(dx, dy, dz));
}

// ============================
// Raymarch
// ============================

float bj_trace(vec3 ro, vec3 rd, float tTime, float size) {
    const float MAX_DIST = 12.0;
    const int   MAX_STEPS = 24;
    const float SURF = 0.02;

    float t = 0.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * t;
        float d = bj_sdf(p, tTime, size);

        if (d < SURF) { return t; }

        t += d * 0.9;
        if (t > MAX_DIST) break;
    }

    return MAX_DIST;
}

// ============================
// Fragment
// ============================

void main() {
    // Replicate the Metal flipped-V UV setup
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);

    // Screen space p
    vec2 p = uv * 2.0 - 1.0;
    float aspect = (u_resolution.x / max(u_resolution.y, 1.0));
    p.x *= aspect;

    float tTime = u_time;

    // Camera
    vec3 ro = vec3(0.0, 0.0, -4.5);

    // Screen-aligned shift
    vec2 pShifted = vec2(p.x - u_posX * aspect, p.y - u_posY);
    vec3 rd = normalize(vec3(pShifted.x, pShifted.y, 2.4));

    // Rotation (base + CPU-integrated phase, matches current iOS provider)
    float angY = u_rotYBase + u_rotYPhase;
    float angX = u_rotXBase + u_rotXPhase;

    ro = bj_rotY(ro, -angY);
    ro = bj_rotX(ro, -angX);
    rd = bj_rotY(rd, -angY);
    rd = bj_rotX(rd, -angX);

    // Trace
    float size = max(u_size, 0.05);
    float tHit = bj_trace(ro, rd, tTime, size);

    // MISS => fully transparent
    if (tHit >= 11.99) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec3 hit = ro + rd * tHit;
    vec3 n = bj_normal(hit, tTime, size);

    // Lighting
    vec3 lightPos = vec3(2.2, 2.8, -2.0);
    vec3 l = normalize(lightPos - hit);
    float ndl = clamp(dot(n, l), 0.0, 1.0);

    vec3 v = normalize(-rd);

    vec3 h = normalize(l + v);
    float spec = pow(clamp(dot(n, h), 0.0, 1.0), 64.0) * 0.9;

    float rim = pow(clamp(1.0 - dot(n, v), 0.0, 1.0), 2.2);

    // Thickness: higher near boundary, helps "jello" look
    float inside = bj_sdf(hit - n * 0.08 * size, tTime, size);
    float thickness = clamp(1.0 - inside * (8.0 / max(size, 0.2)), 0.0, 1.0);

    // Color from hue
    float hue = fract(u_hue);
    vec3 base = bj_hueToRGB(hue);
    base = mix(base, vec3(1.0), 0.12); // slight pastel lift

    // Variation
    float swirl = bj_noise3(hit * 1.3 + vec3(tTime * 0.4, tTime * 0.2, 0.0));
    base *= (0.82 + 0.30 * swirl);

    // Subsurface-ish
    float back = clamp(dot(-n, l), 0.0, 1.0);
    float sss = thickness * (0.25 + 0.75 * back);

    // Color (no bg)
    vec3 col = vec3(0.0);
    col += base * (0.18 + 0.75 * ndl);
    col += base * (0.55 * sss);
    col += (base + vec3(0.25)) * rim * 0.55;
    col += vec3(1.0) * spec;

    // --- TRANSLUCENCY CONTROL ---
    float aJello = clamp(0.12 + 0.55 * rim + 0.33 * thickness, 0.0, 1.0);
    aJello = smoothstep(0.0, 1.0, aJello);

    float tnl = clamp(u_translucency, 0.0, 1.0);
    float alpha = mix(1.0, aJello, tnl);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), alpha);
}
