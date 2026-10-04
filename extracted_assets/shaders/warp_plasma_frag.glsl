#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_warpAmount;
uniform float u_warpSpeed;
uniform float u_warpPhase;
uniform float u_scale;
uniform float u_fbmOctaves;
uniform float u_contrast;
uniform float u_brightness;
uniform float u_hueShift;
uniform float u_hueSpeed;
uniform float u_huePhase;
uniform float u_alphaAmount;
uniform float u_swirl;

float wp_hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wp_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = wp_hash(i);
    float b = wp_hash(i + vec2(1.0, 0.0));
    float c = wp_hash(i + vec2(0.0, 1.0));
    float d = wp_hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 wp_rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float wp_fbm(vec2 p, float oct) {
    float f = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 6; i++) {
        f += amp * wp_noise(p);
        p = wp_rot(p * 2.1, 0.4);
        amp *= 0.55;
        if (float(i) > oct) break;
    }
    return f;
}

vec3 wp_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = vUV;
    float t = u_warpPhase;

    vec2 p = (uv - 0.5) * 2.0;
    p.x *= res.x / res.y;

    float r = length(p);
    float ang = atan(p.y, p.x);
    ang += r * u_swirl;
    p = vec2(cos(ang), sin(ang)) * r;

    p *= u_scale;

    vec2 w = vec2(
        wp_fbm(p + vec2(0.0, t), u_fbmOctaves),
        wp_fbm(p + vec2(7.2, -t), u_fbmOctaves)
    );
    p += w * u_warpAmount;

    float shade = wp_fbm(p, u_fbmOctaves);
    shade = pow(clamp(shade, 0.0, 1.0), u_contrast);

    float hue = fract(u_hueShift + shade + u_huePhase);
    vec3 col = wp_hsv2rgb(vec3(hue, 0.9, 1.0));
    col *= u_brightness;

    float alpha = clamp(shade * u_alphaAmount, 0.0, 1.0);
    gl_FragColor = vec4(col, alpha);
}
