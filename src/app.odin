package main

import "base:runtime"
import "core:c"
import "core:log"
import "core:mem"
import sdl "vendor:sdl3"

Appstate :: struct {
    ctx:      runtime.Context,
    device:   ^sdl.GPUDevice,
    window:   ^sdl.Window,
    pipeline: ^sdl.GPUGraphicsPipeline,
}

app_init :: proc "c" (
    appstate: ^rawptr,
    argc: c.int,
    argv: [^]cstring,
) -> sdl.AppResult {
    context = runtime.default_context()
    context.logger = log.create_console_logger()

    ptr1, err1 := mem.alloc(size_of(Appstate))
    if err1 != .None {
        log.errorf("Cannot allocate memory for appstate {}", err1)
        return .FAILURE
    }

    appstate^ = ptr1
    state := cast(^Appstate)ptr1

    state.ctx = context

    ok := sdl.Init({.VIDEO})
    if !ok {
        log.errorf("Cannot init SDL {}", sdl.GetError())
        return .FAILURE
    }

    state.device = sdl.CreateGPUDevice({.SPIRV}, true, nil)
    if state.device == nil {
        log.errorf("Cannot create gpu device {}", sdl.GetError())
        return .FAILURE
    }

    state.window = sdl.CreateWindow("shapeless", 800, 600, {.RESIZABLE})
    if state.window == nil {
        log.errorf("Cannot create window {}", sdl.GetError())
        return .FAILURE
    }

    ok = sdl.ClaimWindowForGPUDevice(state.device, state.window)
    if !ok {
        log.errorf("GPUClaimWindow failed {}", sdl.GetError())
    }

    log.info("successfully initialized SDL")

    return .CONTINUE
}

app_event :: proc "c" (appstate: rawptr, event: ^sdl.Event) -> sdl.AppResult {
    #partial switch event.type {
    case .QUIT, .WINDOW_CLOSE_REQUESTED:
        return .SUCCESS
    case .KEY_DOWN:
        switch event.key.key {
        case sdl.K_ESCAPE:
            return .SUCCESS
        }
    }

    return .CONTINUE
}

app_iter :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    return .SUCCESS
}

app_quit :: proc "c" (appstate: rawptr, result: sdl.AppResult) {
    state := cast(^Appstate)appstate
    context = state.ctx

    sdl.ReleaseWindowFromGPUDevice(state.device, state.window)
    sdl.DestroyWindow(state.window)
    sdl.DestroyGPUDevice(state.device)
    sdl.Quit()

    mem.free(state)
    log.destroy_console_logger(context.logger)
}
