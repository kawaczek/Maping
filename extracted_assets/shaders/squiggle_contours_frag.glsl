#version 100
// Squiggle Contours — ported from SquiggleContours.metal (sc_squiggle_contours_frag).
// Evenly spaced contour rings moving inward (stable tunnel), circle/square toggle.
precision highp float;

varying vec2 vUV;

uniform float u_time;
uniform vec2  u_resolution;

uniform float u_spacing;        // ring spacing (radius units)
uniform float u_thickness;      // line thickness as fraction of spacing (0..1)
uniform float u_speed;          // inward speed (negative feels like moving inward)
uniform float u_motionPhase;
uniform float u_wiggleAmount;   // wiggle amplitude
uniform float u_wiggleFreq;     // wiggle angular frequency
uniform float u_wiggleSpeed;    // wiggle speed
uniform float u_wigglePhase;
uniform float u_glowAmount;     // glow amount
uniform float u_glowFalloff;    // glow falloff (higher = tighter)
uniform float u_squareMode;     // 0 = circle, 1 = square

// ---------- helpers ----------
float sc_hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// distance to nearest integer in 1D, returns [0..0.5]
float sc_distToNearestInteger(float x) {
    float fx = fract(x);
    return min(fx, 1.0 - fx);
}

// Chebyshev "square radius"
float sc_squareRadius(vec2 p) {
    return max(abs(p.x), abs(p.y));
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 px = 1.0 / res;

    vec2 uv = vUV;

    // Centered, aspect-corrected coordinate space
    vec2 p = (uv - 0.5) * 2.0;
    float aspect = res.x / res.y;
    p.x *= aspect;

    float t = u_time;

    float spacing     = max(u_spacing, 0.0005);
    float thickness   = clamp(u_thickness, 0.0001, 0.95) * spacing;
    float speed       = u_speed;

    float wiggleAmt   = max(u_wiggleAmount, 0.0);
    float wiggleFreq  = max(u_wiggleFreq, 0.0);
    float wiggleSpeed = u_wiggleSpeed;

    float glowAmt     = max(u_glowAmount, 0.0);
    float glowFalloff = max(u_glowFalloff, 0.1);

    float squareMode  = (u_squareMode >= 0.5) ? 1.0 : 0.0;

    // radius: stable ring coordinate uses either circle or square distance
    float rCircle = length(p);
    float rSquare = sc_squareRadius(p);
    float r = mix(rCircle, rSquare, squareMode);

    float ang = atan(p.y, p.x);

    // Stable tunnel motion: PHASE shift in radius (keeps spacing constant)
    // Note: rShift may go negative — GLSL fract(x) = x - floor(x) matches
    // Metal's fract for negatives, so sc_distToNearestInteger stays correct.
    float rShift = r + u_motionPhase;
    float ringCoord = rShift / spacing;

    // Distance to nearest ring centerline in world radius units
    float dInt = sc_distToNearestInteger(ringCoord) * spacing;

    // Wiggle: radial wobble that doesn't grow over time
    float ringId = floor(ringCoord);
    float wt = u_wigglePhase;
    float phase = sc_hash11(ringId * 17.13 + 0.31) * 6.2831853;

    float wig =
        wiggleAmt * (
            0.55 * sin((wiggleFreq * 1.0) * ang + wt * 1.3 + phase) +
            0.30 * sin((wiggleFreq * 2.1) * ang - wt * 0.9 + phase * 0.7) +
            0.15 * sin((wiggleFreq * 3.7) * ang + wt * 0.5 - phase * 0.4)
        );

    // Apply wiggle to band distance
    float band = abs(dInt + wig * 0.12 * spacing) - thickness;

    // Anti-alias
    float aa = 1.6 * min(px.x, px.y) * 2.0;

    float lineAlpha = 1.0 - smoothstep(0.0, aa, band);

    // Glow around the line
    float d = abs(dInt + wig * 0.12 * spacing);
    float glow = exp(-d * glowFalloff) * glowAmt;

    float v = clamp(lineAlpha * 1.15 + glow * 0.75, 0.0, 1.0);

    vec3 col = vec3(v);
    float alpha = clamp(lineAlpha + glow * 0.35, 0.0, 1.0);

    if (alpha <= 0.00005) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        gl_FragColor = vec4(col, alpha);
    }
}
