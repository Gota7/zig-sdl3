#version 450

layout(location = 0) out vec4 color_out;

void main() {
    switch (gl_VertexIndex) {
        case 0:
        gl_Position = vec4(-1, -1, 0, 1);
        color_out = vec4(1, 0, 0, 1);
        break;
        case 1:
        gl_Position = vec4(1, -1, 0, 1);
        color_out = vec4(0, 1, 0, 1);
        break;
        default:
        gl_Position = vec4(0, 1, 0, 1);
        color_out = vec4(0, 0, 1, 1);
        break;
    }
}
