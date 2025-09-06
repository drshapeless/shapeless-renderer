VK_CHECK :: (result: VkResult, loc := #caller_location) {
    assert(result == .SUCCESS, "VK_CHECK failed: %", result, loc = loc);
}

#import "Vulkan";
#import "Basic";
