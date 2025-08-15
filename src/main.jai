sdl :: #import "SDL3";
#import "Basic";
#import "Vulkan";
#import "Renderer";

main :: () {
    ok := sdl.Init(.VIDEO);
    if !ok {
        log("cannot init sdl");
        return;
    }
    log("sdl initialized");
    defer sdl.Quit();

    window := sdl.CreateWindow("shapeless", 800, 600, .RESIZABLE | .VULKAN);
    if window == null {
        log("cannot create window %", to_string(sdl.GetError()));
        return;
    }
    defer sdl.DestroyWindow(window);

    log("window created");

    renderer: Renderer;
    renderer_init(*renderer);
}
