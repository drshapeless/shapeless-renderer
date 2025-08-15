ENABLE_VALIDATION :: true;

Renderer :: struct {
    window: *sdl.Window;
    vk_allocator: *VkAllocationCallbacks;
    instance: VkInstance;
    debug_messenger: VkDebugUtilsMessengerEXT;
}

init_renderer :: (using renderer: *Renderer, sdl_window: *sdl.Window) {
    init_device(renderer);
}

#scope_file

VALIDATION_LAYERS :: (*u8).["VK_LAYER_KHRONOS_validation"];

init_device :: (using renderer: *Renderer) {
    vk_allocator = null;

    vk_load_proc_addresses_global(xx sdl.Vulkan_GetVkGetInstanceProcAddr());

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
        create_info.flags |= .ENUMERATE_PORTABILITY_BIT_KHR;
    }

    extension_count: u32 = 0;
    sdl_extensions := sdl.Vulkan_GetInstanceExtensions(*extension_count);

    #if ENABLE_VALIDATION {
        extension_names: [..]*u8;
        for i: 0..extension_count - 1 {
            array_add(*extension_names, sdl_extensions[i]);
        }

        debug_extension_name := to_c_string(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        defer free(debug_extension_name);

        array_add(*extension_names, debug_extension_name);

        available_layer_count: u32;

        VK_CHECK(vkEnumerateInstanceLayerProperties(*available_layer_count, null));

        available_layers := NewArray(available_layer_count, VkLayerProperties);
        defer free(available_layers.data);
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
                assert(false, "instance layer not supported: %", validation_layer);
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

    vk_load_proc_addresses_instance(instance);

    #if ENABLE_VALIDATION {
        log("creating vulkan debug messenger...");
        VK_CHECK(
            vkCreateDebugUtilsMessengerEXT(instance, *debug_info, vk_allocator, *debug_messenger)
        );
    }
}

VK_CHECK :: (result: VkResult, loc := #caller_location) {
    assert(result == .SUCCESS, "VK_CHECK failed: %", result, loc = loc);
}

debug_utils_callback :: (
    messageSeverity: VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: *VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: *void
) -> VkBool32 #c_call {
    if messageSeverity >= .WARNING_BIT_EXT {
        push_context {
            log("%", to_string(pCallbackData.pMessage));
        }
    }
    return VK_FALSE;
}

debug_utils_messenger_create_info :: VkDebugUtilsMessengerCreateInfoEXT.{
    messageSeverity = .VERBOSE_BIT_EXT | .INFO_BIT_EXT | .WARNING_BIT_EXT | .ERROR_BIT_EXT,
    messageType = .GENERAL_BIT_EXT | .VALIDATION_BIT_EXT | .PERFORMANCE_BIT_EXT,
    pfnUserCallback = debug_utils_callback,
    pUserData = null,
};

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
#import "Basic";
#import "String";
sdl :: #import "SDL3";
