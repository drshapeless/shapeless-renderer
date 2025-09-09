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

#import "Vulkan";
#import,file "common.jai";
#import "Basic";
