package main

import "core:c"
import "core:os"
import "core:strings"
import sdl "vendor:sdl3"

main :: proc() {
    c_args := make([]cstring, len(os.args))
    defer delete(c_args)

    for arg, i in os.args {
        cstr, _ := strings.clone_to_cstring(arg)
        c_args[i] = cstr
    }
    defer for arg in c_args {
        delete(arg)
    }

    sdl.EnterAppMainCallbacks(
        cast(c.int)len(os.args),
        raw_data(c_args),
        app_init,
        app_iter,
        app_event,
        app_quit,
    )
}
