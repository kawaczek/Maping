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

    float t = u_time * u_timeSpeed * 0.4;

    float wave1 = sin(uv.x * 2.5 + t + sin(uv.y * 2.0 + t * 0.7));
    float wave2 = cos(uv.y * 3.0 - t * 0.9 + cos(uv.x * 2.0 + t * 0.5));
    float aurora = sin(wave1 + wave2 + uv.y * 1.5);
    aurora = smoothstep(-0.2, 0.8, aurora);

    float hue = fract(0.45 + uv.x * 0.1 + u_hueShift);
    vec3 color = hsv2rgb(vec3(hue, 0.85, 1.0)) * aurora;
    
    // Delikatna ciemna poświata w tle
    color += vec3(0.02, 0.05, 0.1) * (1.0 - uv.y * 0.5);
    color *= u_brightness;

    gl_FragColor = vec4(color, 1.0);
}
