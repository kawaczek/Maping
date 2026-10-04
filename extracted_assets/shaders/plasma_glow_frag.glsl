#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_rotXSpeed;
uniform float u_rotYSpeed;
uniform float u_rotXPhase;
uniform float u_rotYPhase;
uniform float u_zoom;
uniform float u_iterations;
uniform float u_scale;
uniform float u_frequency;
uniform float u_complexity;
uniform float u_hueShift;
uniform float u_colorBoost;
uniform float u_brightness;
uniform float u_scaleGrowth;
uniform float u_spark;
uniform float u_coreBias;
uniform float u_freqPhase;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 uvTo3D(vec2 uv) {
    float theta = uv.x * 6.283185307;
    float phi = uv.y * 3.141592654;
    float x = sin(phi) * cos(theta);
    float y = sin(phi) * sin(theta);
    float z = cos(phi);
    return vec3(x, y, z);
}

mat3 rotateAxis(vec3 axis, float angle) {
    axis = normalize(axis);
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;
    return mat3(
        t*axis.x*axis.x + c,      t*axis.x*axis.y + s*axis.z,  t*axis.x*axis.z - s*axis.y,
        t*axis.x*axis.y - s*axis.z, t*axis.y*axis.y + c,       t*axis.y*axis.z + s*axis.x,
        t*axis.x*axis.z + s*axis.y, t*axis.y*axis.z - s*axis.x, t*axis.z*axis.z + c
    );
}

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

void main() {
    vec2 uv = vUV;
    float t = u_time;

    vec3 pos = uvTo3D(uv);
    vec3 p = pos * max(u_zoom, 0.001);

    vec3 n = vec3(0.0);
    vec3 N = vec3(0.0);

    float S = max(u_scale, 0.001);
    float growth = max(u_scaleGrowth, 1.001);

    int iters = int(clamp(u_iterations, 1.0, 60.0));

    float ax = 2.0 + sin(u_rotXPhase * 0.35);
    float ay = 1.0 + cos(u_rotYPhase * 0.35);

    mat3 m = rotateAxis(vec3(0.0, 1.0, 0.0), ay) * rotateAxis(vec3(1.0, 0.0, 0.0), ax);

    float jitter = (hash1(uv.x*123.4 + uv.y*456.7) - 0.5) * 0.15;

    for (int i = 0; i < 60; i++) {
        if (i >= iters) break;
        float j = float(i) + 1.0;

        p = m * p;
        n = m * n;

        vec3 q = p * S + (j + jitter) + n + u_freqPhase;

        n += sin(q) * u_complexity;
        N += cos(q) / S;

        S *= growth;
    }

    float sumN = (N.x + N.y);
    float invLen = 1.0 / max(length(N), 1e-5);

    float base = (sumN + u_coreBias);
    float sparks = u_spark * invLen;

    float intensity = base + sparks;

    float hue = fract(intensity * 0.12 + u_hueShift);
    float v = clamp(0.6 + 0.6 * intensity, 0.0, 1.0);
    vec3 col = hsv2rgb(vec3(hue, 0.95, v));

    col *= vec3(3.0, 2.0, 4.0);
    col *= (1.0 + intensity * u_colorBoost);
    col *= u_brightness;

    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float alpha = smoothstep(0.25, 1.25, lum);
    alpha = clamp(alpha, 0.0, 1.0);

    if (alpha < 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }
    gl_FragColor = vec4(col, alpha);
}
