#version 100
precision highp float;
varying vec2 vUV;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_scroll;
uniform float u_lightMode;
uniform float u_darkMode;
uniform float u_animSpeed;
uniform float u_zSpeed;
uniform float u_animPhase;
uniform float u_zPhase;
uniform float u_colorAmount;
uniform float u_colorSpeed;
uniform float u_colorPhase;
uniform float u_scale;
uniform float u_saturation;
uniform float u_lightness;
uniform float u_contrast;
uniform float u_usePerlin;

float sx_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sx_sat3(vec3 v) { return clamp(v, vec3(0.0), vec3(1.0)); }
vec3 sx_applyContrast(vec3 c, float contrast) {
    return (c - 0.5) * contrast + 0.5;
}

float sx_hue2rgb(float f1, float f2, float hue) {
    if (hue < 0.0) hue += 1.0;
    else if (hue > 1.0) hue -= 1.0;
    float res;
    if ((6.0 * hue) < 1.0)       res = f1 + (f2 - f1) * 6.0 * hue;
    else if ((2.0 * hue) < 1.0)  res = f2;
    else if ((3.0 * hue) < 2.0)  res = f1 + (f2 - f1) * ((2.0/3.0) - hue) * 6.0;
    else                         res = f1;
    return res;
}

vec3 sx_hsl2rgb(vec3 hsl) {
    vec3 rgb;
    if (hsl.y == 0.0) {
        rgb = vec3(hsl.z);
    } else {
        float f2;
        if (hsl.z < 0.5) f2 = hsl.z * (1.0 + hsl.y);
        else             f2 = hsl.z + hsl.y - hsl.y * hsl.z;
        float f1 = 2.0 * hsl.z - f2;
        rgb.r = sx_hue2rgb(f1, f2, hsl.x + (1.0/3.0));
        rgb.g = sx_hue2rgb(f1, f2, hsl.x);
        rgb.b = sx_hue2rgb(f1, f2, hsl.x - (1.0/3.0));
    }
    return rgb;
}

vec3 sx_mod289(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 sx_mod289(vec4 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
vec4 sx_permute(vec4 x) {
    return sx_mod289(((x * 34.0) + 10.0) * x);
}
vec4 sx_taylorInvSqrt(vec4 r) {
    return vec4(1.79284291400159) - vec4(0.85373472095314) * r;
}

float sx_snoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = vec3(1.0) - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = sx_mod289(i);
    vec4 p = sx_permute(
        sx_permute(
          sx_permute(i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
      + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = vec4(1.0) - abs(x) - abs(y);
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    vec4 norm = sx_taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    vec4 m = max(vec4(0.5) - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), vec4(0.0));
    m = m * m;
    return 105.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

vec3 sx_fade(vec3 t) {
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

float sx_cnoise(vec3 P) {
    vec3 Pi0 = floor(P);
    vec3 Pi1 = Pi0 + vec3(1.0);
    Pi0 = sx_mod289(Pi0);
    Pi1 = sx_mod289(Pi1);
    vec3 Pf0 = fract(P);
    vec3 Pf1 = Pf0 - vec3(1.0);
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = vec4(Pi0.zzzz);
    vec4 iz1 = vec4(Pi1.zzzz);
    vec4 ixy = sx_permute(sx_permute(ix) + iy);
    vec4 ixy0 = sx_permute(ixy + iz0);
    vec4 ixy1 = sx_permute(ixy + iz1);
    vec4 gx0 = ixy0 * (1.0/7.0);
    vec4 gy0 = fract(floor(gx0) * (1.0/7.0)) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);
    vec4 gx1 = ixy1 * (1.0/7.0);
    vec4 gy1 = fract(floor(gx1) * (1.0/7.0)) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);
    vec3 g000 = vec3(gx0.x, gy0.x, gz0.x);
    vec3 g100 = vec3(gx0.y, gy0.y, gz0.y);
    vec3 g010 = vec3(gx0.z, gy0.z, gz0.z);
    vec3 g110 = vec3(gx0.w, gy0.w, gz0.w);
    vec3 g001 = vec3(gx1.x, gy1.x, gz1.x);
    vec3 g101 = vec3(gx1.y, gy1.y, gz1.y);
    vec3 g011 = vec3(gx1.z, gy1.z, gz1.z);
    vec3 g111 = vec3(gx1.w, gy1.w, gz1.w);
    vec4 norm0 = sx_taylorInvSqrt(vec4(dot(g000,g000), dot(g010,g010), dot(g100,g100), dot(g110,g110)));
    g000 *= norm0.x; g010 *= norm0.y; g100 *= norm0.z; g110 *= norm0.w;
    vec4 norm1 = sx_taylorInvSqrt(vec4(dot(g001,g001), dot(g011,g011), dot(g101,g101), dot(g111,g111)));
    g001 *= norm1.x; g011 *= norm1.y; g101 *= norm1.z; g111 *= norm1.w;
    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);
    vec3 fade_xyz = sx_fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
    return 2.2 * n_xyz;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    float t = u_time;
    vec2 fragCoord = vec2(vUV.x * res.x, vUV.y * res.y);
    vec2 relative = fragCoord + vec2(0.0, res.y * (-u_scroll));
    vec2 p = (relative / res.y) * 2.0 - 1.0;
    vec2 relativePos = (p * 0.5) + vec2(u_animPhase, 0.0);
    float sc = max(0.0001, u_scale);
    relativePos *= sc;

    float nRaw = 0.0;
    if (u_usePerlin >= 0.5) {
        vec3 P = 1.5 * vec3(relativePos, 0.3 * u_zPhase);
        nRaw = 0.7 * sx_cnoise(P);
    } else {
        vec3 P = vec3(relativePos, u_zPhase);
        nRaw = 0.7 * sx_snoise(P);
    }

    float colorAmount = max(1.0, u_colorAmount);
    float cycle = sin(u_colorPhase) * (colorAmount - 1.0);
    float n = (nRaw + cycle) / colorAmount;
    float hue = fract(n);
    float lightness = sx_sat(u_lightness);
    float saturation = sx_sat(u_saturation);
    if (u_darkMode >= 0.5) saturation *= 0.5;
    vec3 rgb = sx_hsl2rgb(vec3(hue, saturation, lightness));
    if (u_lightMode >= 0.5) rgb = vec3(1.0) - rgb;
    float contrast = clamp(u_contrast, 0.0, 3.0);
    rgb = sx_applyContrast(rgb, contrast);
    rgb = sx_sat3(rgb);
    gl_FragColor = vec4(rgb, 1.0);
}
