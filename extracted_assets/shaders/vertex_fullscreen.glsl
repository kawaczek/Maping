#version 100
attribute vec4 aPosition;
attribute vec2 aUV;
varying vec2 vUV;
void main() {
    gl_Position = aPosition;
    vUV = aUV;
}
