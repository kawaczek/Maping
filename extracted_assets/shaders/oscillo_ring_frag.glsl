#version 100
// Oscillo Ring — ported from OscilloRing.metal (or_oscillo_ring_frag).
// Customizable oscilloscope ring: wiggle + glow + smoke + 3D-ish lighting.
//
// Deviation from Metal: the original shades with screen-space derivatives
// (dfdx/dfdy of field = r - rad). GLSL ES 2.0 has no derivatives without the
// GL_OES_standard_derivatives extension, so the gradient is computed
// ANALYTICALLY here: grad(field) = p/r - (d wig / d ang) * grad(ang).
// After normalize() this matches the Metal gradient direction exactly, except
// it omits the per-pixel hash jitter term (ir), which is non-differentiable
// noise anyway.
precision highp float;

varying vec2 vUV;

uniform float u_time;
uniform vec2  u_resolution;

uniform float u_radius;         // ring radius (0..~1 in aspect-corrected space)
uniform float u_thickness;      // ring band thickness
uniform float u_wiggleAmount;   // oscilloscope-ness
uniform float u_wiggleSpeed;    // wiggle speed multiplier
uniform float u_wigglePhase;
uniform float u_glowAmount;     // overall glow brightness
uniform float u_glowFalloff;    // higher = tighter glow
uniform float u_smokeAmount;    // 0 = off
uniform float u_smokeScale;     // bigger = larger smoke blobs
uniform float u_baseHue;        // 0..1
uniform float u_hueSpeed;       // cycles around ring
uniform float u_huePhase;

const float OR_PI = 3.14159265358979;

// ---------- cheap noise helpers ----------
float or_hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float or_hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float or_vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = or_hash21(i + vec2(0.0, 0.0));
    float b = or_hash21(i + vec2(1.0, 0.0));
    float c = or_hash21(i + vec2(0.0, 1.0));
    float d = or_hash21(i + vec2(1.0, 1.0));
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

// HSV -> RGB (0..1)
vec3 or_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 px = 1.0 / res;

    vec2 uv = vUV;

    // Centered, aspect-corrected coordinate space
    vec2 p = (uv - 0.5) * 2.0;
    float aspect = res.x / res.y;
    p.x *= aspect;

    float r = length(p);
    float ang = atan(p.y, p.x);                  // [-pi, pi]
    float a01 = (ang + OR_PI) / (2.0 * OR_PI);   // [0..1]

    float t = u_time;

    // Params (clamped-ish for safety)
    float baseRadius   = max(u_radius, 0.0);
    float thickness    = max(u_thickness, 0.0001);
    float wiggleAmt    = max(u_wiggleAmount, 0.0);
    float wiggleSpeed  = u_wiggleSpeed;
    float glowAmt      = max(u_glowAmount, 0.0);
    float glowFalloff  = max(u_glowFalloff, 1.0);
    float smokeAmt     = max(u_smokeAmount, 0.0);
    float smokeScale   = max(u_smokeScale, 0.0001);
    float baseHue      = fract(u_baseHue);
    float hueSpeed     = u_hueSpeed;

    // Wiggle: harmonic motion + a tiny hash jitter (scaled by wiggleAmount)
    float wt = u_wigglePhase;

    float wig =
        wiggleAmt * (
            0.030 * sin(6.0  * ang + wt * 2.2) +
            0.016 * sin(13.0 * ang - wt * 1.3) +
            0.010 * sin(29.0 * ang + wt * 0.7)
        );

    float ir =
        wiggleAmt *
        (or_hash11(a01 * 64.0 + wt * 0.8) - 0.5) * 0.012;

    float rad = baseRadius + wig + ir;

    // Ring band SDF
    float band = abs(r - rad) - thickness;

    // Anti-alias
    float aa = 1.75 * min(px.x, px.y) * 2.0;

    // Ring alpha (core)
    float ringAlpha = 1.0 - smoothstep(0.0, aa, band);

    // Glow (two exponentials for depth) - scaled by glowAmount
    float d = abs(r - rad);
    float glowTight = exp(-d * (glowFalloff * 1.6));
    float glowWide  = exp(-d * (glowFalloff * 0.6));
    float glow = (glowTight * 0.9 + glowWide * 0.35) * glowAmt;

    // Color around the ring
    float hue = fract(baseHue + a01 + u_huePhase);
    vec3 baseCol = or_hsv2rgb(vec3(hue, 0.85, 1.0));

    // 3D-ish shading: analytic gradient of field = r - rad(ang)
    // (see deviation note in file header)
    float rr = max(r, 1e-4);
    float dwig =
        wiggleAmt * (
            0.030 * 6.0  * cos(6.0  * ang + wt * 2.2) +
            0.016 * 13.0 * cos(13.0 * ang - wt * 1.3) +
            0.010 * 29.0 * cos(29.0 * ang + wt * 0.7)
        );
    vec2 gradR   = p / rr;
    vec2 gradAng = vec2(-p.y, p.x) / (rr * rr);
    vec2 g = gradR - dwig * gradAng;
    vec2 n2 = normalize(g + vec2(1e-5));

    vec2 lightDir = normalize(vec2(0.65, 0.75));
    float ndl = clamp(dot(n2, lightDir), -1.0, 1.0);

    float highlight = pow(clamp(0.5 + 0.5 * ndl, 0.0, 1.0), 1.8);
    float shadow    = pow(clamp(0.5 - 0.5 * ndl, 0.0, 1.0), 2.2);

    vec3 litCol = baseCol * (0.85 + 0.60 * highlight) - vec3(0.10) * shadow;
    litCol = max(litCol, vec3(0.0));

    // Core + glow
    vec3 col = litCol * (ringAlpha * 1.15) + litCol * (glow * 0.85);

    // Smoke: value noise + radial envelope (scaled by smokeAmount)
    float smoke = 0.0;
    if (smokeAmt > 0.0001) {
        vec2 sp = p * smokeScale + vec2(t * 0.08, -t * 0.05);
        float smokeN = or_vnoise(sp) * 0.75 + or_vnoise(sp * 0.5 + 7.3) * 0.25;

        float smokeStart = rad + thickness * 0.2;
        float smokeEnd   = rad + 0.42;

        float smokeRad = smoothstep(smokeStart, smokeEnd, r) *
                         (1.0 - smoothstep(smokeEnd, smokeEnd + 0.25, r));

        float smokeWisps = smoothstep(0.48, 0.78, smokeN) * smokeRad;
        smoke = smokeWisps * smokeAmt;

        // Smoke tint: slightly colder/desaturated
        vec3 smokeCol = mix(litCol, vec3(0.9, 0.95, 1.0), 0.25);
        col += smokeCol * (smoke * 0.35);
    }

    // Final alpha
    float alpha = clamp(ringAlpha + glow * 0.55 + smoke * 0.25, 0.0, 1.0);

    if (alpha <= 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        gl_FragColor = vec4(col, alpha);
    }
}
