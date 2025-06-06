package main

import "core:log"
import SDL "vendor:sdl3"

Renderer :: struct {
    window: ^SDL.Window,
    device: ^SDL.GPUDevice,
}

renderer_init :: proc(self: ^Renderer) {
    self.window = SDL.CreateWindow(
        "shapeless renderer",
        800,
        600,
        {.VULKAN, .RESIZABLE},
    )
    if self.window == nil {
        log.fatalf("Cannot create window %s\n", SDL.GetError())
    }

    self.device = SDL.CreateGPUDevice({.SPIRV}, true, "vulkan")
    if self.device == nil {
        log.fatalf("Cannot create GPU device %s", SDL.GetError())
    }

    ok := SDL.ClaimWindowForGPUDevice(self.device, self.window)
    if !ok {
        log.fatalf("Cannot claim window for GPU device %s", SDL.GetError())
    }
    SDL.GPUGraphicsPipelineCreateInfo

}

renderer_destroy :: proc(self: ^Renderer) {
    SDL.ReleaseWindowFromGPUDevice(self.device, self.window)
    SDL.DestroyGPUDevice(self.device)
    SDL.DestroyWindow(self.window)
}
