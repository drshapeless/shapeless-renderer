#version 450

layout(push_constant) uniform PushConstant {
    mat4 transform;
} p;

layout(location = 0) in vec3 position;

void main() {
    gl_Position = p.transform * vec4(position, 1.0);
}
