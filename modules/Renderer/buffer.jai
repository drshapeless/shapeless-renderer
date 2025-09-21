Buffer :: struct {
    buffer: VkBuffer;
    allocation: VmaAllocation;
    info : VmaAllocationInfo;
}

copy_buffer :: (cmd: VkCommandBuffer, src_buffer: VkBuffer, dst_buffer: VkBuffer, size: u64, src_offset: u64, dst_offset: u64) {
    copy_region := VkBufferCopy2.{
        srcOffset = src_offset,
        dstOffset = dst_offset,
        size = size,
    };

    copy_info := VkCopyBufferInfo2.{
        srcBuffer = src_buffer,
        dstBuffer = dst_buffer,
        regionCount = 1,
        pRegions = *copy_region,
    };

    vkCmdCopyBuffer2(cmd, *copy_info);
}

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
