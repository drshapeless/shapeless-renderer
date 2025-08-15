ENABLE_VALIDATION :: true;

Renderer :: struct {
    vk_allocator: *VkAllocationCallbacks;
    instance: VkInstance;
}

renderer_init :: (using renderer: *Renderer) {
    init_device(renderer);
}

#scope_file

VALIDATION_LAYERS :: (*u8).["VK_LAYER_KHRONOS_validation"];

init_device :: (using renderer: *Renderer) {
    vk_allocator = null;

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

    extension_count: u32;
    sdl_extensions := sdl.Vulkan_GetInstanceExtensions(*extension_count);

    #if ENABLE_VALIDATION {
        extension_names: [..]*u8;
        for i: 0..extension_count {
            array_add(*extension_names, sdl_extensions[i]);
        }

        array_add(*extension_names, VK_EXT_DEBUG_UTILS_EXTENSION_NAME);

        available_layer_count: u32;

        VK_CHECK(vkEnumerateInstanceLayerProperties(*available_layer_count, null));

        available_layers := NewArray(available_layer_count, VkLayerProperties);
        VK_CHECK(vkEnumerateInstanceLayerProperties(*available_layer_count, available_layers.data));

        for validation_layer: VALIDATION_LAYERS {
            found := false;
            for available_layer: available_layers {
                name := available_layer.layerName;
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
    } else {

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
            log("%", pCallbackData.pMessage);
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
