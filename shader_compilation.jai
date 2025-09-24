compile_shaders :: () -> bool {
    at := current_time_monotonic();
    start_time := to_float64_seconds(at);

    #if OS == .LINUX {
        shader_compiler := "glslc";
    } else #if OS == .MACOS {
        shader_compiler := "/opt/homebrew/bin/glslc";
    } else {
        #assert false "Vulkan shader compilation is not supported in this platform";
    }

    for file_list("shaders") {
        if ends_with(it, ".vert") || ends_with(it, ".frag") {
            if !compile_shader(shader_compiler, it, "shaders") {
                return false;
            }
        }
    }

    end_time := to_float64_seconds(current_time_monotonic());
    log("Shader compilation succeeded in % seconds", end_time - start_time);

    return true;
}

compile_shader :: (shader_compiler: string, shader_path: string, output_directory: string) -> bool {
    filename := path_filename(shader_path);

    output_path := tprint("%/%.spv", output_directory, filename);
    compiler_command := string.[shader_compiler, shader_path, "-o", output_path];
    log("Compiling % to % (%)", filename, output_path, get_quoted_command_string(compiler_command));
    result := run_command(..compiler_command);
    if result.exit_code != 0 {
        return false;
    }

    return true;
}

#import "Process";
#import "File_Utilities";
#import "File";
#import "Basic";
#import "String";
