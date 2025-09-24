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

#scope_file
#import "Vulkan";
#import "Renderer";
#import "Basic";
#import "Math";
