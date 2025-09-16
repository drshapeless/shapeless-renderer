PipelineBuilder :: struct {
    shader_stages: [..]VkPipelineShaderStageCreateInfo;
    vertex_bindings:         [..]VkVertexInputBindingDescription;
    vertex_attributes:       [..]VkVertexInputAttributeDescription;
    color_blend_attachments: [..]VkPipelineColorBlendAttachmentState;
    dynamic_states:          [..]VkDynamicState;
    vertex_input_info:       VkPipelineVertexInputStateCreateInfo;
    input_assembly_info:     VkPipelineInputAssemblyStateCreateInfo;
    tessellation_info:       VkPipelineTessellationStateCreateInfo; // No use ATM
    viewport_info:           VkPipelineViewportStateCreateInfo;
    rasterization_info:      VkPipelineRasterizationStateCreateInfo;
    multisample_info:        VkPipelineMultisampleStateCreateInfo;
    depth_stencil_info:      VkPipelineDepthStencilStateCreateInfo;
    color_blend_info:        VkPipelineColorBlendStateCreateInfo;
    dynamic_info:            VkPipelineDynamicStateCreateInfo;
    layout:                  VkPipelineLayout;
    render_info:             VkPipelineRenderingCreateInfo;
    color_attachment_format: VkFormat;
}

pipeline_builder_build :: (using builder: *PipelineBuilder, using renderer: *Renderer) -> VkPipeline {
    vertex_input_info.vertexBindingDescriptionCount = vertex_bindings.count;
    vertex_input_info.pVertexBindingDescriptions = vertex_bindings.data;

    vertex_input_info.vertexAttributeDescriptionCount = vertex_attributes.count;
    vertex_input_info.pVertexAttributeDescriptions = vertex_attributes.data;

    color_blend_info.attachmentCount = color_blend_attachments.count;
    color_blend_info.pAttachments = color_blend_attachments.data;

    dynamic_info.pDynamicStates = dynamic_states.data;
    dynamic_info.dynamicStateCount = dynamic_states.count;

    pipeline_info := VkGraphicsPipelineCreateInfo.{
        stageCount = shader_stages.count,
        pStages = shader_stages.data,
        pVertexInputState = *vertex_input_info,
        pInputAssemblyState = *input_assembly_info,
        pTessellationState  = *tessellation_info,
        pViewportState      = *viewport_info,
        pRasterizationState = *rasterization_info,
        pMultisampleState   = *multisample_info,
        pDepthStencilState  = *depth_stencil_info,
        pColorBlendState    = *color_blend_info,
        pDynamicState       = *dynamic_info,
        layout              = layout,
        renderPass          = null,
        subpass             = null,
        basePipelineHandle  = null,
        basePipelineIndex   = -1,
        pNext               = *render_info,
    };

    pipeline : VkPipeline;

    VK_CHECK(vkCreateGraphicsPipelines(dev, null, 1, *pipeline_info, vk_allocator, *pipeline));

    return pipeline;
}

pipeline_builder_destroy :: (using builder: *PipelineBuilder) {
    array_free(shader_stages);
    array_free(vertex_bindings);
    array_free(vertex_attributes);
    array_free(color_blend_attachments);
    array_free(dynamic_states);
}

pipeline_builder_clear :: (using builder: *PipelineBuilder) {
    vertex_input_info   = .{};
    input_assembly_info = .{};
    tessellation_info   = .{};
    viewport_info = .{
        viewportCount = 1,
        scissorCount  = 1,
    };
    rasterization_info = .{};
    multisample_info   = .{};
    depth_stencil_info = .{};

    color_blend_info = .{
        logicOpEnable = false,
        logicOp       = .COPY,
    };

    dynamic_info = .{};
    layout = null;
    render_info = .{};
}

pipeline_builder_set_shaders :: (using builder: *PipelineBuilder, vert_shader: VkShaderModule, frag_shader: VkShaderModule) {
    array_reset_keeping_memory(*shader_stages);
    vert_info := VkPipelineShaderStageCreateInfo.{
        stage = .VERTEX,
        module = vert_shader,
        pName = "main",
    };

    array_add(*shader_stages, vert_info);

    frag_info := VkPipelineShaderStageCreateInfo.{
        stage = .FRAGMENT,
        module = frag_shader,
        pName = "main",
    };

    array_add(*shader_stages, frag_info);
}

pipeline_builder_set_layout :: (builder: *PipelineBuilder, layout: VkPipelineLayout) {
    builder.layout = layout;
}

pipeline_builder_set_input_topology :: (using builder: *PipelineBuilder, topology: VkPrimitiveTopology) {
    input_assembly_info.topology = topology;
    input_assembly_info.primitiveRestartEnable = VK_FALSE;
}

pipeline_builder_set_polygon_mode :: (using builder: *PipelineBuilder, mode: VkPolygonMode) {
    rasterization_info.polygonMode = mode;
    rasterization_info.lineWidth = 1;
}

pipeline_builder_set_cull_mode :: (using builder: *PipelineBuilder, cull_mode: VkCullModeFlags, front_face: VkFrontFace) {
    rasterization_info.cullMode = cull_mode;
    rasterization_info.frontFace = front_face;
}

pipeline_builder_set_multisampling_none :: (using builder: *PipelineBuilder) {
    multisample_info.sampleShadingEnable   = VK_FALSE;
    multisample_info.rasterizationSamples  = .e1;
    multisample_info.minSampleShading      = 1;
    multisample_info.pSampleMask           = null;
    multisample_info.alphaToCoverageEnable = VK_FALSE;
    multisample_info.alphaToOneEnable      = VK_FALSE;
}

pipeline_builder_disable_blending :: (using builder: *PipelineBuilder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask = .R | .G | .B | .A,
        blendEnable = VK_FALSE,
    };

    array_reset_keeping_memory(*color_blend_attachments);
    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_set_color_attachment_format :: (using builder: *PipelineBuilder, format: VkFormat) {
    color_attachment_format = format;

    render_info.colorAttachmentCount = 1;
    render_info.pColorAttachmentFormats = *color_attachment_format;
}

pipeline_builder_set_depth_format :: (using builder: *PipelineBuilder, format: VkFormat) {
    render_info.depthAttachmentFormat = format;
}

pipeline_builder_disable_depthtest :: (using builder: *PipelineBuilder) {
    depth_stencil_info.depthTestEnable = VK_FALSE;
    depth_stencil_info.depthWriteEnable = VK_FALSE;
    depth_stencil_info.depthCompareOp = .NEVER;
    depth_stencil_info.depthBoundsTestEnable = VK_FALSE;
    depth_stencil_info.stencilTestEnable = VK_FALSE;
    depth_stencil_info.front = .{};
    depth_stencil_info.back = .{};
    depth_stencil_info.minDepthBounds = 0;
    depth_stencil_info.maxDepthBounds = 1;
}

pipeline_builder_enable_depthtest :: (using builder: *PipelineBuilder, depth_write_enable: VkBool32, op: VkCompareOp) {
    depth_stencil_info.depthTestEnable = VK_TRUE;
    depth_stencil_info.depthBoundsTestEnable = VK_TRUE;
    depth_stencil_info.depthWriteEnable = depth_write_enable;
    depth_stencil_info.depthCompareOp = op;
    depth_stencil_info.stencilTestEnable = VK_FALSE;
    depth_stencil_info.front = .{};
    depth_stencil_info.back = .{};
    depth_stencil_info.minDepthBounds = 0;
    depth_stencil_info.maxDepthBounds = 1;
}

pipeline_builder_enable_blending_additive :: (using builder: *PipelineBuilder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask      = .R | .G | .B | .A,
        blendEnable         = VK_TRUE,
        srcColorBlendFactor = .SRC_ALPHA,
        dstColorBlendFactor = .ONE,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
    };

    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_enable_blending_alphablend :: (using builder: *PipelineBuilder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask      = .R | .G | .B | .A,
        blendEnable         = VK_TRUE,
        srcColorBlendFactor = .SRC_ALPHA,
        dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
    };

    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_add_vertex_input_binding :: (using builder: *PipelineBuilder, binding: u32, stride: u32, input_rate: VkVertexInputRate) {
    description := VkVertexInputBindingDescription.{
        binding   = binding,
        stride    = stride,
        inputRate = input_rate,
    };

    array_add(*vertex_bindings, description);
}

pipeline_builder_add_vertex_input_attribute :: (using builder: *PipelineBuilder, location: u32, binding: u32, format: VkFormat, offset: u32) {
    description := VkVertexInputAttributeDescription.{
        location = location,
        binding  = binding,
        format   = format,
        offset   = offset,
    };

    array_add(*vertex_attributes, description);
}

pipeline_builder_clear_vertex_input :: (using builder: *PipelineBuilder) {
    array_reset_keeping_memory(*vertex_attributes);
    array_reset_keeping_memory(*vertex_bindings);
}

pipeline_builder_add_dynamic_state :: (using builder: *PipelineBuilder, state: VkDynamicState) {
    array_add(*dynamic_states, state);
}

pipeline_builder_clear_dynamic_state :: (using builder: *PipelineBuilder) {
    array_reset_keeping_memory(*dynamic_states);
}

#import "Vulkan";
#import,file "common.jai";
#import "Basic";
