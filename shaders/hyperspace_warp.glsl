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

    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    float t = u_time * u_timeSpeed * 1.5;

    // Prędkość podróży w głąb tunelu
    float speed = t + 1.0 / (dist + 0.05);
    
    // Gwiezdne pasy i promienie
    float stars = sin(angle * 16.0 + sin(dist * 10.0 - t * 2.0));
    stars = pow(clamp(stars, 0.0, 1.0), 4.0);

    float rings = sin(dist * 20.0 - t * 4.0);
    rings = smoothstep(0.4, 0.95, rings);

    float intensity = (stars * 0.8 + rings * 0.5) / (dist + 0.3);

    float hue = fract(0.6 + dist * 0.2 + u_hueShift);
    vec3 col = hsv2rgb(vec3(hue, 0.8, 1.0)) * intensity;

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
