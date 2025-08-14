#import "Vulkan";
#import "SDL";
#import "Basic";

main :: () {
    ok := SDL_Init(SDL_INIT_VIDEO);
    if !ok return;
    defer SDL_Quit();

    log("SDL initialized");

    window := SDL_CreateWindow("shapeless renderer", 800, 600, SDL_WINDOW_VULKAN);
    if window == null {
        log("Cannot create SDL window %", SDL_GetError());
    }
    defer SDL_DestroyWindow(window);

    log("window created");

    renderer := SDL_CreateRenderer(window, null);
    if renderer == null {
        log("Cannot create SDL renderer %", SDL_GetError());
    }
    defer SDL_DestroyRenderer(renderer);

    log("renderer created");

    is_running := true;
    e: SDL_Event;
    while is_running {
        while SDL_PollEvent(*e) {
            if e.type == {
            case .QUIT;
            #through;
            case .WINDOW_CLOSE_REQUESTED;
            is_running = false;
            case .KEY_DOWN;
            is_running = false;
            }
        }

        SDL_RenderClear(renderer);
        SDL_RenderPresent(renderer);
    }
}
