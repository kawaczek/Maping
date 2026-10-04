#version 100
// Kaleido2 — faithful port of iOS Metal Kaleido2.metal (k2_fragment).
// Time uniforms are integrated phases (continuity-safe), mirroring Kaleido2Provider.swift.
precision highp float;
varying vec2 vUV;

uniform vec2 u_resolution;
uniform float u_time;        // integrated timeFlow (dt * speed)
uniform float u_driftOffset; // integrated drift phase
uniform float u_twistAngle;  // integrated twist phase
uniform float u_huePhase;    // integrated hue phase
uniform float u_reps;
uniform float u_layers;
uniform float u_lineWidth;
uniform float u_smoothness;
uniform float u_post;
uniform float u_contrast;

#define K2_PI  3.141592654
#define K2_TAU (2.0 * K2_PI)

// GLSL ES 2.0 has no tanh(); emulate (clamped to avoid exp overflow).
float k2_tanh(float x) {
    float e = exp(2.0 * clamp(x, -10.0, 10.0));
    return (e - 1.0) / (e + 1.0);
}
vec3 k2_tanh3(vec3 v) { return vec3(k2_tanh(v.x), k2_tanh(v.y), k2_tanh(v.z)); }

// Metal fmod is truncated toward zero; GLSL mod() is floored. Match Metal.
float k2_fmod(float x, float y) {
    float q = x / y;
    return x - y * (sign(q) * floor(abs(q)));
}

vec2 k2_rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

float k2_psin(float x) { return 0.5 + 0.5 * sin(x); }

float k2_sabs(float x, float k) {
    // SABS(x,k) = LESS((.5/k)*x*x + k*.5, abs(x), abs(x)-k)
    float ax = abs(x);
    float a = (0.5 / max(1e-6, k)) * x * x + (k * 0.5);
    float b = ax;
    float c = ax - k;
    float t = step(0.0, c);
    return mix(a, b, t);
}

float k2_rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec3 k2_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec2 k2_toPolar(vec2 p) {
    return vec2(length(p), atan(p.y, p.x));
}

vec2 k2_toRect(vec2 p) {
    return p.x * vec2(cos(p.y), sin(p.y));
}

vec2 k2_mod2_1(inout vec2 p) {
    vec2 pp = p + 0.5;
    vec2 nn = floor(pp);
    p = fract(pp) - 0.5;
    return nn;
}

float k2_modMirror1(inout float p, float size) {
    float halfsize = size * 0.5;
    float c = floor((p + halfsize) / size);
    p = k2_fmod(p + halfsize, size) - halfsize;
    p *= k2_fmod(c, 2.0) * 2.0 - 1.0;
    return c;
}

float k2_circle(vec2 p, float r) {
    return length(p) - r;
}

float k2_smoothKaleidoscope(inout vec2 p, float sm, float rep) {
    vec2 hp = p;

    vec2 hpp = k2_toPolar(hp);

    float theta = hpp.y;
    float rn = k2_modMirror1(theta, K2_TAU / rep);
    hpp.y = theta;

    float seg = K2_PI / rep;
    float sa = seg - k2_sabs(seg - abs(hpp.y), sm);
    hpp.y = sign(hpp.y) * sa;

    hp = k2_toRect(hpp);
    p = hp;

    return rn;
}

float k2_cell0(vec2 p) {
    float d0 = k2_circle(p + 0.5, 0.5);
    float d1 = k2_circle(p - 0.5, 0.5);
    return min(d0, d1);
}

float k2_cell1(vec2 p) {
    float d0 = abs(p.x);
    float d1 = abs(p.y);
    float d2 = k2_circle(p, 0.25);
    return min(min(d0, d1), d2);
}

// 4 possible quarter-turn rotations: 0, 90, 180, 270 deg
// (no switch / bitwise ops in GLSL ES 1.00; idx is always 0..3 here)
vec2 k2_rotIndex(vec2 v, int idx) {
    int m = idx - 4 * (idx / 4);
    if (m == 0) return v;
    if (m == 1) return vec2(-v.y, v.x);
    if (m == 2) return vec2(-v.x, -v.y);
    return vec2(v.y, -v.x);
}

float k2_cell(vec2 p, vec2 cp, vec2 n, float lw) {
    float r = k2_rand(n + 1237.0);
    cp = k2_rotIndex(cp, int(floor(4.0 * r)));
    float rr = fract(13.0 * r);

    float d = (rr > 0.25) ? k2_cell0(cp) : k2_cell1(cp);
    return abs(d) - lw;
}

float k2_truchet(vec2 p, float lw) {
    float s = 0.1;
    p /= s;
    vec2 cp = p;
    vec2 n = k2_mod2_1(cp);
    float d = k2_cell(p, cp, n, lw) * s;
    return d;
}

float k2_df(vec2 p, float rep, float time) {
    float lw = u_lineWidth;

    vec2 pp = k2_toPolar(p);
    pp.x /= (1.0 + pp.x);
    p = k2_toRect(pp);

    vec2 cp = p;

    float sm = (3.0 / rep) * max(0.05, u_smoothness);

    k2_smoothKaleidoscope(cp, sm, rep);

    cp = k2_rot(cp, u_twistAngle);
    cp -= u_driftOffset;

    float lwMod = lw * mix(0.25, 2.0, k2_psin(-2.0 * time + 5.0 * cp.x + (0.5 * rep) * cp.y));
    return k2_truchet(cp, lwMod);
}

vec3 k2_color(vec2 q, vec2 p, float rep, float tm) {
    vec2 pp = k2_toPolar(p);

    float d = k2_df(p, rep, tm);

    float aa = 2.0 / max(1.0, u_resolution.y);

    float hue = (-u_huePhase) + sin(5.5 * d);
    float sat = k2_tanh(pp.x);
    vec3 baseCol = k2_hsv2rgb(vec3(hue, sat, 1.0));

    vec3 col = mix(vec3(0.0), baseCol, smoothstep(-aa, aa, -d));
    col = baseCol + 0.5 * col.zxy;

    return col;
}

vec3 k2_postProcess(vec3 col, vec2 q) {
    col = pow(clamp(col, 0.0, 1.0), vec3(0.75));
    col = col * 0.6 + 0.4 * col * col * (3.0 - 2.0 * col);
    col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);
    col *= 0.5 + 0.5 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);
    return col;
}

void main() {
    // Metal vertex used uv = ndc*0.5+0.5 (y up); the Android FBO readback flips
    // vertically, so invert v to keep the displayed orientation identical.
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);
    vec2 fragCoord = uv * u_resolution;
    vec2 q = fragCoord / u_resolution;

    vec2 p = -1.0 + 2.0 * q;
    p.x *= (u_resolution.x / max(1.0, u_resolution.y));
    vec2 op = p;

    float tm = u_time * 0.25;

    float aa = -1.0 + 0.5 * length(p);
    float a = 1.0;
    float ra = k2_tanh(length(0.5 * p));

    vec3 col = vec3(0.0);

    int L = int(clamp(floor(u_layers + 0.5), 1.0, 8.0));
    for (int i = 0; i < 8; i++) {
        if (i >= L) break;

        float fi = float(i);

        p = k2_rot(p, sqrt(0.1 * fi) * tm - ra);

        float rep = max(2.0, u_reps - (u_reps / max(1.0, float(L))) * fi);
        col += a * k2_color(q, p, rep, tm + fi);

        a *= aa;
    }

    col = k2_tanh3(col);
    col = abs(p.y - col);
    col = max(1.0 - col, 0.0);
    col = pow(col, k2_tanh3(length(op) * vec3(1.0, 1.5, 3.0)));

    vec3 post = k2_postProcess(col, q);
    col = mix(col, post, clamp(u_post, 0.0, 1.0));

    // final contrast
    col = (col - 0.5) * clamp(u_contrast, 0.0, 3.0) + 0.5;
    col = clamp(col, 0.0, 1.0);

    gl_FragColor = vec4(col, 1.0);
}
