#load "renderer.jai";
#load "image.jai";
#load "buffer.jai";

VK_CHECK :: (result: VkResult, loc := #caller_location) {
    assert(result == .SUCCESS, "VK_CHECK failed: %", result, loc = loc);
}

create_image :: (using renderer: *Renderer, extent: VkExtent3D, format: VkFormat, usage: VkImageUsageFlags, mippmapped: bool, array_layers: u32) -> Image {
    image := Image.{
        format = format,
        extent = extent,
    };

    img_info := VkImageCreateInfo.{
        imageType   = .e2D,
        format      = format,
        extent      = extent,
        mipLevels   = 1,
        arrayLayers = array_layers,
        samples     = .e1,
        tiling      = .OPTIMAL,
        usage       = usage,
    };

    if mippmapped {
        // There is no log2 in Jai, WTF.
        img_info.mipLevels = xx floor(log(max(extent.width, extent.height)) / log(2));
    }

    alloc_info := VmaAllocationCreateInfo.{
        usage = .GPU_ONLY,
        requiredFlags = .DEVICE_LOCAL,
    };

    VK_CHECK(vmaCreateImage(vma_allocator, *img_info, *alloc_info, *image.img, *image.allocation, null));

    aspect_flag := VkImageAspectFlags.COLOR;
    if format == .D32_SFLOAT {
        aspect_flag = .DPETH;
    }

    view_info := VkImageViewCreateInfo.{
        image = image.img,
        viewType = .e2D,
        format = format,
        subresourceRange = .{
            aspectMask = aspect_flag,
            baseMipLevel = 0,
            levelCount = img_info.mipLevels,
            baseArrayLayer = 0,
            layerCount = array_layers,
        },
    };

    if array_layers > 1 {
        view_info.viewType = .e2D_ARRAY;
    }

    VK_CHECK(vkCreateImageView(dev, *view_info, vk_allocator, *image.img_view));
    return image;
}

#scope_file
sdl :: #import "SDL3";
#import "Basic";
