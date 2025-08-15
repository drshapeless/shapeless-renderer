sdl :: #import "SDL";
#import "Basic";

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
        log("cannot create window %", sdl.GetError());
        return;
    }
    defer sdl.DestroyWindow(window);


    log("window created");


}
