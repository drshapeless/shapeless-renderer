AppState :: struct {
    window: *SDL_Window;
    renderer: Renderer;
    solid_color_system: Solid_Color_System;
    test_system: Test_System;
    camera: Camera;
    pc: Solid_Color_System.Vertex_Push_Constant;
}

app_init :: (appstate: **void, argc: s32, argv: **u8) -> SDL_AppResult {
    state := New(AppState);
    using state;
    log("Initializing SDL...");
    ok := SDL_Init(.VIDEO);
    assert(ok, "cannot init SDL");

    log("Creating SDL Window...");
    window = SDL_CreateWindow("shapeless", 800, 600, .RESIZABLE | .VULKAN);
    assert(window != null, "cannot create window %", to_string(SDL_GetError()));

    init_renderer(*renderer, window);

    appstate.* = state;

    init_solid_color_system(*solid_color_system, *renderer);
    init_test_system(*test_system, *renderer);
    init_camera(*camera, get_aspect_ratio(*renderer));
    translate(*pc.model, .{0.5, 0.0, 0.0});
    // pc.view = camera_view(*camera);
    // pc.proj = camera_projection(*camera);
    // pc.proj.coef[1][1] *= -1;
    log("model %", pc.model);
    log("view %", pc.view);
    log("proj %", pc.proj);

    return .CONTINUE;
}

app_event :: (appstate: *void, event: *SDL_Event) -> SDL_AppResult {
    if event.type == {
    case .QUIT;
        #through;
    case .WINDOW_CLOSE_REQUESTED;
        return .SUCCESS;
    case .KEY_DOWN;
        if event.key.key == {
        case SDLK_ESCAPE;
            return .SUCCESS;
        }
    }
    return .CONTINUE;
}

app_iter :: (appstate: *void) -> SDL_AppResult {
    state := cast(*AppState)appstate;
    using state;
    set_clear_color(*renderer, float.[1, 1, 0.5, 1]);

    if begin_draw(*renderer) {
        cmd := renderer.cmd;
        // vkCmdBindPipeline(cmd, .GRAPHICS, solid_color_system.pipeline);
        // vkCmdPushConstants(cmd, solid_color_system.pipeline_layout, .VERTEX, 0, size_of(Matrix4) * 3, *pc);
        // vkCmdPushConstants(cmd, solid_color_system.pipeline_layout, .FRAGMENT, size_of(Solid_Color_System.Vertex_Push_Constant), size_of(Vector4), *TEST_COLOR);
        vkCmdBindPipeline(cmd, .GRAPHICS, test_system.pipeline);
        vkCmdPushConstants(cmd, test_system.pipeline_layout, .VERTEX, 0, size_of(Matrix4), *pc.model);
        vkCmdPushConstants(cmd, test_system.pipeline_layout, .FRAGMENT, size_of(Matrix4), size_of(Vector4), *TEST_COLOR);

        bind_model(*renderer.builtin_models.square, cmd);
        draw_model(*renderer.builtin_models.square, cmd);

        end_draw(*renderer);
    }
    return .CONTINUE;
}

app_quit :: (appstate: *void, result: SDL_AppResult) {
    state := cast(*AppState)appstate;
    using state;
    VK_CHECK(vkDeviceWaitIdle(renderer.dev));
    destroy_test_system(*test_system, *renderer);
    destroy_solid_color_system(*solid_color_system, *renderer);
    destroy_renderer(*renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    free(state);
}

#scope_file
#import "SDL3";
#import "Renderer";
#import "Basic";
#import "Math";
#load "render_systems.jai";
#load "camera.jai";

TEST_COLOR :: Vector4.{0.3, 0.2, 0.7, 1.0};
