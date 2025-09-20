#import "SDL3";
#import "Basic";
#import "Vulkan";
#import "Renderer";

main :: () {
    log("Initializing SDL...");
    ok := SDL_Init(SDL_INIT_VIDEO);
    if !ok {
        log("cannot init sdl");
        return;
    }
    defer SDL_Quit();

    log("Creating SDL Window...");
    window := SDL_CreateWindow("shapeless", 800, 600, SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN);
    if window == null {
        log("cannot create window %", to_string(SDL_GetError()));
        return;
    }
    defer SDL_DestroyWindow(window);

    renderer: Renderer;
    init_renderer(*renderer, window);
    defer destroy_renderer(*renderer);
}
