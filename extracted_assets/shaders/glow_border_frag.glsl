#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_thickness;
uniform float u_glowAmount;
uniform float u_glowFalloff;
uniform float u_hue;
uniform float u_rainbowMode;
uniform float u_rainbowSpeed;
uniform float u_rainbowPhase;
uniform float u_squareMode;
uniform float u_flickerAmount;
uniform float u_pulseAmount;

vec3 gb_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float gb_hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = vUV;
    float t = u_time;

    float thickness = max(u_thickness, 0.0005);
    float glowAmt = max(u_glowAmount, 0.0);
    float glowFalloff = max(u_glowFalloff, 0.1);
    float squareMode = (u_squareMode >= 0.5) ? 1.0 : 0.0;
    float rainbowMode = (u_rainbowMode >= 0.5) ? 1.0 : 0.0;

    vec2 p = uv * 2.0 - 1.0;
    float aspect = res.x / res.y;
    p.x *= aspect;

    float frame169_x = 1.0 * aspect;
    float frame169_y = 1.0;
    float squareHalf = min(frame169_x, frame169_y);
    float hx = mix(frame169_x, squareHalf, squareMode);
    float hy = mix(frame169_y, squareHalf, squareMode);

    vec2 d = abs(p) - vec2(hx, hy);
    float outside = length(max(d, vec2(0.0)));
    float inside = min(max(d.x, d.y), 0.0);
    float dist = outside + inside;

    float band = abs(dist) - thickness;
    float aa = 2.0 / min(res.x, res.y);
    float borderAlpha = 1.0 - smoothstep(0.0, aa, band);

    float dg = abs(dist);
    float glow1 = exp(-dg * glowFalloff * 1.2);
    float glow2 = exp(-dg * glowFalloff * 0.35);
    float glow3 = exp(-dg * glowFalloff * 0.10);
    float glow = (glow1 * 1.0 + glow2 * 1.2 + glow3 * 0.9) * glowAmt;

    float flicker = 1.0 + (gb_hash(floor(t * 55.0)) - 0.5) * u_flickerAmount;
    flicker = clamp(flicker, 0.6, 1.6);
    float pulse = 1.0 + sin(t * 2.0) * u_pulseAmount;

    float ax = abs(p.x) / max(hx, 1e-6);
    float ay = abs(p.y) / max(hy, 1e-6);
    float x = clamp(p.x, -hx, hx);
    float y = clamp(p.y, -hy, hy);
    float L = 4.0 * (hx + hy);
    float s = 0.0;

    if (ay >= ax && p.y >= 0.0) {
        s = (hx - x);
    } else if (ax > ay && p.x <= 0.0) {
        s = (2.0 * hx) + (hy - y);
    } else if (ay >= ax && p.y < 0.0) {
        s = (2.0 * hx + 2.0 * hy) + (x + hx);
    } else {
        s = (4.0 * hx + 2.0 * hy) + (y + hy);
    }
    float s01 = s / max(L, 1e-6);

    float hue = fract(u_hue);
    if (rainbowMode > 0.5) {
        hue = fract(hue + s01 + u_rainbowPhase);
    }
    vec3 baseCol = gb_hsv2rgb(vec3(hue, 0.95, 1.0));

    float core = borderAlpha;
    float bloom = glow;
    vec3 col = baseCol * (core * 3.0 + bloom * 3.8) * flicker * pulse;
    float alpha = clamp(core + bloom * 0.9, 0.0, 1.0);

    if (alpha < 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        gl_FragColor = vec4(col, alpha);
    }
}
