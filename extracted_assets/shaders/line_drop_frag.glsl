#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_lineCount;
uniform float u_vDrop;
uniform float u_spread;
uniform float u_hue;
uniform float u_brightness;
uniform float u_horizontal;

vec3 ld_hsv2rgb(vec3 hsv) {
    float h = hsv.x;
    float s = hsv.y;
    float v = hsv.z;
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(h + K.xyz) * 6.0 - K.www);
    return v * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), s);
}

vec3 ld_brightnessCurve(vec3 color, float b) {
    b = clamp(b, 0.0, 1.0);
    if (b <= 0.5) {
        float t = b / 0.5;
        return mix(vec3(0.0), color, t);
    } else {
        float t = (b - 0.5) / 0.5;
        return mix(color, vec3(1.0), t);
    }
}

int ld_clampEven(int v, int lo, int hi) {
    v = max(lo, min(hi, v));
    if (int(mod(float(v), 2.0)) != 0) v -= 1;
    if (v < lo) v = lo;
    return v;
}

void main() {
    vec2 uv = vUV;
    vec2 res = max(u_resolution, vec2(1.0));
    bool horizontal = (u_horizontal >= 0.5);

    int n = ld_clampEven(int(floor(u_lineCount + 0.5)), 2, 48);
    float stripUv = 1.0 / float(n);

    float axisPx = horizontal ? res.y : res.x;
    float maxGapPx = axisPx * 2.0;
    float gapPx = clamp(u_spread, 0.0, 1.0) * maxGapPx;
    float gapUv = gapPx / axisPx;

    float total = float(n) * stripUv + float(n - 1) * gapUv;
    float start = 0.5 - total * 0.5;
    float drop = clamp(u_vDrop, 0.0, 1.0) * 1.2;

    vec3 baseColor = ld_hsv2rgb(vec3(fract(u_hue), 1.0, 1.0));
    vec3 rgb = ld_brightnessCurve(baseColor, u_brightness);

    for (int i = 0; i < 48; i++) {
        if (i >= n) break;

        float a0 = start + float(i) * (stripUv + gapUv);
        float a1 = a0 + stripUv;

        float alt = (mod(float(i), 2.0) < 1.0) ? 1.0 : -1.0;

        float x0, x1, y0, y1;

        if (!horizontal) {
            x0 = a0;
            x1 = a1;
            y0 = 0.0 + alt * drop;
            y1 = 1.0 + alt * drop;
        } else {
            x0 = 0.0 + alt * drop;
            x1 = 1.0 + alt * drop;
            y0 = a0;
            y1 = a1;
        }

        if (uv.x >= x0 && uv.x < x1 && uv.y >= y0 && uv.y <= y1) {
            gl_FragColor = vec4(rgb, 1.0);
            return;
        }
    }

    gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
}
