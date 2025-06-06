package main

import "core:log"
import SDL "vendor:sdl3"

App :: struct {
    running:  bool,
    renderer: Renderer,
}

app_init :: proc(self: ^App) {
    ok := SDL.Init(SDL.INIT_VIDEO)
    if !ok {
        log.fatalf("Cannot initialize SDL %s\n", SDL.GetError())
    }


    self.running = true

    renderer_init(&self.renderer)
}

app_destroy :: proc(self: ^App) {
    renderer_destroy(&self.renderer)

    SDL.Quit()
}

app_run :: proc(self: ^App) {
    for self.running {
        e: SDL.Event
        for SDL.PollEvent(&e) {
            #partial switch e.type {
            case .QUIT:
                fallthrough
            case .WINDOW_CLOSE_REQUESTED:
                self.running = false
            case .KEY_DOWN:
                switch e.key.key {
                case SDL.K_ESCAPE:
                    self.running = false
                }
            }
        }
    }
}
