#version 450

layout(push_constant) uniform PushConstant {
    layout(offset = 64) vec4 color;
}
fp;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = fp.color;
}
