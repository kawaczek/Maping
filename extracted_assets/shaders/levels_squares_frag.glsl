#version 100
// Direct GLES port of the current iOS LevelsSquares.metal fragment.
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_density;
uniform float u_tileSize;
uniform float u_wave;
uniform float u_fold;
uniform float u_color;
uniform float u_glow;

float lsSat(float value) { return clamp(value, 0.0, 1.0); }
vec2 lsRotate(vec2 point, float angle) {
    float sine = sin(angle), cosine = cos(angle);
    return vec2(cosine * point.x - sine * point.y,
                sine * point.x + cosine * point.y);
}
float lsHash(vec2 point) {
    vec3 p3 = fract(vec3(point.x, point.y, point.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec3 lsHsv(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
float lsSquareDistance(vec2 point, float halfSize) {
    return max(abs(point.x), abs(point.y)) - halfSize;
}

void main() {
    vec2 resolution = max(u_resolution, vec2(1.0));
    vec2 point = vUV * 2.0 - 1.0;
    point.x *= resolution.x / resolution.y;

    float density = clamp(floor(u_density + 0.5), 4.0, 18.0);
    float waveAmount = lsSat(u_wave), foldAmount = lsSat(u_fold), glowAmount = lsSat(u_glow);
    vec2 waveOrigin = vec2(sin(u_time * 0.37), cos(u_time * 0.29 + 0.8)) * (0.42 * waveAmount);
    float globalWave = sin(length(point - waveOrigin) * mix(5.0, 11.0, waveAmount) - u_time * 2.15);
    point += vec2(sin(point.y * 3.2 + u_time * 0.72), cos(point.x * 2.8 - u_time * 0.61))
        * (0.055 * waveAmount);

    float gridScale = density * 0.5;
    vec2 gridPoint = point * gridScale;
    vec2 cell = floor(gridPoint);
    vec2 local = fract(gridPoint) - 0.5;
    vec2 cellCenter = (cell + 0.5) / gridScale;
    float cellNoise = lsHash(cell);
    float radialPhase = length(cellCenter - waveOrigin) * mix(7.0, 14.0, waveAmount)
        - u_time * 2.45 + cellNoise * 1.8;
    float tileWave = 0.5 + 0.5 * sin(radialPhase);
    float signedWave = tileWave * 2.0 - 1.0;

    float foldAngle = signedWave * mix(0.08, 1.12, foldAmount)
        + (cellNoise - 0.5) * (0.38 * foldAmount);
    local = lsRotate(local, foldAngle);
    float tilt = mix(1.0, 0.34 + 0.66 * abs(cos(radialPhase * 0.5)), foldAmount);
    local.y /= max(0.24, tilt);
    local.x += local.y * signedWave * (0.46 * foldAmount);

    float halfSize = mix(0.12, 0.47, lsSat(u_tileSize));
    float distance = lsSquareDistance(local, halfSize);
    float antialias = max(0.002, 2.2 * gridScale / resolution.y);
    float fill = 1.0 - smoothstep(-antialias, antialias, distance);
    float depth = (0.35 + 0.65 * tileWave) * foldAmount;
    vec2 shadowPoint = local + vec2(-0.075, 0.095) * depth;
    float shadowFill = 1.0 - smoothstep(-antialias, antialias, lsSquareDistance(shadowPoint, halfSize));
    float side = max(shadowFill - fill, 0.0);

    float backgroundWave = 0.5 + 0.5 * globalWave;
    vec3 background = lsHsv(vec3(u_color + 0.53 + backgroundWave * 0.04,
        0.68, 0.025 + backgroundWave * (0.045 * waveAmount)));
    float hue = u_color + cell.x * 0.037 + cell.y * 0.061
        + tileWave * (0.20 * waveAmount) + u_time * 0.018;
    vec3 tileColor = lsHsv(vec3(hue, mix(0.72, 0.96, foldAmount), 0.56 + tileWave * 0.44));
    vec3 sideColor = lsHsv(vec3(hue + 0.12, 0.92, 0.24 + tileWave * 0.20));
    float edge = exp(-abs(distance) * 34.0);
    float diagonal = abs(local.x + local.y - signedWave * 0.08);
    float highlight = pow(lsSat(1.0 - diagonal * 3.2), 10.0) * fill
        * mix(0.12, 0.75, foldAmount) * tileWave;

    vec3 color = mix(background, sideColor, side);
    color = mix(color, tileColor, fill);
    color += tileColor * edge * mix(0.05, 0.48, glowAmount);
    color += vec3(1.0, 0.94, 1.0) * highlight;
    gl_FragColor = vec4(1.0 - exp(-color * 1.18), 1.0);
}
