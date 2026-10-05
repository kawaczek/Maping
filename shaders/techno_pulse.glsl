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

    float t = u_time * u_timeSpeed * 1.2;
    float dist = length(uv);

    // Geometryczne pierścienie i wielokąty
    float rings = sin(dist * 18.0 - t * 4.0);
    float pulse = exp(-fract(t * 0.5) * 3.0); // uderzenie basu
    
    float angle = atan(uv.y, uv.x);
    float sectors = sin(angle * 8.0 + t);

    float val = smoothstep(0.4, 0.9, rings * sectors + pulse * 0.4);

    float hue = fract(0.75 + dist * 0.15 + u_hueShift);
    vec3 col = hsv2rgb(vec3(hue, 0.9, 1.0)) * val;

    col += vec3(0.1, 0.0, 0.2) * (1.0 - dist * 0.5);
    col *= u_brightness;

    gl_FragColor = vec4(col, 1.0);
}
