Solid_Color_System :: struct {
    Vertex :: struct {
        position: Vector3;
    }

    Vertex_Push_Constant :: struct {
        model := Matrix4_Identity;
        view  := Matrix4_Identity;
        proj  := Matrix4_Identity;
    }

    Fragment_Push_Constant :: struct {
        color: Vector4;
    }

    pipeline: VkPipeline;
    pipeline_layout: VkPipelineLayout;
}

init_solid_color_system :: (using system: *Solid_Color_System, using renderer: *Renderer) {
    // There is already an assert in the load_shader_module function
    vert_shader := load_shader_module(renderer, "shaders/solid_color.vert.spv");
    frag_shader := load_shader_module(renderer, "shaders/solid_color.frag.spv");
    defer {
        destroy_shader_module(renderer, vert_shader);
        destroy_shader_module(renderer, frag_shader);
    }

    pb: Pipeline_Builder;
    pipeline_builder_clear(*pb);

    pipeline_builder_set_shaders(*pb, vert_shader, frag_shader);
    pipeline_builder_set_input_topology(*pb, .TRIANGLE_LIST);
    pipeline_builder_set_polygon_mode(*pb, .FILL);
    pipeline_builder_set_cull_mode(*pb, .BACK, .CLOCKWISE);
    pipeline_builder_set_multisampling_none(*pb);
    pipeline_builder_set_color_attachment_format(*pb, draw_image.format);
    pipeline_builder_set_depth_format(*pb, depth_image.format);
    pipeline_builder_enable_depthtest(*pb, VK_TRUE, .LESS);
    pipeline_builder_enable_blending_alphablend(*pb);
    pipeline_builder_add_vertex_input_binding(*pb, 0, size_of(Vertex), .VERTEX);
    pipeline_builder_add_vertex_input_attribute(*pb, 0, 0, .R32G32B32_SFLOAT, 0);
    pipeline_builder_add_dynamic_state(*pb, .VIEWPORT);
    pipeline_builder_add_dynamic_state(*pb, .SCISSOR);

    ranges := VkPushConstantRange.[
    .{
        stageFlags = .VERTEX,
        offset = 0,
        size = size_of(Vertex_Push_Constant),
    },
    .{
        stageFlags = .FRAGMENT,
        offset = size_of(Vertex_Push_Constant),
        size = size_of(Fragment_Push_Constant),
    },
    ];

    layout_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount         = 0,
        pSetLayouts            = null,
        pushConstantRangeCount = xx ranges.count,
        pPushConstantRanges    = ranges.data,
    };

    VK_CHECK(vkCreatePipelineLayout(dev, *layout_info, vk_allocator, *pipeline_layout));

    pipeline_builder_set_layout(*pb, pipeline_layout);
    pipeline = pipeline_builder_build(*pb, renderer);
}

// I am thinking of let the system store a pointer to the renderer
destroy_solid_color_system :: (using system: *Solid_Color_System, using renderer: *Renderer) {
    vkDestroyPipelineLayout(dev, pipeline_layout, vk_allocator);
    vkDestroyPipeline(dev, pipeline, vk_allocator);
}

Font_System :: struct {
    pipeline: VkPipeline;
}

init_font_system :: (using system: Font_System, using renderer: *Renderer) {
    pb: Pipeline_Builder;
    pipeline_builder_clear(*pb);

}

Test_System :: struct {
    Vertex :: struct {
        pos: Vector3;
    }
    Vert_Push_Constant :: struct {
        transform: Matrix4;
    }

    Frag_Push_Constant :: struct {
        color: Vector4;
    }

    pipeline: VkPipeline;
    pipeline_layout: VkPipelineLayout;
}

init_test_system :: (using system: *Test_System, using renderer: *Renderer) {
    vert_shader := load_shader_module(renderer, "shaders/test0.vert.spv");
    frag_shader := load_shader_module(renderer, "shaders/test0.frag.spv");
    defer {
        destroy_shader_module(renderer, vert_shader);
        destroy_shader_module(renderer, frag_shader);
    }

    pb: Pipeline_Builder;
    pipeline_builder_clear(*pb);
    pipeline_builder_set_shaders(*pb, vert_shader, frag_shader);
    pipeline_builder_set_input_topology(*pb, .TRIANGLE_LIST);
    pipeline_builder_set_polygon_mode(*pb, .FILL);
    pipeline_builder_set_cull_mode(*pb, .BACK, .CLOCKWISE);
    pipeline_builder_set_multisampling_none(*pb);
    pipeline_builder_set_color_attachment_format(*pb, draw_image.format);
    pipeline_builder_set_depth_format(*pb, depth_image.format);
    pipeline_builder_enable_depthtest(*pb, VK_TRUE, .LESS);
    pipeline_builder_enable_blending_alphablend(*pb);
    pipeline_builder_add_dynamic_state(*pb, .VIEWPORT);
    pipeline_builder_add_dynamic_state(*pb, .SCISSOR);
    pipeline_builder_add_vertex_input_binding(*pb, 0, size_of(Vertex), .VERTEX);
    pipeline_builder_add_vertex_input_attribute(*pb, 0, 0, .R32G32B32_SFLOAT, 0);

    ranges := VkPushConstantRange.[
    .{
        stageFlags = .VERTEX,
        offset = 0,
        size = size_of(Vert_Push_Constant),
    },
    .{
        stageFlags = .FRAGMENT,
        offset = size_of(Vert_Push_Constant),
        size = size_of(Frag_Push_Constant),
    },
    ];

    layout_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount         = 0,
        pSetLayouts            = null,
        pushConstantRangeCount = xx ranges.count,
        pPushConstantRanges    = ranges.data,
    };

    VK_CHECK(vkCreatePipelineLayout(dev, *layout_info, vk_allocator, *pipeline_layout));

    pipeline_builder_set_layout(*pb, pipeline_layout);
    pipeline = pipeline_builder_build(*pb, renderer);
}

destroy_test_system :: (using system: *Test_System, using renderer: *Renderer) {
    vkDestroyPipelineLayout(dev, pipeline_layout, vk_allocator);
    vkDestroyPipeline(dev, pipeline, vk_allocator);
}

/// Below is some handy functions for drawing simple things

// Using s32 to represent rectangle dimensions is for positioning a
// rectangle out of viewport without error.
Rect :: struct {
    x, y: s32;
    w, h: s32;
}

// Here we have a few ways to draw a rectangle, first is to generate
// an exact set of vertices, second is to use some matrix to shape a
// square predefined. We are using the second one.
draw_rectangle :: (renderer: *Renderer, rect: Rect, color: Vector4) {
    // Assume the solid color pipeline is already binded.

}

Texture_System :: struct {
    Vertex :: struct {
        pos: Vector3;
        uv: Vector2;
    }

    Push_Constant :: struct {
        model: Matrix4;
        view: Matrix4;
        proj: Matrix4;
    }

    pipeline: VkPipeline;
    pipeline_layout: VkPipelineLayout;
    descriptor_set_layout: VkDescriptorSetLayout;
    sampler: VkSampler;
}

init_texture_system :: (using system: *Texture_System, using renderer: *Renderer) {
    pb: Pipeline_Builder;
    pipeline_builder_clear(*pb);
    vert_shader := load_shader_module(renderer, "texture.vert.spv");
    frag_shader := load_shader_module(renderer, "texture.frag.spv");
    defer {
        destroy_shader_module(renderer, vert_shader);
        destroy_shader_module(renderer, frag_shader);
    }

    pipeline_builder_set_shaders(*pb, vert_shader, frag_shader);
    pipeline_builder_set_input_topology(*pb, .TRIANGLE_LIST);
    pipeline_builder_set_polygon_mode(*pb, .FILL);
    pipeline_builder_set_cull_mode(*pb, .BACK, .CLOCKWISE);
    pipeline_builder_set_multisampling_none(*pb);
    pipeline_builder_set_color_attachment_format(*pb, draw_image.format);
    pipeline_builder_set_depth_format(*pb, depth_image.format);
    pipeline_builder_enable_depthtest(*pb, VK_TRUE, .LESS);
    pipeline_builder_enable_blending_alphablend(*pb);
    pipeline_builder_add_dynamic_state(*pb, .VIEWPORT);
    pipeline_builder_add_dynamic_state(*pb, .SCISSOR);
    pipeline_builder_add_vertex_input_binding(*pb, 0, size_of(Vertex), .VERTEX);
    pipeline_builder_add_vertex_input_attribute(*pb, 0, 0, .R32G32B32_SFLOAT, 0);
    pipeline_builder_add_vertex_input_attribute(*pb, 1, 0, .R32G32_SFLOAT, size_of(Matrix4) * 3);

    range := VkPushConstantRange.{
        stageFlags = .VERTEX,
        offset = 0,
        size = size_of(Push_Constant),
    };

    lb: Descriptor_Layout_Builder;
    descriptor_layout_builder_clear(*lb);
    descriptor_layout_builder_add_binding(*lb, 0, .COMBINED_IMAGE_SAMPLER, .FRAGMENT);
    descriptor_set_layout = descriptor_layout_builder_build(*lb, renderer, null, 0);

    layout_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount         = 1,
        pSetLayouts            = *descriptor_set_layout,
        pushConstantRangeCount = 1,
        pPushConstantRanges    = *range,
    };

    VK_CHECK(vkCreatePipelineLayout(dev, *layout_info, vk_allocator, *pipeline_layout));
    pipeline_builder_set_layout(*pb, pipeline_layout);

    pipeline = pipeline_builder_build(*pb, renderer);

    sampler_info := VkSamplerCreateInfo.{
        magFilter = .NEAREST,
        minFilter = .NEAREST,
        mipmapMode = .NEAREST,
    };

    VK_CHECK(vkCreateSampler(dev, *sampler_info, vk_allocator, *sampler));
}

destroy_texture_system :: (using system: *Texture_System, using renderer: *Renderer) {
    vkDestroySampler(dev, sampler, vk_allocator);
    vkDestroyDescriptorSetLayout(dev, descriptor_set_layout, vk_allocator);
    vkDestroyPipelineLayout(dev, pipeline_layout, vk_allocator);
    vkDestroyPipeline(dev, pipeline, vk_allocator);
}

#scope_file
#import "Vulkan";
#import "Renderer";
#import "Basic";
#import "Math";
