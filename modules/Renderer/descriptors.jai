DescriptorLayoutBuilder :: struct {
    bindings: [..]VkDescriptorSetLayoutBinding;
}

// There is not init function for DescriptorLayoutBuilder, maybe I
// should make a dumb one for consistency.

descriptor_layout_builder_free :: (using self: *DescriptorLayoutBuilder) {
    array_free(bindings);
}

descriptor_layout_builder_clear :: (using self: *DescriptorLayoutBuilder) {
    array_reset_keeping_memory(bindings);
}

descriptor_layout_builder_add_binding :: (using self: *DescriptorLayoutBuilder, binding: u32, type: VkDescriptorType, shader_stages: VkShaderStageFlags) {
    new_bind := VkDescriptorSetLayoutBinding.{
        binding         = binding,
        descriptorCount = 1,
        descriptorType  = type,
        stageFlags      = shader_stages,
    };

    array_add(*bindings, new_bind);
}

descriptor_layout_builder_build :: (using self: *DescriptorLayoutBuilder, using renderer: *Renderer, pNext: *void, flags: VkDescriptorSetLayoutCreateFlags) -> VkDescriptorSetLayout {
    info := VkDescriptorSetLayoutCreateInfo.{
        pNext        = pNext,
        pBindings    = bindings.data,
        bindingCount = bindings.count,
        flags        = flags,
    };

    set : VkDescriptorSetLayout;
    VK_CHECK(vkCreateDescriptorSetLayout(dev, *info, vk_allocator, *set));

    return set;
}

DescriptorAllocator :: struct {
    pool_sizes : [..]VkDescriptorPoolSize;
    pool       : VkDescriptorPool;
}

descriptor_allocator_destroy :: (using self: *DescriptorAllocator) {
    array_free(pool_sizes);
}

descriptor_allocator_add_pool_size :: (using self: *DescriptorAllocator, type: VkDescriptorType, descriptor_count: u32) {
    pool_size := VkDescriptorPoolSize.{
        type            = type,
        descriptorCount = descriptor_count,
    };

    array_add(*pool_sizes, pool_size);
}

descriptor_allocator_init_pool :: (using self: *DescriptorAllocator, using renderer: *Renderer, max_sets: u32) {
    pool_info := VkDescriptorPoolCreateInfo.{
        maxSets       = max_sets,
        poolSizeCount = xx pool_sizes.count,
        pPoolSizes    = pool_sizes.data,
    };

    VK_CHECK(vkCreateDescriptorPool(dev, *pool_info, vk_allocator, *pool));
}

descriptor_allocator_clear_descriptors :: (using self: *DescriptorAllocator, using renderer: *Renderer) {
    vkResetDescriptorPool(dev, pool, null);
}

descriptor_allocator_destroy_pool :: (using self: *DescriptorAllocator, using renderer: *Renderer) {
    vkDestroyDescriptorPool(dev, pool, vk_allocator);
}

descriptor_allocator_allocate :: (using self: *DescriptorAllocator, using renderer: *Renderer, layout: VkDescriptorSetLayout) -> VkDescriptorSet {
    alloc_info := VkDescriptorSetAllocateInfo.{
        descriptorPool = pool,
        descriptorSetCount = 1,
        pSetLayouts = *layout,
    };

    ds: VkDescriptorSet;
    VK_CHECK(vkAllocateDescriptorSets(dev, *alloc_info, *ds));
    return ds;
}

DescriptorWriter :: struct {
    image_infos  : [..]*VkDescriptorImageInfo;
    buffer_infos : [..]VkDescriptorBufferInfo;
    writes       : [..]VkWriteDescriptorSet;
}

descriptor_writer_destroy :: (using self: *DescriptorWriter) {
    array_free(image_infos);
    array_free(buffer_infos);
    array_free(writes);
}

descriptor_writer_write_image :: (using self: *DescriptorWriter, binding: u32, image_view: VkImageView, sampler: VkSampler, layout: VkImageLayout, type: VkDescriptorType) {
    info := New(VkDescriptorImageInfo);
    info.sampler     = sampler;
    info.imageView   = image_view;
    info.imageLayout = layout;

    array_add(*image_infos, info);

    write := VkWriteDescriptorSet.{
        dstBinding = binding,
        descriptorCount = 1,
        descriptorType = type,
        pImageInfo = info,
    };

    array_add(*writes, write);
}

descriptor_writer_write_buffer :: (using self: *DescriptorWriter, binding: u32, buffer: VkBuffer, size: VkDeviceSize, offset: VkDeviceSize, type: VkDescriptorType) {
    info := New(VkDescriptorBufferInfo);
    info.buffer = buffer;
    info.offset = offset;
    info.range = size;

    array_add(*buffer_infos, info);

    write := VkWriteDescriptorSet.{
        dstBinding = binding,
        descriptorCount = 1,
        descriptorType = type,
        pBufferInfo = info,
    };

    append(*writes, write);
}

descriptor_writer_clear :: (using self: *DescriptorWriter) {
    for i : image_infos {
        free(i);
    }

    for i : buffer_infos {
        free(i);
    }

    array_reset_keeping_memory(image_infos);
    array_reset_keeping_memory(buffer_infos);
    array_reset_keeping_memory(writes);
}

descriptor_writer_update_set :: (using self: *DescriptorWriter, device: VkDevice, set: VkDescriptorSet) {
    for *write : writes {
        write.dstSet = set;
    }

    vkUpdateDescriptorSets(device, writes.count, writes.data, 0, null);
}

#import "Basic";
#import "Vulkan";
#import,file "device.jai";
#import,file "common.jai";
