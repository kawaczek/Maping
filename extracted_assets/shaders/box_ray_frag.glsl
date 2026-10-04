#version 100
// BoxRay — faithful port of iOS Metal BoxRay.metal (br_boxray_frag).
// Analytic ray-vs-plane "room" with two point lights. Static (time unused, as on iOS).
precision highp float;
varying vec2 vUV;

uniform vec2 u_resolution;
uniform float u_time; // present for convention; unused (as in the Metal original)

uniform float u_x;
uniform float u_y;

// camera distance multiplier (higher = less perspective / less angled walls)
uniform float u_focal;

uniform float u_z;

uniform float u_depth;

uniform float u_open;     // 0..1
uniform float u_openW;    // 0..1-ish (half size used internally)
uniform float u_openH;    // 0..1-ish

uniform float u_wallHue;        // 0..1
uniform float u_wallBrightness; // 0..2
uniform float u_roughness;      // 0..1 (higher = softer spec)

uniform vec3 u_light1Pos;       // room space
uniform float u_light1Intensity;

uniform vec3 u_light2Pos;
uniform float u_light2Intensity;

uniform float u_ambient;        // 0..1

const float EPS = 1e-4;

vec2 br_aspectCorrect(vec2 p, vec2 res) {
    float aspect = max(res.x, 1.0) / max(res.y, 1.0);
    p.x *= aspect;
    return p;
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void br_considerPlaneHit(inout float tBest,
                         inout vec3 nBest,
                         inout vec3 hpBest,
                         float t,
                         vec3 ro,
                         vec3 rd,
                         vec3 n,
                         vec2 xRange,
                         vec2 yRange,
                         vec2 zRange)
{
    if (t <= EPS || t >= tBest) return;

    vec3 hp = ro + rd * t;

    if (hp.x < xRange.x - EPS || hp.x > xRange.y + EPS) return;
    if (hp.y < yRange.x - EPS || hp.y > yRange.y + EPS) return;
    if (hp.z < zRange.x - EPS || hp.z > zRange.y + EPS) return;

    tBest = t;
    nBest = n;
    hpBest = hp;
}

float br_atten(float r) {
    return 1.0 / (1.0 + 0.45 * r * r);
}

float br_saturate(float x) { return clamp(x, 0.0, 1.0); }

vec3 br_evalPointLight(vec3 hp,
                       vec3 n,
                       vec3 V,
                       vec3 baseColor,
                       float roughness,
                       vec3 Lpos,
                       float lint)
{
    vec3 Lvec = Lpos - hp;
    float r = length(Lvec);
    vec3 L = (r > 1e-5) ? (Lvec / r) : vec3(0.0);

    float ndl = max(dot(n, L), 0.0);

    vec3 H = normalize(L + V);
    float ndh = max(dot(n, H), 0.0);

    // Metal names this local "exp"; renamed — exp() is a builtin in GLSL.
    float specExp = mix(180.0, 18.0, br_saturate(roughness));
    float spec = pow(ndh, specExp);

    float fres = pow(1.0 - max(dot(n, V), 0.0), 5.0);

    float att = br_atten(r);
    float diff = ndl;
    float sp = spec * (0.20 + 0.80 * fres);

    return att * lint * (baseColor * diff + vec3(1.0) * sp);
}

vec3 br_shade(vec3 hp,
              vec3 n,
              vec3 ro,
              vec3 baseColor,
              float roughness,
              float ambient,
              vec3 L1pos, float L1int,
              vec3 L2pos, float L2int)
{
    vec3 V = normalize(ro - hp);

    vec3 c = baseColor * ambient;
    c += br_evalPointLight(hp, n, V, baseColor, roughness, L1pos, L1int);
    c += br_evalPointLight(hp, n, V, baseColor, roughness, L2pos, L2int);
    return c;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));

    // Metal vertex used a v-flipped uv table; combined with the Android FBO
    // readback flip, vUV maps 1:1 to Metal's in.uv here.
    vec2 uv = vUV;

    // Screen ray setup (DO NOT scale p for "focal" — that would zoom)
    vec2 p = (uv - 0.5) * 2.0;
    p = br_aspectCorrect(p, res);

    float roomDepth = -(u_z * 0.02); // 100 -> -2.0
    float wallT = max(u_depth, 0.0);

    // change perspective by changing camera distance (not p)
    float focal = clamp(u_focal, 0.35, 6.0);
    float camZ  = 1.25 * focal;

    vec3 ro = vec3(u_x, u_y, camZ);

    // Ray through the front plane at z=0 (framing stays identical)
    vec3 P = vec3(p.x, p.y, 0.0);
    vec3 rd = normalize(P - ro);

    if (rd.z >= -1e-5) {
        gl_FragColor = vec4(0.0);
        return;
    }

    float zBack = roomDepth;
    bool hasDepth = (zBack < -1e-4);

    float openAmt = br_saturate(u_open);
    float holeHalfW = br_saturate(u_openW) * openAmt;
    float holeHalfH = br_saturate(u_openH) * openAmt;

    vec3 base = hsv2rgb(vec3(fract(u_wallHue), 0.55, max(u_wallBrightness, 0.0)));

    float tBest = 1e9;
    vec3 nBest = vec3(0.0);
    vec3 hpBest = vec3(0.0);

    // Back wall at z = zBack
    if (abs(rd.z) > EPS) {
        float t = (zBack - ro.z) / rd.z;
        vec3 hp = ro + rd * t;

        if (hp.x >= -1.0 && hp.x <= 1.0 && hp.y >= -1.0 && hp.y <= 1.0) {
            bool inHole = (openAmt > 0.0) &&
                          (abs(hp.x) < holeHalfW) &&
                          (abs(hp.y) < holeHalfH);

            if (!inHole) {
                br_considerPlaneHit(tBest, nBest, hpBest,
                                    t, ro, rd,
                                    vec3(0.0, 0.0, 1.0),
                                    vec2(-1.0, 1.0),
                                    vec2(-1.0, 1.0),
                                    vec2(zBack, zBack));
            }
        }
    }

    // Side walls
    if (hasDepth) {
        if (abs(rd.x) > EPS) {
            float t = (-1.0 - ro.x) / rd.x;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(1.0, 0.0, 0.0),
                                vec2(-1.0, -1.0),
                                vec2(-1.0, 1.0),
                                vec2(zBack, 0.0));
        }

        if (abs(rd.x) > EPS) {
            float t = (1.0 - ro.x) / rd.x;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(-1.0, 0.0, 0.0),
                                vec2(1.0, 1.0),
                                vec2(-1.0, 1.0),
                                vec2(zBack, 0.0));
        }

        if (abs(rd.y) > EPS) {
            float t = (-1.0 - ro.y) / rd.y;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(0.0, 1.0, 0.0),
                                vec2(-1.0, 1.0),
                                vec2(-1.0, -1.0),
                                vec2(zBack, 0.0));
        }

        if (abs(rd.y) > EPS) {
            float t = (1.0 - ro.y) / rd.y;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(0.0, -1.0, 0.0),
                                vec2(-1.0, 1.0),
                                vec2(1.0, 1.0),
                                vec2(zBack, 0.0));
        }
    }

    // Hole plank edges
    if (openAmt > 0.0 && wallT > 1e-4) {
        float z0 = zBack - wallT;
        float z1 = zBack;

        if (holeHalfW > 1e-5 && abs(rd.x) > EPS) {
            float t = (-holeHalfW - ro.x) / rd.x;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(1.0, 0.0, 0.0),
                                vec2(-holeHalfW, -holeHalfW),
                                vec2(-holeHalfH, holeHalfH),
                                vec2(z0, z1));
        }

        if (holeHalfW > 1e-5 && abs(rd.x) > EPS) {
            float t = (holeHalfW - ro.x) / rd.x;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(-1.0, 0.0, 0.0),
                                vec2(holeHalfW, holeHalfW),
                                vec2(-holeHalfH, holeHalfH),
                                vec2(z0, z1));
        }

        if (holeHalfH > 1e-5 && abs(rd.y) > EPS) {
            float t = (-holeHalfH - ro.y) / rd.y;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(0.0, 1.0, 0.0),
                                vec2(-holeHalfW, holeHalfW),
                                vec2(-holeHalfH, -holeHalfH),
                                vec2(z0, z1));
        }

        if (holeHalfH > 1e-5 && abs(rd.y) > EPS) {
            float t = (holeHalfH - ro.y) / rd.y;
            br_considerPlaneHit(tBest, nBest, hpBest,
                                t, ro, rd,
                                vec3(0.0, -1.0, 0.0),
                                vec2(-holeHalfW, holeHalfW),
                                vec2(holeHalfH, holeHalfH),
                                vec2(z0, z1));
        }
    }

    if (tBest > 9e8) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec3 hp = hpBest;
    vec3 n  = normalize(nBest);

    float depthFade = 1.0;
    if (hasDepth) {
        float zNorm = br_saturate((hp.z - zBack) / (0.0 - zBack + 1e-5));
        depthFade = mix(0.72, 1.0, zNorm);
    }

    vec3 c = br_shade(hp, n, ro,
                      base,
                      br_saturate(u_roughness),
                      br_saturate(u_ambient),
                      u_light1Pos, u_light1Intensity,
                      u_light2Pos, u_light2Intensity);

    c *= depthFade;

    c = clamp(c, 0.0, 1.0);
    gl_FragColor = vec4(c, 1.0);
}
