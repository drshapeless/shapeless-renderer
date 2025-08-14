OUTPUT_EXECUTABLE_NAME := "shapeless-renderer";

#run {
    set_build_options_dc(.{do_output = false});

    root_options := get_build_options();
    cpu_target := CPU;
    os_target  := OS;
    log("Compiling for % %", os_target, cpu_target);

    w := compiler_create_workspace("Target workspace");
    options := get_build_options(w);
    copy_commonly_propagated_fields(root_options, *options);
    options.cpu_target = cpu_target;
    options.os_target  = os_target;
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;

    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("src/main.jai", w);

    message_loop();

    compiler_end_intercept(w);
}

message_loop :: () {
    while true {
        message := compiler_wait_for_message();
        if message.kind == {
            case .PHASE;
            ;
            case .ERROR;
                exit(1);

            case .COMPLETE;
                break;
        }
    }
}

#import "Basic";
#import "Compiler";
#import "File_Utilities";
