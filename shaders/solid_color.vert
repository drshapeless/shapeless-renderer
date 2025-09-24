#version 450

layout(push_constant) uniform PushConstant {
    mat4 model;
    mat4 view;
    mat4 proj;
}
pc;

layout(location = 0) in vec3 position;

void main() {
    gl_Position = pc.proj * pc.view * pc.model * vec4(position, 1.0);
}
