precision mediump float;
varying vec2 vUV;
uniform float u_time;
uniform vec2 u_resolution;
uniform float u_timeSpeed;
uniform float u_hueShift;
uniform float u_brightness;
uniform float u_zoom;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;
    uv *= u_zoom;

    float t = u_time * u_timeSpeed * 0.8;

    // Perspektywa 3D podłogi
    vec3 col = vec3(0.01, 0.01, 0.03);

    if (uv.y < 0.1) {
        float depth = 0.5 / (0.12 - uv.y);
        vec2 grid = vec2(uv.x * depth, depth - t * 3.0);

        vec2 line = abs(fract(grid - 0.5) - 0.5) / fwidth(grid);
        float lineVal = 1.0 - min(min(line.x, line.y), 1.0);

        float fog = clamp(depth * 0.06, 0.0, 1.0);
        float hue = fract(0.85 + u_hueShift);
        vec3 gridCol = hsv2rgb(vec3(hue, 0.9, 1.0));

        col = mix(gridCol * lineVal * 1.5, vec3(0.02, 0.0, 0.08), fog);
    } else {
        // Neonowe słońce retro
        vec2 sunUV = uv - vec2(0.0, 0.25);
        float dist = length(sunUV);
        if (dist < 0.35) {
            float bars = step(0.02, fract(sunUV.y * 18.0));
            if (sunUV.y > 0.0 || bars > 0.5) {
                float sunGrad = (sunUV.y + 0.35) / 0.7;
                vec3 sunCol = mix(vec3(1.0, 0.1, 0.4), vec3(1.0, 0.8, 0.0), sunGrad);
                col = sunCol;
            }
        }
        // Poświata horyzontu
        col += vec3(0.8, 0.1, 0.5) * exp(-abs(uv.y - 0.1) * 8.0) * 0.5;
    }

    col *= u_brightness;
    gl_FragColor = vec4(col, 1.0);
}
