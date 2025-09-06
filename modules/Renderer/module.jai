ENABLE_VALIDATION :: true;

Renderer :: struct {
    window: *sdl.Window;
    vk_allocator: *VkAllocationCallbacks;
    instance: VkInstance;
    debug_messenger: VkDebugUtilsMessengerEXT;
    physical_device: VkPhysicalDevice;
    properties: VkPhysicalDeviceProperties;
    surface: VkSurfaceKHR;
    device: VkDevice;
}

init_renderer :: (using renderer: *Renderer, sdl_window: *sdl.Window) {
    window = sdl_window;
    init_instance(renderer);
}

destroy_renderer :: (using renderer: *Renderer) {
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

    assert(physical_device_count == 1, "There are more than one GPU, deal with that!");

    physical_device = physical_devices[0];
    vkGetPhysicalDeviceProperties(physical_device, *properties);
}

init_surface :: (using renderer: *Renderer) {
    ok := sdl.Vulkan_CreateSurface(window, instance, vk_allocator, *surface);
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

    }
}

#import "Vulkan";
#import "Vulkan_Memory_Allocator";
#import "Basic";
#import "String";
sdl :: #import "SDL3";
#import,file "common.jai";
