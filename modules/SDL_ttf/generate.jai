#run build();

build :: () {
    set_build_options_dc(.{do_output=false});

    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;

    output_filename = "SDL_ttf.jai";

    #if OS == .LINUX {
        opts.strip_flags = .FUNCTIONS_WITH_VALIST;

        array_add(*opts.libraries, .{filename = "libSDL3_ttf.so.0"});
    } else #if OS == .MACOS {
        opts.strip_flags = .FUNCTIONS_WITH_VALIST;

        array_add(*opts.library_search_paths, "/opt/homebrew/lib");

        array_add(*opts.libraries, .{filename="libSDL3_ttf.dylib"});
    } else {
        assert(false, "the OS % is currently unsupported. You might be able to add support for it though!", OS);
    }

    array_add(*opts.include_paths, "include");
    array_add(*opts.source_files, "include/SDL3_ttf/SDL_ttf.h");

    opts.visitor = visitor;
    opts.generate_compile_time_struct_checks = false;

    array_add(*opts.strip_prefixes, "TTF_");

    return generate_bindings(opts, output_filename);
}

visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    return .RECURSE;
}

#import "Basic";
#import "Compiler";
#import "Bindings_Generator";
#import "File";
