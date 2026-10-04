#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_warpScale;
uniform float u_warpAmount;
uniform float u_speed;
uniform float u_phaseR;
uniform float u_phaseG;
uniform float u_phaseB;
uniform float u_saturation;
uniform float u_rotate;
uniform float u_zoom;
uniform float u_vignette;

vec2 sw_rot(float a, vec2 v) {
    float s = sin(a), c = cos(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = (vUV - 0.5) * 2.0;
    uv.x *= res.x / res.y;

    float t = mod(u_time, 6283.1853);

    uv /= max(u_zoom, 0.0001);
    uv = sw_rot(u_rotate, uv);

    vec2 w = sin(uv * u_warpScale + t);
    uv += w * u_warpAmount;

    float base = (uv.x + uv.y + t);
    vec3 col = 0.5 + 0.5 * sin(3.14159265 * base + vec3(u_phaseR, u_phaseG, u_phaseB));

    float mx = max(col.x, max(col.y, col.z));
    col = mix(col, col / max(mx, 0.0001), u_saturation);

    vec2 v = vUV - 0.5;
    float vig = smoothstep(1.0, 0.0, dot(v, v) * (1.0 + u_vignette * 2.0));
    col *= vig;

    gl_FragColor = vec4(col, 1.0);
}
