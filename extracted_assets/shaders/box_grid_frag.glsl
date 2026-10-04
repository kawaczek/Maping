#version 100
// BoxGrid — faithful port of iOS Metal BoxGrid.metal (bg_box_grid_frag).
// Parallax grid "room" behind the wall plane. Static (time unused, as on iOS).
#extension GL_OES_standard_derivatives : enable
precision highp float;
varying vec2 vUV;

uniform vec2 u_resolution;
uniform float u_time;  // present for convention; unused (as in the Metal original)

uniform float u_x;     // viewer offset X (screen units)
uniform float u_y;     // viewer offset Y (screen units)
uniform float u_z;     // viewer distance in front of wall (screen units)
uniform float u_depth; // box depth behind wall (screen units)

const float EPS = 1e-4;

vec2 bg_aspectCorrect(vec2 p, vec2 res) {
    float aspect = max(res.x, 1.0) / max(res.y, 1.0);
    p.x *= aspect;
    return p;
}

// Anti-aliased grid lines on 0..1 UV with N cells.
// Returns 1 at lines, 0 elsewhere.
float bg_gridMask(vec2 uv, float N, float lineW) {
    vec2 x = uv * N;

    vec2 g = fract(x);
    vec2 d = min(g, 1.0 - g);            // 0 at line

#ifdef GL_OES_standard_derivatives
    vec2 w = fwidth(x);                  // screen-space footprint (in "cells")
#else
    // Fallback when derivatives are unavailable: approximate one-pixel footprint.
    vec2 w = vec2(N) / max(u_resolution, vec2(1.0));
#endif
    // Convert lineW from "uv units" to "cell units":
    float lw = lineW * N;

    float mX = 1.0 - smoothstep(lw, lw + w.x, d.x);
    float mY = 1.0 - smoothstep(lw, lw + w.y, d.y);

    return clamp(max(mX, mY), 0.0, 1.0);
}

void bg_considerCandidate(inout float tBest,
                          inout int faceBest,
                          inout vec3 hpBest,
                          float t,
                          int face,
                          vec3 ro,
                          vec3 rd,
                          float depth) {
    if (t <= EPS || t >= tBest) return;

    vec3 hp = ro + rd * t;

    // Must be behind the wall (z < 0) and inside the box bounds.
    if (hp.z >= -EPS) return;
    if (hp.z < -depth - EPS) return;

    if (hp.x < -1.0 - EPS || hp.x > 1.0 + EPS) return;
    if (hp.y < -1.0 - EPS || hp.y > 1.0 + EPS) return;

    tBest = t;
    faceBest = face;
    hpBest = hp;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));

    // Metal vertex used a v-flipped uv table; combined with the Android FBO
    // readback flip, vUV maps 1:1 to Metal's in.uv here.
    vec2 p = (vUV - 0.5) * 2.0;
    p = bg_aspectCorrect(p, res);

    float vz = max(u_z, 0.05);
    float d  = max(u_depth, 0.05);

    // Viewer origin and ray through wall plane z=0
    vec3 ro = vec3(u_x, u_y, vz);
    vec3 P  = vec3(p.x, p.y, 0.0);
    vec3 rd = normalize(P - ro);

    // If ray doesn't go toward the wall, nothing
    if (rd.z >= -1e-5) {
        gl_FragColor = vec4(0.0);
        return;
    }

    float tBest = 1e9;
    int faceBest = -1; // 0=back,1=left,2=right,3=bottom,4=top
    vec3 hpBest = vec3(0.0);

    // Back wall: z = -d
    if (abs(rd.z) > EPS) {
        float t = (-d - ro.z) / rd.z;
        vec3 hp = ro + rd * t;
        // quick face bounds precheck
        if (hp.x >= -1.0 && hp.x <= 1.0 && hp.y >= -1.0 && hp.y <= 1.0) {
            bg_considerCandidate(tBest, faceBest, hpBest, t, 0, ro, rd, d);
        }
    }

    // Left wall: x = -1
    if (abs(rd.x) > EPS) {
        float t = (-1.0 - ro.x) / rd.x;
        vec3 hp = ro + rd * t;
        if (hp.y >= -1.0 && hp.y <= 1.0 && hp.z <= -EPS && hp.z >= -d) {
            bg_considerCandidate(tBest, faceBest, hpBest, t, 1, ro, rd, d);
        }
    }

    // Right wall: x = +1
    if (abs(rd.x) > EPS) {
        float t = ( 1.0 - ro.x) / rd.x;
        vec3 hp = ro + rd * t;
        if (hp.y >= -1.0 && hp.y <= 1.0 && hp.z <= -EPS && hp.z >= -d) {
            bg_considerCandidate(tBest, faceBest, hpBest, t, 2, ro, rd, d);
        }
    }

    // Bottom wall: y = -1
    if (abs(rd.y) > EPS) {
        float t = (-1.0 - ro.y) / rd.y;
        vec3 hp = ro + rd * t;
        if (hp.x >= -1.0 && hp.x <= 1.0 && hp.z <= -EPS && hp.z >= -d) {
            bg_considerCandidate(tBest, faceBest, hpBest, t, 3, ro, rd, d);
        }
    }

    // Top wall: y = +1
    if (abs(rd.y) > EPS) {
        float t = ( 1.0 - ro.y) / rd.y;
        vec3 hp = ro + rd * t;
        if (hp.x >= -1.0 && hp.x <= 1.0 && hp.z <= -EPS && hp.z >= -d) {
            bg_considerCandidate(tBest, faceBest, hpBest, t, 4, ro, rd, d);
        }
    }

    if (faceBest < 0) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec3 hp = hpBest;

    // Face UVs (0..1)
    vec2 uvFace = vec2(0.0);

    if (faceBest == 0) {
        // back: x,y
        uvFace = (hp.xy * 0.5) + 0.5;
    } else if (faceBest == 1 || faceBest == 2) {
        // left/right: z,y
        float uz = (hp.z + d) / d;
        float uy = (hp.y * 0.5) + 0.5;
        uvFace = vec2(uz, uy);
    } else {
        // bottom/top: x,z
        float ux = (hp.x * 0.5) + 0.5;
        float uz = (hp.z + d) / d;
        uvFace = vec2(ux, uz);
    }

    // Grid
    float N = 8.0;
    float lineW = 0.010;

    float g = bg_gridMask(uvFace, N, lineW);

    // Slight depth fade
    float distFade = clamp(1.0 - (tBest / (vz + d + 0.001)) * 0.35, 0.0, 1.0);
    float alpha = g * distFade;

    if (alpha <= 0.00005) {
        gl_FragColor = vec4(0.0);
        return;
    }

    gl_FragColor = vec4(1.0, 1.0, 1.0, alpha);
}
