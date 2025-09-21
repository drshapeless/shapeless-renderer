Image :: struct {
    img: VkImage;
    img_view: VkImageView;
    allocation: VmaAllocation;
    extent: VkExtent3D;
    format: VkFormat;
}

transition_image :: (cmd: VkCommandBuffer, img: VkImage, old_layout: VkImageLayout, new_layout: VkImageLayout) {
    aspect_mask : VkImageAspectFlags;
    if new_layout == .DEPTH_ATTACHMENT_OPTIMAL {
        aspect_mask = .DEPTH;
    } else {
        aspect_mask = .COLOR;
    }

    sub_image := VkImageSubresourceRange.{
        aspectMask     = aspect_mask,
        baseMipLevel   = 0,
        levelCount     = VK_REMAINING_MIP_LEVELS,
        baseArrayLayer = 0,
        layerCount     = VK_REMAINING_ARRAY_LAYERS,
    };

    image_barrier := VkImageMemoryBarrier2.{
        srcStageMask     = .ALL_COMMANDS,
        srcAccessMask    = .MEMORY_WRITE,
        dstStageMask     = .ALL_COMMANDS,
        dstAccessMask    = .MEMORY_WRITE | .MEMORY_READ,
        oldLayout        = old_layout,
        newLayout        = new_layout,
        image            = img,
        subresourceRange = sub_image,
    };

    dep_info := VkDependencyInfo.{
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers    = *image_barrier,
    };

    vkCmdPipelineBarrier2(cmd, *dep_info);
}

copy_image :: (cmd: VkCommandBuffer, src_img: VkImage, dst_img: VkImage, src_extent: VkExtent2D, dst_extent: VkExtent2D) {
    blit_region := VkImageBlit2.{
        srcSubresource = .{
            aspectMask     = .COLOR,
            baseArrayLayer = 0,
            layerCount     = 1,
            mipLevel       = 0,
        },
        dstSubresource = .{
            aspectMask     = .COLOR,
            baseArrayLayer = 0,
            layerCount     = 1,
            mipLevel       = 0,
        },
    };

    blit_region.srcOffsets[1] = .{
        x = xx src_extent.width,
        y = xx src_extent.height,
        z = 1,
    };

    blit_region.dstOffsets[1] = .{
        x = xx dst_extent.width,
        y = xx dst_extent.height,
        z = 1,
    };

    blit_info := VkBlitImageInfo2.{
        srcImage       = src_img,
        srcImageLayout = .TRANSFER_SRC_OPTIMAL,
        dstImage       = dst_img,
        dstImageLayout = .TRANSFER_DST_OPTIMAL,
        regionCount    = 1,
        pRegions       = *blit_region,
        filter         = .LINEAR,
    };

    vkCmdBlitImage2(cmd, *blit_info);
}

copy_image_from_buffer :: (cmd: VkCommandBuffer, img: VkImage, buffer: VkBuffer, extent: VkExtent2D) {
    region := VkBufferImageCopy2.{
        bufferOffset      = 0,
        bufferRowLength   = 0,
        bufferImageHeight = 0,
        imageSubresource  = .{
            aspectMask     = .COLOR,
            mipLevel       = 0,
            baseArrayLayer = 0,
            layerCount     = 1,
        },
        imageOffset = .{0, 0, 0},
        imageExtent = .{
            width  = extent.width,
            height = extent.height,
            depth  = 1
        },
    };

    copy_info := VkCopyBufferToImageInfo2.{
        srcBuffer      = buffer,
        dstImage       = img,
        dstImageLayout = .TRANSFER_DST_OPTIMAL,
        regionCount    = 1,
        pRegions       = *region,
    };

    vkCmdCopyBufferToImage2(cmd, *copy_info);
}

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
