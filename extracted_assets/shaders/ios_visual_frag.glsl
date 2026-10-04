#version 100
precision highp float;

varying vec2 vUV;
uniform float u_time;
uniform float u_clock;
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

float sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sat3(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }

vec2 iosSpace(vec2 uv) {
    vec2 p = uv * 2.0 - 1.0;
    p.x *= max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    return p;
}

vec2 iosRot(vec2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 iosHsv(float h, float s, float v) {
    vec3 p = abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return v * mix(vec3(1.0), clamp(p - 1.0, vec3(0.0), vec3(1.0)), s);
}

float iosHash12(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 iosHash22(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float iosNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 q = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(iosHash12(i), iosHash12(i + vec2(1.0, 0.0)), q.x),
        mix(iosHash12(i + vec2(0.0, 1.0)), iosHash12(i + vec2(1.0)), q.x),
        q.y
    );
}

float iosFbm3(vec2 p) {
    return iosNoise(p) * 0.55
        + iosNoise(p * 2.03 + 11.7) * 0.30
        + iosNoise(p * 4.01 - 8.4) * 0.15;
}

float iosLine(float d, float width) {
    return 1.0 - smoothstep(width * 0.55, width, abs(d));
}

float periodicLine(float coordinate, float width, float feather) {
    float d = abs(fract(coordinate) - 0.5);
    return 1.0 - smoothstep(width, width + feather, d);
}

float avjPaletteHue(float signal) {
    float rainbow = sat(u_p2);
    float s = fract(signal);
    if (rainbow < 0.015) return u_p1;
    if (rainbow < 0.965) {
        float bands = min(4.0, max(1.0, floor(rainbow * 4.0) + 1.0));
        float stepped = (floor(s * bands) + 0.5) / bands;
        return u_p1 + stepped * smoothstep(0.02, 0.96, rainbow);
    }
    return u_p1 + s;
}

vec3 avjPalette(float signal, float body) {
    float hue = avjPaletteHue(signal);
    float saturation = mix(0.68, 0.98, sat(u_p2 + body * 0.22));
    vec3 base = iosHsv(hue, saturation, sat(0.05 + body * 1.18));
    vec3 hot = iosHsv(hue + 0.09, 0.42, sat(body * body * 1.25));
    return sat3(base + hot * smoothstep(0.72, 1.0, body) * 0.34);
}

vec4 avjFinish(vec3 color, float body) {
    return vec4(sat3(color), sat(0.20 + body * 0.90));
}

vec4 abstractCloudTunnel() {
    vec2 p = iosSpace(vUV) * 0.66;
    float r = length(p) + 0.035;
    float a = atan(p.y, p.x);
    float tunnel = 1.0 / (r + 0.17) + u_time * 0.52;
    float warpNoise = iosFbm3(p * 1.5 + u_time * 0.08);
    float swirlAngle = a + (warpNoise - 0.5) * u_p6 * TAU * 0.55;
    vec2 circular = vec2(cos(swirlAngle), sin(swirlAngle));
    vec2 circularDouble = vec2(
        circular.x * circular.x - circular.y * circular.y,
        2.0 * circular.x * circular.y
    );
    float angularScale = mix(1.8, 5.4, u_p4);
    float tunnelScale = mix(0.42, 1.30, u_p4);
    float cloudA = iosFbm3(circular * angularScale + vec2(tunnel * tunnelScale, u_time * 0.08 - tunnel * 0.18));
    float cloudB = iosFbm3(circularDouble * angularScale * 0.72 + vec2(-tunnel * tunnelScale * 0.46, u_time * 0.06 + tunnel * 0.27) + 7.3);
    float cloud = cloudA * 0.68 + cloudB * 0.32;
    float rings = smoothstep(0.10, 0.86, fract(tunnel * mix(1.6, 6.2, u_p5) + cloud * mix(0.35, 1.65, u_p7)));
    float mist = 1.0 - smoothstep(1.45, 2.55, r);
    float body = sat((cloud * 0.70 + rings * mix(0.25, 0.58, u_p7)) * mist);
    return avjFinish(avjPalette(swirlAngle / TAU + tunnel * 0.045 + cloud * 0.28, body), body);
}

vec4 abstractMatterBloom() {
    vec2 p = iosSpace(vUV) * 0.88;
    float field = 0.0;
    float hueSignal = 0.0;
    float count = floor(3.0 + u_p4 * 5.0 + 0.5);
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        if (fi >= count) continue;
        float speedA = 0.22 + fi * 0.045;
        float speedB = 0.17 + fi * 0.037;
        float radius = mix(0.18, 0.78, iosHash12(vec2(fi, 4.7)));
        vec2 center = vec2(sin(u_time * speedA + fi * 1.73), cos(u_time * speedB + fi * 2.21)) * radius;
        center += vec2(sin(u_time * speedB * 1.7 + fi * 3.1), cos(u_time * speedA * 1.4 + fi * 0.6)) * u_p6 * 0.20;
        vec2 rel = iosRot(p - center, fi * 1.2 + sin(u_time * 0.13 + fi) * u_p5);
        float stretch = mix(1.0, 2.25, u_p7) * (0.82 + 0.18 * sin(u_time * 0.31 + fi));
        rel.x /= mix(1.0, stretch, u_p5);
        float size = mix(0.16, 0.42, u_p5) * mix(0.76, 1.24, iosHash12(vec2(fi, 9.1)));
        float blob = exp(-dot(rel, rel) / max(size * size, 0.001));
        field += blob;
        hueSignal += blob * (fi * 0.055 + radius * 0.08);
    }
    float membranes = sin(field * mix(2.0, 7.0, u_p7) - u_time * 0.45) * 0.5 + 0.5;
    float body = sat((1.0 - exp(-field * mix(0.48, 0.86, u_p5))) + membranes * u_p7 * 0.16);
    return avjFinish(avjPalette(hueSignal + field * 0.08, body), body);
}

vec4 abstractShapeRift() {
    vec2 p = iosSpace(vUV) * 0.92;
    vec2 warp = vec2(iosFbm3(p * 1.7 + u_time * 0.12), iosFbm3(p.yx * 1.9 - u_time * 0.10)) - 0.5;
    p += warp * u_p6 * 0.72;
    float r = length(p);
    float a = atan(p.y, p.x) / TAU + 0.5;
    float sides = 3.0 + floor(u_p4 * 10.0 + 0.5);
    float shard = abs(fract(a * sides + u_time * 0.10 + iosNoise(p * 2.4) * u_p6) - 0.5) * 2.0;
    float bladeWidth = mix(0.16, 0.54, u_p5);
    float blades = 1.0 - smoothstep(bladeWidth, bladeWidth + 0.18, shard);
    float cracks = 1.0 - smoothstep(0.035, mix(0.16, 0.05, u_p7), abs(fract((r + shard * 0.32) * mix(4.0, 19.0, u_p7) - u_time * 0.72) - 0.5));
    float randomCuts = step(mix(0.82, 0.46, u_p6), iosNoise(p * mix(4.0, 10.0, u_p7) + u_time * 0.35));
    float body = sat((blades * 0.70 + cracks * 0.48 + randomCuts * u_p6 * 0.26) * (1.0 - smoothstep(1.15, 2.05, r)));
    return avjFinish(avjPalette(a + shard * 0.28 + r * 0.12, body), body);
}

vec4 abstractCrystalSoup() {
    vec2 p = iosSpace(vUV);
    vec2 domain = vec2(iosFbm3(p * 1.3 + u_time * 0.07), iosFbm3(p.yx * 1.4 - u_time * 0.06)) - 0.5;
    p = (p + domain * u_p6 * 0.55) * mix(2.0, 8.4, u_p4);
    vec2 id = floor(p);
    vec2 f = fract(p);
    float best = 8.0;
    float second = 8.0;
    float chosen = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 off = vec2(float(x), float(y));
            vec2 seed = iosHash22(id + off);
            vec2 point = seed + sin(vec2(u_time * (0.18 + u_p6 * 0.44)) + seed * TAU) * u_p6 * 0.30;
            vec2 d = off + point - f;
            float metric = mix(length(d), max(abs(d.x), abs(d.y)), u_p5);
            if (metric < best) {
                second = best;
                best = metric;
                chosen = seed.x;
            } else if (metric < second) {
                second = metric;
            }
        }
    }
    float edge = sat((second - best) * mix(3.0, 11.0, u_p5));
    float facet = 1.0 - smoothstep(0.08, mix(0.58, 0.30, u_p5), best);
    float internal = 1.0 - smoothstep(0.04, mix(0.16, 0.06, u_p7), abs(fract(best * mix(5.0, 17.0, u_p7) - u_time * 0.28) - 0.5));
    float body = sat(edge * 0.80 + facet * 0.32 + internal * u_p7 * 0.40);
    return avjFinish(avjPalette(chosen + edge * 0.23 + internal * 0.08, body), body);
}

vec4 abstractPulseVeins() {
    vec2 p = iosSpace(vUV);
    float freq = mix(3.0, 13.0, u_p4);
    vec2 flow = vec2(iosNoise(p * 1.7 + u_time * 0.10), iosNoise(p.yx * 1.9 - u_time * 0.08)) - 0.5;
    p += flow * u_p6 * 0.62;
    float waveA = sin(p.x * freq + p.y * freq * u_p5 + u_time * 1.60);
    float waveB = sin(p.y * freq * mix(0.7, 1.9, u_p5) - p.x * freq * 0.42 - u_time * 1.08);
    float veins = 1.0 - smoothstep(0.020, mix(0.19, 0.040, u_p5), abs(waveA + waveB));
    float runners = 1.0 - smoothstep(0.10, mix(0.42, 0.16, u_p7), abs(fract((p.x + p.y) * mix(2.0, 8.0, u_p7) - u_time * 0.9) - 0.5));
    float body = sat(veins * (0.76 + runners * 0.44) + runners * veins * u_p7 * 0.30);
    return avjFinish(avjPalette(veins * 0.16 + runners * 0.17 + waveA * 0.025, body), body);
}

vec4 abstractPulseWeb() {
    vec2 p = iosSpace(vUV);
    vec2 q = p * mix(3.0, 10.0, u_p4);
    q += vec2(sin(p.y * mix(1.0, 5.0, u_p5) + u_time * 0.65), cos(p.x * mix(1.0, 5.0, u_p5) - u_time * 0.55)) * u_p6;
    vec2 f = fract(q) - 0.5;
    float grid = max(iosLine(f.x, mix(0.035, 0.14, 1.0 - u_p5)), iosLine(f.y, mix(0.035, 0.14, 1.0 - u_p5)));
    float diag = iosLine(f.x + f.y, mix(0.040, 0.13, 1.0 - u_p7));
    float pulse = 0.5 + 0.5 * sin((q.x + q.y) * mix(0.6, 2.4, u_p7) - u_time * 1.8);
    float body = sat(grid * (0.66 + pulse * 0.42) + diag * u_p7 * 0.45);
    return avjFinish(avjPalette(pulse * 0.24 + q.x * 0.025, body), body);
}

vec4 abstractLiquidWire() {
    vec2 p = iosSpace(vUV);
    float wires = 0.0;
    float hue = 0.0;
    float count = floor(3.0 + u_p4 * 5.0 + 0.5);
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        if (fi >= count) continue;
        float lane = (fi - (count - 1.0) * 0.5) * mix(0.26, 0.11, u_p4);
        float wiggle = sin(p.x * mix(1.8, 8.0, u_p5) + u_time * (0.62 + fi * 0.12) + fi);
        wiggle += sin(p.x * mix(1.0, 3.5, u_p7) - u_time * 0.48 + fi * 2.0) * 0.55;
        wiggle *= mix(0.06, 0.38, u_p6);
        float line = iosLine(p.y - lane - wiggle, mix(0.10, 0.022, u_p5));
        float bead = 1.0 - smoothstep(0.10, mix(0.42, 0.15, u_p7), abs(fract(p.x * mix(2.0, 9.0, u_p7) + fi * 0.17 - u_time * 0.6) - 0.5));
        wires += line * (0.78 + bead * 0.35);
        hue += line * (fi * 0.05 + wiggle * 0.08 + bead * 0.07);
    }
    float body = sat(wires * 0.82);
    return avjFinish(avjPalette(hue + p.x * 0.04, body), body);
}

vec4 abstractRibbonStorm() {
    vec2 p = iosRot(iosSpace(vUV), sin(u_time * 0.16) * u_p5);
    float ribbons = 0.0;
    float hue = 0.0;
    float count = floor(3.0 + u_p4 * 5.0 + 0.5);
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        if (fi >= count) continue;
        float wave = sin(p.x * mix(1.3, 5.6, u_p5) + p.y * mix(0.4, 2.4, u_p6) + u_time * (0.55 + fi * 0.18) + fi);
        wave += sin(p.x * mix(2.0, 8.0, u_p7) - u_time * 0.34 + fi) * 0.38 * u_p7;
        float lane = (fi - (count - 1.0) * 0.5) * mix(0.34, 0.15, u_p4);
        float ribbon = 1.0 - smoothstep(mix(0.040, 0.16, u_p5), mix(0.13, 0.24, u_p5), abs(p.y + wave * mix(0.14, 0.58, u_p6) - lane));
        float slash = 1.0 - smoothstep(0.05, mix(0.22, 0.06, u_p7), abs(fract((p.x - p.y) * mix(1.5, 7.0, u_p7) + fi * 0.21) - 0.5));
        ribbons += ribbon * (0.76 + slash * 0.30);
        hue += ribbon * (wave * 0.08 + fi * 0.055 + slash * 0.04);
    }
    float body = sat(ribbons * 0.78);
    return avjFinish(avjPalette(hue + p.x * 0.05, body), body);
}

float cloudHash(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1171, 0.0937, 0.1213));
    p3 += dot(p3, p3.yzx + 21.41);
    return fract((p3.x + p3.y) * p3.z);
}

float cloudNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 q = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(cloudHash(i), cloudHash(i + vec2(1.0, 0.0)), q.x), mix(cloudHash(i + vec2(0.0, 1.0)), cloudHash(i + vec2(1.0)), q.x), q.y);
}

float cloudFbm(vec2 p, float drift, float twist) {
    float total = 0.0;
    float amp = 0.56;
    float norm = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        total += cloudNoise(p + vec2(drift * (0.21 + fi * 0.07), -drift * 0.13)) * amp;
        norm += amp;
        p = iosRot(p * (1.78 + 0.08 * fi), 0.53 + twist * 0.18);
        amp *= 0.48;
    }
    return total / max(norm, 0.0001);
}

float cloudRidge(vec2 p, float drift, float twist) {
    float total = 0.0;
    float amp = 0.50;
    float norm = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float n = cloudNoise(p + vec2(-drift * 0.16, drift * (0.19 + fi * 0.05)));
        float ridge = 1.0 - abs(n * 2.0 - 1.0);
        total += ridge * ridge * amp;
        norm += amp;
        p = iosRot(p * (1.92 + 0.05 * fi), -0.46 - twist * 0.11);
        amp *= 0.52;
    }
    return total / max(norm, 0.0001);
}

vec4 cloudscapeDrift() {
    vec2 uv = vUV;
    float aspect = max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
    vec2 domain = p * mix(1.15, 4.65, u_p3);
    float t = u_time;
    vec2 broad = vec2(
        cloudFbm(domain * 0.46 + vec2(t * 0.24, -t * 0.08), t, u_p6),
        cloudFbm(domain.yx * 0.42 - vec2(t * 0.16, t * 0.12), -t, u_p6)
    ) - 0.5;
    vec2 q = domain + broad * mix(0.12, 1.15, u_p6) + vec2(t * 0.55, -t * 0.12);
    float soft = cloudFbm(q, t, u_p6);
    float billow = cloudRidge(q * mix(0.82, 1.72, u_p5) + broad * 0.7, t * 1.4, u_p6);
    float fine = cloudFbm(q * mix(1.7, 3.4, u_p5) - broad.yx * 0.45, -t * 0.9, u_p6);
    float shape = soft * mix(0.72, 0.38, u_p5) + billow * mix(0.28, 0.58, u_p5);
    shape += (fine - 0.5) * mix(0.08, 0.28, u_p6);
    float threshold = mix(0.70, 0.28, u_p4);
    float feather = mix(0.22, 0.065, u_p5);
    float body = smoothstep(threshold - feather, threshold + feather, shape);
    float vapor = smoothstep(threshold - feather * 2.4, threshold + feather * 0.4, shape) * 0.34;
    body = sat(body + vapor * mix(0.18, 0.72, u_p7));
    float shade = sat((billow - soft) * 0.80 + 0.42);
    float highlight = smoothstep(0.54, 0.96, fine + billow * 0.45) * u_p7;
    float luminance = sat(body * (0.72 + shade * 0.40 + highlight * 0.34 + smoothstep(0.0, 1.0, uv.y) * 0.22));
    vec3 skyLow = iosHsv(u_p1 + 0.52, 0.46, 0.32 + u_p7 * 0.20);
    vec3 skyHigh = iosHsv(u_p1 + 0.58, 0.32, 0.78 + u_p7 * 0.14);
    vec3 warm = iosHsv(u_p1 + 0.10, 0.20, 0.92 + u_p7 * 0.22);
    vec3 cool = iosHsv(u_p1 + 0.56, 0.18, 0.76 + u_p7 * 0.18);
    vec3 color = mix(mix(skyLow, skyHigh, smoothstep(0.0, 1.0, uv.y)), mix(cool, warm, smoothstep(0.34, 1.0, luminance)), luminance);
    color += iosHsv(u_p1 + 0.07, 0.30, highlight * body * 0.24);
    float grain = cloudHash(floor(uv * u_resolution * 0.42) + floor(t * 12.0));
    color *= mix(0.96, 1.04, grain);
    float vignette = 1.0 - smoothstep(0.72, 1.25, length((uv - 0.5) * vec2(aspect, 1.0)));
    color *= mix(0.74, 1.0, vignette);
    return vec4(sat3(color), 1.0);
}

vec4 abstractSquareTunnel() {
    vec2 screenPoint = vUV * 2.0 - 1.0;
    vec2 point = vec2(screenPoint.x * max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0), screenPoint.y);
    vec2 center = vec2(sin(u_time * 0.31), cos(u_time * 0.23)) * u_p5 * 0.12;
    vec2 tunnelPoint = point - center;
    tunnelPoint += vec2(sin(tunnelPoint.y * 2.8 + u_time * 0.55), cos(tunnelPoint.x * 2.3 - u_time * 0.46)) * u_p5 * 0.052;
    float roughRadius = max(abs(tunnelPoint.x), abs(tunnelPoint.y));
    float depthPhase = -log2(max(roughRadius, 0.004));
    tunnelPoint = iosRot(tunnelPoint, sin(u_time * 0.19 + depthPhase * 0.58) * u_p6 * 0.34);
    float squareRadius = max(abs(tunnelPoint.x), abs(tunnelPoint.y));
    float safeRadius = max(squareRadius, 0.004);
    float tunnelCoordinate = -log2(safeRadius) * mix(2.1, 4.8, u_p3) + u_time * 0.90;
    float aa = max(1.5 / max(u_resolution.y, 1.0), 0.0015);
    float frameWidth = mix(0.050, 0.205, u_p4);
    float frames = periodicLine(tunnelCoordinate, frameWidth, aa);
    float frameDistance = abs(fract(tunnelCoordinate) - 0.5);
    float aura = max(exp(-frameDistance / mix(0.070, 0.13, u_p4)) - 0.08, 0.0) * 0.38;
    float verticalWall = step(abs(tunnelPoint.y), abs(tunnelPoint.x));
    float wallCoordinate = mix(tunnelPoint.x, tunnelPoint.y, verticalWall) / safeRadius;
    float ribbonRail = periodicLine((wallCoordinate * 0.5 + 0.5) * mix(2.0, 6.0, u_p3), mix(0.020, 0.070, u_p4), aa);
    float diagonalDistance = abs(abs(tunnelPoint.x) - abs(tunnelPoint.y)) / safeRadius;
    float diagonal = 1.0 - smoothstep(0.015, 0.060 + aa * 2.0, diagonalDistance);
    float framePulse = 0.70 + 0.30 * sin(floor(tunnelCoordinate) * 1.71 + u_time * 1.45);
    float hue = u_p1 + tunnelCoordinate * 0.027 + wallCoordinate * 0.08;
    vec3 violet = iosHsv(hue + 0.03, 0.82, 1.0);
    vec3 aqua = iosHsv(hue + 0.48, 0.78, 1.0);
    vec3 amber = iosHsv(hue + 0.16, 0.72, 1.0);
    float farOpacity = mix(0.30, 0.025, sat(u_p7));
    float fadeDistance = mix(0.16, 0.72, pow(sat(u_p7), 1.15));
    float innerReveal = mix(farOpacity, 1.0, smoothstep(0.018, fadeDistance, squareRadius));
    innerReveal *= smoothstep(0.006, 0.022, squareRadius);
    float frameSignal = sat(frames + aura) * innerReveal;
    float ribbonSignal = ribbonRail * (0.10 + frames * 0.48) * innerReveal;
    float diagonalSignal = diagonal * (0.06 + frames * 0.28) * innerReveal;
    vec3 color = mix(violet, aqua, sat(wallCoordinate * 0.5 + 0.5)) * frameSignal * (0.80 + framePulse * 0.32);
    color += amber * ribbonSignal + aqua * diagonalSignal;
    float vignette = 1.0 - smoothstep(0.82, 1.48, length(screenPoint));
    float vignetteAmount = mix(0.72, 1.0, vignette);
    color *= vignetteAmount;
    return vec4(sat3(color), sat(frameSignal + ribbonSignal + diagonalSignal) * vignetteAmount);
}

float signalHash(float value) { return fract(sin(value * 127.1) * 43758.5453); }

vec4 signalSquareTunnel() {
    vec2 screenPoint = vUV * 2.0 - 1.0;
    vec2 point = vec2(screenPoint.x * max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0), screenPoint.y);
    point.x += sin(point.y * 5.0 - u_time * 0.82) * u_p7 * 0.020;
    float squareRadius = max(abs(point.x), abs(point.y));
    float safeRadius = max(squareRadius, 0.004);
    float tunnelCoordinate = -log2(safeRadius) * mix(2.25, 5.15, u_p3) + u_time * 1.04;
    float aa = max(1.5 / max(u_resolution.y, 1.0), 0.0015);
    float frames = periodicLine(tunnelCoordinate, mix(0.050, 0.205, u_p4), aa);
    float verticalWall = step(abs(point.y), abs(point.x));
    float wallCoordinate = mix(point.x, point.y, verticalWall) / safeRadius;
    float wallCellCount = mix(7.0, 18.0, u_p3);
    float wallCell = floor((wallCoordinate * 0.5 + 0.5) * wallCellCount);
    float ringCell = floor(tunnelCoordinate);
    float dataValue = signalHash(wallCell * 17.0 + ringCell * 3.0);
    float dataMask = step(mix(0.04, 0.72, u_p7), dataValue);
    float segments = frames * dataMask;
    float wallGrid = periodicLine((wallCoordinate * 0.5 + 0.5) * mix(3.0, 9.0, u_p3), mix(0.020, 0.065, u_p4), aa);
    float diagonalDistance = abs(abs(point.x) - abs(point.y)) / safeRadius;
    float cornerRails = 1.0 - smoothstep(0.012, 0.055 + aa * 2.0, diagonalDistance);
    float pulseWave = 0.62 + 0.38 * sin(ringCell * 1.67 + wallCell * 0.41 + u_time * mix(0.8, 3.2, u_p5));
    pulseWave = mix(1.0, pulseWave, u_p5);
    float pieceSeed = wallCell * 29.0 + ringCell * 11.0;
    float piecePhase = signalHash(pieceSeed + 4.7) * TAU;
    float pieceRate = mix(0.55, 1.05, signalHash(pieceSeed + 19.3));
    float pieceWave = 0.5 + 0.5 * sin(u_clock * pieceRate + piecePhase);
    float piecePulse = mix(1.0, 0.42 + smoothstep(0.30, 1.0, pieceWave) * 0.88, u_p6);
    float frameDistance = abs(fract(tunnelCoordinate) - 0.5);
    float aura = max(exp(-frameDistance / mix(0.060, 0.11, u_p5)) - 0.08, 0.0) * u_p5 * dataMask * 0.32;
    vec3 terminal = iosHsv(u_p1, 0.92, 1.0);
    vec3 dimSignal = iosHsv(u_p1 + 0.02, 0.88, 0.30);
    vec3 alert = iosHsv(u_p1 - 0.215, 0.90, 1.0);
    float intersections = segments * wallGrid;
    float innerReveal = smoothstep(0.055, 0.12, squareRadius);
    float segmentSignal = sat(segments + aura) * innerReveal;
    float gridSignal = wallGrid * 0.22 * innerReveal;
    float cornerSignal = cornerRails * (0.10 + segments * 0.34) * innerReveal;
    float alertSignal = intersections * (0.58 + u_p5 * 0.42) * innerReveal;
    float pulsed = segmentSignal * piecePulse;
    vec3 color = dimSignal * gridSignal + terminal * pulsed * pulseWave + terminal * cornerSignal;
    color += alert * alertSignal * mix(1.0, piecePulse, u_p6 * 0.65);
    color *= 0.92 + 0.08 * sin(vUV.y * u_resolution.y * 0.42);
    float vignette = 1.0 - smoothstep(0.82, 1.48, length(screenPoint));
    float vignetteAmount = mix(0.72, 1.0, vignette);
    color *= vignetteAmount;
    return vec4(sat3(color), sat(pulsed + gridSignal + cornerSignal + alertSignal) * vignetteAmount);
}

float neonLine(float field, float thickness, float glowAmount) {
    return exp(-abs(field) * (5.5 / max(thickness * glowAmount, 0.08)));
}

float polygonRadius(vec2 p, float sides) {
    float angle = atan(p.y, p.x);
    float slice = TAU / max(sides, 3.0);
    float sector = mod(angle + TAU, slice) - slice * 0.5;
    return length(p) * cos(sector) / cos(slice * 0.5);
}

vec4 neonFamily(float style) {
    vec2 p = iosSpace(vUV);
    float density = u_p2;
    float thickness = u_p3;
    float glow = u_p4;
    float shape = u_p5;
    float hue = u_p6;
    float spread = u_p7;
    vec3 color = vec3(0.0);
    float alphaAccum = 0.0;
    if (style < 0.5) {
        float freq = 2.2 * density;
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            vec2 dir = normalize(vec2(cos(fi * 1.9 + 0.6), sin(fi * 1.3 - 0.4)));
            float wave = sin(dot(p, dir) * (freq + fi * 0.7)
                + sin(p.y * (1.3 + fi * 0.5) + u_time * (0.8 + fi * 0.21)) * 1.4 * sat(shape)
                + sin(p.x * (1.1 + fi * 0.4) - u_time * (0.6 + fi * 0.17)) * 1.2 * sat(shape)
                + u_time * (0.5 + fi * 0.13));
            float strand = neonLine(wave, thickness, glow);
            float strandHue = fract(hue + (fi * 0.11 + dot(p, dir) * 0.05 + u_time * 0.02) * spread);
            color += iosHsv(strandHue, 0.85, 1.0) * strand * 0.85;
            color += iosHsv(strandHue, 0.55, 1.0) * strand * strand * 0.6;
            alphaAccum += strand;
        }
    } else if (style < 2.5) {
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float direction = mod(fi, 2.0) < 0.5 ? 1.0 : -1.0;
            vec2 q = iosRot(p, u_time * shape * direction * (0.5 + fi * 0.3) + fi * 0.5);
            float boxRadius = max(abs(q.x), abs(q.y));
            float ring = neonLine(sin(boxRadius * TAU * density * (1.3 + fi * 0.35) - u_time * (1.2 + fi * 0.4)), thickness, glow) * (1.0 - fi * 0.22);
            float ringHue = fract(hue + (fi * 0.16 + boxRadius * 0.25) * spread);
            color += iosHsv(ringHue, 0.85, 1.0) * ring + iosHsv(ringHue, 0.5, 1.0) * ring * ring * 0.5;
            alphaAccum += ring;
        }
    } else if (style < 3.5) {
        float sides = clamp(shape, 3.0, 8.0);
        vec2 q = iosRot(p, u_time * 0.35);
        float radius = polygonRadius(q, sides);
        float ring = neonLine(sin(radius * TAU * density * 1.5 - u_time * 1.6), thickness, glow);
        float ringHue = fract(hue + (floor(radius * density * 1.5) * 0.12 + u_time * 0.025) * spread);
        color += iosHsv(ringHue, 0.85, 1.0) * ring + iosHsv(ringHue, 0.5, 1.0) * ring * ring * 0.6;
        float echo = neonLine(sin(polygonRadius(iosRot(p * 1.6, -u_time * 0.5), sides) * TAU * density - u_time), thickness * 0.7, glow);
        color += iosHsv(fract(ringHue + 0.3 * spread), 0.75, 1.0) * echo * 0.45;
        alphaAccum += ring + echo * 0.45;
    } else {
        float flow = sat(shape);
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float widthScale = 0.6 + fi * 0.5;
            float yWave = p.y * density * (1.2 + fi * 0.4)
                + sin(p.x * (1.1 + fi * 0.6) + u_time * (0.7 + fi * 0.2) * (0.4 + flow)) * (0.5 + flow * 0.8)
                + u_time * (0.35 + fi * 0.1);
            float ribbon = neonLine(sin(yWave * PI), thickness * widthScale, glow);
            float ribbonHue = fract(hue + (fi * 0.14 + p.x * 0.04 + u_time * 0.02) * spread);
            color += iosHsv(ribbonHue, 0.85, 1.0) * ribbon * (0.9 - fi * 0.12);
            color += iosHsv(ribbonHue, 0.5, 1.0) * ribbon * ribbon * 0.4;
            alphaAccum += ribbon * (0.9 - fi * 0.12);
        }
    }
    color += iosHsv(fract(hue + 0.5), 0.7, 1.0) * 0.05;
    return vec4(sat3(color), sat(alphaAccum + 0.08));
}

float cyberLine(float value, float width) {
    return periodicLine(value, width, max(1.5 / max(u_resolution.y, 1.0), 0.001));
}

float cyberCenterLine(float value, float width) {
    float aa = max(1.5 / max(u_resolution.y, 1.0), 0.001);
    return 1.0 - smoothstep(width, width + aa, abs(value));
}

float cyberBox(vec2 p, vec2 halfSize, float softness) {
    vec2 d = abs(p) - halfSize;
    return 1.0 - smoothstep(0.0, softness, length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0));
}

vec4 cyberColor(float mask, float accentMask, float body) {
    float shaped = sat(mask);
    float aura = pow(shaped, 0.38 + 1.2 * (1.0 - sat(u_p6)));
    vec3 base = iosHsv(u_p1, 0.92, 1.0);
    vec3 accentA = iosHsv(u_p1 + 0.43, 0.92, 1.0);
    vec3 accentB = iosHsv(u_p1 + 0.11, 0.92, 0.85);
    vec3 color = iosHsv(u_p1 + 0.62, 0.92, 0.08) * (0.20 + 0.20 * body);
    color += base * shaped * (0.88 + u_p6 * 0.55);
    color += accentA * aura * u_p6 * 0.52;
    color += accentB * sat(accentMask) * (0.45 + u_p6 * 0.35);
    color *= 0.92 + 0.18 * sin((vUV.x + vUV.y) * 16.0 + u_time);
    return vec4(sat3(color), sat(0.18 + shaped * 0.78 + aura * u_p6 * 0.38 + body * 0.18));
}

vec4 cyberPattern(float style) {
    vec2 p = iosSpace(vUV);
    float reps;
    float width;
    float motionPhase = u_clock * u_p7;
    if (style < 0.5) {
        reps = mix(5.0, 24.0, sat(u_p4)) * max(u_p3, 0.2);
        width = mix(0.010, 0.070, sat(u_p5));
        float flowAmount = mix(0.22, 0.82, sat(u_p7));
        vec2 q = p * reps + vec2(u_time * 0.82, -u_time * 0.46) * flowAmount;
        q += vec2(sin(u_time * 0.63), cos(u_time * 0.47)) * (0.12 * sat(u_p7));
        float grid = max(cyberLine(q.x, width), cyberLine(q.y, width));
        vec2 cell = fract(q) - 0.5;
        float node = 1.0 - smoothstep(0.04, 0.22, length(cell));
        float scan = cyberLine(vUV.y * mix(40.0, 120.0, u_p4) + u_time * 0.55, 0.035);
        return cyberColor(max(grid, node * 0.85), node + scan * 0.28, 0.12);
    }
    if (style < 1.5) {
        reps = mix(5.0, 28.0, sat(u_p4)) * max(u_p3, 0.2);
        width = mix(0.018, 0.105, sat(u_p5));
        vec2 q = iosRot(p, 0.785398 + 0.12 * sin(motionPhase * 0.35) * u_p7) * reps;
        float weaveA = cyberLine(q.x + motionPhase * 0.12, width);
        float weaveB = cyberLine(q.y - motionPhase * 0.10, width);
        float checker = step(0.5, fract(floor(q.x) + floor(q.y)) * 0.5);
        float mask = max(weaveA * mix(0.62, 1.0, checker), weaveB * mix(1.0, 0.62, checker));
        float shine = cyberLine((q.x + q.y) * 0.5 + u_time * 0.5, width * 0.38);
        return cyberColor(mask, shine, 0.10 + 0.10 * checker);
    }
    if (style < 2.5) {
        reps = mix(4.0, 24.0, sat(u_p4)) * max(u_p3, 0.2);
        width = mix(0.006, 0.052, sat(u_p5));
        vec2 a = iosRot(p, 0.48 + 0.10 * sin(motionPhase * 0.4) * u_p7) * reps;
        vec2 b = iosRot(p, -0.82 + 0.08 * cos(motionPhase * 0.33) * u_p7) * reps;
        float laserA = cyberLine(a.x + motionPhase * 0.35, width);
        float laserB = cyberLine(b.y - motionPhase * 0.28, width);
        float hit = laserA * laserB;
        float pulse = 0.65 + 0.35 * sin(u_time * 2.0 + (a.x + b.y) * 0.5);
        return cyberColor(max(laserA, laserB) * pulse + hit, hit, 0.05);
    }
    reps = mix(4.0, 24.0, sat(u_p4)) * max(u_p3, 0.2);
    width = mix(0.010, 0.090, sat(u_p5));
    vec2 q = iosRot(p, 0.18 * sin(motionPhase * 0.3) * u_p7) * reps;
    vec2 cell = floor(q);
    vec2 local = fract(q) - 0.5;
    float diamond = cyberCenterLine(abs(local.x) + abs(local.y) - 0.44, width);
    float inset = cyberBox(local, vec2(0.24), 0.018) - cyberBox(local, vec2(0.16), 0.018);
    float pulse = 0.55 + 0.45 * sin(u_time * 0.8 + motionPhase * 2.2 + iosHash12(cell) * TAU);
    float stitch = max(cyberCenterLine(local.x, width * 0.4), cyberCenterLine(local.y, width * 0.4)) * step(0.62, iosHash12(cell + 2.0));
    return cyberColor(max(diamond, inset * pulse) + stitch * 0.55, inset + stitch, 0.10);
}

// Psychedelic Velvet Star: direct port of PsychedelicVelvetStar.metal.
float velvetStripe(float x, float width) {
    return 1.0 - smoothstep(width, width + 0.030, abs(fract(x) - 0.5));
}

vec4 psychedelicVelvetStar() {
    vec2 p = (vUV - 0.5) * vec2(max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0), 1.0);
    float curveBlend = sat(u_p6); curveBlend *= curveBlend * (3.0 - 2.0 * curveBlend);
    float legacyWarp = curveBlend * 0.38;
    p = iosRot(p, sin(u_time * 0.11) * legacyWarp * 0.34);
    float r = length(p) + 0.0008;
    float a = atan(p.y, p.x);
    float petalIndex = clamp(floor((u_p4 - 2.0) * 0.5 + 0.5), 0.0, 4.0);
    float petalCount = petalIndex * 2.0 + 2.0;
    float petalShape = (petalCount - 2.0) / 8.0;
    float petalWave = cos(a * petalCount + sin(r * 5.0 - u_time * 0.45) * legacyWarp * 1.5);
    float curvedRadius = r * (1.0 + petalWave * mix(0.12, 0.42, petalShape));
    float sector = TAU / petalCount;
    float localAngle = (fract(a / sector + 0.5) - 0.5) * sector;
    float polygonRadius = r * cos(localAngle);
    float sharpWave = 1.0 - 4.0 * abs(localAngle) / sector;
    float sharpRadius = polygonRadius * (1.0 + sharpWave * mix(0.0, 0.42, petalShape));
    float starRadius = mix(sharpRadius, curvedRadius, curveBlend);
    float edgeRadius = mix(sharpRadius, r, curveBlend);
    float shapeWave = mix(sharpWave, petalWave, curveBlend);
    float radial = starRadius * mix(4.0, 12.0, u_p5) - u_time;
    radial += sin(a * (petalCount * 0.5 + 1.0) - u_time * 0.52) * legacyWarp * 0.42;
    float band = velvetStripe(radial, mix(0.20, 0.055, u_p7));
    float groove = velvetStripe(radial + 0.50, mix(0.080, 0.028, u_p7));
    float petalCore = pow(abs(shapeWave) * 0.5 + 0.5, 1.2);
    float center = exp(-edgeRadius * mix(3.0, 8.0, u_p7));
    float mask = smoothstep(1.45, 0.08, edgeRadius);
    float hueSignal = radial * 0.055 + shapeWave * 0.15 + edgeRadius * 0.14;
    vec3 gold = iosHsv(u_p1 + hueSignal + 0.10, 0.58, 1.0);
    vec3 rose = iosHsv(u_p1 + hueSignal + 0.92, 0.78, 1.0);
    vec3 midnight = iosHsv(u_p1 + hueSignal + 0.58, 0.72, 0.24);
    float colorMix = smoothstep(-0.45, 0.65, sin(radial * TAU + shapeWave * 2.0));
    vec3 multicolor = mix(midnight, mix(gold, rose, colorMix), band);
    vec3 singleColor = iosHsv(u_p1, 0.72, mix(0.24, 1.0, band) * mix(0.88, 1.0, colorMix));
    vec3 color = mix(singleColor, multicolor, sat(u_p2));
    color *= mask * (0.48 + petalCore * 0.70);
    color *= 1.0 - groove * mix(0.64, 0.94, u_p7);
    color += iosHsv(u_p1 + 0.02 * sat(u_p2), 0.40, center * (0.65 + u_p7)) * (0.55 + petalCore);
    color += iosHsv(u_p1 + 0.88 * sat(u_p2), 0.72, band * band * u_p7 * 0.42);
    return vec4(sat3(color * mix(0.72, 1.0, 1.0 - smoothstep(0.80, 1.40, edgeRadius))), 1.0);
}

float synthLine(float d, float width, float glow) {
    float core = 1.0 - smoothstep(width * 0.35, width, abs(d));
    float aura = exp(-abs(d) / max(width * mix(3.0, 8.0, glow), 0.0001)) * glow * 0.42;
    return sat(max(core, aura));
}
vec3 synthPalette(float signal, float amount) {
    float hue = u_p1 + signal * 0.13;
    vec3 magenta = iosHsv(hue + 0.80, 0.86, amount);
    vec3 cyan = iosHsv(hue + 0.52, 0.82, amount * 0.88);
    vec3 hot = iosHsv(hue + 0.96, 0.58, amount * amount * 1.15);
    return sat3(mix(magenta, cyan, 0.5 + 0.5 * sin(signal * TAU + u_time * 0.24)) + hot * u_p5 * 0.42);
}
vec3 synthSunPalette(float signal) {
    float shift = u_p1 - 0.56;
    float blend = 0.5 + 0.5 * sin(signal * TAU + u_time * 0.24);
    vec3 warm = mix(iosHsv(shift + 0.92, 0.96, 1.0), iosHsv(shift + 0.14, 0.74, 1.0), smoothstep(0.08, 0.92, blend));
    return sat3(warm + iosHsv(shift + 0.045, 0.90, 1.0) * (0.12 + u_p5 * 0.14));
}

vec4 synthNeonSun() {
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);
    vec2 p = uv * 2.0 - 1.0;
    p.x *= max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    float verticalOffset = mix(0.02, 0.10, u_p4); p.y -= verticalOffset;
    float r = length(p), aspect = max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    float radius = mix(0.28, (length(vec2(aspect, 1.0 + verticalOffset)) + 0.02) * 1.12, pow(sat(u_p4), 3.5));
    float circle = 1.0 - smoothstep(radius, radius + 0.010, r);
    float edgeGlow = exp(-abs(r - radius) * mix(14.0, 32.0, u_p5)) * u_p5;
    float warpedY = p.y + sin(p.x * TAU * mix(0.5, 3.5, u_p7) + u_time * 0.35) * u_p6 * 0.025;
    float spacingResponse = pow(sat(u_p7 / 500.0), 0.55), spread = sat(u_p3);
    float bandY = clamp(warpedY / max(radius * 2.0, 0.0001) + 0.5, 0.0, 1.0);
    float upperDistance = max(0.5 - bandY, 0.0), upperProgress = sat(upperDistance * 2.0);
    float equalPhaseY = (bandY - 0.5) * mix(1.0, 0.08, spacingResponse);
    float drop = 1.0 - mix(0.62, 0.08, spacingResponse);
    float spreadPhaseY = bandY >= 0.5 ? bandY - 0.5 : -(upperDistance - drop * upperDistance * upperDistance);
    float gapFraction = mix(0.50, mix(0.62, 0.985, spacingResponse) * upperProgress, spread);
    float stripePhase = fract((mix(equalPhaseY, spreadPhaseY, spread) * radius * 2.0 + u_time) * 13.0 + 0.5);
    float halfWidth = max((1.0 - gapFraction) * 0.5, 0.0025);
    float soft = min(0.045, max(0.0025, halfWidth * 0.35));
    float stripe = mix(1.0, 1.0 - smoothstep(max(halfWidth - soft, 0.0), halfWidth, abs(stripePhase - 0.5)), smoothstep(0.001, 0.03, gapFraction));
    float body = circle * mix(0.20, 0.72, stripe);
    float scan = 0.86 + 0.14 * smoothstep(0.1, 0.9, fract(uv.y * 180.0 - u_time * 4.0));
    vec3 color = mix(iosHsv(u_p1 + 0.92, 0.52, 1.0), iosHsv(u_p1 + 0.75 + p.y * 0.08, 0.88, 1.0), smoothstep(-radius * 0.78, radius * 0.78, p.y)) * body * scan;
    color += synthPalette(p.y + 0.2, edgeGlow * 0.48) + iosHsv(u_p1 + 0.78, 0.92, edgeGlow * 0.38);
    return vec4(sat3(color), 1.0);
}

vec4 synthWireTunnel() {
    vec2 p = iosSpace(vUV), center = vec2(sin(u_time * 0.17), cos(u_time * 0.13)) * u_p6 * 0.12;
    vec2 q = p - center;
    float r = mix(length(q), max(abs(q.x), abs(q.y)), smoothstep(0.0, 1.0, sat(u_p7))) + 0.002;
    float a = atan(q.y, q.x), twist = r * mix(0.4, 3.3, u_p6) + u_time * 0.18;
    float spokes = mix(10.0, 32.0, u_p3);
    float spokeCoord = (a + twist) / TAU * spokes;
    float spoke = synthLine(abs(fract(spokeCoord) - 0.5), mix(0.024, 0.009, u_p7), u_p5);
    float secondCoord = (a - twist * 0.46) / TAU * (spokes * 0.5) + u_time * 0.055;
    float second = synthLine(abs(fract(secondCoord) - 0.5), mix(0.018, 0.006, u_p7), u_p5) * 0.52;
    float ringCoord = 1.0 / (r + 0.12) * mix(0.30, 1.32, u_p4) + u_time;
    float rings = synthLine(fract(ringCoord) - 0.5, mix(0.058, 0.020, u_p7), u_p5);
    float echo = synthLine(fract(ringCoord * 0.5 - u_time * 0.075 + 0.22) - 0.5, mix(0.036, 0.012, u_p7), u_p5) * (0.28 + u_p7 * 0.26);
    float fade = smoothstep(0.04, 0.26, r) * (1.0 - smoothstep(1.25, 2.05, r));
    float intersections = rings * max(spoke, second);
    float twinkle = 0.58 + 0.42 * sin(floor(ringCoord) * 1.71 + floor(spokeCoord) * 2.13 + u_time * 2.8);
    float body = sat(max(rings * 0.58, intersections) + echo * 0.54 + max(spoke * 0.34, second * 0.42) * 0.30) * fade;
    float signal = ringCoord * 0.075 + a / TAU * 0.20;
    vec3 color = synthSunPalette(signal) * body * (1.02 + u_p5 * 0.34);
    color += synthSunPalette(signal + 0.34) * echo * fade * (0.28 + u_p5 * 0.30);
    color += mix(vec3(1.0, 0.34, 0.72), vec3(1.0, 0.94, 0.48), sat(twinkle)) * intersections * intersections * sat(twinkle) * fade * (0.48 + u_p5 * 0.58);
    color += synthSunPalette(0.18) * exp(-r * 6.2) * u_p5 * 0.34;
    return vec4(sat3(color), 1.0);
}

vec4 synthGlowRain() {
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);
    vec2 p = uv * 2.0 - 1.0;
    p.x *= max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    float cols = mix(16.0, 46.0, u_p3), cellX = floor(uv.x * cols);
    float rnd = iosHash12(vec2(cellX, 0.0) + 5.3), colX = (cellX + rnd) / cols;
    float xDist = abs(uv.x - colX) * cols;
    float y = fract(uv.y + u_time * mix(0.5, 1.7, rnd) + rnd * 3.1);
    float head = 1.0 - smoothstep(0.0, mix(0.12, 0.34, u_p4), y);
    float trail = exp(-y * mix(6.0, 18.0, u_p7));
    float line = synthLine(xDist, mix(0.055, 0.025, u_p5), u_p5) * (head + trail * 0.75);
    float wobble = sin(uv.y * TAU * mix(1.0, 7.0, u_p7) + u_time + rnd * 5.0) * u_p6 * 0.5;
    line *= smoothstep(0.55, 0.0, abs(xDist + wobble));
    float grid = synthLine(fract((p.x * (u_resolution.x / max(u_resolution.y, 1.0)) + u_time * 0.06) * mix(2.0, 8.0, u_p7)) - 0.5, 0.018, u_p5) * 0.16;
    float body = sat(line + grid * u_p7) * (0.82 + 0.18 * smoothstep(0.15, 0.95, fract(uv.y * 170.0 - u_time * 3.0)));
    vec3 color = synthPalette(rnd + uv.y * 0.1, body) * body + iosHsv(u_p1 + 0.55, 0.80, body * body * u_p5 * 0.5);
    return vec4(sat3(color), 1.0);
}

vec4 synthChromeRoad() {
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);
    float aspect = max(u_resolution.x, 1.0) / max(u_resolution.y, 1.0);
    float horizon = mix(0.46, 0.60, u_p4), roadMask = 1.0 - smoothstep(horizon - 0.02, horizon + 0.02, uv.y);
    float z = 1.0 / max(horizon - uv.y, 0.018);
    float x = (uv.x - 0.5) * aspect * z * 0.34 + sin(z * 0.15 + u_time * 0.55) * u_p6 * 0.18;
    float width = mix(0.92, 1.75, u_p4), rx = x / max(width, 0.001), arx = abs(rx);
    float surface = (1.0 - smoothstep(0.96, 1.02, arx)) * roadMask;
    float phase = z * mix(0.24, 0.92, u_p3) + u_time;
    float outer = synthLine(abs(x) - width, mix(0.022, 0.007, u_p7), u_p5);
    float inner = synthLine(abs(x) - width * 0.88, mix(0.014, 0.0045, u_p7), u_p5);
    float center = synthLine(abs(rx) - 0.032, mix(0.013, 0.005, u_p7), u_p5);
    float lane = synthLine(min(abs(rx - 0.34), abs(rx + 0.34)), mix(0.014, 0.005, u_p7), u_p5);
    float dash = smoothstep(0.08, 0.18, fract(phase * 0.55)) * (1.0 - smoothstep(0.58, 0.76, fract(phase * 0.55)));
    float panels = max(synthLine(fract((rx * 0.5 + 0.5) * mix(3.0, 8.0, u_p7)) - 0.5, mix(0.040, 0.016, u_p7), u_p5) * 0.42,
                       synthLine(fract(phase) - 0.5, mix(0.050, 0.018, u_p7), u_p5) * 0.62) * surface;
    float energy = synthLine(fract(phase * 2.35 - u_time * 0.16) - 0.5, mix(0.030, 0.010, u_p7), u_p5);
    float shine = pow(sat((0.5 + 0.5 * sin((rx * mix(2.2, 5.6, u_p7) + z * 0.040) * TAU + u_time * 0.42)) * 0.68
        + (0.5 + 0.5 * sin((-rx * 7.4 + z * 0.085) * TAU - u_time * 0.31)) * 0.32), 4.0);
    float shift = u_p1 - 0.76;
    vec3 pink = iosHsv(shift + 0.92, 0.96, 1.0), cyan = iosHsv(shift + 0.52, 0.88, 1.0);
    vec3 violet = iosHsv(shift + 0.77, 0.90, 1.0), yellow = iosHsv(shift + 0.14, 0.74, 1.0);
    vec3 color = mix(iosHsv(shift + 0.73, 0.90, 0.16), iosHsv(shift + 0.56, 0.88, 0.12), sat(rx * 0.5 + 0.5)) * (0.22 + shine * 0.78) * surface;
    color += pink * outer * roadMask * (0.82 + u_p5 * 0.48) + cyan * inner * roadMask * (0.62 + u_p5 * 0.38);
    color += yellow * center * surface * (0.68 + u_p5 * 0.34) + cyan * lane * dash * surface * (0.70 + u_p5 * 0.36);
    color += violet * panels * (0.42 + u_p5 * 0.30) + mix(cyan, pink, sat(rx * 0.5 + 0.5)) * energy * surface * (0.26 + u_p7 * 0.34);
    float horizonLine = synthLine(uv.y - horizon, mix(0.008, 0.0035, u_p7), u_p5);
    color += mix(pink, cyan, smoothstep(0.15, 0.85, uv.x)) * horizonLine * (0.74 + u_p5 * 0.46);
    color += violet * exp(-abs(uv.y - horizon) * mix(28.0, 62.0, u_p7)) * u_p5 * 0.18;
    return vec4(sat3(color), 1.0);
}

vec4 circleSequence() {
    vec2 p = iosSpace(vUV);
    float spacing = mix(0.17, 0.34, sat(u_p4));
    vec2 baseId = floor(p / spacing + 0.5);
    float body = 0.0, hueNumerator = 0.0, hueWeight = 0.0;
    float lineWidth = spacing * mix(0.018, 0.070, sat(u_p5));
    float aa = max(1.35 / min(u_resolution.x, u_resolution.y), 0.0012);
    float sequence = sat(u_p6), delay = mix(0.025, 0.160, sequence), rate = mix(0.48, 0.82, sequence);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = baseId + vec2(float(x), float(y));
            float order = mix(length(id), (abs(id.x) + abs(id.y)) * 0.58, sequence * 0.45);
            float phase = fract(u_time * rate - order * delay);
            float pulse = 0.5 - 0.5 * cos(phase * TAU);
            float eased = pulse * pulse * (3.0 - 2.0 * pulse);
            float radius = mix(spacing * 0.070, spacing * 0.490, eased);
            float ring = (1.0 - smoothstep(lineWidth, lineWidth + aa, abs(length(p - id * spacing) - radius)))
                * smoothstep(0.05, 0.18, pulse);
            body = body + ring - body * ring;
            hueNumerator += ring * fract(id.x * 0.137 + id.y * 0.173 + phase * 0.18);
            hueWeight += ring;
        }
    }
    body = sat(body) * u_p7;
    float hue = fract(u_p1 + (hueWeight > 0.0001 ? hueNumerator / hueWeight : 0.0) * sat(u_p2));
    vec3 color = iosHsv(hue, mix(0.92, 0.78, sat(u_p2)), body) + vec3(body * body * 0.12);
    return vec4(sat3(color), sat(body * 1.04));
}

vec2 squiggleFlow(vec2 p, float time, float warp) {
    float t = time * mix(0.42, 0.78, warp);
    float a = sin(p.y * mix(1.25, 2.75, warp) + p.x * 0.38 + t * 1.15);
    float b = sin(p.x * mix(1.00, 2.30, warp) - p.y * 0.46 - t * 0.92);
    float c = sin(dot(p, vec2(0.72, 0.96)) * mix(1.10, 2.20, warp) + t * 0.66);
    float d = cos(dot(p, vec2(-0.82, 0.58)) * mix(0.95, 1.80, warp) - t * 0.54);
    return vec2(a * 0.17 + c * 0.10 + d * 0.045, b * 0.15 - c * 0.075 + d * 0.055);
}

vec4 smoothSquiggle() {
    float spacing = max(u_p1, 0.001), thickness = clamp(u_p2, 0.001, 0.95) * spacing;
    float squareAmount = sat(u_p5), warp = sat(u_p4);
    vec2 p = iosSpace(vUV);
    p -= vec2(sin(u_time * 0.19) + sin(u_time * 0.071 + 1.8) * 0.42,
              cos(u_time * 0.16 + 0.7) + sin(u_time * 0.097 - 0.4) * 0.36) * (0.052 * warp);
    float damp = smoothstep(0.10, 0.42, length(p));
    vec2 waveA = squiggleFlow(p, u_time, warp);
    vec2 waveB = squiggleFlow(p * 1.65 + waveA * 0.22, u_time * 0.74 + 3.4, warp);
    vec2 push = (waveA * 0.74 + waveB * 0.34) * warp * damp;
    vec2 q = p + push;
    float radius = mix(length(q), max(abs(q.x), abs(q.y)), smoothstep(0.0, 1.0, squareAmount));
    float broad = sin((q.x * 0.82 + q.y * 0.56) * mix(1.1, 2.8, warp) + u_time * 0.40)
        + cos((q.x * -0.38 + q.y * 0.94) * mix(0.9, 2.1, warp) - u_time * 0.33) * 0.72;
    float warpedRadius = radius + broad * 0.026 * warp * damp;
    // u_time is speed-integrated; derive the same ring and hue phase rates as iOS.
    float ringCoord = warpedRadius / spacing + u_time / spacing;
    float fx = fract(ringCoord), dRing = min(fx, 1.0 - fx) * spacing;
    float aa = max(1.2 / min(u_resolution.x, u_resolution.y), 0.001);
    float line = 1.0 - smoothstep(0.0, aa * 2.0, dRing - thickness);
    float glow = exp(-dRing * mix(16.0, 44.0, thickness / spacing)) * mix(0.28, 0.78, warp);
    float body = sat(line * 1.08 + glow * 0.62), colorOn = smoothstep(0.02, 0.18, sat(u_p6));
    float travelHue = (warpedRadius / spacing) * 0.035 + warpedRadius * 0.18 + dot(push, vec2(0.45, 0.24));
    float hue = fract(sat(u_p6) + 0.58 + travelHue * sat(u_p7) + u_time * 0.08 * sat(u_p7));
    float saturation = mix(0.0, mix(0.72, 0.95, sat(u_p7)), colorOn);
    vec3 color = iosHsv(hue, saturation, body) + iosHsv(hue + 0.10, saturation * 0.70, glow * 0.28 * colorOn);
    color = mix(vec3(body), color, colorOn);
    return vec4(sat3(color), sat(line + glow * 0.46));
}

float vhsBand(float y, float center, float width) {
    float q = (y - center) / max(width, 0.001); return exp(-(q * q));
}
vec4 vhsTape() {
    vec2 uv = (vUV - 0.5) / max(u_p7, 1.0) + 0.5;
    float flow = smoothstep(0.0, 1.0, u_p3), t = u_time, x = uv.x, y = uv.y;
    float wave = sin(x * mix(3.2, 8.6, u_p5) + y * mix(0.25, 2.15, flow) + t * mix(0.38, 0.82, flow) + 1.7) * mix(0.08, 0.22, flow);
    wave += sin(x * mix(4.6, 12.8, u_p4) - y * mix(0.10, 3.40, flow) - t * mix(0.18, 0.58, flow) + 0.85) * mix(0.03, 0.16, flow);
    wave += sin((x + y * 0.65) * mix(1.8, 5.2, flow) + t * 0.30 + 1.7) * mix(0.02, 0.14, flow);
    float bandA = vhsBand(y, 0.28 + 0.10 * sin(t * 0.22 + 1.7), mix(0.10, 0.23, u_p5));
    float bandB = vhsBand(y, 0.70 + 0.08 * sin(t * 0.18 + 3.7), mix(0.12, 0.26, u_p5));
    wave += bandA * sin(x * mix(3.4, 9.0, u_p4) + y * flow * 2.2 - t * 0.52 + 1.7) * mix(0.08, 0.36, u_p4);
    wave -= bandB * sin(x * mix(3.0, 8.2, u_p4) - y * flow * 2.6 + t * 0.48 + 1.19) * mix(0.08, 0.34, u_p4);
    float d = abs(fract((y + wave * mix(0.18, 0.36, flow)) * 58.0) - 0.5);
    float width = mix(0.042, 0.026, u_p6), aa = max(58.0 / max(u_resolution.y, 1.0) * 0.75, 0.002);
    float core = 1.0 - smoothstep(width, width + aa, d);
    float line = sat(max(core, exp(-max(d - width, 0.0) * mix(18.0, 38.0, u_p6)) * u_p6 * 0.34));
    float hue = u_p1 + wave * 0.11 + uv.x * 0.10;
    vec3 blue = iosHsv(hue + 0.58, 0.82, line), violet = iosHsv(hue + 0.77, 0.82, line * 0.86);
    vec3 color = mix(violet, blue, 0.5 + 0.5 * sin(uv.x * TAU * 1.2 + wave * 4.0 + t * 0.22));
    color += iosHsv(hue + 0.48, 0.72, line * line * u_p6 * 0.75);
    return vec4(sat3(color), line);
}

vec4 pixelSquareTunnel() {
    vec2 screen = vUV * 2.0 - 1.0;
    vec2 point = vec2(screen.x * u_resolution.x / max(u_resolution.y, 1.0), screen.y);
    float rawRadius = max(max(abs(point.x), abs(point.y)), 0.004), depth = -log2(rawRadius), flowTime = u_time * 0.48;
    vec2 bend = vec2(sin(depth * 0.68 + flowTime) + 0.42 * sin(depth * 1.31 - flowTime * 0.57),
                     cos(depth * 0.57 - flowTime * 0.83) + 0.38 * sin(depth * 1.07 + flowTime * 0.44));
    point -= bend * (0.085 * sat(u_p3) * mix(0.28, 1.0, sat(depth / 6.0)));
    point = iosRot(point, sin(depth * 0.61 - flowTime * 0.72) * (0.18 * sat(u_p3)));
    float radius = max(abs(point.x), abs(point.y)), safeRadius = max(radius, 0.004);
    float detail = mix(1.0, 2.6, sat(u_p4)), depthRows = mix(5.4, 2.2, 0.0) * detail, columns = mix(15.0, 5.0, 0.0) * detail;
    float depthCoord = -log2(safeRadius) * depthRows + u_time * 1.05;
    float vertical = step(abs(point.y), abs(point.x));
    float across = (mix(point.x, point.y, vertical) / safeRadius * 0.5 + 0.5) * columns;
    vec2 local = fract(vec2(across, depthCoord));
    float tileEdge = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
    float tileMask = smoothstep(0.125, 0.125 + max(1.5 / min(u_resolution.x, u_resolution.y), 0.0015), tileEdge);
    float wallIndex = vertical > 0.5 ? (point.x >= 0.0 ? 0.0 : 2.0) : (point.y >= 0.0 ? 1.0 : 3.0);
    float dc = floor(depthCoord), wc = floor(across), hash = iosHash12(vec2(wc + wallIndex * 31.0, dc));
    float checker = step(0.5, fract((wc + dc + wallIndex) * 0.5));
    float value = mix(0.48, 1.0, checker) * mix(0.72, 1.08, 0.5 + 0.5 * sin(dc * 0.73 - u_time * 0.42)) * mix(0.90, 1.08, hash);
    float rate = mix(0.12, 0.72, sat(u_p1)), changeTime = u_clock * rate + hash * 17.0, changeStep = floor(changeTime);
    vec2 changeId = vec2(wc + wallIndex * 47.0, dc + wallIndex * 19.0);
    float state = mix(iosHash12(changeId + changeStep * vec2(17.0, 29.0)), iosHash12(changeId + (changeStep + 1.0) * vec2(17.0, 29.0)), smoothstep(0.48, 0.94, fract(changeTime)));
    value *= mix(1.0, mix(0.58, 1.10, state), sat(u_p1));
    float rainbowHue = fract(dc * 0.071 + wc * 0.037 + wallIndex * 0.17 + (state - 0.5) * 0.16 * sat(u_p1) - u_time * 0.028);
    float rainbowAmount = smoothstep(0.78, 1.0, sat(u_p5));
    vec3 color = mix(iosHsv(fract(sat(u_p5) / 0.78) + (state - 0.5) * 0.055 * sat(u_p1), 0.90, sat(value)), iosHsv(rainbowHue, 0.94, sat(value)), rainbowAmount);
    color *= mix(vertical > 0.5 ? 0.78 : 0.70, vertical > 0.5 ? 1.0 : 0.92, vertical > 0.5 ? step(0.0, point.x) : step(0.0, point.y)) * max(0.0, u_p6);
    float fade = sat(u_p7), reveal = mix(mix(0.30, 0.025, fade), 1.0, smoothstep(0.018, mix(0.16, 0.72, pow(fade, 1.15)), radius));
    reveal *= smoothstep(0.006, 0.022, radius);
    float alpha = tileMask * reveal * mix(1.0, mix(0.72, 1.0, state), sat(u_p1)) * mix(0.78, 1.0, 1.0 - smoothstep(0.88, 1.55, length(screen)));
    return vec4(sat3(color), sat(alpha));
}

void main() {
    vec4 color;
    if (u_variant < 1.5) color = psychedelicVelvetStar();
    else if (u_variant > 6.5 && u_variant < 7.5) color = cloudscapeDrift();
    else if (u_variant > 7.5 && u_variant < 8.5) color = synthNeonSun();
    else if (u_variant > 8.5 && u_variant < 9.5) color = synthWireTunnel();
    else if (u_variant > 9.5 && u_variant < 10.5) color = synthChromeRoad();
    else if (u_variant > 10.5 && u_variant < 11.5) color = synthGlowRain();
    else if (u_variant > 11.5 && u_variant < 12.5) color = circleSequence();
    else if (u_variant > 12.5 && u_variant < 13.5) color = smoothSquiggle();
    else if (u_variant > 13.5 && u_variant < 14.5) color = vhsTape();
    else if (u_variant > 14.5 && u_variant < 15.5) color = abstractCloudTunnel();
    else if (u_variant > 15.5 && u_variant < 16.5) color = abstractMatterBloom();
    else if (u_variant > 16.5 && u_variant < 17.5) color = abstractShapeRift();
    else if (u_variant > 18.5 && u_variant < 19.5) color = abstractCrystalSoup();
    else if (u_variant > 20.5 && u_variant < 21.5) color = abstractPulseVeins();
    else if (u_variant > 21.5 && u_variant < 22.5) color = abstractPulseWeb();
    else if (u_variant > 23.5 && u_variant < 24.5) color = abstractLiquidWire();
    else if (u_variant > 24.5 && u_variant < 25.5) color = abstractRibbonStorm();
    else if (u_variant > 32.5 && u_variant < 33.5) color = pixelSquareTunnel();
    else if (u_variant > 33.5 && u_variant < 34.5) color = cyberPattern(0.0);
    else if (u_variant > 36.5 && u_variant < 37.5) color = cyberPattern(1.0);
    else if (u_variant > 38.5 && u_variant < 39.5) color = cyberPattern(2.0);
    else if (u_variant > 39.5 && u_variant < 40.5) color = cyberPattern(3.0);
    else if (u_variant > 57.5 && u_variant < 58.5) color = abstractSquareTunnel();
    else if (u_variant > 58.5 && u_variant < 59.5) color = signalSquareTunnel();
    else if (u_variant > 59.5 && u_variant < 60.5) color = neonFamily(0.0);
    else if (u_variant > 60.5 && u_variant < 61.5) color = neonFamily(2.0);
    else if (u_variant > 61.5 && u_variant < 62.5) color = neonFamily(3.0);
    else if (u_variant > 62.5 && u_variant < 63.5) color = neonFamily(4.0);
    else color = vec4(0.0, 0.0, 0.0, 1.0);
    gl_FragColor = color;
}
