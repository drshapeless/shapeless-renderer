// This file is from https://github.com/overlord-systems/jai-sdl3
// Slightly modified by drshapeless
// Now it supports SDL_image and SDL_ttf, not sure if that is the best thing to do.

#run build();

build :: () {

    set_build_options_dc(.{do_output=false});

    options := get_build_options();

    if !generate_bindings() {
        compiler_set_workspace_status(.FAILED);
        return;
    }
}

generate_bindings :: () -> bool {
    include_path : string;
    output_filename: string;
    opts: Generate_Bindings_Options;

    {
        #if OS == .WINDOWS {

            output_filename = "windows/windows.jai";
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            FOOTER :: #string EOF
#if CPU == .X64 {
    sdl3 :: #library,no_dll "bin/x64/SDL3";
} else #if CPU == .ARM64 {
    sdl3 :: #library,no_dll "bin/arm64/SDL3";
}
EOF
            // DLL provided by user not in bin, so use our own footer not generated library declaration
            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            #if CPU == .X64 {
                array_add(*opts.library_search_paths, "windows/bin/x64");
            } else #if CPU == .ARM64 {
                array_add(*opts.library_search_paths, "windows/bin/arm64");
            } else {
                assert(false, "the CPU % is currently unsupported. You might be able to add support for it though!", CPU);
            }

            array_add(*opts.libraries, .{filename="SDL3"});

        } else #if OS == .LINUX {
            include_path = "/usr/include";
            output_filename = "linux/linux.jai";
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            FOOTER :: #string EOF
libsdl3 :: #library,system "libSDL3.so.0";
EOF;
            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            array_add(*opts.libraries, .{filename="libSDL3.so.0"});

            array_add(*opts.path_fragments_to_treat_as_non_system_paths, "SDL3");
        } else #if OS == .MACOS {
            output_filename = "macos/macos.jai";
            include_path = "/opt/homebrew/include";
            opts.strip_flags = .FUNCTIONS_WITH_VALIST;

            FOOTER :: #string EOF
libsdl3 :: #library,system "libSDL3";
EOF;
            array_add(*opts.library_search_paths, "/opt/homebrew/lib");

            opts.footer = FOOTER;
            opts.generate_library_declarations = false;

            // We need the .a to bind but .dylib is used in runtime.
            array_add(*opts.libraries, .{filename="libSDL3.dylib"});
        } else {
            assert(false, "the OS % is currently unsupported. You might be able to add support for it though!", OS);
        }

        array_add(*opts.include_paths, include_path);
        array_add(*opts.source_files, sprint("%/SDL3/SDL.h", include_path));
        array_add(*opts.source_files, sprint("%/SDL3/SDL_vulkan.h", include_path));

        array_add(*opts.strip_prefixes, "SDL_");

        opts.visitor = sdl3_visitor;
        opts.generate_compile_time_struct_checks = false;
    }

    return generate_bindings(opts, output_filename);
}

event_type_decl: *Enum;

sdl3_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {

    // if parent_decl return .RECURSE;

    if array_find(DECLARATIONS_TO_OMIT, decl.name) {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    if decl.kind == .ENUM {
        en := cast(*Enum)decl;
        if en.name == "SDL_EventType" {
            event_type_decl = en; // Save for later
        }
    }

    // Here we replace the Uint8 type to SDL_EventType enum
    if parent_decl && parent_decl.kind == .STRUCT && ends_with(parent_decl.name, "Event") && decl.kind == .DECLARATION && decl.name == "type" {
        type := New(CType);
        type.type_of_enum = event_type_decl;
        type.size = event_type_decl.type.size;
        decl.type = type;
    }

    if parent_decl == null && decl.kind == .TYPEDEF {
        // We handcraft our window flag.
        if decl.name == "SDL_WindowFlags" {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }

        // Also handcraft init flag.
        if decl.name == "SDL_InitFlags" {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }
    }

    // Remove the init flag define.
    if parent_decl == null && begins_with(decl.name, "SDL_INIT_") {
        decl.decl_flags |= .OMIT_FROM_OUTPUT;
        return .STOP;
    }

    // We cannot have the same name as the type in a function
    // declaration.

    // When we stripped the SDL_ prefix, those MemoryFunctions fucked
    // up, because originally it was declare like this
    /// (malloc_func: *SDL_malloc_func),
    // and now it is like this
    /// (malloc_func: *malloc_func).

    // The following replaces the parameter name from _func to _function
    if parent_decl && parent_decl.kind == .FUNCTION && ends_with(parent_decl.name, "MemoryFunctions") {
        if ends_with(decl.name, "_func") {
            new_name := replace(decl.name, "func", "function");
            decl.output_name = new_name;
        }
    }

    return .RECURSE;
}

#scope_file

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Check";
#import "Bindings_Generator";
#import "File";
#import "String";

DECLARATIONS_TO_OMIT :: string.[
    "_m_prefetch",
    "__debugbreak",

    /*
    Those are force inlined functions defined in the headers, so they don't appear in the library and so bindings generator complains.

    One way is to automatically remove inline, compile them into a DLL, and turn them into #c_call jai procs. However, this loses inline.

    The performant way is to rewrite them in pure jai code, however that introduces overhead of ensuring they are updated.
    */
    "SDL_size_mul_check_overflow",
    "SDL_size_mul_check_overflow_builtin",
    "SDL_size_add_check_overflow",
    "SDL_size_add_check_overflow_builtin",
    "SDL_SwapFloat",
    "SDL_MostSignificantBitIndex32",
    "SDL_HasExactlyOneBitSet32",
    "SDL_RectToFRect",
    "SDL_PointInRect",
    "SDL_RectEmpty",
    "SDL_RectsEqual",
    "SDL_PointInRectFloat",
    "SDL_RectEmptyFloat",
    "SDL_RectsEqualEpsilon",
    "SDL_RectsEqualFloat",
];
