AppState :: struct {
    window: *SDL_Window;
    renderer: Renderer;
    solid_color_system: Solid_Color_System;
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

    // TODO: WIP
    vertex_buffer := create_buffer(*renderer, size_of(Solid_Color_System.Vertex) * 3, .VERTEX_BUFFER, .GPU_ONLY);


    if begin_draw(*renderer) {
        cmd := renderer.cmd;

        vkCmdBindPipeline(cmd, .GRAPHICS, solid_color_system.pipeline);
        vkCmdPushConstants(cmd, solid_color_system.pipeline_layout, .FRAGMENT, sizeof(Solid_Color_System.Vertex_Push_Constant), sizeof(Solid_Color_System.Fragment_Push_Constant), *RED);
        vkCmdDraw(cmd, 3, 1, 0, 0);

        end_draw(*renderer);
    }
    return .CONTINUE;
}

app_quit :: (appstate: *void, result: SDL_AppResult) {
    state := cast(*AppState)appstate;
    using state;
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
#load "render_systems.jai";

VV :: Solid_Color_System.Vertex.[.{.{0.5, 0.5, 0}}, .{.{-0.5, 0.5, 0}}, .{.{0.5, -0.5, 0}}];

RED :: Vector4.{1, 0, 0, 1};
