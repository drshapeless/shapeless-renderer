ENABLE_VALIDATION :: true;

Renderer :: struct {
    window: *sdl.Window;
    vk_allocator: *VkAllocationCallbacks;
    instance: VkInstance;
    debug_messenger: VkDebugUtilsMessengerEXT;
    pdev: VkPhysicalDevice;
    properties: VkPhysicalDeviceProperties;
    surface: VkSurfaceKHR;
    dev: VkDevice;

    // Family and queue
    graphics_family: u32;
    graphics_queue: VkQueue;
    present_family: u32;
    present_queue: VkQueue;
    compute_family: u32;
    compute_queue: VkQueue;
    transfer_family: u32;
    transfer_queue: VkQueue;

    vma_allocator: VmaAllocator;
}

init_renderer :: (using renderer: *Renderer, sdl_window: *sdl.Window) {
    window = sdl_window;
    init_instance(renderer);
    get_physical_device(renderer);
    init_surface(renderer);
    init_device(renderer);
    init_vma(renderer);
}

destroy_renderer :: (using renderer: *Renderer) {
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

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
#import "Basic";
#import "String";
sdl :: #import "SDL3";
#import,file "common.jai";
