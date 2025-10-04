#version 450

layout(set = 3, binding = 0, std140) uniform uniforms {
    float near_plane;
    float far_plane;
};

layout(location = 0) in vec4 color_in;

layout(location = 0) out vec4 color_out;

float linearizeDepth(float depth, float near, float far) {
    float z = depth * 2 - 1;
    return ((2.0 * near * far) / (far + near - z * (far - near))) / far;
}

void main() {
    color_out = color_in;
    gl_FragDepth = linearizeDepth(gl_FragCoord.z, near_plane, far_plane);
}
