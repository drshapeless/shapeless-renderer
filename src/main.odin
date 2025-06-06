package main

import "core:log"

main :: proc() {
    context.logger = log.create_console_logger(log.Level.Debug)

    app: App
    app_init(&app)
    defer app_destroy(&app)

    app_run(&app)

}
