#version 100
precision highp float;
varying vec2 vUV;

uniform float u_timeFlow;
uniform float u_spinPhase;
uniform float u_flowPhase;
uniform float u_palettePhase;
uniform vec2 u_resolution;
uniform float u_zoom;
uniform float u_rotation;
uniform float u_texScale;
uniform float u_texWarp;
uniform float u_texSpin;
uniform float u_texFlow;
uniform float u_texContrast;
uniform float u_hueShift;
uniform float u_rainbow;
uniform float u_intensity;
uniform float u_alphaCut;
uniform float u_alphaSoft;

const float DTX_PI = 3.141592654;
const float DTX_TAU = 6.283185308;

float dtx_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 dtx_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }

vec2 dtx_rot(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 dtx_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 dtx_cosPalette(float t) {
    return (1.0 + cos(vec3(0.0, 1.0, 2.0) + DTX_TAU * t)) * 0.5;
}

float dtx_psyField(vec2 p, float timeFlow, float flowPhase, float spinPhase, float scale, float warp, float spin, float flow) {
    vec2 q = p * scale;
    q += warp * vec2(sin(1.1 * q.y + 0.9 * flowPhase), cos(1.0 * q.x + 0.8 * flowPhase));
    float a = 0.35 * spinPhase;
    q = dtx_rot(q, a);
    float v = 0.0;
    v += sin(q.x + 0.63 * timeFlow);
    v += sin(1.3 * q.y - 0.41 * timeFlow);
    v += sin(0.9 * (q.x + q.y) + 0.27 * timeFlow);
    v *= 0.3333;
    return 0.5 + 0.5 * sin(2.2 * v);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 q = vUV;
    vec2 p = -1.0 + 2.0 * q;
    p.x *= (res.x / res.y);

    float t = u_timeFlow;
    p /= max(0.05, u_zoom);
    float rotA = (u_rotation * DTX_TAU);
    p = dtx_rot(p, rotA);

    float texScale = clamp(u_texScale, 0.25, 8.0);
    float texWarp = clamp(u_texWarp, 0.0, 4.0);
    float texSpin = clamp(u_texSpin, 0.0, 8.0);
    float texFlow = clamp(u_texFlow, 0.0, 8.0);
    float texC = clamp(u_texContrast, 0.0, 3.0);

    float field = dtx_psyField(p, u_timeFlow, u_flowPhase, u_spinPhase, texScale, texWarp, texSpin, texFlow);

    field = pow(clamp(field, 0.0, 1.0), max(0.25, 1.6 - 0.5 * texC));
    field = mix(field, smoothstep(0.20, 0.80, field), dtx_sat(texC));

    float palT = (0.35 * u_palettePhase) + field + u_hueShift;
    vec3 schemeA = dtx_cosPalette(palT);
    vec3 schemeB = dtx_hsv2rgb(vec3(fract(palT), 1.0, 1.0));
    vec3 col = mix(schemeA, schemeB, dtx_sat(u_rainbow));

    col *= max(0.0, u_intensity);
    col = dtx_sat3(col);

    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    float cut = clamp(u_alphaCut, 0.0, 0.6);
    float soft = clamp(u_alphaSoft, 0.01, 0.6);
    float a = smoothstep(cut, cut + soft, luma);

    col *= a;
    if (a <= 0.00005) {
        gl_FragColor = vec4(0.0);
        return;
    }
    gl_FragColor = vec4(col, a);
}
