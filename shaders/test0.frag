#version 450

layout(push_constant) uniform PushConstant {
    layout(offset = 64) vec4 color;
} p;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = p.color;
}
