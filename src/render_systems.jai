Solid_Color_System :: struct {
    Vertex :: struct {
        position: Vector3;
    }

    Vertex_Push_Constant :: struct {
        transform: Matrix4;
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
    pipeline_builder_add_vertex_input_attribute(*pb, 0, 0, .R32G32B32_SFLOAT, offset_of(Vertex, position));

    ranges: [2]VkPushConstantRange;
    ranges[0].stageFlags = .VERTEX;
    ranges[0].offset = 0;
    ranges[0].size = size_of(Vertex_Push_Constant);

    ranges[1].stageFlags = .FRAGMENT;
    ranges[1].offset = size_of(Vertex_Push_Constant);
    ranges[1].size = size_of(Fragment_Push_Constant);

    layout_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount         = 0,
        pSetLayouts            = null,
        pushConstantRangeCount = 2,
        pPushConstantRanges    = ranges.data,
    };

    VK_CHECK(vkCreatePipelineLayout(dev, *layout_info, vk_allocator, *pipeline_layout));

    pipeline_builder_set_layout(*pb, pipeline_layout);
    pipeline = pipeline_builder_build(*pb);
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

#scope_file
#import "Vulkan";
#import "Renderer";
#import "Basic";
#import "Math";
