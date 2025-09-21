#version 450

layout(push_constant) uniform PushConstant {
    mat4 transform;
}
vp;

layout(location = 0) in vec3 position;

void main() {
    gl_Position = vp.transform * vec4(position, 1.0);
}
