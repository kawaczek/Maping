#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_speed;
uniform float u_scale;
uniform float u_rotate;
uniform float u_intensity;
uniform float u_contrast;
uniform float u_darkness;
uniform float u_alpha;

const float FG_PI = 3.141592654;
const float FG_TAU = 6.283185308;

float fg_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 fg_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

vec2 fg_rot(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 fg_applyContrast(vec3 c, float k) {
    return (c - 0.5) * k + 0.5;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 q = vUV;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= (res.x / res.y);

    float t = u_time * u_speed;
    float baseRot = (FG_PI / 4.0);
    float userRot = fg_sat(u_rotate) * FG_TAU;
    p = fg_rot(p, baseRot + userRot);

    float sc = max(0.05, u_scale);
    p *= sc;

    float w = (p.y * p.y * p.x - p.x);
    vec3 col0 = (1.0 + cos(vec3(0.0, 1.0, 2.0) + 1.0 * w - 0.25 * t)) * 0.5;
    vec3 col1 = sqrt(0.5) * col0 * col0;

    float blend = 0.5 + 0.5 * sin(0.85 * p.y + 0.35 * t);
    vec3 col = mix(col0, col1, fg_sat(blend));

    col *= max(0.0, u_intensity);

    float d = fg_sat(u_darkness);
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3(luma), d * 0.55);
    col *= (1.0 - d * 0.65);

    col = fg_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = fg_sat3(col);
    col = sqrt(col);

    float a = fg_sat(u_alpha);
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float alphaOut = a * (0.25 + 0.75 * lum);

    gl_FragColor = vec4(col, alphaOut);
}
