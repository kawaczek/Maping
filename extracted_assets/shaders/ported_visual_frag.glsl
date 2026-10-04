#version 100
precision highp float;

varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_variant;
uniform float u_p1;
uniform float u_p2;
uniform float u_p3;
uniform float u_p4;
uniform float u_p5;
uniform float u_p6;
uniform float u_p7;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const vec2 PIXEL_GRID = vec2(36.0, 64.0);

float sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sat3(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }

vec2 rot(vec2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 hsv(float h, float s, float v) {
    vec3 p = abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return v * mix(vec3(1.0), clamp(p - 1.0, vec3(0.0), vec3(1.0)), s);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    float total = 0.0;
    for (int i = 0; i < 5; i++) {
        v += noise(p) * a;
        total += a;
        p = rot(p, 1.08) * 1.82 + 0.17;
        a *= 0.52;
    }
    return v / max(total, 0.0001);
}

float pulseLine(float x, float width) {
    float d = abs(fract(x) - 0.5);
    return 1.0 - smoothstep(width, width + 0.032, d);
}

float lineAt(float x, float width) {
    return 1.0 - smoothstep(width, width + 0.018, abs(x));
}

vec2 aspectSpace(vec2 uv, float scale) {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 p = uv * 2.0 - 1.0;
    p.x *= res.x / res.y;
    return p * max(scale, 0.05);
}

vec4 alphaFinish(vec3 color, float body, float opacity) {
    vec3 col = sat3(color);
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    return vec4(col, sat(opacity) * sat(0.24 + 0.76 * max(lum, body)));
}

vec4 psychEffect(float variant) {
    float color = u_p1;
    float speed = u_p2;
    float petals = u_p3;
    float rings = u_p4;
    float warp = u_p5;
    float layers = u_p6;
    float glow = u_p7;

    vec2 p = aspectSpace(vUV, 1.0);
    float t = u_time;
    p = rot(p, sin(t * 0.18 + variant) * warp * 0.45);
    p += vec2(sin(p.y * 3.5 + t * 0.55), cos(p.x * 3.1 - t * 0.42)) * warp * 0.12;

    float r = length(p) + 0.001;
    float a = atan(p.y, p.x);
    float petalCount = floor(mix(4.0, 15.0, petals) + variant * 0.35);
    float fold = abs(cos(a * petalCount * 0.5 + sin(r * 6.0 - t) * warp));
    float folded = pow(fold, mix(0.8, 5.2, layers));
    float tunnel = mix(r * mix(4.0, 14.0, rings), 1.0 / (r + 0.12), step(1.5, variant));
    // Speed is already integrated into t on the CPU. Keeping it out of the
    // shape equation prevents the pattern from relocating while the slider moves.
    float ribbon = tunnel + folded * mix(0.25, 1.3, warp) - t * 0.55;

    float bright = pulseLine(ribbon, mix(0.24, 0.048, glow));
    float dark = pulseLine(ribbon + 0.5 + fold * 0.05, mix(0.13, 0.030, glow));
    float center = exp(-r * mix(3.0, 8.5, glow));
    float outer = 1.0 - smoothstep(1.08, 1.82, r);
    float body = sat((bright * 0.92 + folded * 0.42 + center * 0.38) * outer);

    float hueSignal = ribbon * 0.055 + fold * 0.18 + r * 0.08;
    vec3 aCol = hsv(color + hueSignal + 0.03, mix(0.48, 0.86, petals), body + 0.10);
    vec3 bCol = hsv(color + hueSignal + 0.36, mix(0.50, 0.92, rings), body * 0.95 + 0.05);
    vec3 cCol = hsv(color + hueSignal + 0.86, 0.78, body * 0.76 + center * 0.20);
    vec3 col = mix(aCol, bCol, folded);
    col = mix(col, cCol, smoothstep(0.30, 0.96, bright * (0.4 + folded)));
    col *= 1.0 - dark * mix(0.50, 0.94, glow);
    col += hsv(color + 0.08, 0.42, center * (0.35 + glow * 0.65));

    if (variant > 3.5) {
        col = mix(col, hsv(color + hueSignal + 0.14, 0.45, body + 0.25), 0.35 + 0.35 * sin(p.x * 4.0 + p.y * 2.0 + t));
    } else if (variant > 2.5) {
        float liquid = fbm(vec2(a * 0.8 + t * 0.08, r * 6.0 - t * 0.1));
        col = mix(col, hsv(color + liquid * 0.46, 0.72, body + liquid * 0.22), 0.45);
    }

    return vec4(sat3(col), 1.0);
}

vec4 contourEffect() {
    float color = u_p1;
    float speed = u_p2;
    float scale = mix(1.4, 6.2, u_p3);
    float bands = mix(5.0, 20.0, u_p4);
    float flow = u_p5;
    float sharp = u_p6;
    float glow = u_p7;

    vec2 p = aspectSpace(vUV, scale);
    float t = u_time;
    float n = fbm(p * (0.55 + flow) + vec2(t * 0.22, -t * 0.15));
    n += 0.36 * sin(p.x * 1.7 + p.y * 1.1 + t * 1.3);
    float level = fract(n * bands);
    float line = 1.0 - smoothstep(mix(0.18, 0.035, sharp), mix(0.24, 0.070, sharp), abs(level - 0.5));
    float body = sat(line + pow(n, 3.0) * glow * 0.3);
    vec3 col = hsv(color + n * 0.28 + t * 0.015, 0.86, body * (0.55 + glow));
    col += hsv(color + 0.48, 0.9, line * line * glow * 0.5);
    return vec4(sat3(col), 1.0);
}

vec4 squareSequenceEffect() {
    float color = u_p1;
    float speed = u_p2;
    float tiles = mix(4.0, 18.0, u_p3);
    float ringWidth = mix(0.06, 0.28, u_p4);
    float wave = u_p5;
    float echo = u_p6;
    float glow = u_p7;

    vec2 grid = floor(vUV * tiles);
    vec2 cell = fract(vUV * tiles) - 0.5;
    float t = u_time;
    float dist = max(abs(cell.x), abs(cell.y));
    float phase = hash12(grid) * 2.5 + t + sin((grid.x + grid.y) * 0.4 + t) * wave;
    float ring = pulseLine(dist * mix(3.5, 8.0, echo) - phase, ringWidth);
    float fill = step(dist, mix(0.14, 0.46, echo)) * (0.25 + 0.75 * ring);
    float body = sat(ring + fill * 0.7);
    vec3 col = hsv(color + hash12(grid) * 0.22 + phase * 0.035, 0.86, body * (0.65 + glow * 0.55));
    return vec4(sat3(col), sat(0.25 + body));
}

vec4 cloudscapeEffect() {
    float color = u_p1;
    float speed = u_p2;
    float scale = mix(1.4, 5.5, u_p3);
    float coverage = u_p4;
    float depth = u_p5;
    float turbulence = u_p6;
    float glow = u_p7;

    vec2 p = aspectSpace(vUV, scale);
    float t = u_time;
    float n1 = fbm(p * 0.8 + vec2(t * 0.05, -t * 0.03));
    float n2 = fbm(p * (1.8 + turbulence * 1.4) - vec2(t * 0.12, t * 0.04));
    float cloud = smoothstep(coverage * 0.9, 1.0, n1 * 0.75 + n2 * 0.35);
    float soft = smoothstep(coverage * 0.45, 1.0, n1);
    vec3 sky = hsv(color + 0.54, 0.55, 0.18 + depth * 0.25);
    vec3 cloudCol = hsv(color + n2 * 0.10, 0.42, 0.55 + glow * 0.55);
    vec3 col = mix(sky, cloudCol, sat(cloud + soft * depth * 0.45));
    col += hsv(color + 0.08, 0.35, cloud * cloud * glow * 0.35);
    return vec4(sat3(col), 1.0);
}

vec4 synthwaveEffect(float variant) {
    float color = u_p1;
    float speed = u_p2;
    float density = u_p3;
    float depth = u_p4;
    float glow = u_p5;
    float warp = u_p6;
    float detail = u_p7;

    vec2 p = aspectSpace(vUV, 1.0);
    float t = u_time;
    p.x += sin(p.y * 4.0 + t) * warp * 0.12;

    float horizon = -0.12 + depth * 0.22;
    float floorMask = 1.0 - smoothstep(-0.95, horizon, p.y);
    float perspective = 1.0 / max(0.08, p.y - horizon + 0.62);
    vec2 gp = vec2(p.x * perspective, perspective + t * (0.35 + density));
    float gridX = pulseLine(gp.x * mix(3.0, 9.0, density), mix(0.030, 0.012, glow));
    float gridY = pulseLine(gp.y * mix(2.0, 8.0, detail), mix(0.035, 0.014, glow));
    float grid = max(gridX, gridY) * floorMask;

    float sun = 0.0;
    vec2 sunP = p - vec2(0.0, 0.20 + depth * 0.15);
    float sr = length(sunP);
    sun = 1.0 - smoothstep(0.18, 0.42, sr);
    float bands = step(0.50, fract((sunP.y + t * 0.08) * mix(8.0, 18.0, density)));
    sun *= mix(1.0, bands, step(7.5, variant));

    float rain = 0.0;
    if (variant > 10.5) {
        vec2 rp = vUV * vec2(18.0 + density * 30.0, 6.0);
        float lane = hash12(vec2(floor(rp.x), 3.0));
        rain = step(0.78, lane) * lineAt(fract(rp.y + t * (0.8 + lane)) - 0.5, 0.08);
    }

    float tunnel = 0.0;
    if (variant > 8.5 && variant < 9.5) {
        float r = length(p) + 0.02;
        float a = atan(p.y, p.x) / TAU;
        tunnel = max(pulseLine(1.0 / r + t * 0.7, 0.08), pulseLine(a * 10.0, 0.04));
    }

    vec3 base = hsv(color + p.y * 0.10, 0.75, 0.05 + floorMask * 0.18);
    vec3 neon = hsv(color + 0.55 + t * 0.02, 0.95, grid * (0.6 + glow));
    vec3 sunCol = hsv(color + 0.08, 0.75, sun * (0.8 + glow * 0.5));
    vec3 chrome = vec3(sat(grid + tunnel)) * (0.45 + detail);
    vec3 col = base + neon + sunCol + hsv(color + 0.42, 0.9, rain * glow);
    if (variant > 9.5 && variant < 10.5) col = mix(col, chrome + sunCol * 0.35, 0.55);
    col += hsv(color + 0.70, 0.9, tunnel * glow);
    return vec4(sat3(col), 1.0);
}

vec4 circleSequenceEffect() {
    float color = u_p1;
    float speed = u_p2;
    float cellSize = mix(5.0, 18.0, u_p3);
    float ringWidth = mix(0.08, 0.28, u_p4);
    float sequence = u_p5;
    float bloom = u_p6;
    float evolution = u_p7;

    vec2 grid = floor(vUV * cellSize);
    vec2 cell = fract(vUV * cellSize) - 0.5;
    float t = u_time;
    float r = length(cell);
    float order = hash12(grid);
    float phase = t + order * mix(1.0, 6.0, sequence) + evolution * sin(t + grid.x);
    float ring = pulseLine(r * mix(3.0, 9.0, ringWidth) - phase, mix(0.16, 0.05, bloom));
    float disk = (1.0 - smoothstep(0.08, 0.45, r)) * (0.20 + 0.80 * ring);
    float body = sat(ring + disk * bloom);
    vec3 col = hsv(color + order * 0.22 + phase * 0.025, 0.86, body * (0.7 + bloom));
    return vec4(sat3(col), sat(0.20 + body));
}

vec4 smoothSquiggleEffect() {
    float spacing = u_p1;
    float thickness = u_p2;
    float speed = u_p3;
    float warp = u_p4;
    float squareAmount = u_p5;
    float hue = u_p6;
    float colorTravel = u_p7;

    vec2 p = aspectSpace(vUV, 1.0);
    float t = u_time;
    p += vec2(sin(p.y * 4.0 + t), cos(p.x * 3.8 - t)) * warp * 0.16;
    float circleR = length(p);
    float squareR = max(abs(p.x), abs(p.y));
    float d = mix(circleR, squareR, squareAmount);
    float waves = d / max(spacing, 0.001) + sin(p.x * 3.0 + t) * warp * 0.7;
    float line = pulseLine(waves, thickness * 0.35);
    float travel = colorTravel * (waves * 0.035 + t * 0.05);
    vec3 col = hsv(hue + travel, 0.88, line * 1.08);
    return vec4(sat3(col), sat(0.22 + line));
}

vec4 vhsEffect() {
    float color = u_p1;
    float speed = u_p2;
    float flow = u_p3;
    float waveDepth = u_p4;
    float bandPush = u_p5;
    float tear = u_p6;
    float glow = u_p7;

    vec2 uv = vUV;
    float t = u_time;
    float row = floor(uv.y * mix(45.0, 140.0, bandPush));
    uv.x += sin(uv.y * 32.0 + t * 2.5) * waveDepth * 0.025;
    uv.x += (hash12(vec2(row, floor(t * 12.0))) - 0.5) * tear * 0.055;
    vec2 p = aspectSpace(uv, mix(2.0, 6.0, flow));
    float n = fbm(p + vec2(t * 0.12, -t * 0.05));
    float contour = pulseLine(n * mix(5.0, 18.0, bandPush) + uv.y * 4.0, mix(0.18, 0.05, glow));
    float scan = step(0.48, fract(vUV.y * 180.0));
    vec3 col = hsv(color + n * 0.24, 0.75, contour * (0.75 + glow * 0.5));
    col *= mix(0.58, 1.0, scan);
    col.r += contour * tear * 0.18;
    col.b += contour * waveDepth * 0.18;
    return vec4(sat3(col), sat(0.20 + contour));
}

vec4 abstractEffect(float variant) {
    float color = u_p1;
    float rainbow = u_p2;
    float motion = u_p3;
    float density = u_p4;
    float shape = u_p5;
    float warp = u_p6;
    float detail = u_p7;

    vec2 p = aspectSpace(vUV, mix(1.2, 4.8, density));
    float t = u_time * motion;
    float local = variant - 15.0;
    p = rot(p, t * 0.08 + local * 0.21);
    p += vec2(sin(p.y * (2.0 + detail * 5.0) + t), cos(p.x * (2.0 + detail * 4.0) - t)) * warp * 0.22;
    float r = length(p) + 0.001;
    float a = atan(p.y, p.x);
    float n = fbm(p * (1.0 + detail * 2.5) + vec2(t * 0.12, -t * 0.08));

    float body = n;
    if (local < 1.5) {
        body = pulseLine(1.0 / (r + 0.12) + t * 0.45 + n, mix(0.18, 0.06, shape));
    } else if (local < 2.5) {
        body = smoothstep(0.30, 0.86, n + shape * 0.25) * exp(-r * 0.9);
    } else if (local < 3.5) {
        body = max(pulseLine(a / TAU * mix(6.0, 16.0, density) + n, 0.09), pulseLine(r * mix(5.0, 16.0, shape) - t, 0.08));
    } else if (local < 4.5) {
        body = smoothstep(0.25, 0.82, n) * (1.0 - smoothstep(1.2, 2.0, r));
    } else if (local < 5.5) {
        body = pulseLine(max(abs(p.x), abs(p.y)) * mix(4.0, 12.0, density) + n - t * 0.5, mix(0.20, 0.06, detail));
    } else if (local < 6.5) {
        body = pulseLine(a / TAU * mix(4.0, 12.0, shape) + r * 2.0 - t * 0.28 + n, 0.10);
    } else if (local < 9.5) {
        float pulse = sin(t * 2.0 - r * mix(6.0, 18.0, density));
        body = smoothstep(0.28, 0.95, pulse * 0.5 + 0.5 + n * 0.35);
        body *= pulseLine(a / TAU * mix(5.0, 18.0, detail) + n, mix(0.15, 0.05, shape)) + 0.25;
    } else {
        body = pulseLine(p.x * mix(3.0, 12.0, density) + sin(p.y * 4.0 + t) * warp - t * 0.4, mix(0.18, 0.05, detail));
    }

    float hue = color + n * 0.22 + a / TAU * 0.20 + t * 0.018;
    vec3 mono = hsv(color, 0.42, body);
    vec3 rain = hsv(hue, 0.88, body * (0.75 + detail * 0.55));
    vec3 col = mix(mono, rain, rainbow);
    col += hsv(color + 0.48, 0.92, body * body * warp * 0.38);
    return vec4(sat3(col), sat(0.22 + body));
}

vec2 pixelUV(vec2 uv) {
    vec2 cell = floor(clamp(uv, vec2(0.0), vec2(0.999)) * PIXEL_GRID);
    return (cell + 0.5) / PIXEL_GRID;
}

vec2 pixelCell(vec2 uv) {
    return floor(clamp(uv, vec2(0.0), vec2(0.999)) * PIXEL_GRID);
}

vec2 pixelSpace(vec2 uv, float scale) {
    return aspectSpace(uv, max(0.2, scale));
}

vec4 pixelFinish(vec2 rawUV, vec3 color, float body) {
    vec2 local = fract(clamp(rawUV, vec2(0.0), vec2(0.999)) * PIXEL_GRID);
    float edge = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
    float grout = step(0.038, edge);
    vec3 outColor = color * max(0.0, u_p4);
    outColor *= mix(0.66, 1.0, grout);
    outColor = (outColor - 0.5) * clamp(u_p5, 0.0, 3.0) + 0.5;
    return alphaFinish(outColor, body, u_p7);
}

vec4 pixelEffect(float variant) {
    vec2 uv = pixelUV(vUV);
    vec2 p = pixelSpace(uv, u_p3);
    float t = u_time * u_p2;
    float motion = sat(u_p6);
    float id = variant - 26.0;
    float r = length(p) + 0.001;
    float a = atan(p.y, p.x);
    float body = 0.0;
    vec3 col = vec3(0.0);

    if (id < 0.5) {
        float twist = mix(2.2, 7.5, motion);
        float wave = sin(a * 3.0 + r * twist * 3.1 - t * TAU);
        float hue = u_p1 + a / TAU + r * 0.46 + wave * 0.075 + t * 0.055;
        body = 0.68 + 0.32 * step(0.0, wave);
        col = hsv(hue, 0.96, body);
    } else if (id < 1.5) {
        float tunnel = 1.0 / (r + 0.14) + t * 0.60;
        float stripe = step(0.5, fract(tunnel * mix(3.0, 8.0, motion) + a / TAU * 5.0));
        float shard = step(0.58, fract((abs(p.x) + abs(p.y)) * 5.5 + u_time * motion * 1.5));
        body = sat(0.40 + 0.38 * stripe + 0.28 * shard + (1.0 - smoothstep(0.0, 1.2, r)) * 0.18);
        col = hsv(u_p1 + tunnel * 0.08 + a / TAU * 0.55 + stripe * 0.18, 0.92, body);
    } else if (id < 2.5) {
        vec2 wobble = sin(p.yx * 3.0 + u_time * motion * 2.2) * (0.14 + 0.42 * motion);
        vec2 g = p * 3.6 + wobble + t * vec2(0.35, -0.22);
        float check = fract((floor(g.x) + floor(g.y)) * 0.5) * 2.0;
        float ripple = sin((g.x - g.y) * 2.2 + t * 5.0);
        body = mix(0.52, 0.98, check) * (0.82 + 0.18 * step(0.0, ripple));
        col = hsv(u_p1 + check * 0.31 + ripple * 0.055, 0.98, body);
    } else if (id < 3.5) {
        float aa = atan(p.y, p.x) / TAU + 0.5;
        float segments = mix(5.0, 13.0, motion);
        float wedge = abs(fract(aa * segments + t * 0.18) - 0.5) * 2.0;
        float ray = step(0.34 + 0.18 * sin(t * 4.0 + r * 8.0), wedge);
        float ring = step(0.5, fract(r * 6.5 - t * 1.2));
        body = sat(0.35 + ray * 0.38 + ring * 0.22 + (1.0 - smoothstep(0.0, 1.0, r)) * 0.22);
        col = hsv(u_p1 + wedge * 0.42 + r * 0.33 + ray * 0.16, 0.95, body);
    } else if (id < 4.5) {
        float swirl = a + r * mix(4.5, 11.0, motion) - t * 3.4;
        float arm = step(0.5, fract(swirl / TAU * 5.0));
        float ring = step(0.52, fract(r * 10.0 - u_time * motion * 1.8));
        float core = 1.0 - smoothstep(0.0, 0.95, r);
        body = sat(0.28 + arm * 0.36 + ring * 0.28 + core * 0.34);
        col = hsv(u_p1 + swirl / TAU * 0.28 + ring * 0.23 + r * 0.18, 0.98, body);
    } else if (id < 5.5) {
        vec2 cell = pixelCell(vUV);
        float rays = sin(a * mix(7.0, 19.0, motion) + u_time * motion * 2.8 + r * 3.0) * 0.5 + 0.5;
        float ray = step(0.61, rays);
        float spark = step(0.88, hash12(cell + floor(t * 5.0)));
        float core = 1.0 - smoothstep(0.0, 1.25, r);
        body = sat(0.25 + core * 0.55 + ray * 0.30 + spark * 0.25);
        col = hsv(u_p1 + 0.04 + r * 0.10 + spark * 0.10, mix(0.62, 0.96, sat(ray + spark)), body);
    } else if (id < 6.5) {
        vec2 cell = pixelCell(vUV);
        float v = sin(p.x * 3.0 + t * 2.4);
        v += sin(p.y * 4.3 - u_time * motion * 2.0);
        v += sin((p.x + p.y) * 2.2 + t * 1.3);
        v += (hash12(cell) - 0.5) * 0.55 * motion;
        float n = v * 0.166 + 0.5;
        body = 0.50 + 0.50 * sat(n);
        col = hsv(u_p1 + n * 0.42 + t * 0.035, 0.93, body);
    } else {
        float squareRadius = max(abs(p.x), abs(p.y));
        float ringCount = mix(5.0, 16.0, sat(u_p3 / 3.0));
        float zoomSpeed = mix(0.35, 2.20, motion);
        float tunnel = squareRadius * ringCount - t * zoomSpeed;
        float ring = fract(tunnel);
        float ringID = floor(tunnel);
        float lineWidth = mix(0.075, 0.18, motion);
        float line = max(step(ring, lineWidth), step(1.0 - lineWidth, ring));
        float fade = 1.0 - smoothstep(1.02, 1.42, squareRadius);
        body = line * fade;
        float hue = fract(ringID * 0.085 - t * 0.035);
        vec3 rainbow = hsv(hue, 0.96, max(body, 0.55));
        vec3 blackWhite = vec3(body);
        col = mix(blackWhite, rainbow, sat(u_p1));
    }

    return pixelFinish(vUV, col, body);
}

vec4 cyberEffect(float variant) {
    float color = u_p1;
    float speed = u_p2;
    float scale = u_p3;
    float density = u_p4;
    float thickness = u_p5;
    float glow = u_p6;
    float motion = u_p7;

    vec2 p = aspectSpace(vUV, scale);
    float t = u_time;
    float id = variant - 34.0;
    float body = 0.0;
    vec3 col = vec3(0.0);

    if (id < 0.5) {
        vec2 gp = p * mix(3.0, 12.0, density);
        gp.y += t * motion;
        body = max(pulseLine(gp.x, mix(0.10, 0.025, thickness)), pulseLine(gp.y, mix(0.10, 0.025, thickness)));
        col = hsv(color + body * 0.15, 0.92, body * (0.65 + glow));
    } else if (id < 1.5) {
        vec2 g = vUV * vec2(mix(12.0, 42.0, density), 18.0);
        float lane = hash12(vec2(floor(g.x), 2.0));
        float drop = fract(g.y + t * (0.6 + lane) * (0.5 + motion));
        body = step(0.70, lane) * lineAt(drop - 0.5, mix(0.20, 0.04, thickness));
        col = hsv(color + lane * 0.10, 0.88, body * (0.8 + glow));
    } else if (id < 2.5) {
        float r = length(p) + 0.025;
        float a = atan(p.y, p.x) / TAU;
        body = max(pulseLine(1.0 / r + t * motion, mix(0.12, 0.035, thickness)), pulseLine(a * mix(8.0, 22.0, density), 0.045));
        col = hsv(color + r * 0.18, 0.92, body * (0.70 + glow));
    } else if (id < 3.5) {
        vec2 q = rot(p, 0.8);
        float weave = max(pulseLine(q.x * mix(3.0, 10.0, density) + sin(q.y * 3.0 + t), mix(0.11, 0.035, thickness)),
                          pulseLine(q.y * mix(3.0, 10.0, density) - cos(q.x * 2.0 - t), mix(0.11, 0.035, thickness)));
        body = weave;
        col = mix(vec3(body), hsv(color + 0.45, 0.35, body * 0.9), 0.45 + glow * 0.35);
    } else if (id < 4.5) {
        vec2 g = floor(vUV * mix(6.0, 24.0, density));
        float n = hash12(g + floor(t * (2.0 + motion * 12.0)));
        vec2 local = fract(vUV * mix(6.0, 24.0, density));
        float block = step(0.68 - thickness * 0.25, n) * step(local.x, 0.78) * step(local.y, 0.78);
        body = block + pulseLine(vUV.y * 80.0 + t * 5.0, 0.025) * motion * 0.35;
        col = hsv(color + n * 0.3, 0.95, body * (0.75 + glow));
    } else if (id < 5.5) {
        vec2 q = rot(p, 0.6 + sin(t) * motion * 0.3);
        body = max(pulseLine(q.x * mix(5.0, 16.0, density) + q.y * 2.0, mix(0.07, 0.015, thickness)),
                   pulseLine(q.x * -2.0 + q.y * mix(5.0, 16.0, density), mix(0.07, 0.015, thickness)));
        col = hsv(color + body * 0.22, 0.98, body * (0.8 + glow));
    } else {
        vec2 g = fract(vUV * mix(4.0, 18.0, density));
        vec2 cell = floor(vUV * mix(4.0, 18.0, density));
        float tile = step(max(abs(g.x - 0.5), abs(g.y - 0.5)), mix(0.16, 0.44, thickness));
        float wave = 0.5 + 0.5 * sin(hash12(cell) * 6.0 + t * (0.5 + motion * 2.0));
        body = tile * wave;
        col = hsv(color + hash12(cell) * 0.22, 0.88, body * (0.65 + glow));
    }

    col += hsv(color + 0.55, 0.9, body * body * glow * 0.40);
    return vec4(sat3(col), sat(0.22 + body));
}

vec4 simplePortedEffect(float variant) {
    float color = u_p1;
    float speed = u_p2;
    float scale = u_p3;
    float density = u_p4;
    float shape = u_p5;
    float glow = u_p6;
    float opacity = u_p7;

    if (variant > 40.5 && variant < 41.5) {
        return vec4(hsv(u_p1, u_p2, u_p3), sat(u_p4));
    }

    vec2 p = aspectSpace(vUV, scale);
    float t = u_time;
    float id = variant - 42.0;
    float r = length(p) + 0.001;
    float a = atan(p.y, p.x);
    float n = fbm(p * (1.2 + density * 3.0) + vec2(t * 0.12, -t * 0.07));
    float body = n;

    if (id < 0.5) {
        vec2 ball = p - vec2(sin(t * 0.7) * 0.45, 0.85 - fract(t * 0.22) * 1.9);
        body = (1.0 - smoothstep(0.03, 0.26, length(ball))) + pulseLine(p.y * mix(4.0, 12.0, density) - t, 0.08);
    } else if (id < 1.5) {
        body = smoothstep(0.3, 1.0, sin(r * mix(8.0, 24.0, density) - t * 2.3) * 0.5 + 0.5 + n * 0.45);
    } else if (id < 2.5) {
        float seg = floor(mix(5.0, 14.0, shape));
        float wedge = abs(fract(a / TAU * seg + 0.5) - 0.5) * 2.0;
        body = pulseLine(wedge + r * density * 3.0 - t * 0.3, 0.12) + (1.0 - smoothstep(0.0, 0.8, r)) * 0.25;
    } else if (id < 3.5) {
        body = pulseLine(1.0 / (r + 0.08) + t * 0.45 + n, mix(0.16, 0.055, shape));
    } else if (id < 4.5) {
        vec2 g = p * mix(3.0, 14.0, density);
        body = max(pulseLine(g.x + sin(g.y + t) * shape, 0.05), pulseLine(g.y + cos(g.x - t) * shape, 0.05));
    } else if (id < 5.5) {
        body = pulseLine(max(abs(p.x), abs(p.y)) * mix(4.0, 14.0, density) - t, mix(0.16, 0.04, shape));
    } else if (id < 6.5) {
        body = pulseLine(1.0 / (r + 0.10) - t * 0.45 + sin(a * 6.0) * shape, mix(0.18, 0.05, glow));
    } else if (id < 7.5) {
        body = smoothstep(0.28, 0.92, n + sin(p.x * 2.0 + t) * 0.2);
    } else if (id < 8.5) {
        body = pulseLine(max(abs(p.x), abs(p.y)) * mix(5.0, 16.0, density) - t, mix(0.20, 0.06, shape));
    } else if (id < 9.5) {
        body = smoothstep(0.32, 0.92, fbm(p * 2.4 + vec2(t * 0.25, sin(t) * 0.2)));
        body *= 1.0 - smoothstep(1.2, 2.0, r);
    } else if (id < 10.5) {
        body = smoothstep(0.34, 0.86, n + sin(p.x * 4.0 + t) * 0.25);
    } else if (id < 11.5) {
        body = smoothstep(0.42, 0.82, n + 0.2 * sin(t + p.x * 3.0));
    } else if (id < 12.5) {
        body = pulseLine(r * mix(5.0, 16.0, density) + sin(a * 8.0 + t) * shape, mix(0.15, 0.05, glow));
    } else if (id < 13.5) {
        body = pulseLine(a / TAU * mix(5.0, 20.0, density) + sin(r * 8.0 - t) * shape, mix(0.16, 0.05, glow));
    } else {
        float slice = abs(fract(a / TAU + t * 0.05) - 0.5) * 2.0;
        body = (1.0 - smoothstep(0.0, max(shape, 0.001), slice)) * (1.0 - smoothstep(0.1, 1.2, r));
    }

    body = sat(body);
    float hue = color + n * 0.22 + a / TAU * 0.18 + t * 0.025;
    vec3 col = hsv(hue, 0.82, body * (0.65 + glow * 0.6));
    col += hsv(color + 0.5, 0.9, body * body * glow * 0.36);
    return vec4(sat3(col), sat(opacity) * sat(0.18 + body));
}

vec4 ambientGlowEffect() {
    float drift = u_p2;
    float swirl = u_p3;
    float evolve = u_p4;
    float scale = u_p5;
    float hue = u_p6;
    float colorFlow = u_p7;
    vec2 p = aspectSpace(vUV, scale);
    float t = u_time;
    p += vec2(drift * t * 0.10, -drift * t * 0.06);
    p = rot(p, swirl * (0.35 * sin(t * 0.24) + length(p) * 0.42));
    float n = fbm(p * 1.35 + vec2(t * (0.05 + evolve * 0.12), -t * 0.04));
    float n2 = fbm(rot(p, 1.1) * 2.15 - vec2(t * 0.035, t * 0.055));
    float wash = smoothstep(0.16, 0.92, n * 0.74 + n2 * 0.40);
    float center = exp(-length(p) * 0.72);
    float movingHue = hue + colorFlow * (n * 0.34 + t * 0.035);
    vec3 col = hsv(movingHue, 0.72, wash * 0.82 + center * 0.24);
    col += hsv(movingHue + 0.42, 0.80, n2 * wash * 0.34);
    return vec4(sat3(col), sat(0.30 + wash));
}

vec4 squareTunnelEffect(float variant) {
    vec2 p = aspectSpace(vUV, 1.0);
    float t = u_time;
    float r = max(abs(p.x), abs(p.y)) + 0.001;
    float a = atan(p.y, p.x);

    if (variant < 58.5) {
        float palette = u_p1;
        float layerCount = mix(4.0, 18.0, u_p3);
        float ribbonWidth = mix(0.035, 0.28, sat(u_p4 / 1.25));
        float bend = u_p5;
        float twist = u_p6;
        float fade = u_p7;
        vec2 q = rot(p, twist * (0.55 * sin(t * 0.22) + r * 0.45));
        q.x += sin(q.y * 3.0 + t * 0.42) * bend * 0.12;
        float qr = max(abs(q.x), abs(q.y)) + 0.001;
        float tunnel = 1.0 / (qr + 0.09) + t * 0.62;
        float line = pulseLine(tunnel * layerCount * 0.12, ribbonWidth);
        float edge = 1.0 - smoothstep(0.98, mix(1.05, 1.65, fade), qr);
        float body = line * edge;
        vec3 col = hsv(palette + floor(tunnel) * 0.055 + a / TAU * 0.16, 0.86, body * 1.16);
        col += hsv(palette + 0.52, 0.92, body * body * 0.42);
        return vec4(sat3(col), sat(0.18 + body));
    }

    float color = u_p1;
    float density = mix(4.0, 22.0, u_p3);
    float segmentLength = mix(0.08, 0.72, u_p4);
    float pulse = u_p5;
    float spark = u_p6;
    float breakup = u_p7;
    float tunnel = 1.0 / (r + 0.08) + t * 0.75;
    float ringId = floor(tunnel * density * 0.12);
    float ring = pulseLine(tunnel * density * 0.12, mix(0.12, 0.035, pulse));
    float side = floor((a / TAU + 0.5) * 4.0);
    float segment = step(1.0 - segmentLength, hash12(vec2(ringId, side)));
    float broken = step(breakup * 0.62, hash12(vec2(ringId + floor(t * 3.0), side + 7.0)));
    float sparkBody = step(0.96 - spark * 0.22, hash12(floor(vUV * 72.0) + floor(t * 8.0)));
    float body = ring * mix(1.0, segment * broken, breakup) + sparkBody * spark;
    vec3 col = hsv(color + ringId * 0.035 + sparkBody * 0.18, 0.94, body * 1.18);
    return vec4(sat3(col), sat(0.16 + body));
}

vec4 neonFamilyEffect(float variant) {
    float density = u_p2;
    float thickness = u_p3;
    float glow = u_p4;
    float shape = u_p5;
    float hue = u_p6;
    float colorSpread = u_p7;
    float style = variant - 60.0;
    vec2 p = aspectSpace(vUV, density);
    float t = u_time;
    float body = 0.0;
    float signal = 0.0;

    if (style < 0.5) {
        float wave = sin(p.x * 3.2 + t) * (0.22 + shape * 0.55);
        signal = p.y + wave + 0.24 * sin(p.x * 7.0 - t * 0.7);
        body = lineAt(signal, mix(0.11, 0.018, sat(thickness / 2.5)));
    } else if (style < 1.5) {
        vec2 q = rot(p, t * shape * 0.24);
        float d = max(abs(q.x), abs(q.y));
        signal = fract(d * 3.4 - t * 0.38) - 0.5;
        body = lineAt(signal, mix(0.12, 0.025, sat(thickness / 2.5)));
    } else if (style < 2.5) {
        float sides = floor(clamp(shape, 3.0, 8.0) + 0.5);
        float sector = TAU / sides;
        float polygon = cos(floor(0.5 + atan(p.y, p.x) / sector) * sector - atan(p.y, p.x)) * length(p);
        signal = fract(polygon * 3.8 - t * 0.34) - 0.5;
        body = lineAt(signal, mix(0.12, 0.025, sat(thickness / 2.5)));
    } else {
        signal = p.y + sin(p.x * 2.4 + t * (0.55 + shape)) * (0.28 + shape * 0.42);
        float ribbon = pulseLine(signal * 1.6, mix(0.30, 0.10, sat(thickness / 2.5)));
        body = ribbon * (0.65 + 0.35 * sin(p.x * 4.0 - t));
    }

    float halo = exp(-abs(signal) * mix(5.0, 18.0, sat(glow / 2.0)));
    float hueSignal = hue + colorSpread * (p.x * 0.12 + p.y * 0.08 + t * 0.035);
    vec3 col = hsv(hueSignal, 0.92, body * 1.10 + halo * glow * 0.32);
    col += hsv(hueSignal + 0.48, 0.88, body * body * glow * 0.28);
    return vec4(sat3(col), sat(0.15 + max(body, halo * 0.5)));
}

void main() {
    float variant = floor(u_variant + 0.5);
    if (variant < 4.5) {
        gl_FragColor = psychEffect(variant);
    } else if (variant < 5.5) {
        gl_FragColor = contourEffect();
    } else if (variant < 6.5) {
        gl_FragColor = squareSequenceEffect();
    } else if (variant < 7.5) {
        gl_FragColor = cloudscapeEffect();
    } else if (variant < 11.5) {
        gl_FragColor = synthwaveEffect(variant);
    } else if (variant < 12.5) {
        gl_FragColor = circleSequenceEffect();
    } else if (variant < 13.5) {
        gl_FragColor = smoothSquiggleEffect();
    } else if (variant < 14.5) {
        gl_FragColor = vhsEffect();
    } else if (variant < 25.5) {
        gl_FragColor = abstractEffect(variant);
    } else if (variant < 33.5) {
        gl_FragColor = pixelEffect(variant);
    } else if (variant < 40.5) {
        gl_FragColor = cyberEffect(variant);
    } else if (variant < 56.5) {
        gl_FragColor = simplePortedEffect(variant);
    } else if (variant < 57.5) {
        gl_FragColor = ambientGlowEffect();
    } else if (variant < 59.5) {
        gl_FragColor = squareTunnelEffect(variant);
    } else {
        gl_FragColor = neonFamilyEffect(variant);
    }
}
