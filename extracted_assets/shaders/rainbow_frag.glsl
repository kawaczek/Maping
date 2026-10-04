#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_speed;
uniform float u_rotation;
uniform float u_width;
uniform float u_hueShift;
uniform float u_darkness;
uniform float u_contrast;

const float RB_TAU = 6.28318530718;

float rb_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 rb_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }
vec3 rb_applyContrast(vec3 c, float contrast) {
    return (c - 0.5) * contrast + 0.5;
}

vec3 rb_cosPalette(float phase, float hueShift) {
    float x = RB_TAU * (phase + hueShift);
    vec3 offs = vec3(0.0, 2.09439510239, 4.18879020479);
    return 0.5 + 0.5 * cos(vec3(x) + offs);
}

void main() {
    vec2 uv = vUV;
    float ang = u_rotation * RB_TAU;
    vec2 dir = normalize(vec2(cos(ang), sin(ang)));
    vec2 p = uv - vec2(0.5, 0.5);
    float s = dot(p, dir);

    float cycles = max(0.0001, u_width);
    float phase = (s * cycles) + (u_time * u_speed);
    vec3 rgb = rb_cosPalette(phase, u_hueShift);

    float d = rb_sat(u_darkness);
    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb = mix(rgb, vec3(luma), d * 0.55);
    rgb *= (1.0 - d * 0.65);

    rgb = rb_applyContrast(rgb, clamp(u_contrast, 0.0, 3.0));
    rgb = rb_sat3(rgb);

    gl_FragColor = vec4(rgb, 1.0);
}
