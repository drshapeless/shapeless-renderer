main :: () {
    SDL_EnterAppMainCallbacks(app_init, app_iter, app_event, app_quit);
}

#load "app.jai";
