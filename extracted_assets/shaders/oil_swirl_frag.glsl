#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_speed;
uniform float u_zoom;
uniform float u_swirl;
uniform float u_warp;
uniform float u_bands;
uniform float u_colorShift;
uniform float u_glow;
uniform float u_contrast;
uniform float u_darkness;

const float OSW_PI = 3.141592654;
const float OSW_TAU = 6.283185308;

float osw_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 osw_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

vec2 osw_rot(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float osw_hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 osw_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 osw_applyContrast(vec3 c, float k) {
    return (c - 0.5) * k + 0.5;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 q = vUV;
    vec2 p = (q - 0.5) * 2.0;
    p.x *= (res.x / res.y);

    float t = u_time * u_speed;
    float zoom = max(0.05, u_zoom);
    p /= zoom;

    float r = length(p);
    float ang = (u_swirl * r) + 0.35 * t;
    vec2 pr = osw_rot(p, ang);

    float warp = u_warp;
    float n0 = osw_hash(pr * 1.7 + vec2(t, -t));
    float n1 = osw_hash(pr * 3.1 + vec2(-t, t));
    pr += warp * 0.20 * vec2(
        sin(1.8 * pr.y + 2.1 * t + 6.0 * n0),
        sin(1.5 * pr.x - 1.7 * t + 6.0 * n1)
    );

    float bands = max(0.0, u_bands);
    float f0 = sin(bands * (pr.x + 0.35 * pr.y) + 1.2 * t);
    float f1 = sin(bands * (pr.y - 0.30 * pr.x) - 0.9 * t);
    float field = 0.55 * f0 + 0.45 * f1;

    float g = exp(-abs(field) * 2.6) * max(0.0, u_glow);
    float hue = fract(0.12 * t + 0.18 * field + (u_colorShift / OSW_TAU));
    float sat = 0.90;
    float val = 1.0;
    vec3 base = osw_hsv2rgb(vec3(hue, sat, val));

    float bandMask = smoothstep(0.1, 0.9, 0.5 + 0.5 * field);
    vec3 col = base * (0.35 + 0.65 * bandMask);
    col += base * (0.35 * g);

    float d = osw_sat(u_darkness);
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3(luma), d * 0.55);
    col *= (1.0 - d * 0.65);

    col = osw_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = osw_sat3(col);

    gl_FragColor = vec4(col, 1.0);
}
