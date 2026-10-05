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
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // 8-krotna symetria kalejdoskopowa
    float sectors = 8.0;
    angle = abs(mod(angle, 6.28318 / sectors) - 3.14159 / sectors);
    vec2 kUV = vec2(cos(angle), sin(angle)) * dist;

    float pattern = sin(kUV.x * 12.0 + t) * cos(kUV.y * 12.0 - t * 0.7);
    pattern += sin(dist * 16.0 - t * 2.0) * 0.5;
    float flower = smoothstep(-0.2, 0.8, pattern);

    float hue = fract(0.92 + dist * 0.2 + u_hueShift);
    vec3 col = hsv2rgb(vec3(hue, 0.75, 1.0)) * flower;
    col += vec3(0.08, 0.02, 0.06);
    col *= u_brightness;

    gl_FragColor = vec4(col, 1.0);
}
