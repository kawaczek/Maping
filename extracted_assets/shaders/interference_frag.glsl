#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_speed;
uniform float u_cellSize;
uniform float u_smoothness;
uniform float u_falloff;
uniform float u_colorFreq;
uniform float u_vignette;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_contrast;

float ip_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 ip_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }
vec3 ip_applyContrast(vec3 c, float contrast) {
    return (c - 0.5) * contrast + 0.5;
}

float ip_df(vec2 p, float m) {
    float l = length(p);
    l = mod(l + (0.5 * m), m) - (0.5 * m);
    return abs(l) - (m * 0.25);
}

float ip_pmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
float ip_pmax(float a, float b, float k) {
    return -ip_pmin(-a, -b, k);
}

vec3 ip_effect(vec2 p, vec2 pp) {
    float aa = 2.0 / max(1.0, u_resolution.y);
    float tm = u_time * u_speed;

    vec2 dir = vec2(1.0, sqrt(0.5));
    vec2 p0 = p + sin(dir * (tm + 100.0));
    vec2 p1 = p + sin(1.2 * dir * (tm + 200.0));

    float sm = u_smoothness * length(p);
    float d0 = ip_df(p0, u_cellSize);
    float d1 = ip_df(p1, u_cellSize);

    float d = d0;
    d = ip_pmax(d, d1, sm);
    float dd = -d0;
    dd = ip_pmax(dd, -d1, sm);
    d = min(d, dd);

    float so = max(0.001, u_falloff);
    float co = u_colorFreq;
    float huePhase = u_hueShift * 6.28318530718;

    float lp0 = length(p0);
    float lp1 = length(p1);
    float denom0 = (so * dot(p0, p0) + 0.0001);
    float denom1 = (so * dot(p1, p1) + 0.0001);
    vec3 base = vec3(0.0, 1.0, 2.0);

    vec3 bcol0 = (1.0 + sin(base + huePhase + co * lp0 + 1.0 - u_time)) / denom0;
    vec3 bcol1 = (1.0 + sin(base + huePhase + co * lp1 + 3.0 + u_time)) / denom1;
    vec3 bcol = bcol0 + bcol1;

    vec3 col = vec3(0.0);
    col += 0.005 * bcol / (max(dd + 0.005, 0.0) + 0.0001);
    col = mix(col, bcol, smoothstep(aa, -aa, d));
    col -= 0.25 * vec3(2.0, 1.0, 0.0) * length(pp);

    float vig = smoothstep(1.5, 0.5, length(pp));
    col *= mix(1.0, vig, ip_sat(u_vignette));
    col = ip_sat3(col);
    col = sqrt(col);
    col *= max(0.0, u_brightness);
    col = ip_applyContrast(col, clamp(u_contrast, 0.0, 3.0));
    col = ip_sat3(col);
    return col;
}

void main() {
    vec2 q = vUV;
    vec2 p = -1.0 + 2.0 * q;
    vec2 pp = p;
    p.x *= (u_resolution.x / max(1.0, u_resolution.y));
    vec3 col = ip_effect(p, pp);
    gl_FragColor = vec4(col, 1.0);
}
