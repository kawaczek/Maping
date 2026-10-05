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

    float t = u_time * u_timeSpeed * 0.5;

    vec2 p = uv * 3.0;
    for (int i = 1; i < 4; i++) {
        float fi = float(i);
        vec2 newP = p;
        newP.x += 0.6 / fi * sin(fi * p.y + t + 0.3 * fi);
        newP.y += 0.6 / fi * cos(fi * p.x + t + 0.3 * fi);
        p = newP;
    }

    float caustics = sin(p.x + p.y + t) * sin(p.x - p.y - t);
    caustics = pow(clamp(caustics + 0.5, 0.0, 1.0), 3.0);

    float hue = fract(0.52 + u_hueShift);
    vec3 waterBase = vec3(0.01, 0.08, 0.2);
    vec3 waterLight = hsv2rgb(vec3(hue, 0.7, 1.0));

    vec3 col = mix(waterBase, waterLight, caustics);
    col *= u_brightness;

    gl_FragColor = vec4(col, 1.0);
}
