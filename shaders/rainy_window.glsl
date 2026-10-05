precision mediump float;
varying vec2 vUV;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_zoom;

// Pseudo-losowy szum
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Kropla na szybie
vec3 rainLayer(vec2 uv, float t) {
    vec2 aspect = vec2(2.0, 1.0);
    vec2 st = uv * aspect;
    vec2 id = floor(st);
    vec2 gv = fract(st) - 0.5;

    float n = hash(id);
    float dropTime = t + n * 6.28;

    // Pozycja spływającej kropli z mikro-drżeniem
    float y = -sin(dropTime + sin(dropTime + sin(dropTime) * 0.5)) * 0.45;
    vec2 dropPos = vec2(0.0, y);
    vec2 diff = gv - dropPos;

    float d = length(diff);
    float drop = smoothstep(0.07, 0.02, d);

    // Ogon / ślad za spływającą kroplą
    float trail = smoothstep(0.025, 0.01, abs(gv.x));
    float trailMask = smoothstep(y, y + 0.35, gv.y) * smoothstep(y + 0.35, y, gv.y);
    float droplet = drop + trail * trailMask * 0.6;

    // Wektor załamania światła kropli
    vec2 offset = normalize(diff + vec2(0.001)) * droplet * 0.15;
    return vec3(offset, droplet);
}

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed * 0.8;

    // Kilka warstw kropel: duże spływające i małe statyczne
    vec3 drops1 = rainLayer(uv * 3.5, t);
    vec3 drops2 = rainLayer(uv * 7.0 + vec2(3.2, 5.8), t * 1.3);
    vec3 totalDrops = drops1 + drops2;

    // Załamane tło miejskie (rozmyte neony za szybą)
    vec2 bgUV = uv + totalDrops.xy;
    
    // Nocne tło: głęboki granat deszczowego nieba
    vec3 nightSky = mix(vec3(0.02, 0.04, 0.08), vec3(0.05, 0.08, 0.15), uv.y * 0.5 + 0.5);

    // Rozmyte neony miasta w dali (Bokeh)
    vec3 bokeh = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        vec2 bPos = vec2(sin(fi * 1.8 + t * 0.2) * 1.4, -0.4 + cos(fi * 2.3) * 0.3);
        float bDist = length(bgUV - bPos);
        float bGlow = smoothstep(0.4, 0.02, bDist);
        vec3 bColor = (mod(fi, 2.0) == 0.0) ? vec3(0.9, 0.4, 0.1) : vec3(0.1, 0.7, 0.9);
        bokeh += bColor * bGlow * 0.6;
    }

    vec3 finalColor = nightSky + bokeh;
    
    // Błysk i refleks światła na krawędzi kropli deszczu
    finalColor += vec3(0.8, 0.9, 1.0) * totalDrops.z * 1.4;

    finalColor *= u_brightness;
    gl_FragColor = vec4(finalColor, 1.0);
}
