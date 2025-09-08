ENABLE_VALIDATION :: true;

FrameData :: struct {
    command_pool         : VkCommandPool;
    cmd                  : VkCommandBuffer;
    swapchain_semaphore  : VkSemaphore;
    render_semaphore     : VkSemaphore;
    render_fence         : VkFence;
    descriptor_allocator : DescriptorAllocator;
}

Renderer :: struct {
    window: *sdl.Window;

    // Device
    vk_allocator    : *VkAllocationCallbacks;
    instance        : VkInstance;
    debug_messenger : VkDebugUtilsMessengerEXT;
    pdev            : VkPhysicalDevice;
    properties      : VkPhysicalDeviceProperties;
    surface         : VkSurfaceKHR;
    dev             : VkDevice;

    // Family and queue
    graphics_family : u32;
    graphics_queue  : VkQueue;
    present_family  : u32;
    present_queue   : VkQueue;
    compute_family  : u32;
    compute_queue   : VkQueue;
    transfer_family : u32;
    transfer_queue  : VkQueue;

    vma_allocator: VmaAllocator;

    // Swapchain
    swapchain           : VkSwapchainKHR;
    image_count         : u32;
    swapchain_extent    : VkExtent2D;
    image_format        : VkFormat;
    images              : []VkImage;
    image_views         : []VkImageView;
    frames              : []FrameData;
    current_frame_index : u32;
    current_image_index : u32;
}

init_renderer :: (using renderer: *Renderer, sdl_window: *sdl.Window) {
    window = sdl_window;
    init_instance(renderer);
    get_physical_device(renderer);
    init_surface(renderer);
    init_device(renderer);
    init_vma(renderer);
    init_swapchain(renderer);
}

destroy_renderer :: (using renderer: *Renderer) {
    log("Destroying swapchain...");
    destroy_swapchain(renderer);

    log("Destroying vma allocator...");
    vmaDestroyAllocator(vma_allocator);

    log("Destroying device...");
    vkDestroyDevice(dev, vk_allocator);

    log("Destroying surface...");
    sdl.Vulkan_DestroySurface(xx instance, xx surface, xx vk_allocator);

    #if ENABLE_VALIDATION {
        log("Destorying debug messenger...");
        vkDestroyDebugUtilsMessengerEXT(instance, debug_messenger, vk_allocator);
    }
    log("Destroying instance...");
    vkDestroyInstance(instance, vk_allocator);
}

#scope_file

VALIDATION_LAYERS :: (*u8).["VK_LAYER_KHRONOS_validation"];
SWAPCHAIN_SURFACE_FORMAT : VkFormat : .B8G8R8A8_UNORM;
SWAPCHAIN_COLOR_SPACE    : VkColorSpaceKHR : .SRGB_NONLINEAR;
SWAPCHAIN_IMAGE_USAGE    : VkImageUsageFlags : .TRANSFER_DST | .COLOR_ATTACHMENT;

#if OS == .MACOS {
    ENABLED_EXTENSION_NAMES :: (*u8).[VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    VK_KHR_PORTABILITY_SUBSET_EXTENSION_NAME,
    VK_EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME];
} else {
    ENABLED_EXTENSION_NAMES :: (*u8).[VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    VK_EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME];
}

init_instance :: (using renderer: *Renderer) {
    vk_allocator = null;

    vk_load_global_functions(xx sdl.Vulkan_GetVkGetInstanceProcAddr());

    application_info:= VkApplicationInfo.{
        pApplicationName = "shapeless renderer",
        applicationVersion = #run VK_MAKE_API_VERSION(0, 1, 0, 0),
        pEngineName = "shapeless engine",
        engineVersion = #run VK_MAKE_API_VERSION(0, 1, 0, 0),
        apiVersion = VK_API_VERSION_1_3
    };

    create_info := VkInstanceCreateInfo.{
        pApplicationInfo = *application_info,
    };

    #if OS == .MACOS {
        create_info.flags |= .ENUMERATE_PORTABILITY_KHR;
    }

    extension_count: u32 = 0;
    sdl_extensions := sdl.Vulkan_GetInstanceExtensions(*extension_count);

    push_allocator(temp);
    defer reset_temporary_storage();

    #if ENABLE_VALIDATION {
        extension_names: [..]*u8;
        for i: 0..extension_count - 1 {
            array_add(*extension_names, sdl_extensions[i]);
        }

        debug_extension_name := to_c_string(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

        array_add(*extension_names, debug_extension_name);

        available_layer_count: u32;

        VK_CHECK(vkEnumerateInstanceLayerProperties(*available_layer_count, null));

        available_layers := NewArray(available_layer_count, VkLayerProperties);
        VK_CHECK(vkEnumerateInstanceLayerProperties(*available_layer_count, available_layers.data));

        for validation_layer: VALIDATION_LAYERS {
            found := false;
            for available_layer: available_layers {
                name := available_layer.layerName;
                // Calling to_string does not allocate memory.
                if to_string(name.data) == to_string(validation_layer) {
                    found = true;
                    break;
                }
            }

            if !found {
                assert(false, "instance layer not supported: %", to_string(validation_layer));
            }
        }

        debug_info := debug_utils_messenger_create_info;
        create_info.pNext = *debug_info;
        create_info.enabledExtensionCount = xx extension_names.count;
        create_info.ppEnabledExtensionNames = extension_names.data;
        create_info.enabledLayerCount = VALIDATION_LAYERS.count;
        create_info.ppEnabledLayerNames = VALIDATION_LAYERS.data;
    } else {
        create_info.enabledExtensionCount = extension_count;
        create_info.ppEnabledExtensionNames = sdl_extensions;
    }

    log("creating vulkan instance...");
    VK_CHECK(vkCreateInstance(*create_info, vk_allocator, *instance));

    vk_load_instance_functions(instance);

    #if ENABLE_VALIDATION {
        log("creating vulkan debug messenger...");
        VK_CHECK(
            vkCreateDebugUtilsMessengerEXT(instance, *debug_info, vk_allocator, *debug_messenger)
        );
    }
}

debug_utils_callback :: (
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: *void
) -> VkBool32 #c_call {
    if messageSeverity >= .WARNING {
        push_context {
            log("%", to_string(pCallbackData.pMessage));
        }
    }
    return VK_FALSE;
}

debug_utils_messenger_create_info :: VkDebugUtilsMessengerCreateInfoEXT.{
    messageSeverity = .VERBOSE | .INFO | .WARNING | .ERROR,
    messageType = .GENERAL | .VALIDATION | .PERFORMANCE,
    pfnUserCallback = debug_utils_callback,
    pUserData = null,
};

get_physical_device :: (using renderer: *Renderer) {
    log("picking physical device...");
    physical_device_count : u32;
    vkEnumeratePhysicalDevices(instance, *physical_device_count, null);
    assert(physical_device_count > 0, "There is no GPU");

    physical_devices := NewArray(physical_device_count, VkPhysicalDevice);
    vkEnumeratePhysicalDevices(instance, *physical_device_count, physical_devices.data);

    if physical_device_count > 1 {
        for d : physical_devices {
            props : VkPhysicalDeviceProperties;
            vkGetPhysicalDeviceProperties(d, *props);

            if props.deviceType == .DISCRETE_GPU {
                pdev = d;
            }
        }

    } else {
        assert(physical_device_count == 1);
        pdev = physical_devices[0];
    }

    vkGetPhysicalDeviceProperties(pdev, *properties);
}

init_surface :: (using renderer: *Renderer) {
    // Mismatch binding types between SDL3 and Vulkan
    ok := sdl.Vulkan_CreateSurface(window, xx instance, xx vk_allocator, xx *surface);
    assert(ok);
}

init_device :: (using renderer: *Renderer) {
    priority := 1.0;
    device_info : VkDeviceCreateInfo;

    #if OS == .MACOS {
        queue_create_info := VkDeviceQueueCreateInfo.{
            queueFamilyIndex = 0,
            queueCount       = 1,
            pQueuePriorities = *priority,
        };
        device_info = VkDeviceCreateInfo.{
            queueCreateInfoCount = 1,
            pQueueCreateInfos = *queue_create_info,

        };
    } else {
        // In my 9070XT, I only have two separate queue.
        // So squeeze compute and transfer queue together.
        indices := find_queue_families(pdev, surface);
        queue_infos: [2]VkDeviceQueueCreateInfo;
        queue_infos[0] = VkDeviceQueueCreateInfo.{
            queueFamilyIndex = indices.graphics,
            queueCount       = 1,
            pQueuePriorities = *priority,
        };
        queue_infos[1] = VkDeviceQueueCreateInfo.{
            queueFamilyIndex = indices.compute,
            queueCount       = 1,
            pQueuePriorities = *priority,
        };

        device_info = VkDeviceCreateInfo.{
            queueCreateInfoCount = 2,
            pQueueCreateInfos = queue_infos.data,
        };
    }

    dynamic_state3_features := VkPhysicalDeviceExtendedDynamicState3FeaturesEXT.{
        extendedDynamicState3PolygonMode = VK_TRUE,
    };

    features13 := VkPhysicalDeviceVulkan13Features.{
        pNext = *dynamic_state3_features,
        dynamicRendering = VK_TRUE,
        synchronization2 = VK_TRUE,
    };

    features12 := VkPhysicalDeviceVulkan12Features.{
        pNext = *features13,
        bufferDeviceAddress = VK_TRUE,
        descriptorIndexing = VK_TRUE,
    };

    device_features := VkPhysicalDeviceFeatures2.{
        pNext = *features12,
        features = .{samplerAnisotropy = VK_TRUE, fillModeNonSolid = VK_TRUE},
    };

    device_info.pNext = *device_features;
    device_info.pEnabledFeatures = null;
    device_info.enabledExtensionCount = xx ENABLED_EXTENSION_NAMES.count;
    device_info.ppEnabledExtensionNames = ENABLED_EXTENSION_NAMES.data;

    log("creating vulkan logical device...");
    VK_CHECK(vkCreateDevice(pdev, *device_info, vk_allocator, *dev));

    vk_load_device_functions(dev);

    graphics_family = 0;
    vkGetDeviceQueue(dev, 0, 0, *graphics_queue);
    present_family = graphics_family;
    present_queue = graphics_queue;

    #if OS == .MACOS {
        compute_family = graphics_family;
        compute_queue = graphics_queue;
        present_family = graphics_family;
        present_queue = graphics_queue;
    } else {
        compute_family = 0;
        vkGetDeviceQueue(dev, 0, 0, *compute_queue);
        transfer_family = compute_family;
        transfer_queue = compute_queue;
    }
}

init_vma :: (using renderer: *Renderer) {
    log("creating vam allocator...");
    vma_vulkan_functions := VmaVulkanFunctions.{
        vkGetInstanceProcAddr = vkGetInstanceProcAddr,
        vkGetDeviceProcAddr = vkGetDeviceProcAddr,
    };
    allocator_info := VmaAllocatorCreateInfo.{
        vulkanApiVersion = VK_API_VERSION_1_3,
        physicalDevice   = pdev,
        device           = dev,
        instance         = instance,
        flags            = VMA_BUFFER_DEVICE_ADDRESS,
        pVulkanFunctions = *vma_vulkan_functions,
    };
    VK_CHECK(vmaCreateAllocator(*allocator_info, *vma_allocator));
}

QueueFamilyIndices :: struct {
    graphics : u32;
    present  : u32;
    compute  : u32;
    transfer : u32;
}

find_queue_families :: (pdevice: VkPhysicalDevice, surface: VkSurfaceKHR) -> QueueFamilyIndices {
    indices: QueueFamilyIndices;

    queue_family_count: u32;
    vkGetPhysicalDeviceQueueFamilyProperties(pdevice, *queue_family_count, null);

    queue_families := NewArray(queue_family_count, VkQueueFamilyProperties);
    vkGetPhysicalDeviceQueueFamilyProperties(pdevice, *queue_family_count, queue_families.data);
    defer array_free(queue_families);

    present_found := false;
    compute_found := false;
    transfer_found := false;

    for i : 0..queue_family_count - 1 {
        if present_found && compute_found && transfer_found {
            break;
        }

        if queue_families[i].queueFlags & .GRAPHICS {
            present_support: VkBool32;
            vkGetPhysicalDeviceSurfaceSupportKHR(pdevice, i, surface, *present_support);
            if present_support {
                indices.graphics = i;
                indices.present = i;
                present_found = true;
            }
        } else {
            if queue_families[i].queueFlags & .COMPUTE {
                indices.compute = i;
                compute_found = true;
            }

            if queue_families[i].queueFlags & .TRANSFER {
                indices.transfer = i;
                transfer_found = true;
            }
        }
    }

    assert(present_found && compute_found && transfer_found, "Not all queue families are found");
    return indices;
}

init_swapchain :: (using renderer: *Renderer) {
    create_swapchain(renderer, get_window_extent(window), null);
    get_swapchain_images(renderer);
    init_swapchain_commands(renderer);
    init_swapchain_sync_structures(renderer);
    init_swapchain_descriptor_pools(renderer);
}

destroy_swapchain :: (using renderer: *Renderer) {
    for i : 0..image_count - 1 {
        descriptor_allocator_destroy_pool(*frames[i].descriptor_allocator, renderer);
        descriptor_allocator_destroy(*frames[i].descriptor_allocator);

        vkDestroyCommandPool(dev, frames[i].command_pool, vk_allocator);
        vkDestroyFence(dev, frames[i].render_fence, vk_allocator);
        vkDestroySemaphore(dev, frames[i].render_semaphore, vk_allocator);
        vkDestroySemaphore(dev, frames[i].swapchain_semaphore, vk_allocator);
    }

    cleanup_swapchain(renderer);
}

create_swapchain :: (using renderer: *Renderer, extent: VkExtent2D, old_swapchain: VkSwapchainKHR) {
    swapchain_support := query_swapchain_support(pdev, surface);
    surface_format := choose_swap_surface_format(swapchain_support.formats);
    present_mode := choose_swap_present_mode(swapchain_support.present_modes);
    swapchain_extent = choose_swap_extent(*swapchain_support.capabilities, extent);

    image_count = swapchain_support.capabilities.minImageCount + 1;
    // Allocate the array according to image_count
    images = NewArray(image_count, VkImage);
    image_views = NewArray(image_count, VkImageView);
    frames = NewArray(image_count, FrameData);

    if swapchain_support.capabilities.maxImageCount > 0 && image_count > swapchain_support.capabilities.maxImageCount {
        image_count = swapchain_support.capabilities.maxImageCount;
    }

    create_info := VkSwapchainCreateInfoKHR.{
        surface = surface,
        minImageCount = image_count,
        imageFormat = surface_format.format,
        imageColorSpace = surface_format.colorSpace,
        imageExtent = swapchain_extent,
        imageArrayLayers = 1, // For normal 3D view, use one
        imageUsage = SWAPCHAIN_IMAGE_USAGE,
        imageSharingMode = .EXCLUSIVE,
        queueFamilyIndexCount = 0,
        pQueueFamilyIndices = null,
        preTransform = swapchain_support.capabilities.currentTransform,
        compositeAlpha = .OPAQUE,
        presentMode = present_mode,
        clipped = VK_TRUE,
        oldSwapchain = old_swapchain,
    };

    log("creating swapchain...");
    VK_CHECK(vkCreateSwapchainKHR(dev, *create_info, vk_allocator, *swapchain));
    image_format = surface_format.format;
}

get_window_extent :: (window: *sdl.Window) -> VkExtent2D {
    w: s32;
    h : s32;
    if !sdl.GetWindowSize(window, *w, *h) {
        log_error("Cannot get window size %", sdl.GetError());
    }

    return VkExtent2D.{xx w, xx h};
}

SwapchainSupportDetails :: struct {
    capabilities: VkSurfaceCapabilitiesKHR;
    formats: []VkSurfaceFormatKHR;
    present_modes: []VkPresentModeKHR;
}

query_swapchain_support :: (device: VkPhysicalDevice, surface: VkSurfaceKHR) -> SwapchainSupportDetails {
    details: SwapchainSupportDetails;
    VK_CHECK(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, *details.capabilities));

    format_count: u32;
    VK_CHECK(vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, *format_count, null));
    if format_count > 0 {
        details.formats = NewArray(format_count, VkSurfaceFormatKHR);
        VK_CHECK(vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, *format_count, details.formats.data));
    }

    mode_count: u32;
    VK_CHECK(vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, *mode_count, null));
    if mode_count > 0 {
        details.present_modes = NewArray(mode_count, VkPresentModeKHR);
        VK_CHECK(vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, *mode_count, details.present_modes.data));
    }

    return details;
}

choose_swap_surface_format :: (available_formats: []VkSurfaceFormatKHR) -> VkSurfaceFormatKHR {
    for f : available_formats {
        if f.format == SWAPCHAIN_SURFACE_FORMAT &&
            f.colorSpace == SWAPCHAIN_COLOR_SPACE {
            return f;
        }
    }

    return available_formats[0];
}

choose_swap_present_mode :: (available_present_modes: []VkPresentModeKHR) -> VkPresentModeKHR {
    for m : available_present_modes {
        if m == .MAILBOX {
            return m;
        }
    }

    return .FIFO;
}

choose_swap_extent :: (capabilities: *VkSurfaceCapabilitiesKHR, extent: VkExtent2D) -> VkExtent2D {
    if capabilities.currentExtent.width != U32_MAX {
        return capabilities.currentExtent;
    } else {
        e := extent;
        e.width = clamp(extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
        e.height = clamp(extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
        return e;
    }
}

get_swapchain_images :: (using renderer: *Renderer) {
    log("getting swapchain images... count: %", image_count);
    VK_CHECK(vkGetSwapchainImagesKHR(dev, swapchain, *image_count, images.data));

    log("creating swapchain image views...");
    for i : 0..image_count - 1 {
        view_info := VkImageViewCreateInfo.{
            image = images[i],
            viewType = .e2D,
            format = image_format,
            subresourceRange = .{
                aspectMask = .COLOR,
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        };
        VK_CHECK(vkCreateImageView(dev, *view_info, vk_allocator, *image_views[i]));
    }
}

init_swapchain_commands :: (using renderer: *Renderer) {
    cmd_pool_info := VkCommandPoolCreateInfo.{
        flags = .RESET_COMMAND_BUFFER,
        queueFamilyIndex = graphics_family,
    };

    for i : 0..image_count - 1 {
        VK_CHECK(vkCreateCommandPool(dev, *cmd_pool_info, vk_allocator, *frames[i].command_pool));
        cmd_alloc_info := VkCommandBufferAllocateInfo.{
            commandPool = frames[i].command_pool,
            commandBufferCount = 1,
        };

        VK_CHECK(vkAllocateCommandBuffers(dev, *cmd_alloc_info, *frames[i].cmd));
    }
}

init_swapchain_sync_structures :: (using renderer: *Renderer) {
    fence_info := VkFenceCreateInfo.{
        flags = .SIGNALED,
    };

    semaphore_info := VkSemaphoreCreateInfo.{

    };

    for i : 0..image_count - 1 {
        VK_CHECK(vkCreateFence(dev, *fence_info, vk_allocator, *frames[i].render_fence));
        VK_CHECK(vkCreateSemaphore(dev, *semaphore_info, vk_allocator, *frames[i].swapchain_semaphore));
        VK_CHECK(vkCreateSemaphore(dev, *semaphore_info, vk_allocator, *frames[i].render_semaphore));
    }
}

init_swapchain_descriptor_pools :: (using renderer: *Renderer) {
    for i : 0..image_count - 1 {
        descriptor_allocator_add_pool_size(*frames[i].descriptor_allocator, .UNIFORM_BUFFER, 5);
        descriptor_allocator_add_pool_size(*frames[i].descriptor_allocator, .COMBINED_IMAGE_SAMPLER, 5);
        descriptor_allocator_add_pool_size(*frames[i].descriptor_allocator, .STORAGE_BUFFER, 5);
        descriptor_allocator_init_pool(*frames[i].descriptor_allocator, renderer, 500);
    }
}

cleanup_swapchain :: (using renderer: *Renderer) {
    log("destroying swapchain...");
    for i : 0..image_count - 1 {
        vkDestroyImageView(dev, image_views[i], vk_allocator);
    }
    vkDestroySwapchainKHR(dev, swapchain, vk_allocator);
}

recreate_swapchain :: (using renderer: *Renderer) {
    log("recreating swapchain...");
    for i : 0..image_count - 1 {
        vkDestroyImageView(dev, image_views[i], vk_allocator);
    }

    array_free(images);
    array_free(image_views);
    array_free(frames);

    old_swapchain := swapchain;
    create_swapchain(renderer, extent, old_swapchain);
    get_swapchain_images(self);
    vkDestroySwapchainKHR(dev, old_swapchain, vk_allocator);
}

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
#import "Basic";
#import "String";
sdl :: #import "SDL3";
#import,file "descriptors.jai";
#import "Math";
