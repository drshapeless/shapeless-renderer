AppState :: struct {
    window: *SDL_Window;
    renderer: Renderer;
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
        end_draw(*renderer);
    }
    return .CONTINUE;
}

app_quit :: (appstate: *void, result: SDL_AppResult) {
    state := cast(*AppState)appstate;
    using state;
    destroy_renderer(*renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    free(state);
}

#scope_file
#import "SDL3";
#import "Renderer";
#import "Basic";
