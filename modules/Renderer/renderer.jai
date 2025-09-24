ENABLE_VALIDATION :: true;

Frame_Data :: struct {
    command_pool         : VkCommandPool;
    cmd                  : VkCommandBuffer;
    swapchain_semaphore  : VkSemaphore;
    render_semaphore     : VkSemaphore;
    render_fence         : VkFence;
    descriptor_allocator : Descriptor_Allocator;
}

Renderer :: struct {
    window: *SDL_Window;

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
    frames              : []Frame_Data;
    current_frame_index : u32;
    current_image_index : u32;

    // Other
    draw_image            : Image;
    depth_image           : Image;
    clear_color           : VkClearValue;
    draw_extent           : VkExtent2D;
    transfer_command_pool : VkCommandPool;
    graphics_command_pool : VkCommandPool;
    cmd                   : VkCommandBuffer;
    resize_requested      : bool;

    // Builtin shapes
    builtin_models: Builtin_Models;
}

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

VK_CHECK :: (result: VkResult, loc := #caller_location) {
    assert(result == .SUCCESS, "VK_CHECK failed: %", result, loc = loc);
}

init_renderer :: (using renderer: *Renderer, sdl_window: *SDL_Window) {
    window = sdl_window;
    init_instance(renderer);
    get_physical_device(renderer);
    init_surface(renderer);
    init_device(renderer);
    init_vma(renderer);
    init_swapchain(renderer);
    create_command_pool(renderer);
    create_draw_images(renderer);
    init_builtin_models(renderer);
}

destroy_renderer :: (using renderer: *Renderer) {
    VK_CHECK(vkDeviceWaitIdle(dev));

    destroy_builtin_models(renderer);
    destroy_draw_images(renderer);
    destroy_command_pool(renderer);

    log("Destroying swapchain...");
    destroy_swapchain(renderer);

    log("Destroying vma allocator...");
    vmaDestroyAllocator(vma_allocator);

    log("Destroying device...");
    vkDestroyDevice(dev, vk_allocator);

    log("Destroying surface...");
    SDL_Vulkan_DestroySurface(xx instance, xx surface, xx vk_allocator);

    #if ENABLE_VALIDATION {
        log("Destorying debug messenger...");
        vkDestroyDebugUtilsMessengerEXT(instance, debug_messenger, vk_allocator);
    }
    log("Destroying instance...");
    vkDestroyInstance(instance, vk_allocator);
}

init_instance :: (using renderer: *Renderer) {
    vk_allocator = null;

    vk_load_global_functions(xx SDL_Vulkan_GetVkGetInstanceProcAddr());

    application_info:= VkApplicationInfo.{
        pApplicationName = "shapeless renderer",
        applicationVersion = #run VK_MAKE_API_VERSION(0, 1, 0, 0),
        pEngineName = "shapeless engine",
        engineVersion = #run VK_MAKE_API_VERSION(0, 1, 0, 0),
        apiVersion = VK_API_VERSION_1_4,
    };

    create_info := VkInstanceCreateInfo.{
        pApplicationInfo = *application_info,
    };

    #if OS == .MACOS {
        create_info.flags |= .ENUMERATE_PORTABILITY_KHR;
    }

    extension_count: u32 = 0;
    sdl_extensions := SDL_Vulkan_GetInstanceExtensions(*extension_count);

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

    log("Creating vulkan instance...");
    VK_CHECK(vkCreateInstance(*create_info, vk_allocator, *instance));

    vk_load_instance_functions(instance);

    #if ENABLE_VALIDATION {
        log("Creating vulkan debug messenger...");
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
    log("Picking physical device...");
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
        log("Using the only gpu");
        pdev = physical_devices[0];
    }

    vkGetPhysicalDeviceProperties(pdev, *properties);
}

init_surface :: (using renderer: *Renderer) {
    // Mismatch binding types between SDL3 and Vulkan
    ok := SDL_Vulkan_CreateSurface(window, xx instance, xx vk_allocator, xx *surface);
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

    log("Creating vulkan logical device...");
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
    log("Creating vam allocator...");
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
    frames = NewArray(image_count, Frame_Data);

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

    log("Creating swapchain...");
    VK_CHECK(vkCreateSwapchainKHR(dev, *create_info, vk_allocator, *swapchain));
    image_format = surface_format.format;
}

get_window_extent :: (window: *SDL_Window) -> VkExtent2D {
    w: s32;
    h : s32;
    if !SDL_GetWindowSize(window, *w, *h) {
        log_error("Cannot get window size %", SDL_GetError());
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
    log("Getting swapchain images... count: %", image_count);
    VK_CHECK(vkGetSwapchainImagesKHR(dev, swapchain, *image_count, images.data));

    log("Creating swapchain image views...");
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
    log("Destroying swapchain...");
    for i : 0..image_count - 1 {
        vkDestroyImageView(dev, image_views[i], vk_allocator);
    }
    vkDestroySwapchainKHR(dev, swapchain, vk_allocator);
}

recreate_swapchain :: (using renderer: *Renderer) {
    log("Recreating swapchain...");
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

Descriptor_Allocator :: struct {
    pool_sizes : [..]VkDescriptorPoolSize;
    pool       : VkDescriptorPool;
}

descriptor_allocator_destroy :: (using self: *Descriptor_Allocator) {
    array_free(pool_sizes);
}

descriptor_allocator_add_pool_size :: (using self: *Descriptor_Allocator, type: VkDescriptorType, descriptor_count: u32) {
    pool_size := VkDescriptorPoolSize.{
        type            = type,
        descriptorCount = descriptor_count,
    };

    array_add(*pool_sizes, pool_size);
}

descriptor_allocator_init_pool :: (using self: *Descriptor_Allocator, using renderer: *Renderer, max_sets: u32) {
    pool_info := VkDescriptorPoolCreateInfo.{
        maxSets       = max_sets,
        poolSizeCount = xx pool_sizes.count,
        pPoolSizes    = pool_sizes.data,
    };

    VK_CHECK(vkCreateDescriptorPool(dev, *pool_info, vk_allocator, *pool));
}

descriptor_allocator_clear_descriptors :: (using self: *Descriptor_Allocator, using renderer: *Renderer) {
    vkResetDescriptorPool(dev, pool, 0);
}

descriptor_allocator_destroy_pool :: (using self: *Descriptor_Allocator, using renderer: *Renderer) {
    vkDestroyDescriptorPool(dev, pool, vk_allocator);
}

descriptor_allocator_allocate :: (using self: *Descriptor_Allocator, using renderer: *Renderer, layout: VkDescriptorSetLayout) -> VkDescriptorSet {
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

Pipeline_Builder :: struct {
    shader_stages: [..]VkPipelineShaderStageCreateInfo;
    vertex_bindings:         [..]VkVertexInputBindingDescription;
    vertex_attributes:       [..]VkVertexInputAttributeDescription;
    color_blend_attachments: [..]VkPipelineColorBlendAttachmentState;
    dynamic_states:          [..]VkDynamicState;
    vertex_input_info:       VkPipelineVertexInputStateCreateInfo;
    input_assembly_info:     VkPipelineInputAssemblyStateCreateInfo;
    tessellation_info:       VkPipelineTessellationStateCreateInfo; // No use ATM
    viewport_info:           VkPipelineViewportStateCreateInfo;
    rasterization_info:      VkPipelineRasterizationStateCreateInfo;
    multisample_info:        VkPipelineMultisampleStateCreateInfo;
    depth_stencil_info:      VkPipelineDepthStencilStateCreateInfo;
    color_blend_info:        VkPipelineColorBlendStateCreateInfo;
    dynamic_info:            VkPipelineDynamicStateCreateInfo;
    layout:                  VkPipelineLayout;
    render_info:             VkPipelineRenderingCreateInfo;
    color_attachment_format: VkFormat;
}

pipeline_builder_build :: (using builder: *Pipeline_Builder, using renderer: *Renderer) -> VkPipeline {
    vertex_input_info.vertexBindingDescriptionCount = xx vertex_bindings.count;
    vertex_input_info.pVertexBindingDescriptions = vertex_bindings.data;

    vertex_input_info.vertexAttributeDescriptionCount = xx vertex_attributes.count;
    vertex_input_info.pVertexAttributeDescriptions = vertex_attributes.data;

    color_blend_info.attachmentCount = xx color_blend_attachments.count;
    color_blend_info.pAttachments = color_blend_attachments.data;

    dynamic_info.pDynamicStates = dynamic_states.data;
    dynamic_info.dynamicStateCount = xx dynamic_states.count;

    pipeline_info := VkGraphicsPipelineCreateInfo.{
        stageCount = xx shader_stages.count,
        pStages = shader_stages.data,
        pVertexInputState = *vertex_input_info,
        pInputAssemblyState = *input_assembly_info,
        pTessellationState  = *tessellation_info,
        pViewportState      = *viewport_info,
        pRasterizationState = *rasterization_info,
        pMultisampleState   = *multisample_info,
        pDepthStencilState  = *depth_stencil_info,
        pColorBlendState    = *color_blend_info,
        pDynamicState       = *dynamic_info,
        layout              = layout,
        renderPass          = null,
        subpass             = 0,
        basePipelineHandle  = null,
        basePipelineIndex   = -1,
        pNext               = *render_info,
    };

    pipeline : VkPipeline;

    VK_CHECK(vkCreateGraphicsPipelines(dev, null, 1, *pipeline_info, vk_allocator, *pipeline));

    return pipeline;
}

pipeline_builder_destroy :: (using builder: *Pipeline_Builder) {
    array_free(shader_stages);
    array_free(vertex_bindings);
    array_free(vertex_attributes);
    array_free(color_blend_attachments);
    array_free(dynamic_states);
}

pipeline_builder_clear :: (using builder: *Pipeline_Builder) {
    vertex_input_info   = .{};
    input_assembly_info = .{};
    tessellation_info   = .{};
    viewport_info = .{
        viewportCount = 1,
        scissorCount  = 1,
    };
    rasterization_info = .{};
    multisample_info   = .{};
    depth_stencil_info = .{};

    color_blend_info = .{
        logicOpEnable = VK_FALSE,
        logicOp       = .COPY,
    };

    dynamic_info = .{};
    layout = null;
    render_info = .{};
}

pipeline_builder_set_shaders :: (using builder: *Pipeline_Builder, vert_shader: VkShaderModule, frag_shader: VkShaderModule) {
    array_reset_keeping_memory(*shader_stages);
    vert_info := VkPipelineShaderStageCreateInfo.{
        stage = .VERTEX,
        module = vert_shader,
        pName = "main",
    };

    array_add(*shader_stages, vert_info);

    frag_info := VkPipelineShaderStageCreateInfo.{
        stage = .FRAGMENT,
        module = frag_shader,
        pName = "main",
    };

    array_add(*shader_stages, frag_info);
}

pipeline_builder_set_layout :: (builder: *Pipeline_Builder, layout: VkPipelineLayout) {
    builder.layout = layout;
}

pipeline_builder_set_input_topology :: (using builder: *Pipeline_Builder, topology: VkPrimitiveTopology) {
    input_assembly_info.topology = topology;
    input_assembly_info.primitiveRestartEnable = VK_FALSE;
}

pipeline_builder_set_polygon_mode :: (using builder: *Pipeline_Builder, mode: VkPolygonMode) {
    rasterization_info.polygonMode = mode;
    rasterization_info.lineWidth = 1;
}

pipeline_builder_set_cull_mode :: (using builder: *Pipeline_Builder, cull_mode: VkCullModeFlags, front_face: VkFrontFace) {
    rasterization_info.cullMode = cull_mode;
    rasterization_info.frontFace = front_face;
}

pipeline_builder_set_multisampling_none :: (using builder: *Pipeline_Builder) {
    multisample_info.sampleShadingEnable   = VK_FALSE;
    multisample_info.rasterizationSamples  = .e1;
    multisample_info.minSampleShading      = 1;
    multisample_info.pSampleMask           = null;
    multisample_info.alphaToCoverageEnable = VK_FALSE;
    multisample_info.alphaToOneEnable      = VK_FALSE;
}

pipeline_builder_disable_blending :: (using builder: *Pipeline_Builder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask = .R | .G | .B | .A,
        blendEnable = VK_FALSE,
    };

    array_reset_keeping_memory(*color_blend_attachments);
    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_set_color_attachment_format :: (using builder: *Pipeline_Builder, format: VkFormat) {
    color_attachment_format = format;

    render_info.colorAttachmentCount = 1;
    render_info.pColorAttachmentFormats = *color_attachment_format;
}

pipeline_builder_set_depth_format :: (using builder: *Pipeline_Builder, format: VkFormat) {
    render_info.depthAttachmentFormat = format;
}

pipeline_builder_disable_depthtest :: (using builder: *Pipeline_Builder) {
    depth_stencil_info.depthTestEnable = VK_FALSE;
    depth_stencil_info.depthWriteEnable = VK_FALSE;
    depth_stencil_info.depthCompareOp = .NEVER;
    depth_stencil_info.depthBoundsTestEnable = VK_FALSE;
    depth_stencil_info.stencilTestEnable = VK_FALSE;
    depth_stencil_info.front = .{};
    depth_stencil_info.back = .{};
    depth_stencil_info.minDepthBounds = 0;
    depth_stencil_info.maxDepthBounds = 1;
}

pipeline_builder_enable_depthtest :: (using builder: *Pipeline_Builder, depth_write_enable: VkBool32, op: VkCompareOp) {
    depth_stencil_info.depthTestEnable = VK_TRUE;
    depth_stencil_info.depthBoundsTestEnable = VK_TRUE;
    depth_stencil_info.depthWriteEnable = depth_write_enable;
    depth_stencil_info.depthCompareOp = op;
    depth_stencil_info.stencilTestEnable = VK_FALSE;
    depth_stencil_info.front = .{};
    depth_stencil_info.back = .{};
    depth_stencil_info.minDepthBounds = 0;
    depth_stencil_info.maxDepthBounds = 1;
}

pipeline_builder_enable_blending_additive :: (using builder: *Pipeline_Builder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask      = .R | .G | .B | .A,
        blendEnable         = VK_TRUE,
        srcColorBlendFactor = .SRC_ALPHA,
        dstColorBlendFactor = .ONE,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
    };

    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_enable_blending_alphablend :: (using builder: *Pipeline_Builder) {
    color_blend_attachment := VkPipelineColorBlendAttachmentState.{
        colorWriteMask      = .R | .G | .B | .A,
        blendEnable         = VK_TRUE,
        srcColorBlendFactor = .SRC_ALPHA,
        dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
        colorBlendOp        = .ADD,
        srcAlphaBlendFactor = .ONE,
        dstAlphaBlendFactor = .ZERO,
        alphaBlendOp        = .ADD,
    };

    array_add(*color_blend_attachments, color_blend_attachment);
}

pipeline_builder_add_vertex_input_binding :: (using builder: *Pipeline_Builder, binding: u32, stride: u32, input_rate: VkVertexInputRate) {
    description := VkVertexInputBindingDescription.{
        binding   = binding,
        stride    = stride,
        inputRate = input_rate,
    };

    array_add(*vertex_bindings, description);
}

pipeline_builder_add_vertex_input_attribute :: (using builder: *Pipeline_Builder, location: u32, binding: u32, format: VkFormat, offset: u32) {
    description := VkVertexInputAttributeDescription.{
        location = location,
        binding  = binding,
        format   = format,
        offset   = offset,
    };

    array_add(*vertex_attributes, description);
}

pipeline_builder_clear_vertex_input :: (using builder: *Pipeline_Builder) {
    array_reset_keeping_memory(*vertex_attributes);
    array_reset_keeping_memory(*vertex_bindings);
}

pipeline_builder_add_dynamic_state :: (using builder: *Pipeline_Builder, state: VkDynamicState) {
    array_add(*dynamic_states, state);
}

pipeline_builder_clear_dynamic_state :: (using builder: *Pipeline_Builder) {
    array_reset_keeping_memory(*dynamic_states);
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
        img_info.mipLevels = xx floor(log(cast(float)max(extent.width, extent.height)) / #run log(2));
    }

    alloc_info := VmaAllocationCreateInfo.{
        usage = .GPU_ONLY,
        requiredFlags = .DEVICE_LOCAL,
    };

    VK_CHECK(vmaCreateImage(vma_allocator, *img_info, *alloc_info, *image.img, *image.allocation, null));

    aspect_flag := VkImageAspectFlags.COLOR;
    if format == .D32_SFLOAT {
        aspect_flag = .DEPTH;
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

destroy_image :: (using renderer: *Renderer, image: *Image) {
    vkDestroyImageView(dev, image.img_view, vk_allocator);
    vmaDestroyImage(vma_allocator, image.img, image.allocation);
}

get_current_frame :: (using renderer: *Renderer) -> *Frame_Data {
    return *frames[current_frame_index];
}

get_current_image :: (using renderer: *Renderer) -> VkImage {
    return images[current_image_index];
}

acquire_next_image :: (using renderer: *Renderer) -> VkResult {
    info := VkAcquireNextImageInfoKHR.{
        swapchain = swapchain,
        timeout = U64_MAX,
        semaphore = get_current_frame(renderer).swapchain_semaphore,
        fence = null,
        deviceMask = 1,
    };

    return vkAcquireNextImage2KHR(dev, *info, *current_image_index);
}

create_command_pool :: (using renderer: *Renderer) {
    log("Creating command pools...");

    cmd_pool_info := VkCommandPoolCreateInfo.{
        flags = .TRANSIENT | .RESET_COMMAND_BUFFER,
        queueFamilyIndex = graphics_family,
    };
    VK_CHECK(vkCreateCommandPool(dev, *cmd_pool_info, vk_allocator, *graphics_command_pool));

    cmd_pool_info.queueFamilyIndex = transfer_family;
    VK_CHECK(vkCreateCommandPool(dev, *cmd_pool_info, vk_allocator, *transfer_command_pool));
}

destroy_command_pool :: (using renderer: *Renderer) {
    vkDestroyCommandPool(dev, graphics_command_pool, vk_allocator);
    vkDestroyCommandPool(dev, transfer_command_pool, vk_allocator);
}

create_draw_images :: (using renderer: *Renderer) {
    log("Creating draw images...");
    draw_extent = get_window_extent(window);
    image_extent := VkExtent3D.{
        width = draw_extent.width,
        height = draw_extent.height,
        depth = 1,
    };
    draw_image = create_image(renderer, image_extent, .R16G16B16A16_SFLOAT, .TRANSFER_SRC | .STORAGE | .COLOR_ATTACHMENT, false, 1);
    depth_image = create_image(renderer, image_extent, .D32_SFLOAT, .DEPTH_STENCIL_ATTACHMENT, false, 1);
}

destroy_draw_images :: (using renderer: *Renderer) {
    log("Destroying draw images...");
    destroy_image(renderer, *draw_image);
    destroy_image(renderer, *depth_image);
}

set_clear_color :: (using renderer: *Renderer, color: [4]float) {
    clear_color.color.float32_ = color;
}

load_shader_module :: (using renderer: *Renderer, file_path: string) -> VkShaderModule {
    data, ok := read_entire_file(file_path);
    assert(ok, "cannot read file %", file_path);

    create_info := VkShaderModuleCreateInfo.{
        codeSize = xx data.count,
        pCode = xx data.data,
    };

    shader_module : VkShaderModule;
    VK_CHECK(vkCreateShaderModule(dev, *create_info, vk_allocator, *shader_module));

    return shader_module;
}

destroy_shader_module :: (using renderer: *Renderer, module: VkShaderModule) {
    vkDestroyShaderModule(dev, module, vk_allocator);
}

begin_draw :: (using renderer: *Renderer) -> bool {
    current_frame := get_current_frame(renderer);

    VK_CHECK(vkWaitForFences(dev, 1, *current_frame.render_fence, VK_TRUE, U64_MAX));
    VK_CHECK(vkResetFences(dev, 1, *current_frame.render_fence));

    // TODO: Flush frame data here

    descriptor_allocator_clear_descriptors(*current_frame.descriptor_allocator, renderer);

    VK_CHECK(vkResetCommandBuffer(current_frame.cmd, 0));
    result := acquire_next_image(renderer);
    if result == .ERROR_OUT_OF_DATE_KHR {
        resize_requested = true;
        return false;
    } else {
        assert(result == .SUBOPTIMAL_KHR || result == .SUCCESS, "acquire image failed %", result);
    }

    cmd = current_frame.cmd;

    cmd_begin_info := VkCommandBufferBeginInfo.{
        flags = .ONE_TIME_SUBMIT,
    };
    VK_CHECK(vkBeginCommandBuffer(cmd, *cmd_begin_info));

    transition_image(cmd, draw_image.img, .UNDEFINED, .GENERAL);

    color_attachment := VkRenderingAttachmentInfo.{
        imageView   = draw_image.img_view,
        imageLayout = .GENERAL,
        loadOp      = .CLEAR,
        storeOp     = .STORE,
        clearValue  = clear_color,
    };

    depth_attachment := VkRenderingAttachmentInfo.{
        imageView = depth_image.img_view,
        imageLayout = .DEPTH_ATTACHMENT_OPTIMAL,
        loadOp = .CLEAR,
        storeOp = .STORE,
        clearValue = .{depthStencil = .{depth = 1}},
    };

    rendering_info := VkRenderingInfo.{
        renderArea = .{offset = .{0, 0}, extent = draw_extent},
        layerCount = 1,
        colorAttachmentCount = 1,
        pColorAttachments = *color_attachment,
        pDepthAttachment = *depth_attachment,
        pStencilAttachment = null,
    };

    vkCmdBeginRendering(cmd, *rendering_info);

    viewport := VkViewport.{
        x = 0,
        y = 0,
        width = xx draw_extent.width,
        height = xx draw_extent.height,
        minDepth = 0,
        maxDepth = 1,
    };

    vkCmdSetViewport(cmd, 0, 1, *viewport);

    scissor := VkRect2D.{
        offset = .{0, 0},
        extent = draw_extent,
    };
    vkCmdSetScissor(cmd, 0, 1, *scissor);

    return true;
}

end_draw :: (using renderer: *Renderer) {
    current_frame := get_current_frame(renderer);
    assert(cmd != null, "cmd is null, you should not be here");

    vkCmdEndRendering(cmd);

    current_image := get_current_image(renderer);
    transition_image(cmd, draw_image.img, .GENERAL, .TRANSFER_SRC_OPTIMAL);
    transition_image(cmd, current_image, .UNDEFINED, .TRANSFER_DST_OPTIMAL);
    copy_image(cmd, draw_image.img, current_image, draw_extent, swapchain_extent);
    transition_image(cmd, current_image, .TRANSFER_DST_OPTIMAL, .PRESENT_SRC_KHR);

    VK_CHECK(vkEndCommandBuffer(cmd));
    cmd_info := VkCommandBufferSubmitInfo.{
        commandBuffer = cmd,
    };
    wait_info := VkSemaphoreSubmitInfo.{
        semaphore = current_frame.swapchain_semaphore,
        value = 1,
        stageMask = .COLOR_ATTACHMENT_OUTPUT,
    };

    signal_info := VkSemaphoreSubmitInfo.{
        semaphore = current_frame.render_semaphore,
        value = 1,
        stageMask = .ALL_GRAPHICS,
    };

    submit := VkSubmitInfo2.{
        waitSemaphoreInfoCount = 1,
        pWaitSemaphoreInfos = *wait_info,
        commandBufferInfoCount = 1,
        pCommandBufferInfos = *cmd_info,
        signalSemaphoreInfoCount = 1,
        pSignalSemaphoreInfos = *signal_info,
    };

    VK_CHECK(vkQueueSubmit2(graphics_queue, 1, *submit, current_frame.render_fence));
    present_info := VkPresentInfoKHR.{
        waitSemaphoreCount = 1,
        pWaitSemaphores = *current_frame.render_semaphore,
        swapchainCount = 1,
        pSwapchains = *swapchain,
        pImageIndices = *current_image_index,
    };

    result := vkQueuePresentKHR(graphics_queue, *present_info);
    if result == .ERROR_OUT_OF_DATE_KHR {
        resize_requested = true;
        return;
    } else {
        assert(result == .SUBOPTIMAL_KHR || result == .SUCCESS, "present failed");
    }

    current_frame_index = (current_frame_index + 1) % image_count;
    cmd = null;
}

begin_single_time_commands :: (using renderer: *Renderer) -> VkCommandBuffer {
    cmd_alloc_info := VkCommandBufferAllocateInfo.{
        commandPool = graphics_command_pool,
        commandBufferCount = 1,
        level = .PRIMARY,
    };
    command: VkCommandBuffer;
    VK_CHECK(vkAllocateCommandBuffers(dev, *cmd_alloc_info, *command));

    cmd_begin_info := VkCommandBufferBeginInfo.{
        flags = .ONE_TIME_SUBMIT,
    };
    VK_CHECK(vkBeginCommandBuffer(command, *cmd_begin_info));

    return command;
}

end_single_time_commands :: (using renderer: *Renderer, command: VkCommandBuffer) {
    VK_CHECK(vkEndCommandBuffer(command));

    cmdinfo := VkCommandBufferSubmitInfo.{
        commandBuffer = command,
    };
    submit := VkSubmitInfo2.{
        commandBufferInfoCount = 1,
        pCommandBufferInfos = *cmdinfo,
    };
    VK_CHECK(vkQueueSubmit2(graphics_queue, 1, *submit, null));
    vkQueueWaitIdle(graphics_queue);
    vkFreeCommandBuffers(dev, graphics_command_pool, 1, *command);
}

create_buffer :: (using renderer: *Renderer, alloc_size: u64, usage: VkBufferUsageFlags, memory_usage: VmaMemoryUsage) -> Buffer {
    buffer_info := VkBufferCreateInfo.{
        size = alloc_size,
        usage = usage,
    };

    vma_alloc_info := VmaAllocationCreateInfo.{
        usage = memory_usage,
        flags = xx VmaAllocationCreateFlagBits.MAPPED_BIT,
    };

    new_buffer: Buffer;

    VK_CHECK(vmaCreateBuffer(vma_allocator, *buffer_info, *vma_alloc_info, *new_buffer.buffer, *new_buffer.allocation, *new_buffer.info));

    return new_buffer;
}

destroy_buffer :: (using renderer: *Renderer, buffer: *Buffer) {
    vmaDestroyBuffer(vma_allocator, buffer.buffer, buffer.allocation);
}

map_buffer :: (using renderer: *Renderer, buffer: *Buffer) -> *void {
    data: *void;
    vmaMapMemory(vma_allocator, buffer.allocation, *data);
    return data;
}

unmap_buffer :: (using renderer: *Renderer, buffer: *Buffer) {
    vmaUnmapMemory(vma_allocator, buffer.allocation);
}

// This function is seldom used, I am not sure whether to keep it.
flush_buffer :: (using renderer: *Renderer, buffer: *Buffer, size: VkDeviceSize, offset: VkDeviceSize) {
    vmaFlushAllocation(vma_allocator, buffer.allocation, offset, size);
}

upload_buffer :: (using renderer: *Renderer, buffer: *Buffer, data: *void, size: u64, src_offset: u64, dst_offset: u64) {
    staging_buffer := create_buffer(renderer, size, .TRANSFER_SRC | .STORAGE_BUFFER, .CPU_ONLY);
    staging_data := map_buffer(renderer, *staging_buffer);
    copy(staging_data, data, xx size);
    unmap_buffer(renderer, *staging_buffer);

    c := begin_single_time_commands(renderer);
    copy_buffer(c, staging_buffer.buffer, buffer.buffer, size, src_offset, dst_offset);
    end_single_time_commands(renderer, c);

    destroy_buffer(renderer, *staging_buffer);
}

create_model :: (using renderer: *Renderer, vertices: *void, vertex_stride: u64, vertex_size: u32, indices: *u32, index_size: u32) -> Model {
    model := Model.{
        vertex_size = vertex_size,
        index_size = index_size,
    };

    buffer_size := vertex_stride * vertex_size;

    model.vertex_buffer = create_buffer(renderer, buffer_size, .VERTEX_BUFFER | .TRANSFER_DST, .GPU_ONLY);
    upload_buffer(renderer, *model.vertex_buffer, vertices, buffer_size, 0, 0);

    if index_size > 0 {
        buffer_size = size_of(u32) * index_size;
        model.index_buffer = create_buffer(renderer, buffer_size, .INDEX_BUFFER | .TRANSFER_DST, .GPU_ONLY);
        upload_buffer(renderer, *model.index_buffer, indices, buffer_size, 0, 0);
    }

    return model;
}

destroy_model :: (using renderer: *Renderer, model: *Model) {
    destroy_buffer(renderer, *model.vertex_buffer);
    if model.index_size > 0 {
        destroy_buffer(renderer, *model.index_buffer);
    }
}

init_builtin_models :: (using renderer: *Renderer) {
    builtin_models.square = create_model(renderer, SQUARE_VERTICES.data, size_of(Vector3), xx SQUARE_VERTICES.count, SQUARE_INDICES.data, xx SQUARE_INDICES.count);
}

destroy_builtin_models :: (using renderer: *Renderer) {
    destroy_model(renderer, *builtin_models.square);
}

get_aspect_ratio :: (using renderer: *Renderer) -> float {
    extent := get_window_extent(renderer.window);
    return cast(float)extent.width / extent.height;
}

#scope_file

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
#import "Basic";
#import "String";
#import "SDL3";
#import "Math";
#import "File";
#import "Memory";
