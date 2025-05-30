package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:reflect"
import sdl "vendor:sdl3"

main :: proc() {
    context.logger = log.create_console_logger(log.Level.Debug)

    ok := sdl.Init(sdl.INIT_VIDEO)
    if !ok {
        log.fatalf("Cannot initialize SDL %s\n", sdl.GetError())
    }
    defer sdl.Quit()

    window := sdl.CreateWindow(
        "shapeless renderer",
        800,
        600,
        sdl.WINDOW_RESIZABLE,
    )
    if window == nil {
        log.fatalf("Cannot create window %s\n", sdl.GetError())
    }
    defer sdl.DestroyWindow(window)


    running := true
    for running {
        e: sdl.Event
        for sdl.PollEvent(&e) {
            #partial switch e.type {
            case .QUIT:
                fallthrough
            case .WINDOW_CLOSE_REQUESTED:
                running = false
            case .KEY_DOWN:
                switch e.key.key {
                case sdl.K_ESCAPE:
                    running = false
                }
            }
        }

        window_surface := sdl.GetWindowSurface(window)
        if window_surface == nil {
            log.fatalf("Cannot get window surface %s\n", sdl.GetError())
        }

        swap_surface := sdl.CreateSurface(
            window_surface.w,
            window_surface.h,
            window_surface.format,
        )
        defer sdl.DestroySurface(swap_surface)

        for y in 0 ..< swap_surface.h {
            for x in 0 ..< swap_surface.w {
                data := cast([^]u32)swap_surface.pixels
                data[x + y * swap_surface.h] = 0xffff00ff
            }
        }

        sdl.BlitSurface(swap_surface, nil, window_surface, nil)
        sdl.UpdateWindowSurface(window)
    }


    fmt.fprintf(os.stdout, "Hello world!\n")
}
