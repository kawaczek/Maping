#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_speed;
uniform float u_zoom;
uniform float u_rotation;
uniform float u_octaves;
uniform float u_amplitude;
uniform float u_frequency;
uniform float u_exponent;
uniform float u_colorFreq;
uniform float u_hueShift;
uniform float u_contrast;
uniform float u_darkness;

const float TL_PI = 3.141592654;
const float TL_TAU = 6.283185308;

float tl_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 tl_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

vec2 tl_rot2(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2 tl_mul2x2(vec2 v, vec2 c0, vec2 c1) {
    return vec2(v.x * c0.x + v.y * c1.x, v.x * c0.y + v.y * c1.y);
}

vec3 tl_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 tl_applyContrast(vec3 c, float k) {
    return (c - 0.5) * k + 0.5;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = (vUV - 0.5) * 2.0;
    p.x *= (res.x / res.y);

    float rotA = (u_rotation * TL_TAU);
    p = tl_rot2(p, rotA);
    p /= max(0.05, u_zoom);

    int OCT = int(clamp(floor(u_octaves + 0.5), 1.0, 8.0));
    float amp = max(0.0, u_amplitude);
    float spd = u_speed;
    float freq = max(0.0001, u_frequency);
    float expn = max(1.0, u_exponent);

    vec2 c0 = vec2(0.6, 0.8);
    vec2 c1 = vec2(-0.8, 0.6);
    vec2 pos = vec2(0.0);
    float f = freq;
    float t = u_time;

    for (int i = 0; i < 8; i++) {
        if (i >= OCT) break;

        vec2 pr = tl_mul2x2(p, c0, c1);
        float phase = f * pr.y + spd * t + float(i);
        pos += (amp * c0 * sin(phase)) / f;

        vec2 nc0 = tl_mul2x2(c0, vec2(0.6, 0.8), vec2(-0.8, 0.6));
        vec2 nc1 = tl_mul2x2(c1, vec2(0.6, 0.8), vec2(-0.8, 0.6));
        c0 = nc0;
        c1 = nc1;
        f *= expn;
    }

    float cf = max(0.0, u_colorFreq);
    vec3 wave = 0.5 + 0.5 * cos(t + vec3(pos.x, pos.y, pos.x + pos.y) * (0.02 + 0.08 * cf) + vec3(0.0, 2.0, 4.0));

    float hue = fract(u_hueShift + 0.15 * (pos.x - pos.y) * (0.01 + 0.06 * cf) + 0.08 * t);
    vec3 rainbow = tl_hsv2rgb(vec3(hue, 0.95, 1.0));

    float tint = 0.35;
    vec3 col = mix(wave, wave * rainbow, tint);

    float dk = tl_sat(u_darkness);
    col *= (1.0 - dk);
    col = tl_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = tl_sat3(col);
    col = sqrt(col);

    gl_FragColor = vec4(col, 1.0);
}
