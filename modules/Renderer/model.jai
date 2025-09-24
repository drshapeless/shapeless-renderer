Model :: struct {
    vertex_buffer: Buffer;
    index_buffer:  Buffer;
    vertex_size:   u32;
    index_size:    u32;
}

bind_model :: (using model: *Model, cmd: VkCommandBuffer) {
    offsets := VkDeviceSize.[0];
    vkCmdBindVertexBuffers(cmd, 0, 1, *vertex_buffer.buffer, offsets.data);
    if index_size > 0 {
        vkCmdBindIndexBuffer(cmd, index_buffer.buffer, 0, .UINT32);
    }
}

draw_model :: (using model: *Model, cmd: VkCommandBuffer) {
    if index_size > 0 {
        vkCmdDrawIndexed(cmd, index_size, 1, 0, 0, 0);
    } else {
        vkCmdDraw(cmd, vertex_size, 1, 0, 0);
    }
}

#scope_file
#import "Vulkan";
