sdl :: #import "SDL3";
#import "Basic";
#import "Vulkan";
#import "Renderer";

main :: () {
    log("Initializing SDL...");
    ok := sdl.Init(.VIDEO);
    if !ok {
        log("cannot init sdl");
        return;
    }
    defer sdl.Quit();

    log("Creating SDL Window...");
    window := sdl.CreateWindow("shapeless", 800, 600, .RESIZABLE | .VULKAN);
    if window == null {
        log("cannot create window %", to_string(sdl.GetError()));
        return;
    }
    defer sdl.DestroyWindow(window);

    renderer: Renderer;
    init_renderer(*renderer, window);
    defer destroy_renderer(*renderer);
}
