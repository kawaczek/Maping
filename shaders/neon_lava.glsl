precision mediump float;
varying vec2 vUV;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_zoom;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed * 0.7;

    vec2 p = uv;
    for (int i = 1; i < 5; i++) {
        float fi = float(i);
        p.x += 0.3 / fi * sin(fi * 3.0 * p.y + t + 0.3 * fi);
        p.y += 0.3 / fi * cos(fi * 3.0 * p.x + t + 0.3 * fi);
    }

    float v = sin(p.x * 4.0) * cos(p.y * 4.0);
    float glow = smoothstep(-0.5, 0.8, v);

    float hue = fract(0.05 + length(p) * 0.15 + u_hueShift);
    vec3 col = hsv2rgb(vec3(hue, 0.9, 1.0)) * glow;
    col += vec3(0.5, 0.05, 0.0) * pow(glow, 2.0);

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
