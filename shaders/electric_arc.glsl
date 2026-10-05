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

    float t = u_time * u_timeSpeed * 1.5;

    float lightning = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float offset = sin(uv.y * 5.0 + t * 2.0 + fi * 2.0) * 0.2
                     + sin(uv.y * 12.0 - t * 3.0) * 0.08
                     + sin(uv.y * 25.0 + t * 4.0) * 0.03;
        float d = abs(uv.x - offset + (fi - 1.0) * 0.4);
        lightning += 0.015 / (d + 0.01);
    }

    float hue = fract(0.58 + u_hueShift);
    vec3 col = hsv2rgb(vec3(hue, 0.8, 1.0)) * lightning;
    col += vec3(0.02, 0.01, 0.06);
    col *= u_brightness;

    gl_FragColor = vec4(col, 1.0);
}
