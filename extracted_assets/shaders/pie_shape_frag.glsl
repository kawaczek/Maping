#version 100
// Port of PieShape.metal (ps_pie_shape_frag) — circle/square morph with border,
// pie fill (fill-then-unfill) + glow, transparent background.
// The Metal vertex stage used a FLIPPED V; replicated as uv = vec2(vUV.x, 1.0 - vUV.y)
// so the pie seam sits at TOP (12 o'clock) at rotation = 0, matching iOS.
precision highp float;
varying vec2 vUV;

uniform float u_time;       // unused (kept for harness convention)
uniform vec2 u_resolution;

uniform float u_size;          // 0.05..0.98
uniform float u_border;        // 0.001..0.20
uniform float u_pieFill;       // 0..1 (fills then unfills in one sweep)
uniform float u_radialFill;    // 0..1
uniform float u_borderColor;   // 0..1 knob (0 black, mid rainbow, 1 white)
uniform float u_fillColor;     // 0..1 knob
uniform float u_borderOpacity; // 0..1
uniform float u_fillOpacity;   // 0..1
uniform float u_rotation;      // 0..1 turns
uniform float u_morph;         // 0..1 (0 circle, 1 square)
uniform float u_glow;          // 0..3

const float PS_PI = 3.14159265358979;

vec2 ps_rotate(vec2 p, float a) {
    float s = sin(a), c = cos(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec3 ps_hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Knob mapping: 0 => black, mid => rainbow, 1 => white
vec3 ps_knobColor(float k) {
    k = clamp(k, 0.0, 1.0);

    float hue = fract(k * 0.92);
    vec3 rainbow = ps_hsv2rgb(vec3(hue, 0.90, 1.0));

    float lo = smoothstep(0.00, 0.08, k);
    float hi = smoothstep(0.92, 1.00, k);

    vec3 col = mix(vec3(0.0), rainbow, lo);
    col = mix(col, vec3(1.0), hi);
    return col;
}

float ps_sdfCircle(vec2 p, float r) { return length(p) - r; }
float ps_sdfSquare(vec2 p, float r) { return max(abs(p.x), abs(p.y)) - r; }

float ps_wrapAngleDist(float a, float b) {
    float d = abs(a - b);
    return min(d, (2.0 * PS_PI) - d);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 px  = 1.0 / res;

    // Replicate the Metal flipped-V UV setup
    vec2 uv = vec2(vUV.x, 1.0 - vUV.y);

    // Base centered coords in "screen space" (NO aspect correction)
    vec2 p0 = (uv - 0.5) * 2.0;

    // AA (based on pixels)
    float aa = 1.75 * min(px.x, px.y) * 2.0;

    // Rotation 0..1 turns => 0..2pi (exactly 360 deg range)
    float rot = clamp(u_rotation, 0.0, 1.0) * (2.0 * PS_PI);

    // For the PIE angle / boundaries: use screen-space so the boundary is a perfect straight ray
    vec2 pLine = ps_rotate(p0, rot);

    // For the SHAPE itself: aspect-correct (keeps circle circular)
    vec2 pShape = p0;
    float aspect = res.x / res.y;
    pShape.x *= aspect;
    vec2 pr = ps_rotate(pShape, rot);

    float size       = max(u_size, 0.0001);
    float border     = max(u_border, 0.00001);
    float pieFill    = clamp(u_pieFill, 0.0, 1.0);
    float radialFill = clamp(u_radialFill, 0.0, 1.0);
    float morph      = clamp(u_morph, 0.0, 1.0);

    // Morph SDF circle->square (in aspect-corrected space)
    float dC  = ps_sdfCircle(pr, size);
    float dS  = ps_sdfSquare(pr, size);
    float sdf = mix(dC, dS, morph);

    // Border mask
    float band = abs(sdf) - border;
    float borderMask = 1.0 - smoothstep(0.0, aa, band);

    // Inside mask
    float inside = 1.0 - smoothstep(0.0, aa, sdf);

    // Distance metric that morphs circle->square (for radial fill & glow math)
    float rCircle = length(pr);
    float rSquare = max(abs(pr.x), abs(pr.y));
    float rMetric = mix(rCircle, rSquare, morph);

    // ----------------------------
    // Pie sector: fill then unfill
    // ----------------------------

    // Angle from screen-space (straight rays)
    float ang = atan(pLine.y, pLine.x);            // [-pi, pi]
    float a01 = (ang + PS_PI) / (2.0 * PS_PI);     // [0..1]

    // With the flipped-UV setup, TOP corresponds to ang = -pi/2 => a01 = 0.25
    const float startA01 = 0.25;
    float aShift = fract(a01 - startA01);          // 0 is now "top seam"

    // One-knob fill-then-unfill window:
    // k in [0..0.5] : expands [0..2k]
    // k in (0.5..1] : shrinks by moving start forward [2k-1..1]
    float k = pieFill;
    float startEdge = max(0.0, 2.0 * k - 1.0);
    float endEdge   = min(1.0, 2.0 * k);
    float span      = max(0.0, endEdge - startEdge);

    // True off when empty
    float pieOn = smoothstep(0.0, aa * 4.0, span);

    // Special case: when span ~ 1 (k ~ 0.5), treat as full circle
    float fullCircle = smoothstep(1.0 - 6.0 * aa, 1.0, span);

    // AA for the wedge boundaries using signed linear distance to the angle edges
    float aRad     = aShift    * (2.0 * PS_PI);
    float startRad = startEdge * (2.0 * PS_PI);
    float endRad   = endEdge   * (2.0 * PS_PI);

    // Signed distances (positive when inside the interval)
    float ds = (aRad - startRad);
    float de = (endRad - aRad);

    // Convert angular distance to approximate linear distance (keeps AA consistent on screen)
    float w = aa * 1.25;                 // edge softness in "p units"
    float dsLin = ds * rMetric;
    float deLin = de * rMetric;

    float edgeInStart = smoothstep(0.0, w, dsLin);
    float edgeInEnd   = smoothstep(0.0, w, deLin);

    float sectorAA = edgeInStart * edgeInEnd;

    // In the fullCircle region, just return 1.0 (no seams)
    float sector = mix(sectorAA, 1.0, fullCircle) * pieOn;

    // Radial fill (morph metric)
    float rEdge = size * radialFill;
    float radial = 1.0 - smoothstep(rEdge, rEdge + (aa * 2.0), rMetric);

    float fillMask = inside * sector * radial;

    // Colors
    vec3 borderCol = ps_knobColor(u_borderColor);
    vec3 fillCol   = ps_knobColor(u_fillColor);

    float bOp = clamp(u_borderOpacity, 0.0, 1.0);
    float fOp = clamp(u_fillOpacity, 0.0, 1.0);

    // Border glow
    float glowAmt = max(u_glow, 0.0);
    float glowFalloff = 18.0;
    float distToEdge = abs(sdf);
    float glowBorder = exp(-(max(0.0, distToEdge - border)) * glowFalloff) * glowAmt;

    // Pie fill glow (two boundaries):
    // 1) radial boundary (rMetric == rEdge)
    // 2) sector boundary lines (aShift == startEdge/endEdge)
    float fillOn = pieOn * smoothstep(0.0, aa * 4.0, radialFill);

    // Radial-edge glow (only where sector is active)
    float glowRadial = exp(-abs(rMetric - rEdge) * 22.0) * glowAmt;
    glowRadial *= inside * sector * fillOn;

    // Sector-edge glow using wrapped angular distance (safe near 0/2pi)
    float distStart = rMetric * ps_wrapAngleDist(aRad, startRad);
    float distEnd   = rMetric * ps_wrapAngleDist(aRad, endRad);

    float glowStart = exp(-distStart * 20.0) * glowAmt;
    float glowEnd   = exp(-distEnd   * 20.0) * glowAmt;

    glowStart *= inside * radial * fillOn;
    glowEnd   *= inside * radial * fillOn;

    float glowFill = (glowRadial * 0.7 + (glowStart + glowEnd) * 0.9);

    // Compose
    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // Fill
    col += fillCol * (fillMask * fOp);
    alpha = max(alpha, fillMask * fOp);

    // Border
    col += borderCol * (borderMask * bOp);
    alpha = max(alpha, borderMask * bOp);

    // Border glow
    col += borderCol * (glowBorder * 0.65) * bOp;
    alpha = max(alpha, min(1.0, glowBorder * 0.45) * bOp);

    // Fill glow
    col += fillCol * (glowFill * 0.75) * fOp;
    alpha = max(alpha, min(1.0, glowFill * 0.35) * fOp);

    col = clamp(col, 0.0, 1.0);
    alpha = clamp(alpha, 0.0, 1.0);

    if (alpha <= 0.00005) {
        gl_FragColor = vec4(0.0);
        return;
    }
    gl_FragColor = vec4(col, alpha);
}
