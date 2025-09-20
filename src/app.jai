AppState :: struct {
    window: *SDL_Window;
    renderer: Renderer;
}

app_init :: (appstate: **void, argc: s32, argv: **u8) -> SDL_AppResult {
    state := New(AppState);
    using state;
    log("Initializing SDL...");
    ok := SDL_Init(SDL_INIT_VIDEO);
    assert(ok, "cannot init SDL");

    log("Creating SDL Window...");
    window = SDL_CreateWindow("shapeless", 800, 600, SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN);
    assert(window != null, "cannot create window %", to_string(SDL_GetError()));

    init_renderer(*renderer, window);

    appstate.* = state;

    return .CONTINUE;
}

app_event :: (appstate: *void, event: *SDL_Event) -> SDL_AppResult {
    return .CONTINUE;
}

app_iter :: (appstate: *void) -> SDL_AppResult {
    // TODO: When it works, return .CONTINUE
    return .SUCCESS;
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
